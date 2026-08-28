# P5B Expense Documents and Commands

P5B is implemented by `20260901120000_p5b_expense_commands.sql` and is applied only to the synthetic-only `MakerACC-Development` project. It builds on P5A without adding supplier payments, custody funding/settlement/return, subcontract flows, frontend cutover, Payroll, or import behavior.

## Domain decision and lifecycle

The current localStorage expense behavior was audited before implementation. Production supports the four current funding modes: `TREASURY`, `CUSTODIAN`, `OWNER`, and `SUPPLIER_CREDIT`; historical pooled `CASH`/`BANK` labels are not valid new funding modes. Project is optional for genuine company-level cost. Category, description, integer net amount, VAT, funding identity, optional supplier, payment method, invoice evidence, and notes are captured.

An expense has `DRAFT`, `POSTED`, or `REVERSED` status. P5B deliberately exposes no browser draft CRUD: the command creates an internal draft and posts it with its journal in one transaction. Posted economics, dimensions, provenance, and notes cannot be updated or deleted. Reversal changes only lifecycle/link metadata and preserves the original.

The local `advanceId` field remains informational and was not copied into production because no production advance parent exists yet.

## Amount and VAT rules

Money is `BIGINT` AED minor units. Gross must equal net plus VAT using overflow-safe numeric comparison. `ZERO` requires zero VAT. `AUTO_5` calculates `round(net * 5 / 100)` with PostgreSQL numeric round-half-away-from-zero. `MANUAL` requires a positive amount no greater than net.

Recoverable VAT requires `has_tax_invoice=true` and a nonblank invoice number. Without qualifying invoice evidence, VAT must be zero; any non-recoverable tax belongs in the net expense cost. This intentionally tightens the ambiguous local UI behavior and prevents unsupported input-VAT claims.

## Funding and journal entries

The command resolves accounts by stable master identity, never display names or client-provided GL IDs:

| Funding mode | Debit | Credit | Required identity |
|---|---|---|---|
| Treasury | Expense cost; recoverable VAT when applicable | Treasury's permanent GL account | Active treasury; project compatibility; payment method |
| Custodian | Expense cost; recoverable VAT when applicable | Custodian control account | Active custodian party |
| Owner | Expense cost; recoverable VAT when applicable | Owner current account | Active owner party |
| Supplier Credit | Expense cost; recoverable VAT when applicable | Supplier payable | Active supplier party |

Cost lines preserve project. Funding/payable lines preserve the relevant treasury or party dimensions. Supplier Credit requires a supplier and no treasury/paid-by party. Treasury requires a treasury and no paid-by party. Custodian/Owner require the matching active party type and no treasury.

Inactive categories, parties, or treasuries; wrong-company dimensions; closed projects; incompatible project treasuries; invalid amounts; and invalid VAT/invoice shapes are rejected before posting. Completed projects remain valid for late cost capture; closed projects do not.

## Posting, references, and concurrency

`public.post_expense` is a fixed-empty-search-path `SECURITY DEFINER` command callable only by `authenticated`. It accepts business inputs, derives the actor from Auth, checks `accounting.post`, validates every parent and amount, computes a canonical SHA-256 request hash, reserves the idempotency key, allocates an `EXP` reference, creates the document and balanced journal, links them, and completes the command atomically.

References use the P5A company/type/year counter format. Same-key/same-request retries return the original result. Same-key/changed-request calls fail. Source uniqueness and command locking ensure concurrent identical requests produce one expense and one journal.

## Reversal

`public.reverse_expense` requires `accounting.reverse`, currently granted only to `ACCOUNTING_ADMIN`. It locks the posted expense, validates tenant/state/reason/date, reserves an idempotent command, calls the private P5A reversal primitive, and atomically links the exact opposite journal and changes status to `REVERSED`. Reversal lines retain all original dimensions. Duplicate, cross-company, changed-payload, and reversal-of-non-posted attempts fail; the original journal stays immutable.

## Authorization and RLS

`expenses` has RLS enabled and forced. Its only policy is authenticated SELECT:

- `ACCOUNTING_ADMIN`, `ACCOUNTANT`, and `MANAGEMENT_VIEWER`: active-company read.
- `PROJECT_MANAGER`: assigned-project rows only; company-level and unrelated-project rows are hidden.
- `DATA_ENTRY`, `PROCUREMENT`, `SYSTEM_ADMIN`, inactive users/memberships, and anonymous callers: no rows.

The table grants `authenticated` and `service_role` SELECT only. Command execution is granted only to `authenticated`; each command performs its permission check. No browser/service role can execute the private kernel, mutate expenses directly, or write journals. Posting is available to Accounting Admin and Accountant. Reversal is Accounting Admin only.

## Hosted Development verification

All 64 numbered checks passed:

| Cases | Coverage | Result |
|---:|---|---|
| 1–7 | Treasury/company-treasury posting and cost/VAT/project/treasury dimensions | PASS |
| 8–13 | Custodian posting, control account, party/project/VAT dimensions, and no treasury | PASS |
| 14–17 | Owner posting, current account, party dimension, and no treasury | PASS |
| 18–23 | Supplier Credit plus recoverable/non-recoverable VAT treatment | PASS |
| 24–36 | VAT arithmetic/evidence, cross-company, inactive/wrong-type parents, project states, and amount guards | PASS |
| 37–42 | Idempotent replay, changed payload, concurrent single effect, and reference generation/uniqueness | PASS |
| 43–48 | Browser posted-field update and delete denial | PASS |
| 49–56 | Exact balanced reversal, preserved dimensions/state, replay, tenant guard, and immutable original journal | PASS |
| 57–60 | Accountant success; Data Entry, Procurement, Project Manager, Viewer, and System Admin post denial | PASS |
| 61–64 | Project Manager assigned-only read, anonymous denial, direct journal-write denial, and private-kernel denial | PASS |

Trusted SQL additionally found 13 synthetic company-A expenses, zero orphan posted/reversal links, zero unbalanced expense journals, and zero duplicate `EXPENSE` sources. RLS is enabled/forced; authenticated/service table privileges are SELECT-only; command grants are authenticated-only; private execution grants and unsafe search paths are empty; no financial float columns or journal privilege regressions exist.

Database lint reports no schema errors. Security advisors report the six established authenticated authorization helpers, the two intentionally callable specialized P5B commands, and the pre-existing Development leaked-password-protection recommendation. The command warnings are expected: the functions are the deliberate security boundary and perform Auth, permission, tenant, state, dimension, and idempotency checks before any owner-privileged work.

## Limitations and next boundary

P5B does not provide browser integration, editable drafts, expense attachments/audit events, supplier settlement, advances, custody reconciliation, subcontract transactions, or historical migration. Synthetic fixtures remain in Development because immutable journals/documents must not be weakened for cleanup. The next proposed batch is separately reviewed P5C Supplier Payment; P5B does not authorize it.
