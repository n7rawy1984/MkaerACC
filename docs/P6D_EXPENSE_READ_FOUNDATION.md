# P6D Checkpoint 1 — Expense READ Foundation

**Expense READ — COMPLETE for Development. P6D — IN PROGRESS. Expense POST — NOT STARTED.** P6C remains COMPLETE; P6E NOT STARTED; Production readiness DEFERRED. The operator selected this checkpoint explicitly after the roadmap was found to have no prescribed first P6D workflow.

Baseline: clean `main`, HEAD = fetched origin/main = `9cc37db166a55ebe2ec5cd273bc234595ad000e9`. This checkpoint implements reads only. No migration, financial command, new Auth/browser fixture, Staging/Production action, commit or push.

## Source and accounting contract

Authoritative source: `public.expenses`, introduced by `20260901120000_p5b_expense_commands.sql`, with existing P5 financial dependencies unchanged. Live Development inspection confirms all 30 selected columns, three BIGINT money fields, forced RLS and SELECT-only authenticated/service grants. Anonymous SELECT is denied. Existing data at inspection: 84 POSTED and 7 REVERSED expenses; no data was changed.

The projection retains stored net/VAT/gross, VAT mode/invoice evidence, funding/payment mode, expense reference/date/description, nullable notes and dimensions, exact DRAFT/POSTED/REVERSED status, provenance, and both posted/reversal journal IDs. Expense ID is the stable business-source identity. There is no fabricated source field or journal lookup that could expose raw ledger details to a Project Manager. Project remains analytic; Supplier/Party, Category and Treasury references remain stable UUIDs. Hidden master names are not fetched through privileged joins.

Every monetary field is cast to PostgreSQL text before JSON decoding. The read type overrides generated numeric BIGINT types with strings. Malformed numeric responses fail closed. AED formatting splits the minor-unit string into whole/fractional digits; it does not use Number money conversion, recalculate VAT, sum a ledger balance or reconstruct journal/accounting truth. Tests cover the canonical 9,000,000,000,000,000-minor-unit maximum and a mapper-only precision sentinel above JavaScript's safe integer range; no out-of-contract hosted amount is inserted.

## Production integration

Before this checkpoint `/expenses` was a production holding route. `src/pages/Expenses.tsx` is the demo page and depends on AppDataContext, the local ExpenseForm and local money helpers. It remains unchanged and unreachable from the production graph.

`ProtectedApplication` now routes `/expenses` to the existing `TenantReadyApplication` shell with an Expenses navigation entry. `ExpenseReadPanel` supplies loading, populated, valid-empty, error/retry and read-only identity/reference details in EN/AR. It adds no posting, editing, payment or reversal controls. Other financial routes remain deferred.

`src/financial/expenseRepository.ts` owns the explicit Company-filtered projection. `useExpenseRead.ts` is a separate financial-resource hook using the existing production scoped-async pattern; financial rows are not added to the master provider. The panel is keyed by authoritative P6A user/Company/role. Scope-tagged state hides old snapshots immediately; effect cleanup and Auth event invalidation reject late responses after scope change/logout/unmount. Session checks run before and after the read. P6A remains responsible for claims and active profile/membership/Company revalidation and unmounts protected content on authority loss. Role capability is never substituted for RLS.

Reads use deterministic expense-date/ID ordering and 50-row pages with one lookahead row. The UI labels pages and has previous/next/refresh controls; it presents no partial-list total as an accounting total. Offset pages are snapshots, not a realtime or transaction-consistent report across concurrent postings. Refresh starts at the first page. Assignment-only changes follow the existing P6A model: RLS applies on the next query; an already displayed snapshot requires refresh. No stronger realtime revocation claim is made.

## Verification

- `npm run build` PASS; `npm run lint` PASS with only four existing Fast Refresh warnings. Existing demo chunk-size advisory remains.
- `node scripts/verify-p6d-expense-read.mjs` PASS: explicit projection/filter/order/paging, all 30 fields, faithful nulls/lifecycle/IDs/journal linkage, BIGINT strings and exact display, invalid/error rejection, actual Supabase SDK request construction through an in-memory transport, and fail-closed cross-Company responses.
- Controlled real-hook execution PASS: delayed Company/user/role/page/refresh races, session loss/errors, logout, unmount/unsubscribe, unchanged-scope stability and error recovery. React server rendering PASS for EN/AR loading/empty/error/populated/reversed details without financial controls.
- `npm run verify:p6a-boundary` and `node scripts/verify-p6c-boundary.mjs --static-only` PASS: 64 production modules, unchanged 42 master modules and isolated 54-module demo graph. The new optional static-only flag skips the historical master behavior runner; the default command still runs its original full checks.
- `scripts/sql/p6d-expense-read/contract.sql` ran read-only on MakerACC-Development (`eqnzueginpkskbnqvgoc`): expected schema, text projections, forced RLS and exact SELECT-only grants confirmed.
- `scripts/sql/p6d-expense-read/rls-checks.sql` ran inside a read-only transaction and rolled back: 3,864 existing profile/Company combinations matched an independent canonical role/assignment model, with 123 nonempty and 3,741 empty/denied results; all seven membership roles were present; anonymous SELECT denied. No identity, assignment, membership or financial row was created or modified.
- Focused secret scan and `git diff --check` PASS. No dependency added.

The SQL read policy permits active ACCOUNTING_ADMIN/ACCOUNTANT/MANAGEMENT_VIEWER Company reads and assigned-project PROJECT_MANAGER reads. DATA_ENTRY/PROCUREMENT/SYSTEM_ADMIN have no expense rows. Inactive profile/membership/Company and foreign-tenant access fail closed through unchanged P5/P2 helpers. Financial DML/RPCs are absent from the new module.

No historical P6C behavior/browser suite or posting/concurrency/reversal suite was rerun: the checkpoint changes no accounting command. No authenticated browser acceptance or interactive narrow-screen smoke is claimed. A short existing-session `/expenses` EN/AR/paging/refresh/tenant-switch smoke is recommended at the next operator UI review; this does not require a new fixture and is not represented as completed.

## Database and readiness

No schema/grant/RLS migration was required or applied. The last verified migration alignment remains 41 from P6C closeout; it was not redundantly re-audited here. Fresh read-only global integrity is Companies/settings 14/14, missing/orphan 0/0. No accounting history changed.

| Lifecycle lens | Classification |
|---|---|
| Business/accounting | VERIFIED faithful stored reads; financial mutation NOT APPLICABLE |
| Security/authorization | VERIFIED Company filters, live read-only RLS matrix, session/scoped async guards and isolated import graph |
| Database | VERIFIED existing schema/grants/RLS; migration NOT APPLICABLE |
| Deployment | Development only; Staging/Production and Production readiness DEFERRED |
| Testing | VERIFIED focused automated/hosted-read evidence; operator browser presentation smoke DEFERRED |
| Documentation | VERIFIED selected checkpoint and explicit scope/evidence limits recorded |

**P6D IN PROGRESS; Expense READ checkpoint COMPLETE for Development; Expense POST NOT STARTED.** Supplier Payments and Subcontract financial workflows were not started. `PRE_DEMO_UAT.md` remains separate/non-blocking. Development completion is not Production readiness.
