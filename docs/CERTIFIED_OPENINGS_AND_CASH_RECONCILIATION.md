# Certified opening positions and physical cash reconciliation

**2026-11-05 activation update:** canonical78 is now hosted-applied; focused read-only postflight PASS,22 existing-table fingerprints preserved and all seven new tables empty. The exact application/migration implementation and completed local test results are unchanged. Frontend publication is pending the Product Owner's manual push of the isolated release commit; no new deployment is claimed. The local/unapplied statements below record the preceding implementation checkpoint and are superseded only for database activation. [Actual release result](CERTIFIED_OPENINGS_RELEASE.md).

2026-11-05 — local implementation; migration78 is prepared, **not hosted-applied**. The Product Owner reports the preceding Financial Operations release published at `945b725`. That implementation is reused. Read-only linked verification confirms canonical77; current feature publication is not authorized.

## Reused foundation and operator entry

The Treasury Accounts workspace contains the new opening/count register. Existing Custody and Financial Evidence workspaces link to it. Company/auth authority, approved themes, professional bilingual UI, CUS-03/CUS-04, configured Partner controls, immutable journal/reversal primitives, recorded-funds guards, and Excel/printable PDF infrastructure are reused. No parallel money ledger or direct browser journal write exists. Existing ad hoc `CASH_COUNT` evidence remains explicitly unapproved evidence; it is not silently converted into a certified reconciliation.

## Supported opening positions

- Actual Company Cash and Bank Treasuries, including GL lines carrying employee/Project dimensions. Bank balances are not physical cash counts.
- Configured Custody control by authoritative holder, pooled across Projects, without creating Project cost.
- Separately configured Partner current, documented loan, capital and additional-capital controls, by authoritative Partner.
- Explicit ordinary nondimensional Asset/Liability/Equity counterpart positions with verified source evidence. Unsupported system/subledger accounts, Revenue and Expense accounts cannot be selected as a balancing shortcut.

The accountant records source, reason, evidence, an opening date, accounting month/period authorization and desired debit/credit positions. The opening date is the end of the pre-cutover position; subsequent operations follow it. Supported financial dates follow the existing kernel's year2000 minimum and cannot be future dated. Existing recorded CLOSED correction months cannot be bypassed; this is not a new general fiscal-close engine.

The server resolves controls from Company configuration and captures exact posted history through the opening date. It stores target, existing position, derived delta and history hash per scope. Both the declared positions and their deltas must balance independently. Missing historical counterpart/P&L carry-forward evidence therefore blocks that schedule instead of generating current-year income, Expense, suspense or artificial funding. New drafts create **no journal**.

Accounting Admin reviews server-derived amounts and explicitly confirms evidence, period and legitimate counterparts. One canonical journal recognizes only the evidenced difference. An already recorded position can be certified with **no new journal**; prior activity is not recognized again. This is scoped certification, not a claim that all Company openings or books are complete. Draft/reversed schedules remain distinctly labelled in UI and exports.

Normalized request hashes, natural document-ID approvals and Company serialization protect retries/concurrent approvals. Changed history rejects stale reviews. Active certifications cannot overlap the same account/holder scope. A Company cutover remains consistent even after reversal. Existing journal dates/history are never changed.

After certification, every canonical journal-line insert participates in the same serialization boundary and cannot backdate into a certified scope. Nondimensional Treasury scope includes lines with optional employee/Project dimensions; a different `party_id` cannot bypass the cutover. Other dates/scopes retain existing business/authorization rules.

## Corrections and opening loan principal

A specialized immutable opening reversal is allowed before later dated scoped activity, subject to existing funds and period controls. Reversal retains the original and exact journal lineage; a corrected schedule uses fresh evidence at the same cutover. Later scoped activity blocks opening cancellation, including where activity has subsequently reversed: this increment does not invent a forward reclassification policy for consumed openings.

Documented opening loans have their own bounded principal-payment and exact reversal workflow. Payment debits the configured Partner loan liability and credits the actual Treasury, without new funding, cost or dividends. Dated original principal, existing repayments/reversals, the actual recorded Partner credit and Treasury funds are enforced atomically. Existing document-scoped operational loans cannot be recast as opening debt; those require loan-level reconciliation. Existing obligations remain settleable without imposing the new-recognition commercial gate; new opening recognition does require commercial readiness. Capital returns, interest, dividends and debit/overdrawn Partner openings remain unsupported.

## Physical count and review

Cash counts record Company, actual location, responsible person, timezone-qualified timestamp, exact physical amount, source, explanation, supporting evidence and optional unposted support. Custody counts are holder-specific; Treasury counts accept actual CASH only. A count document can cover distinct holders/locations, while duplicate source recognition in the same money scope is prevented.

The immutable GL snapshot includes all applicable posted lines **through the Dubai posting date**, captured when the evidence is recorded. Treasury snapshots include Payroll/employee-tagged lines and require existing Payroll visibility. This is a date-based book comparison, not reconstructed intraday cash at the physical timestamp. Timing differences must be explained; full bank matching is not claimed.

Physical cash, recorded Custody receivables, personal expenditure and reimbursement liabilities remain separate. Unposted support is not added to GL or physical cash. Signed difference is counted minus recorded GL. Neither recording nor reviewing a count creates a journal or arbitrarily changes a balance.

Accounting Admin appends one of: match approved, difference reviewed (still unresolved), or more evidence required. A match requires zero difference, no outstanding unposted support and an unchanged GL fingerprint. Newly recorded journals dated on/before that as-of date mark even an approved count **STALE**. The original evidence/review remains immutable; prepare a fresh reconciliation. An unexplained shortage never automatically becomes Expense, employee debt or a reimbursement claim. Existing authorized source/reversal workflows remain the route for supported corrections.

## Statements and exports

The actual Treasury movement and Custody reconciliation modules distinguish certified opening deltas from operating receipts/funding, preserving exact GL closing reconciliation. A custody Expense consumes its holder balance once; settlements add no cost, returns do not reverse Project cost, and personal reimbursements are not netted against Custody. Existing separate Partner statements include opening/repayment journal trace and configured classification.

English and Arabic RTL Excel/PDF reports include Company identity, relevant record dates, source/evidence/approval references, posted versus unposted/reversed status, target and existing amounts, derived deltas, separate balanced schedule totals, physical/GL differences, snapshot freshness, count review audit, loan principal outstanding/payments and reversal lineage. Historical/uncertified coverage remains explicit. Existing Excel precision protection rejects unrepresentable numeric cells instead of rounding; exact PDF remains available. Totals are per schedule/account/obligation, not misleading sums across unrelated or reversed evidence.

## Authorization and database boundary

Existing Accountant/Admin may capture evidence and repay supported opening loans. Accounting Admin approves/reverses openings, reviews counts and reverses payments; the same authorized operator may perform the workflow. No new role or permission is introduced. Management Viewer remains read-only for permitted statements/holder counts; mixed opening schedules and Treasury snapshots are withheld without Payroll visibility. Company/actor authority comes from PostgreSQL, never the active URL/context alone.

Seven new tables force Company RLS and immutable evidence triggers, with no browser direct INSERT/UPDATE/DELETE. Specialized commands use fixed search paths, constrained business inputs, authoritative dimensions, source uniqueness, exact BIGINT/numeric money, canonical balanced journals and transactional serialization. Boolean-only public RLS/freshness helpers expose no privileged ledger payload; authenticated USAGE of the private schema is not granted. Generic snapshot/period/journal helpers remain private; public RPCs have no anonymous EXECUTE. The count register is a security-invoker view.

Migration78: `20261105090000_certified_opening_cash_reconciliation.sql`. It adds domain tables/commands/read view and a journal-line cutover guard. No applied migration, existing record, balance, Company, Auth identity, membership or subscription is changed or backfilled by this feature batch. Activating78 later changes reachable insertion guards but creates no opening/count/payment data automatically. No new environment variable or deployment configuration is needed; an unapplied workflow fails closed while existing routes remain available.

## Verification and status

Final evidence is in [certified-opening-verification.json](certified-opening-verification.json). Reproducible focused scripts cover actual canonical SQL, historical preservation, normalized retries, zero/duplicate/stale opening plans, GL reconciliation, source/role/tenant denial, immutable evidence, principal payments/reversals, real native lock waits, repeatable-read serialization, browser lost-response recovery, bilingual responsive UI and real Excel/PDF artifacts. Fixtures are synthetic and local; native PostgreSQL tests are not a Supabase backup restoration.

32 focused SQL/business/actual-report/schema-grant checks,7 independent native concurrency checks,14 real browser checks and4 generated Excel/PDF inspections PASS. Production TypeScript/Vite build PASS; focused lint exits0 with three informational warnings (two test-string escaping warnings and a monotonic generation-ref cleanup warning). Existing large-bundle warning remains. Read-only linked CLI dry-run PASS and lists only78; no activation occurred. Whitespace and changed-file secret/private-key scans PASS. Hosted canonical77 alignment was verified READ ONLY. No78 activation, hosted business mutation, commit, push, deployment, real Maker import or comprehensive operational acceptance was performed.

Remaining boundaries: complete Company-wide certified trial balance/carry-forward, unsupported source subledgers/analytic historical cases, consumed-opening forward correction, generic fiscal open/close, Bank statement matching, exact intraday reconstruction, external evidence authenticity and integrated Maker operational acceptance. Full disaster-recovery verification remains at the final readiness milestone under the unchanged Product Owner risk-based policy; this batch performs no restoration experiment.

## Files changed

- `NARVO_ERP_ACCOUNTING_REQUIREMENTS_REGISTER.md`
- `NARVO_ERP_MASTER_ROADMAP_V2.0.md`
- `PROJECT_HANDOFF.md`
- `PROJECT_ROADMAP.md`
- `docs/CERTIFIED_OPENINGS_AND_CASH_RECONCILIATION.md`
- `docs/CUSTODY_OPERATIONS.md`
- `docs/CUSTODY_RECONCILIATION.md`
- `docs/FINANCIAL_OPERATIONS_INTEGRATION.md`
- `docs/V1_TREASURY_MASTER_PROVISIONING.md`
- `docs/certified-opening-verification.json`
- `scripts/fixtures/priority-financial.tsx`
- `scripts/opening-reconciliation-fixture.mjs`
- `scripts/priority-financial-browser-server.mjs`
- `scripts/production-boundary.mjs`
- `scripts/verify-certified-opening-browser.mjs`
- `scripts/verify-certified-opening-exports.py`
- `scripts/verify-certified-opening-races.mjs`
- `scripts/verify-certified-opening.mjs`
- `src/app/TenantReadyApplication.tsx`
- `src/financial/CustodyWorkspace.tsx`
- `src/financial/FinancialEvidenceWorkspace.tsx`
- `src/financial/OpeningReconciliationWorkspace.tsx`
- `src/financial/openingReconciliation.ts`
- `src/reports/CustodyReconciliation.tsx`
- `src/reports/TreasuryMovements.tsx`
- `src/reports/custodyReconciliation.ts`
- `src/reports/partyStatement.ts`
- `src/reports/treasuryMovements.ts`
- `supabase/migrations/20261105090000_certified_opening_cash_reconciliation.sql`
