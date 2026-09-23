# P6D Checkpoint 4 — Supplier Payment

## Result

**COMPLETE for Development.** Production-mode `/supplier-payments` now provides Company-scoped Supplier Payment history, immutable allocations, exact outstanding Supplier Credit Expenses, Treasury-funded posting, and Accounting Admin reversal through the existing P5C commands. P6D remains **IN PROGRESS**. Expense READ, Treasury Expense POST, Expense Reversal, and Supplier Payment are complete; all other financial workflows are not started. PRE_DEMO_UAT remains separate/non-blocking. One local closure commit only; no push or Staging/Production action.

## Canonical boundary and accounting

Posting calls only `post_supplier_payment`; reversal calls only `reverse_supplier_payment`. Browser inputs are payment date, one Supplier, one active Treasury, explicit total, payment method, optional external reference/notes, unique positive Expense allocations, and one scoped idempotency UUID. BIGINT money crosses the wire as decimal strings and is never converted through JavaScript `Number`.

Outstanding is read from POSTED `SUPPLIER_CREDIT` Expenses and immutable allocations whose parent payment remains POSTED. The UI calculation is advisory and exact; the database remains authoritative for locks, allocation limits, Supplier/Company/source identity, active Treasury/Asset GL, Project-Treasury consistency, authorization, references, idempotency, and journal balance.

The canonical entry remains Dr Supplier Payable by each source Expense Project, including null Company-level Project, and Cr the Treasury permanent GL with Treasury dimension. Payment does not create Project Cost, Company Expense, or VAT. Existing liabilities remain payable after Supplier inactivation or Project closure. Reversal preserves the original document/allocations/journal, creates exact opposite lines, and restores outstanding. Expense reversal remains blocked while a POSTED payment allocation exists.

## Authorization and recovery

- READ: ACCOUNTING_ADMIN, ACCOUNTANT, MANAGEMENT_VIEWER through existing forced RLS.
- POST: ACCOUNTING_ADMIN and ACCOUNTANT through `accounting.post`.
- REVERSAL: ACCOUNTING_ADMIN through `accounting.reverse`.
- PROJECT_MANAGER, PROCUREMENT, DATA_ENTRY, SYSTEM_ADMIN, inactive/anonymous and cross-tenant paths receive no accounting bypass.

Post and reversal attempts are frozen in actor/Company-scoped `sessionStorage` before transmission. Lost responses and remounts retain the exact payload and key; same-tab duplicate sends coalesce; confirmed receipts perform readback only. A first-send SQL rejection unlocks re-entry, while uncertain/restored outcomes remain frozen for same-key reconciliation. Session loss and tenant/role remounts fail closed.

## Focused evidence

- `node scripts/verify-p6d-supplier-payment.mjs`: PASS. Exact BIGINT payloads beyond JavaScript safe integer, normalization, totals/uniqueness, role/lifecycle gates, canonical SDK RPC calls, frozen same-key recovery/replay, reversal payload, exact outstanding projections, Project-Treasury UI guards, authoritative readback hooks, and financial mutation boundary.
- `scripts/sql/p6d-supplier-payment/hosted-checks.sql`: PASS on linked MakerACC-Development in one rollback-only transaction. Partial multi-Expense allocation, POSTED-only outstanding, inactive Supplier/closed Project settlement, Company-wide and Project-specific Treasury rules, exact AP Project/null dimensions, no cost/VAT, over-allocation rejection, Expense reversal dependency, active Treasury requirement, POST and READ role matrices, tenant isolation, idempotent replay, exact reversal, and outstanding restoration passed.
- Post-rollback read-only integrity: checkpoint Expenses/Payments zero; Supplier Payments/allocations unchanged at 32/34; Companies/settings 14/14, missing/orphan 0/0.
- `npm run build`: PASS.
- `npm run lint`: PASS with four unchanged fast-refresh warnings outside this checkpoint; no new warning.
- `npm run verify:p6a-boundary` and `npm run verify:p6c-boundary`: PASS. Historical browser matrices were not rerun.
- Linked `supabase db push --dry-run`: up to date/no-op. No migration was added or applied.
- `git diff --check` and focused secret scan: PASS at final closeout.

## Files and deferred evidence

Application: `src/financial/SupplierPaymentPanel.tsx`, `SupplierPaymentPost.tsx`, `SupplierPaymentReverseAction.tsx`, Supplier Payment read/post/reversal repositories, hooks and attempt recovery modules; route wiring in `TenantReadyApplication.tsx` and `ProtectedApplication.tsx`; EN/AR dictionaries.

Verification: `scripts/verify-p6d-supplier-payment.mjs` and rollback-only `scripts/sql/p6d-supplier-payment/hosted-checks.sql`. Documentation: this record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`, and `docs/PRE_DEMO_UAT.md`.

A short existing-session real-browser smoke remains in PRE_DEMO_UAT: Accounting Admin posts one disposable partial payment, refreshes without duplication, confirms outstanding, reverses it, confirms restoration, and checks EN/AR responsive presentation. Automated and rollback-only hosted evidence are sufficient for Development checkpoint closure; this smoke is deferred/non-blocking.

## Definition of Done

| Category | State |
|---|---|
| Business/accounting | VERIFIED canonical payable settlement, dimensions, dependency and exact reversal |
| Security/authorization | VERIFIED actor, role, tenant, RLS, denied-role and no SYSTEM_ADMIN bypass boundaries |
| Database | VERIFIED unchanged P5C schema/commands, rollback effects and no-op dry-run; migration NOT APPLICABLE |
| Deployment | DEFERRED; Development only, no Staging/Production action |
| Testing | VERIFIED focused automated and rollback-only hosted evidence; operator smoke DEFERRED/non-blocking |
| Documentation | VERIFIED checkpoint, handoff and roadmap reconciled |

No implementation blocker remains. Supplier Credit Expense creation is still outside P6D: this checkpoint settles existing eligible liabilities only. Corrected Replacement Expense and every other financial workflow remain not started.
