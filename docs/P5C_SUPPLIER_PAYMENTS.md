# P5C Supplier Payments

P5C is implemented by `20260902120000_p5c_supplier_payments.sql` and forward correction `20260902123000_p5c_explicit_payment_total.sql`, applied only to synthetic-only `MakerACC-Development`.

## Domain audit and production decision

The localStorage model records one supplier-level amount, allows Treasury/Custodian/Owner funding, has no invoice allocation, generates `PAY-*` client references, and derives supplier balance from party-scoped AP journal lines. Its accounting entry is correctly Dr Supplier Payable / Cr funding and never repeats cost.

Production deliberately improves the unsafe mechanics: P5C is Treasury-only and requires explicit allocations to P5B Supplier Credit expenses. The authoritative source liability is `expenses.gross_amount_minor`, because P5B credits AP for net plus recoverable VAT. Payment method, optional external reference, and notes are retained. Project is derived per allocation, not accepted as an invented payment header dimension.

## Schema and lifecycle

`supplier_payments` stores company/reference/date/supplier/treasury/total/method/external reference/notes, `DRAFT|POSTED|REVERSED`, journal links, actors, and timestamps. `supplier_payment_allocations` stores immutable same-company payment/expense/positive amount provenance with one row per expense per payment.

Draft is internal to the atomic command. Posted economics and allocations cannot be updated or deleted. Reversal preserves the original payment, journal, and allocation rows.

## Posting and allocation accounting

`post_supplier_payment` accepts business inputs plus explicit total, allocation JSON, and idempotency UUID. It verifies authenticated `accounting.post`, same-company Supplier, active Treasury with active Asset GL, positive/matching totals, and 1–999 unique allocations.

Each source Expense is locked in UUID order. It must be `POSTED`, `SUPPLIER_CREDIT`, same company, and same Supplier. Outstanding is:

`Expense gross − allocations belonging to POSTED Supplier Payments`

Payments in `REVERSED` state do not consume outstanding. The insert trigger independently locks and rechecks each source, so trusted SQL cannot bypass the limit. Competing different payments serialize on the source Expense and cannot over-allocate.

Journal construction groups AP debits by source `project_id`, preserving company-level null and each project represented by the allocations:

- Dr Supplier Payable, Supplier party, source Project: grouped allocated amount.
- Cr selected Treasury permanent GL, Treasury dimension: total payment.

There is no Project Cost, Company Expense, or VAT line. A multi-invoice/multi-project payment has multiple AP debit groups and one Treasury credit. A project-specific Treasury may settle only liabilities from its own Project; a company-wide Treasury can settle a valid multi-project payment.

## Closed projects and inactive suppliers

P5B continues to block new cost on a closed Project and new Supplier Credit for an inactive Supplier. P5C intentionally allows settlement of a liability that was validly created earlier even if its Project is now `CLOSED` or its Supplier later becomes `INACTIVE`. Treasury must still be active because payment is a new cash/bank movement.

## References, idempotency, and reversal

References use the P5A atomic `SPAY` company/type/year sequence. The first migration's internal implementation derives the allocation total; the forward correction moves it to `private` and exposes a public wrapper that also verifies the caller's explicit total.

Canonical request hashing includes company/date/supplier/treasury/method/normalized reference/notes and allocations sorted by Expense UUID. Same key/request replays the stable result; changed payload rejects; concurrent identical calls create one document/allocation set/journal/effect.

`reverse_supplier_payment` requires `accounting.reverse` (Accounting Admin only), locks the posted Payment, calls the exact P5A reversal primitive, links the opposite journal, and changes status to `REVERSED`. AP is restored, Treasury is debited, dimensions are identical, and outstanding becomes available again. Supplier Credit Expense reversal is separately blocked while any active posted payment allocation exists.

## Authorization and tenant isolation

Both tables have forced RLS. Accounting Admin, Accountant, and Management Viewer receive company-scoped SELECT. Project Manager receives no raw payment rows because payments expose Treasury/AP activity; Procurement, Data Entry, System Admin, inactive identities, and anonymous callers also receive none.

Authenticated and service roles have table SELECT only. Only authenticated can execute the two public specialized commands, which enforce permissions internally. All P5C trigger/private implementation functions and the P5A kernel have no browser/service execution grants. Cross-company supplier, Expense, Treasury, allocation, read, and UUID-guessing paths were denied across two synthetic tenants.

## Hosted verification

All 68 checks passed:

| Cases | Coverage | Result |
|---:|---|---|
| 1–12 | Full/partial/multi-invoice/multi-project payment and exact AP/Treasury/project/party dimensions; no cost/VAT | PASS |
| 13–24 | Source/supplier/company/state/amount/total validation, outstanding reduction/final settlement, competing-payment locking | PASS |
| 25–29 | Cross/inactive Treasury, permanent GL, closed-Project and inactive-Supplier settlement | PASS |
| 30–35 | Idempotency, changed hash, concurrent identical effect, atomic references | PASS |
| 36–41 | Payment/allocation update and delete immutability | PASS |
| 42–50 | Exact reversal, state/replay/immutability, outstanding restoration | PASS |
| 51–60 | Accounting roles, denied roles, anonymous/direct-write/private-kernel denial | PASS |
| 61–64 | Two-tenant read/allocation/Supplier/Treasury isolation | PASS |
| 65–68 | Paid-expense reversal dependency, Project Manager raw-read denial, Viewer read-only, Accountant reversal denial | PASS |

Trusted verification found 32 synthetic payments/34 allocations, zero total mismatches, overallocated expenses, invalid sources, orphan links, duplicate sources, unbalanced payment journals, or cost/VAT payment lines. Forced RLS, SELECT-only table grants, authenticated-only public command grants, empty private grants, fixed empty search paths, integer financial columns, and unchanged journal grants were inspected directly.

Database lint has one harmless `warning extra`: the private implementation assigns a typed Supplier row solely for same-company/type existence validation; its status is intentionally not consumed because inactive existing liabilities remain payable. Security advisors contain the six established authorization helpers, P5B/P5C specialized command boundaries, and the pre-existing leaked-password-protection recommendation. No unintended exposure exists.

## Limitations and next boundary

P5C has no frontend integration, project-safe payment summary view, remittance document, attachments/P7 audit events, custody, subcontract, Payroll, AR/revenue, import, tenant selector, or white-label UI. Synthetic immutable fixtures remain in Development. P5 remains in progress; the next custody-related batch requires separate review and was not started.
