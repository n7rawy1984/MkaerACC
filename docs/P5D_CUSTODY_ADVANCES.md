# P5D Custody Advance Funding

P5D is implemented by `20260903120000_p5d_custody_advances.sql`, applied only to the synthetic-only `MakerACC-Development` project.

## Domain decision

Production custody is pooled by `(company_id, custodian_id)`. `project_id` is an optional analytic dimension on the Advance and its journal lines; it is not an allocation to a particular Advance. Custodian Expenses, multiple Advances, reversals, and future returns settle through the party-scoped `CUSTODY_ADVANCE` control-account balance. No FIFO or per-Advance expense allocation was invented.

P5D funding is Treasury-only. Owner Current funding and settlement/cash return require later reviewed commands. Legacy localStorage `CASH`/`BANK` provenance is not a valid production funding choice.

## Schema and accounting

`custody_advances` stores company/reference/date/Custodian/Treasury/optional Project/amount/method/reference/notes, `DRAFT|POSTED|REVERSED`, journal links, actors, and timestamps. Composite keys enforce same-company dimensions. Posted economics and provenance are immutable; deletion is forbidden.

`post_custody_advance` requires `accounting.post`, an active same-company Custodian, an optional non-closed same-company Project, and an active same-company Treasury backed by an active Asset GL. A project Treasury may fund only its own Project. It posts atomically:

- Dr `CUSTODY_ADVANCE`, Custodian party, optional Project.
- Cr selected Treasury permanent GL, Treasury dimension, optional Project.

Funding is a balance-sheet transfer and creates no Project Cost, Company Expense, or VAT line. References use the P5A atomic `CADV` company/type/year sequence. Canonical request hashing and the financial-command registry provide replay, changed-payload rejection, and one effect for concurrent identical calls.

## Balance and P5B hardening

`private.custody_balance_minor` derives the authoritative balance from posted journal lines on the stable `CUSTODY_ADVANCE` system account filtered by company and Custodian party. It is not browser executable.

P5D moves the applied P5B Expense implementation to `private` and keeps the exact public `post_expense` signature through a security-definer wrapper. For `CUSTODIAN` funding, the wrapper locks the Custodian row, calculates gross including VAT, checks the pooled control balance, and rejects overspend before calling the original atomic implementation. The lock serializes competing Custodian Expenses so two individually valid requests cannot jointly make custody negative. Other P5B funding modes retain their prior behavior.

## Reversal

`reverse_custody_advance` requires `accounting.reverse`, locks the Advance and Custodian, and uses the exact P5A journal reversal primitive. Reversal is permitted only when the current pooled balance is at least the Advance amount. Thus an unused Advance can reverse exactly; a sole partially consumed Advance cannot be reversed until dependent custody activity is reversed or otherwise settled by a later approved workflow. The original document and both journals remain immutable.

## Authorization and tenant isolation

Forced RLS exposes company-scoped SELECT only to Accounting Admin, Accountant, and Management Viewer. Only authenticated Accounting Admin/Accountant may post; only Accounting Admin may reverse. Project Manager, Procurement, Data Entry, System Admin, and anonymous callers have neither raw Advance visibility nor command authority. Browser/service roles cannot insert, update, or delete financial rows, invoke private balance/kernel functions, or write journals.

## Hosted verification

All 66 synthetic checks passed across two companies:

| Cases | Coverage | Result |
|---:|---|---|
| 1–13 | Project/company funding, exact custody/Treasury dimensions, no cost/VAT, references, completed Project | PASS |
| 14–23 | Custodian/Treasury/Project/company/amount validation | PASS |
| 24–28 | Idempotency, changed hash, concurrent one-effect, atomic references | PASS |
| 29–32 | Direct document/journal mutation denial | PASS |
| 33–41 | P5B Custodian Expense accounting, pooled consumption, overspend and concurrent overspend prevention | PASS |
| 42–48 | Safe exact reversal, dimensions/state/replay, consumed and Accountant reversal denial | PASS |
| 49–57 | Posting-role matrix, anonymous and private-kernel denial | PASS |
| 58–64 | Second-tenant posting/read isolation and read-only policy boundaries | PASS |
| 65–66 | Advance never duplicates cost; control balance remains future settlement authority | PASS |

The linked migration history is aligned through `20260903120000`. Database lint reports only the pre-existing documented P5C unused lock-validation variable and no P5D issue. Generated TypeScript types include the new table and commands.

## Boundary

P5D adds no custody settlement/finalization, cash return, Owner Current Advance funding, Custody/Owner-funded Supplier Payment, subcontract, Payroll, AR/revenue, import, audit-event, attachment, or frontend behavior. Synthetic fixtures remain in Development. P5E Custody Settlement/Cash Return is the next separately reviewed batch and was not started.
