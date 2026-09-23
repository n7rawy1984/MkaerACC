# P6D Checkpoint 2 — Treasury-funded Expense POST

Historical Checkpoint 2 record; subsequent Expense Reversal state is in [Checkpoint 3](P6D_EXPENSE_REVERSAL.md). Reversal NOT STARTED below describes Checkpoint 2 closure.

P6D **IN PROGRESS**. Expense READ **COMPLETE for Development**. Treasury-funded Expense POST **COMPLETE for Development** based on accepted focused automated and Development SQL evidence; operator smoke deferred below and non-blocking. Expense reversal **NOT STARTED**. P6C COMPLETE; P6E NOT STARTED; Production readiness DEFERRED.

Clean starting baseline: `main`, HEAD = fetched origin/main = `5e3d15474cdcf2f0f4bba8aa9bc20019595fa5f0`. No commit/push or Staging/Production action. “Production” UI means the production-mode application using MakerACC-Development, not deployment to Production.

## Contract and integration

Existing canonical P5B `private.post_expense` (`20260901120000`) through public `post_expense` wrapper (`20260903120000`), unchanged. Exact RPC arguments:

- `target_company_id`, `target_expense_date`, nullable `target_project_id`, `target_expense_category_id`, `target_description`.
- `target_net_amount_minor` decimal string; `target_vat_mode` ZERO/AUTO_5/MANUAL; nullable `target_manual_vat_amount_minor` decimal string.
- `target_funding_mode = TREASURY`, `target_treasury_account_id`, `target_paid_by_party_id = null`, nullable `target_supplier_id`.
- `target_payment_method`, `target_has_tax_invoice`, nullable `target_invoice_number`, nullable `target_notes`, stable UUID `target_idempotency_key`.

Returns one `{expense_id, expense_reference, journal_entry_id, replayed}` receipt. The local RPC type corrects generated BIGINT/null types only. Net is 1..9,000,000,000,000,000 minor units, subject to the server's gross limit. Decimal AED entry converts with BigInt; wire amounts and PostgreSQL text-projected readback remain strings. No JS Number money, VAT/gross calculation or journal construction in React. AUTO_5 and MANUAL require invoice evidence; all policy validation remains canonical.

Recognition: direct Treasury-funded Expense, not payment of a previously recognized liability. Server debits COMPANY_EXPENSE or PROJECT_COST for net, INPUT_VAT when applicable, and credits the Treasury's permanent GL account for gross. Project is analytic only. Server owns active masters, tenant dimensions, authorization, normalized hash, source uniqueness, transaction locking, atomic document/journal and immutable posted history.

`ExpenseReadPanel` adds a minimal EN/AR form only for ACCOUNTING_ADMIN/ACCOUNTANT. It uses existing Company-scoped master snapshots: active Category, optional nonclosed Project, optional active Supplier and active compatible Treasury. No master mutation/refresh, browser GL inputs, demo repository, or financial state in the master provider. Successful receipt refreshes only Expense READ; targeted Company/ID readback verifies journal linkage and displays stored amounts. Readback failure cannot trigger repost with a new key.

## Retry, authorization and limits

A frozen, allowlisted command and UUID are stored in actor/Company-scoped **sessionStorage before transmission**. This is recovery intent, not a draft or local accounting source. Duplicate sends coalesce within the tab. Lost response, reload and remount retain identical input/key. Known receipts retry reads only. Storage failure prevents a first send. A known SQL rollback on the first transmission allows re-entry; an uncertain or restored attempt stays frozen even if a later retry is rejected, because the canonical RPC validates masters before replay lookup. Blocked recovery needs operator reconciliation using the displayed request key, not a new attempt.

Keep the original tab/recovery record until resolved; closing the tab or clearing session storage loses this recovery record. Separate tabs do not share intent deduplication. Do not re-enter an uncertain expense in another tab. No claim of cross-tab business deduplication is made.

UI role gates are usability only; existing DB `accounting.post`, active profile/membership/Company checks, RLS and master validation remain authoritative. SYSTEM_ADMIN has no bypass. Parent actor/Company/role keys, Auth invalidation and session checks reject stale UI results; persisted receipts remain in the originating actor/Company scope. Authority changes continue to use P6A's existing revalidation model.

## Focused verification

- `verify-p6d-expense-post.mjs`: exact 17-field actual SDK transport payload; BIGINT limits/nulls; VAT input pass-through; both permitted/all denied UI roles; frozen persistence; simultaneous same-tab send coalescing; lost-response replay; known-receipt no-repost; first rejection versus uncertain retry; actor/storage failures; no direct financial DML/demo writes.
- `verify-p6d-expense-post-interactions.mjs`: isolated real Chromium and actual form with in-memory transport, no hosted Auth fixture: scoped selectors, exact input, lost response/reload/same key, failed readback/read-only retry, authoritative projection/filter and Expense-only refresh, roles, Company isolation, EN/AR/RTL at 390px.
- `scripts/sql/p6d-expense-post/hosted-checks.sql`: PASS on linked MakerACC-Development (`eqnzueginpkskbnqvgoc`), one rollback-only transaction using existing synthetic masters/actor. ZERO/AUTO_5/MANUAL, 101→5→106 exact rounding and three balanced account/dimension lines, maximum BIGINT, same-key single effect, changed-payload rejection, both allowed/all denied membership roles including SYSTEM_ADMIN, missing actor, cross-Company command/read denial, foreign Category rejection and authenticated own-Expense readback. Temporary role changes and every financial effect rolled back; no new Auth users or durable fixture rows.
- Directly affected Expense READ repository/hook/render regression PASS. Current P6A/P6C **static-only** boundaries PASS (67 production modules, 42 master modules, 54 demo modules). No historical P6C behavior/browser matrices.
- Build PASS; lint PASS with four pre-existing Fast Refresh warnings; existing demo chunk advisory. Focused changed-file secret scan and `git diff --check` PASS.
- Fresh post-rollback read-only integrity: Companies/settings 14/14, missing/orphan 0/0; expenses unchanged at 84 POSTED / 7 REVERSED; forced RLS and SELECT-only authenticated grants preserved.

No new DB concurrency implementation: canonical normalized idempotency reservation and row locking were source-reviewed; hosted same-key replay plus frontend simultaneous-send coverage ran. A new multi-connection server race suite was not run. No end-to-end authenticated browser/PostgREST acceptance is claimed; isolated SDK/UI and authenticated SQL evidence are distinct.

## Database, files and readiness

No schema/RLS/grant/accounting migration required or applied. Canonical migration files untouched; last verified alignment remains 41 from P6C closeout (not redundantly re-audited). No accounting policy changed.

Application files: new `src/financial/{TreasuryExpensePost.tsx,expensePostRepository.ts,expensePostAttempt.ts}`; updated `ExpenseReadPanel.tsx`, `expenseRepository.ts`, `src/i18n/{en,ar}.ts`. Verification: two POST runners, isolated fixture, rollback SQL, narrow READ runner adaptation. Documentation: this record, handoff, roadmap, Checkpoint 1 historical-state clarification and PRE_DEMO_UAT.

| Lens | Classification |
|---|---|
| Business/accounting | VERIFIED canonical Treasury posting and stored journal effects; reversal/other workflows NOT STARTED |
| Security/authorization | VERIFIED focused role/tenant/RLS and production/demo boundaries; unchanged DB authority |
| Database | VERIFIED rollback effects and final integrity; migration NOT APPLICABLE |
| Deployment | Development only; Staging/Production/readiness DEFERRED |
| Testing | VERIFIED focused automated and hosted SQL; short operator browser smoke DEFERRED to PRE_DEMO_UAT |
| Documentation | VERIFIED current scope, evidence and limitations recorded |

No implementation blocker. A short existing-session operator smoke should post one synthetic Treasury expense in Development, confirm stored readback and EN/AR presentation, and exercise refresh without duplicate posting. PRE_DEMO_UAT remains separate/non-blocking. Reversal, other funding, Supplier Payments, custody/subcontract flows, drafts, attachments and reports remain out of scope. Stop after Checkpoint 2; no subsequent workflow started.
