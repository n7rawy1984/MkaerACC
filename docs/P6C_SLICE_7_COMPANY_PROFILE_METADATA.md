# P6C Slice 7 — Company Profile Metadata UPDATE — VERIFIED COMPLETE

2026-09-16 — **VERIFIED COMPLETE**, including user-completed authenticated hosted browser acceptance and final fixture cleanup. P6C remains IN PROGRESS; P6D/P6E and Slice 8 remain NOT STARTED. Closure authorizes one local commit only; no push. This documentation closure records accepted evidence without rerunning verification.

## Recovery and exact starting state (historical)

The resumed run inspected `AGENTS.md`, binding phase documentation, git status/stat/full diff/untracked files, and the actual linked Development migration/catalog state before further edits. HEAD and origin/main were both `6b18823535bbd4f9cfba77c7c94fd5b69ca8b3fd` (ahead 0 / behind 0). Nine tracked files were modified and four files were untracked. All belonged to the authorized partial Slice 7 work; none was discarded, reset, regenerated, or duplicated.

| File already present at resume | Recovery classification |
|---|---|
| `src/master/companyProfileMutations.ts` (untracked) | Complete implementation shape; verification pending |
| `src/master/CompanyProfileForm.tsx` (untracked) | Complete four-field form; interaction verification pending |
| `src/master/CompanyProfilePanel.tsx` (untracked) | Partial; subsequent Chromium proved Close focus restoration needed completion |
| `supabase/migrations/20260916120000_p6c_company_profile_metadata.sql` (untracked) | Complete proposed migration; not applied at resume |
| `src/master/ProductionMasterDataProvider.tsx` | Complete operation shape; lifecycle/recovery verification pending |
| `src/master/masterTypes.ts` | Complete action/model integration |
| `src/auth/AuthContext.tsx` | Complete scoped legal-name synchronization shape; race verification pending |
| `src/auth/ProtectedApplication.tsx` | Complete route/provider callback integration |
| `src/app/TenantReadyApplication.tsx` | Complete navigation/profile panel integration |
| `src/i18n/en.ts`, `src/i18n/ar.ts` | Complete bilingual keys |
| `scripts/verify-p6c-boundary.mjs` | Complete initial Company-writer allowlist extension |
| `scripts/verify-p6c-behavior.mjs` | Partial adapter wiring; missing Company writer mock caused module-resolution failure; Company tests not yet added |

Slice 7 documentation, hosted/concurrency scripts, and Company Chromium coverage had not started. No material scope conflict was found. The existing implementation was retained.

Fresh `migration list --linked` showed 29 matched versions and local-only `20260916120000`. A separate live catalog check confirmed the new function absent, only `companies_set_updated_at` present, baseline authenticated table UPDATE still present, and global Companies/settings 14/14. Thus no Slice 7 schema application was present at resume. Earlier catalog checks were read-only; there was no persisted Slice 7 fixture. Current-state checks cannot reconstruct arbitrary past rolled-back queries and do not claim to.

After resume, existing files changed only in `scripts/verify-p6c-behavior.mjs` (adapter completion and tests), `src/master/CompanyProfilePanel.tsx` (focus completion), and official documentation (`PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`, `docs/P4_AUTHORIZATION.md`). Added this document, `docs/verification/p6c-slice7/`, `scripts/fixtures/p6c-company-profile-interactions.tsx`, and `scripts/verify-p6c-company-profile-interactions.mjs`. The existing migration was applied unchanged; no second migration was created.

## Business and authorization contract

Existing active Company only: edit/clear `legal_name`, `trn`, `address`, `notes`. Normalization uses JavaScript String.trim's exact whitespace set at both repository and DB boundaries; blank becomes NULL. Internal text, Unicode, case, line breaks and leading-zero TRNs remain text. There is no added uniqueness, jurisdiction rule or length cap.

Existing `company.manage` permits ACCOUNTING_ADMIN and SYSTEM_ADMIN only with active same-Company membership, active profile and active Company. SYSTEM_ADMIN gains no cross-tenant or financial authority. All five other roles, inactive authority, unrelated tenants and anonymous users cannot update.

No Company create/delete/status/id/code/name mutation, settings/branding/slug/domain/locale mutation, membership/role/profile/assignment administration, other master mutation, financial command, journal, balance or P6D flow was added. Controlled synthetic verification fixtures use trusted setup/teardown; they are not product mutation paths.

## Applied canonical database change

Migration `20260916120000_p6c_company_profile_metadata.sql` was the only selected dry-run item and was applied through `supabase db push --linked --yes` only to positively identified MakerACC-Development. It is now immutable. SHA-256 at application/checkpoint: `628128dbab3a4e6e51378a66a8a5fad40fee6c36b82a0d646d61dc884522af62`.

- Authenticated UPDATE is restricted to the four metadata columns. No table-wide UPDATE or INSERT/DELETE/TRUNCATE; an effective privilege assertion catches inherited/residual column grants.
- Forced RLS and `companies_update_config_admin` USING/WITH CHECK remain unchanged, as do permission maps and FKs.
- Only Company's timestamp trigger is replaced. The Company-local invoker function has fixed empty search_path and no direct EXECUTE for PUBLIC/anon/authenticated/service_role. Shared `set_updated_at()` and other tables' triggers are untouched.
- UPDATE preserves creation provenance, derives authenticated updated_by from auth.uid(), preserves trusted updated_by, normalizes metadata and sets `greatest(clock_timestamp(), OLD.updated_at + interval '1 microsecond')`, including trusted/no-op updates.
- Trusted INSERT/defaults and supplied historical provenance remain unchanged. There is no backfill or stored-data rewrite during migration.
- Existing trusted service_role grant extras remain the previously documented non-blocking hardening opportunity; this slice does not widen them.

## Frontend and lifecycle

The explicit Company repository reconstructs only approved fields, filters by Company's `id` (not nonexistent `company_id`) plus exact loaded `updated_at`, and requires exactly one matching returned active Company. It never converts timestamps with Date, upserts, retries automatically, or exposes a generic mutation/RPC interface. Zero rows means conflict/unavailability; invalid, denied and uncertain errors are safe summaries.

`/company-profile` uses the existing production shell, bilingual profile panel and four-field form. Both permitted roles receive Edit; other roles retain authorized reads/refresh only. Raw values render as React text. Opening focuses and scrolls the form; closing restores Edit focus after rendering has re-enabled the button. The original pre-render focus attempt was a confirmed presentation defect corrected during verification.

Company operation state/lock/generation is independent of Supplier/category operations. Successful saves reread only Company, merge that resource, and synchronize legal name into Auth membership/active-tenant presentation. Provider keys and settings dependencies do not change; no secure loader, branding reset, settings query or whole-master reload is introduced. An overlapping older Auth authority read cannot put its old legal name back after a confirmed Company refresh; identity/membership/role/revocation checks still apply. Later fresh authority reads remain authoritative.

Conflicts/denials/uncertain writes require refresh and review. A confirmed save with a failed subsequent read remains REFRESH_ERROR through failed recovery reads; recovery performs no write. User/Company/role/session/unmount generation checks discard late results and prevent late Auth synchronization. Closing or navigating cannot undo a server commit already made in the original authorized scope. Existing snapshot/realtime limits remain.

## Verification actually performed

- Recovery build PASS after the interrupted code's earlier Arabic insertion syntax had already been corrected; no claim that the interrupted run finished all checks.
- Initial recovered P6C check failed at the missing test-adapter module injection. Adapter completion fixed that; existing Slice 1–6 behavior checks and new Slice 7 repository/provider cases subsequently PASS.
- **Hosted Slice 7: 96/96 PASS**, rollback-only. Covers exact effective grants, forced RLS/policy/permission roles, both allowed/all denied roles, cross-tenant read/write, anonymous and inactive authority, protected-field forgery, INSERT/DELETE/TRUNCATE/settings denial, normalization, NULL/Unicode/internal whitespace/long text/TRN preservation, authenticated/trusted actors, immutable creation provenance, trusted provisioning, no-op/future monotonic tokens and stale tokens.
- **Concurrent exact-token writers: PASS, affected rows 1 and 0.** Winner `Editor 1`; correct actor and advanced token independently verified. Fixture created only for this test and removed with exact-manifest/dependency guards.
- **Supplier hosted regression: 104/104 PASS. Category hosted regression: 70/70 PASS.** Both existing suites ran and rolled back.
- **Company real Chromium: PASS**, actual Auth/settings/master providers, repository, shell and form with isolated in-memory transport; no credential or hosted Auth identity. Covers click/form/save/clear/exact payload/token, focus, RTL, both allowed/all denied controls, Company-only refresh, Auth legal-name sync including overlapping authority race, stale edit, failed refresh/recovery, Alpha/Beta and delayed-save isolation, open-form role downgrade, revocation/recovery and logout. Test-harness role/language selectors and post-revocation explicit Company selection were corrected before the passing run; these were test assumptions, not production authorization defects.
- **Supplier real Chromium regression: PASS**, existing inline row panels, keyboard/focus, exact-token mutation and resource/scoped-state tests.
- Public Development DB lint: PASS, no schema errors reported.
- Final build PASS; existing >500 kB demo chunk advisory only. Lint PASS with exactly four pre-existing Fast Refresh warnings, zero errors. Final P6A/P6C boundary/behavior, `git diff --check` and focused real-secret scan across all 30 changed/new files PASS.
- Exact SQL fixture cleanup verified: Company/Auth/profile/membership fixture counts zero. Global Companies/settings **14/14**, missing **0**, orphan **0**. This was the automated-verification cleanup baseline; the user subsequently confirmed authenticated browser fixture cleanup and no stale tenant data as recorded below.
- Final local/remote migration history: 30 matched versions including Slice 7. Final linked dry-run: **Remote database is up to date**, no migrations/seeds/roles.

## Final accepted authenticated hosted browser evidence

The user completed the prepared authenticated hosted browser acceptance and supplied successful results for:

- ACCOUNTING_ADMIN Company profile mutation and SYSTEM_ADMIN same-Company mutation.
- Denied-role UI behavior; metadata update/clear; leading-zero TRN preservation.
- Real stale two-tab conflict protection and Alpha/Beta tenant isolation.
- Authority downgrade/revocation fail-closed behavior, including profile revocation to the no-company state.
- Focus/tab-return behavior; Arabic/RTL, keyboard and narrow-layout checks.
- Final fixture cleanup and absence of stale tenant data.

These are user-supplied accepted results, distinct from the previously executed hosted SQL and isolated Chromium evidence. Closure reran no build, lint, SQL, concurrency, Chromium, authenticated acceptance, migration, secret-scan or diff-check verification. No additional individual browser cases, counts, timing measurements or network traces are claimed beyond the supplied evidence. The prior automated cleanup baseline was 14 Companies/14 settings with zero missing/orphan rows; final authenticated fixture cleanup is accepted from the user without a new database query.

The earlier credential-access decision and pending-browser/fixture notes are superseded by the user's completed acceptance and cleanup. No further credential access is required for closure. No credentials are stored in the Slice 7 changes.

## Final lifecycle classification

| Lifecycle category | Classification |
|---|---|
| Business/accounting | VERIFIED: approved metadata-only semantics; no P6D/financial effects |
| Security/authorization | VERIFIED: source, hosted SQL matrix, controlled lifecycle and accepted authenticated role/tenant/revocation evidence |
| Database | VERIFIED: canonical Development application, RLS/grants/provenance/concurrency, aligned 30-version history and accepted fixture cleanup |
| Deployment | Development DB change VERIFIED; frontend release, production readiness and full pre-production audit DEFERRED; Staging/Production action NOT APPLICABLE |
| Testing | VERIFIED: accepted automated, hosted SQL, isolated Chromium and user-completed authenticated browser evidence, with the limits above |
| Documentation | VERIFIED: roadmap, handoff, authorization and Slice 7 records reconciled to accepted closure |

No material schema, authorization, accounting-boundary or migration drift was found in the accepted evidence. No P6D/financial behavior, Staging/Production action or Slice 8 work was introduced. One local closure commit is authorized; no push. Development slice completion is not production readiness.
