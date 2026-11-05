# Certified Openings / Cash Reconciliation — production preflight

**Subsequent authorized activation — 2026-11-05:** migration78 APPLIED; hosted preservation/schema postflight PASS. The owner now performs Git publication from a prepared isolated local release; automated push credentials are not required for this handoff. This preflight is retained as the historical approval baseline. The final release includes its original30-file allowlist plus the directly necessary [actual release record](CERTIFIED_OPENINGS_RELEASE.md),31 files total. No Git push or new Vercel deployment has been performed.

2026-11-05. Read-only release preparation; no migration, hosted business write, commit, push or deployment performed.

## Decision

**Migration78: READY for separate Product Owner activation authorization. End-to-end agent-executed publication: BLOCKED by unavailable GitHub HTTPS push credentials.** Vercel API access remains403; use the existing project's dashboard for deployment verification if access remains unavailable. This is not evidence of a Production outage. Do not activate78 until an authorized publisher and the verification route are available. No implementation, financial-policy or migration defect was identified in this focused review.

## A. Migration safety and direct dependencies

- Authorized shared Supabase target: `eqnzueginpkskbnqvgoc`; project identity verified through the management API. Hosted canonical migrations1–77 match local versions, names and normalized SQL statements. Last applied: `20261104190000_operational_liability_posting`.
- Only pending migration: `20261105090000_certified_opening_cash_reconciliation.sql`.
- SHA256: `fc5304e36f0bb9a9c430b7eaf9b938ead45dab228628440a5293c0242c4865a0`.
- Fresh linked CLI dry-run, with its connection forced read-only, lists only78. No78 table/function/trigger name collision exists.
- Additive: seven new evidence/payment tables, specialized commands, read helpers/view, indexes and a journal-line insert guard. No existing data UPDATE/DELETE/backfill, existing function replacement, applied-migration edit, account creation, balance normalization or financial posting occurs at activation. Existing negative balances remain unchanged.
- Direct foundations verified: canonical Company/Auth/membership permissions; accounts/Parties/Treasuries and composite Company FKs; canonical journal/reversal primitives; commercial readiness; person roles; existing correction-period state;76's immutable evidence trigger;77's actor, serialization, classified account configuration and recorded-funds guards; pgcrypto digest. Referenced functions exist. All11 function definitions/security/grants in77's retained postflight remain unchanged; four overlapping earlier kernel/readiness/person-role/immutable definitions also match retained evidence.
- Seven forced-RLS tables, no authenticated direct writes; Company-consistent dimensions and audit actors; fixed-search-path specialized commands; no anonymous posting or generic financial primitive grants. Private-schema authenticated USAGE remains absent. Mixed openings and Treasury counts require existing Payroll visibility; permitted holder counts remain role-scoped. The register uses security-invoker reads.
- Actor derives from Auth; active Company/profile/accountant membership plus existing posting/reversal permission is required. Accounting Admin explicitly approves/reverses openings and approves counts. No new role, subscription or authentication behavior is introduced.
- Canonical journals remain balanced/immutable. BIGINT minor units and exact derived deltas; normalized actor-bound hashes, unique sources, transactional Company serialization, fresh snapshots and once-only approval/payment/reversal receipts prevent duplicate effects. Count/review creates no journal. Existing Treasury/Custody funds guards remain active, including legitimate inflows into negative balances and rejection of unfunded outflows.
- Current hosted journal imbalance count:0. Financial table counts/hashes were captured read-only as a preflight reference; refresh immediately before approved activation. No real hosted financial command or write-denial probe was run.

## Existing-client compatibility and retained verification

78 does not replace the current client's tables, RPC signatures or permissions. Before any certification, the added journal-line guard introduces serialization but no cutover restriction. After an operator certifies a scope, backdated insertions into that scope are intentionally rejected through every client version; other dates/scopes retain existing rules. The matching frontend must follow schema activation. No environment-variable, Vercel configuration or dependency/package change is required.

All29 implementation files exist, and the dirty tree exactly matches the milestone manifest. All28 externally recorded SHA256 hashes still match; the manifest JSON is the29th file. Applied1–77 files are unchanged. Completed32 SQL/business/report/schema checks,7 native race checks,14 browser checks,4 EN/AR export checks and Production TypeScript/Vite build remain applicable. They were not repeated. Focused lint previously exited0 with three informational warnings; the existing bundle-size warning remains. Current `git diff --check` passes.

Canonical Master Roadmap V2.0, requirements register, PROJECT_ROADMAP and PROJECT_HANDOFF accurately label the milestone locally implemented/verified,78 unapplied and frontend unpublished. Their top checkpoint explicitly distinguishes the owner's preceding945b725 publication report from historical release notes. Supported limits remain explicit: scoped rather than complete Company trial-balance certification; no consumed-opening forward correction, general fiscal close, bank matching, reconstructed intraday balances, automatic shortage posting or Maker import. No deferred feature was implemented during preflight.

## Recovery limitation

The existing encrypted2026-11-04 migration75 database and password-free roles exports still match both recorded ciphertext hashes and sizes. Retained evidence verifies decryption integrity, archive scope,114 table fingerprints and required schema/role coverage. This review did not decrypt them again or rehearse restoration. The backup predates76/77 and is not a current77 recovery point. Restoration is untested; role passwords, external Auth/Edge/Vercel configuration, off-site protection and Storage blobs need separate coverage. No recovery-time/success guarantee is claimed. Under the explicit Product Owner active-development policy in AGENTS.md, full restoration testing remains a final operational-readiness milestone, not an ordinary additive-release prerequisite.

Frontend rollback cannot undo78, later certifications, payments or journals. Retain the prior frontend for incident rollback; any durable database defect needs an approved forward correction. Financial corrections use supported immutable reversals subject to dependency/funds rules, never a schema DROP or history rewrite. Full database recovery requires separate authorization and intervening-write assessment.

## B. Publication access and baseline

- Local branch preserved: `release/platform-owner-console`; HEAD `945b72565e2a4912a0f08f3c9196bc6e4387b303`.
- Fresh `git ls-remote` confirms existing `n7rawy1984/MkaerACC` main equals that SHA. No remote divergence currently exists.
- GitHub's Vercel check for that SHA is success; current `https://maker-eosin.vercel.app/` responds200 with the application shell. These do not independently establish the current Production alias's exact commit/Ready deployment.
- Existing Vercel project: `maker`, ID `prj_n03DWya5Gr1uB82qtY084FvsC7q4`. Current API metadata request returns403. Prior Production/branch evidence and the owner's945b725 publication report are retained, not upgraded into fresh control-plane verification. Formal Production branch setting and exact current alias target remain dashboard-verification items.
- Noninteractive Git credential lookup fails; no HTTPS GitHub push credential is available to this agent. The Product Owner must authenticate the existing Git publishing workflow or perform the reviewed fast-forward publication. Do not place credentials in source, change remote/project settings or infer write access from public read access.
- Minimum dashboard evidence before activation: existing repository `n7rawy1984/MkaerACC`, Production branch `main`, current Ready deployment/commit and confirmation that main publishes to existing maker. After publication: exact new commit, deployment ID, Production target/alias and Ready status. API access is optional if these checks are performed in the dashboard.

## C. Exact publication allowlist

Publish the following29 unchanged milestone files, plus this preflight record (30 files total). Do not stage the whole working tree. The exact implementation hashes remain in `docs/certified-opening-verification.json`; temporary outputs, credentials, backups, .env, .temp and ignored local release artifacts are excluded.

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
- `docs/CERTIFIED_OPENINGS_RELEASE_PREFLIGHT.md`

## D. Activation and publication sequence — proposed, not executed

1. Obtain explicit Product Owner authorization for this exact78 hash and the reviewed application package. First resolve Git publishing access and confirm the existing maker dashboard repository/Production-main relationship. Coordinate a short quiet accounting window; take immediate read-only financial/business/access preservation fingerprints, including journals/lines, Expenses, accounts, Treasuries, Parties, Companies, memberships/profiles and protected Auth/MFA records. Do not change them or run synthetic hosted transactions.
2. Immediately recheck target `eqnzueginpkskbnqvgoc`, canonical77, exact78 hash, dependencies/name collisions and backup availability. Stop on any unexpected migration, drift or material change. Do not treat the old preflight fingerprints as a current activation baseline.
3. Use the established isolated canonical Supabase package containing only1–78, browser-safe config/templates and the verified local link metadata. Run the installed Supabase CLI `db push --linked --dry-run --workdir <isolated-package>`; require exactly78. After the separately approved activation gate, use `migration up --linked --workdir <isolated-package>` so only78 is pending. Never run a blanket migration push, repair history or modify1–77. Use existing private credentials/TLS; never print or copy them into Git.
4. Stop frontend publication unless read-only hosted postflight passes: exactly78 canonical history and SQL match; expected seven tables initially empty; forced RLS, no browser direct-write grants, seven authorized commands and two boolean helpers, fixed search paths, private helper protection, invoker view and enabled cutover trigger; existing77 guards retained. Compare the immediate baseline's existing financial/business/protected-access fingerprints, balances and balanced journals. Investigate any concurrent legitimate activity instead of resetting records. Verify existing Company readiness/access, including Maker legacy compatibility, through read-only predicates. Run linked dry-run again and require no pending migration. Save sanitized actual evidence.
5. Fetch existing GitHub main and verify it still has the expected baseline. In a separate release worktree based on origin/main, copy only this30-file allowlist; preserve the development branch and its uncommitted implementation. Review staged content, secrets and whitespace. If main or any reviewed implementation hash changed, stop and reconcile the actual candidate before committing. Record actual database activation in roadmap/handoff/phase evidence without claiming frontend deployment yet. Commit the reviewed release; record its full SHA. Push `HEAD:main` only as a verified fast-forward; never force-push. Re-read remote main and require the new SHA. No second Vercel project or configuration change.
6. Wait for the existing GitHub integration's maker Production deployment. Verify repository, branch main, exact pushed SHA, full deployment ID, Production alias and Ready via API or the owner's dashboard. A push, successful build/check or a login-page200 alone is insufficient. Preserve the prior Ready release for frontend incident recovery.
7. Perform non-mutating smoke checks on the actual Production alias: app/assets load, authorized sign-in/tenant access, existing Treasury/Custody/Expenses reports and the new empty-or-existing opening/count register; EN/AR and role-appropriate controls/error behavior. Do not submit opening, count, repayment or financial forms. Verify no runtime/missing-schema error; record final commit/deployment and explicit remaining limits. Financial operator acceptance and final disaster-recovery validation stay separate.

## E. Disposition

Business/accounting, focused authorization/database review, source completeness and retained local verification: VERIFIED within supported scope. Hosted alignment, dependencies, backup ciphertext integrity and read-only baseline: VERIFIED. Migration78 activation, live78 authorization/postflight, Git publication and new Vercel deployment: NOT PERFORMED / require authorization and the publication-access prerequisites above. Final disaster recovery and broader operational acceptance: DEFERRED. No Production change has been made by this preflight.
