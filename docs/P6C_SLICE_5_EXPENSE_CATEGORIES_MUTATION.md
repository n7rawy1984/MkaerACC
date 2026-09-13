# P6C Slice 5 — Expense Categories MUTATION

2026-09-13. **P6C Slice 5 — Expense Categories MUTATION — VERIFIED COMPLETE.** Implementation, automated/hosted verification, authenticated browser acceptance and disposable fixture/Auth cleanup are complete. Overall **P6C — IN PROGRESS**; this is not production readiness. Slices 1–4 remain VERIFIED COMPLETE. P6D/P6E and other master mutation slices remain unstarted.

## Approved scope and preflight

The user approved only category create, code/name/description edit, deactivate and reactivate, via direct authenticated table writes under existing RLS. No delete, upsert, bulk/generic CRUD, merging, expense recategorization, financial effect, or other entity mutation. All mutations require existing `category.manage`, mapped only to ACCOUNTING_ADMIN. SYSTEM_ADMIN has no master/browser bypass.

Started at clean `a9ca416fe4e471a50f17900b74af5cce1ad0339f`. Fresh CLI project metadata positively identified linked MakerACC-Development (`eqnzueginpkskbnqvgoc`). All 27 canonical migrations matched through `20260911123000`. Fresh read-only catalog inspection confirmed actual category columns/defaults, constraints/indexes, expense FK, forced RLS, policies, role permission, grants/inheritance, and trigger definitions matched the approved scope. No material discrepancy was found. The CLI needed sandbox escalation for its own configuration/telemetry access; no credential was printed or placed in source.

## Canonical migration and database contract

Only `20260913120000_p6c_category_mutations.sql` was created and applied, through linked `db push` after its dry-run selected only that migration and no seeds/roles. Development only; Staging/Production untouched. Do not rewrite this applied migration.

- Revoke table-wide authenticated INSERT/UPDATE on `public.expense_categories`.
- Grant INSERT only on `company_id, code, name, description`.
- Grant UPDATE only on `code, name, description, status`.
- Existing SELECT, category policies, `category.manage`, forced RLS, tenant-reassignment trigger, normalized Company/code unique index, `(company_id,id)` key and restrictive Company/actor/expense FKs remain unchanged.
- Browser creation cannot nominate ID, status, actors or timestamps. Existing defaults generate UUID and ACTIVE. Explicit INSERT status is denied even when ACTIVE.
- Drop only `expense_categories_set_updated_at`; shared `public.set_updated_at()` and other entities' triggers are unchanged.
- Add invoker-security `public.prepare_expense_category_mutation()` with fixed empty search_path and browser/service direct EXECUTE revoked. A single `expense_categories_prepare_mutation` BEFORE INSERT/UPDATE trigger owns category normalization/provenance/update token.
- At the database boundary, btrim code/name and NULLIF(btrim(description),''); preserve internal text and case, existing code/name bounds and normalized uniqueness. Inactive categories reserve their code; duplicate names remain allowed.
- `current_user = 'authenticated'` determines browser stamping, not JWT presence. Browser INSERT sets both actors from auth.uid() and both timestamps from one clock reading. Browser UPDATE derives updated_by and preserves creation provenance.
- Any UPDATE attempting to change created_by/created_at is rejected, including trusted execution. Trusted INSERT retains legitimate supplied/NULL actors and historical timestamps; trusted UPDATE retains supplied/NULL updated_by. No backfill or fabricated actor.
- Every accepted UPDATE, including trusted and no-op updates, sets `greatest(clock_timestamp(), OLD.updated_at + interval '1 microsecond')`. No other category trigger writes the token.
- Migration assertions check effective per-column privileges, including inheritance, and reject residual broad INSERT/UPDATE grants.

No additional table, application RPC, Edge Function, shared-function change, financial schema change or generated row-shape change. Trigger-return functions are not browser command APIs.

## Frontend behavior

The existing production `/expense-categories` route now integrates `ExpenseCategoriesList` and `ExpenseCategoryForm`; no new route or demo financial import. ACCOUNTING_ADMIN sees create/edit/deactivate/reactivate; other roles retain their existing read scope and no mutation controls. New-category form has no status selector. Status actions require an explicit confirmation. EN/AR messages and existing RTL/branding are preserved.

`expenseCategoryMutations.ts` is the dedicated typed direct-write boundary. It reconstructs business payloads explicitly, strips extra input fields, reuses the existing reader/mapper, filters every UPDATE by active Company + category UUID + exact loaded updated_at string, and requires exactly one matching returned row. It never converts that token through JS Date. Errors map to safe invalid/duplicate/denied/conflict/uncertain outcomes; raw server messages are not shown.

The provider/context exposes only category-specific save/refresh actions. Saves run only from READY/Accounting Admin UI scope and check live session identity before/after asynchronous work; RLS remains authoritative. In-flight locking prevents duplicate submission. User/Company/role keys, request generations, layout cleanup and session checks prevent old mutation or refresh results entering a new scope. Successful save rereads only categories. Unchanged focus still uses the established P6A background authority flow; no seven-resource reload or settings reset is added.

A zero-row UPDATE is not success. Uncertain/conflict/error outcomes block further saves until an explicit refresh and review. A failed post-save refresh is separately identified; it does not claim the committed write failed. Forms clear on explicit refresh. UI closure, navigation, switching or logout cannot undo a request already committed in its original authorized Company.

## Exact file manifest

Added:

- `supabase/migrations/20260913120000_p6c_category_mutations.sql`
- `src/master/expenseCategoryMutations.ts`
- `src/master/ExpenseCategoryForm.tsx`
- `src/master/ExpenseCategoriesList.tsx`
- `docs/P6C_SLICE_5_EXPENSE_CATEGORIES_MUTATION.md`
- `docs/verification/p6c-slice5/README.md`
- `docs/verification/p6c-slice5/hosted-checks.sql`
- `docs/verification/p6c-slice5/concurrency-setup.sql`
- `docs/verification/p6c-slice5/concurrency-create-1.sql`
- `docs/verification/p6c-slice5/concurrency-create-2.sql`
- `docs/verification/p6c-slice5/concurrency-edit-1.sql`
- `docs/verification/p6c-slice5/concurrency-edit-2.sql`
- `docs/verification/p6c-slice5/concurrency-verify-cleanup.sql`
- `docs/verification/p6c-slice5/browser-setup.sql`
- `docs/verification/p6c-slice5/verify.sql`

Changed:

- `src/app/TenantReadyApplication.tsx`
- `src/master/ProductionMasterDataProvider.tsx`
- `src/master/productionMasterDataContext.ts`
- `src/master/masterTypes.ts`
- `src/i18n/en.ts`, `src/i18n/ar.ts`
- `scripts/verify-p6c-boundary.mjs`, `scripts/verify-p6c-behavior.mjs`
- `PROJECT_ROADMAP.md`, `PROJECT_HANDOFF.md`

## Verification and evidence limits

- Build PASS, existing large demo-chunk advisory only.
- Lint PASS with exactly the existing four Fast Refresh warnings (Field, I18nContext twice, AppDataContext); initial new provider warnings were corrected before final verification.
- P6A boundary PASS. P6C boundary PASS: mutations are permitted only in the dedicated category file and only against expense_categories; other production master writes and all financial/RPC integration remain rejected.
- Standalone P6C behavior PASS: previous read/precision/scope checks plus explicit payloads, normalization, exact timestamp transport, zero/multiple/wrong-Company returned rows, safe errors, denied roles, single-resource refresh, duplicate submission, delayed save and refresh across Company/role/user/logout/unmount, unchanged-scope reads, error recovery and actual static role-gated list/form rendering.
- Hosted `hosted-checks.sql`: final **70/70** assertions PASS under actual database roles in a rolled-back transaction. Includes protected column attacks, ACTIVE default, all non-admin mutation denials, inactive authority, existing cross-tenant UUID denial, trusted/browser provenance, inactive code reservation, cross-Company codes, duplicate names, invalid values, no-op token advance, restrictive references, and unchanged expense/journal row hashes after category edits.
- Hosted competing creates: one success, one expected SQLSTATE 23505, exactly one normalized row. Competing edits: exact affected-row counts **1 and 0** from one snapshot.
- Hosted tests simulate authenticated database execution and claims; they are not password-based Auth, captured PostgREST responses, or authenticated browser acceptance.
- The internal draft reference fixture and financial comparison existed only in the rollback test; no posting command or persistent financial fixture was introduced.
- Disposable concurrency fixture and its non-login synthetic identity were verified and removed after their tests. Browser setup was separately rollback-validated before the later authorized browser fixture creation and completed cleanup recorded below.
- Focused credential scan PASS across all 25 changed/added files; diff check PASS. Final history aligns at 28/28 through `20260913120000`; linked dry-run is a no-op with no migrations/seeds/roles. One parallel CLI alignment attempt failed temporary login-role authentication; a sequential retry and final dry-run passed without credential/configuration changes. No unrelated work was found at that verification checkpoint.
- Final read-only verification reports zero Slice 5 fixture Companies/categories/Auth identities and global 14 Companies/14 settings with zero missing/orphan settings. Final catalog confirms the exact column grants, two category triggers (tenant guard plus single token owner), invoker security, empty search_path, no browser EXECUTE and unchanged shared timestamp function.

## Final accepted browser evidence — 2026-09-13

The user completed and accepted authenticated manual acceptance:

- ACCOUNTING_ADMIN list/create/edit/deactivate/reactivate: PASS.
- Normalized duplicate-code rejection: PASS.
- Optimistic concurrency stale-edit conflict: PASS.
- Beta tenant / MANAGEMENT_VIEWER read-only behavior: PASS.
- Alpha role downgrade to MANAGEMENT_VIEWER observed after revalidation; mutation controls disappeared: PASS.
- Tab-away/tab-return regression: PASS, without blocking “Loading securely” or stale tenant flash.
- Arabic/RTL: PASS.

Cross-tab locale persistence is a **non-blocking UX observation**: one tab retained English until refresh, then converged to Arabic. No Slice 5 fix is required or introduced.

## Final Development cleanup

The disposable database fixture was fully removed. Auth user `e6cac418-6739-4b66-a1ab-f7cd98bf89fc` was deleted through Supabase Authentication. Final accepted cleanup counts:

- `auth_user=0`, `profile=0`, `fixture_companies=0`, `memberships=0`.
- `global_companies=14`, `global_settings=14`.
- No missing/orphan Company settings.
- All inspected financial/out-of-scope fixture tables were zero before cleanup.

## Final accepted local and migration checks

These are the user's final accepted results, recorded during documentation closure without rerunning build/lint/database verification:

- `npm run build`: PASS; only the existing Vite >500 kB demo chunk advisory.
- `npm run lint`: PASS; 0 errors, 4 pre-existing Fast Refresh warnings.
- P6A boundary, P6C boundary, P6C behavior: PASS.
- `git diff --check`: PASS.
- All 28 local/remote migration versions aligned, including `20260913120000`.
- Linked `db push --dry-run`: Remote database is up to date.
- Focused real-secret scan: PASS.

## Evidence limits and deferred concerns

Browser PASS claims are limited to the accepted cases above; hosted SQL-role simulations and controlled automated tests are distinct evidence, not claims of separately executed exploratory browser cases.

Lists remain API-limited snapshots without pagination/realtime; assignment-only visibility changes still need a fresh query. Initial load remains aggregate fail-closed. Conditional stale-edit protection is enforced by the application request predicate, not a new general-purpose database requirement on trusted/direct SQL updates. No financial idempotency ledger or exact retry-result guarantee was added. Existing expense category status checks do not promise cancellation of an already-running posting transaction. P7 audit and full production readiness remain deferred; trusted-only service_role grant extras are unchanged.

## Lifecycle classification

- Business/accounting: **VERIFIED** for category-only behavior, preserved references and no accounting effects.
- Security/authorization: source, hosted boundaries and accepted authenticated role/tenant/revalidation behavior **VERIFIED**.
- Database: canonical Development application, hosted behavior, migration alignment and fixture cleanup **VERIFIED**; other-environment database changes **NOT APPLICABLE**.
- Testing: automated, hosted and accepted authenticated browser evidence **VERIFIED**.
- Deployment: Development migration and local Auth-mode acceptance **VERIFIED**; frontend release/Staging/Production and production readiness **DEFERRED**.
- Documentation: final evidence, cleanup and scope status **VERIFIED**.

No P6D/financial mutation path or other mutation slice was introduced. Overall P6C remains IN PROGRESS. Closure authorizes one local Slice 5 checkpoint commit only; no push or further implementation is authorized.
