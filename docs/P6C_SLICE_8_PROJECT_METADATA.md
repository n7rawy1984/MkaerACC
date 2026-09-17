# P6C Slice 8 — Project Descriptive Metadata UPDATE — VERIFIED COMPLETE

2026-09-17 — **VERIFIED COMPLETE**, including user-completed authenticated hosted browser acceptance and exact-manifest cleanup. P6C remains IN PROGRESS; P6D/P6E NOT STARTED. One local closure commit only; no push or Slice 9.

## Selection and baseline

Started from clean `865d2bd4591dc67f962fa709b7b86bda4ddb29b4` with Slices 1–7 VERIFIED COMPLETE. Chose an existing-Project descriptive UPDATE surface: name, client_name, location, contract_number, notes. It adds practical Project maintenance without Project lifecycle/monetary writes, GL/Treasury configuration or Subcontract terms. Other Party types would reopen Supplier's shared restrictive policies and trigger; this slice leaves them intact. No generic CRUD framework.

Completed lifecycle for this slice: bounded requirements/design, implementation, focused security/DB verification and accepted authenticated browser verification. Release, production readiness and the full pre-production audit remain later gates.

## Contract

- Existing same-Company Projects only, including CLOSED: descriptive maintenance does not reopen operational activity or rewrite financial documents. No Project create/delete, id/company/code/status/date/amount mutation; no assignment administration UI, financial commands, journals, ledger entries, expenses, payments, receivables, liabilities, opening balances or hybrid financial writes.
- Existing P4 UPDATE RLS retained: ACCOUNTING_ADMIN Company-wide or PROJECT_MANAGER with active assignment. Both require active authoritative profile/membership/Company. All other roles denied; SYSTEM_ADMIN gains no bypass. SELECT/assignment semantics and helpers remain unchanged.
- Name trimmed and required, 1–200 PostgreSQL characters; frontend counts Unicode code points. Optional fields trim to NULL when blank, without invented length/uniqueness/jurisdiction rules. Internal spaces, newlines, Unicode/case and leading-zero contract identifiers preserved.
- Explicit repository sends only the five fields, company_id + id + exact loaded updated_at; exactly one matching row required. Zero rows is conflict/unavailable. No Date conversion, retry, upsert, generic RPC or caller-controlled provenance.

## Canonical database change

`20260916140000_p6c_project_metadata.sql` applied only to positively identified MakerACC-Development (`eqnzueginpkskbnqvgoc`), after baseline 30-version alignment, scoped live catalog inspection and linked single-item dry-run. No unexpected drift found. No applied migration rewritten.

Authenticated table-wide INSERT/UPDATE/DELETE/TRUNCATE revoked; UPDATE columns restricted to name/client_name/location/contract_number/notes. This deliberately narrows the historical P4 browser Project creation/status/monetary surface to the selected Slice 8 contract. Existing policies remain, but INSERT is unavailable by grant. Trusted/service INSERT/defaults/provisioning remain unchanged. Effective privilege assertions cover every actual column.

Replaces only Project's shared-timestamp trigger with `projects_prepare_metadata_update` calling `prepare_project_metadata_update()`: security invoker, fixed empty search_path, direct EXECUTE revoked from PUBLIC/anon/authenticated/service_role. Preserve created_at/created_by; authenticated updated_by derived from auth.uid(); trusted updated_by retained. Normalize descriptive fields on UPDATE and use greatest(clock_timestamp(), old.updated_at + 1 microsecond), including future/no-op tokens. Shared timestamp helper, tenant guard, forced RLS, existing constraints/FKs/permissions and all P5 objects untouched. No data backfill.

## Frontend and scope isolation

`ProjectsList` replaces the existing inline read list at `/projects` and `/`; `ProjectMetadataForm` is inline beside the selected row with populated fields, focus/scroll, cancel/success focus restoration, EN/AR and narrow layout. Denied roles receive no Edit. Project Manager controls act only on RLS-loaded rows; UPDATE independently rechecks assignment. Plain React text rendering; no browser secrets.

The provider adds an independent Project lock/generation/feedback state, reuses the established live-session and scope guards, refreshes only Projects and merges only that resource. Category/Supplier/Company states remain independent. No Auth changes, provider-key changes, branding/settings reload or persistence. Error/uncertain/conflict requires refresh/review; acknowledged commit plus failed refresh remains distinct through repeated recovery failures, without replay. Project name changes update in-memory related Project labels through the existing shared snapshot.

**Expected/intentional limitation:** assignment-only revocation is not a realtime UI signal and does not change P6A role/membership state. DB denies immediately on the next operation; explicit Projects refresh removes inaccessible rows. Existing read snapshots/pagination limitations remain. A pending request can commit in its originally authorized scope even if the browser subsequently navigates; stale results cannot repaint another scope.

## Actual verification

- Focused hosted SQL **108/108 PASS**: all column grants, forced RLS/local trigger, role/assignment/tenant matrix, protected-field forgery, INSERT/DELETE/TRUNCATE denial, normalization/NULL/Unicode/length/leading zeros, actor/creation provenance, unchanged monetary/status fields, exact stale/future/no-op tokens, inactive assignment/profile/membership/Company, anonymous denial and trusted provisioning/updates. Rollback-only. Existing synthetic Auth actor reused; no Auth user created.
- Concurrency **PASS 1/0** affected rows; Editor 1, correct actor and advanced token verified; exact guarded fixture cleanup complete. Existing actor/profile preserved.
- Repository/provider and P6C boundary/behavior PASS: allowed/denied roles, exact payload/token, invalid/conflict/uncertain results, duplicate submissions, late writes/reads across user/Company/role/session/unmount, Projects-only refresh, known-commit recovery, assignment-filtered empty snapshot and concurrent independent operations.
- New isolated real Chromium **PASS**: populated lower-row form/keyboard/focus, update/clear, exact payload/token, CLOSED descriptive update, stale conflict, read-failure recovery, both permitted roles, denied roles, assignment revoke/refresh, open-form role downgrade, delayed tenant switch, unchanged tab-return, Arabic/RTL/390px layout, profile revocation/logout. Actual UI/Auth/settings/master providers with isolated fake transport; not hosted acceptance.
- Essential regressions: Company and Supplier isolated Chromium PASS; existing Category/Supplier/Company repository/provider/role-render behavior PASS through P6C suite. No unrelated historic hosted/financial suites rerun.
- Build PASS with existing demo chunk advisory; lint **0 errors/4 existing warnings**; P6A boundary PASS. Diff check and focused real-secret scan PASS.
- All **31** migrations aligned; final linked dry-run **Remote database is up to date**, no seeds/roles/migrations; public DB lint **no schema errors**.
- Final `verify.sql`: fixture Companies/Projects/memberships/assignments **0**, browser Auth **0**; global Companies/settings **14/14**, missing/orphan **0/0**.

Initial isolated Chromium launch was blocked by sandbox loopback restrictions; the authorized escalated loopback-only run passed. No product defect or material schema/authorization/accounting/migration blocker was found. The user subsequently completed authenticated hosted browser acceptance and final cleanup, recorded below.

## Final accepted authenticated browser evidence (2026-09-17)

The user completed authenticated hosted browser acceptance successfully and supplied these accepted results:

- ACCOUNTING_ADMIN in Alpha: descriptive edits on ACTIVE and CLOSED Projects; optional clear-to-NULL; leading-zero contract number preservation; no code/status/date/financial mutation controls.
- Two-tab stale conflict protection; Alpha/Beta isolation and Beta Project mutation.
- PROJECT_MANAGER assigned-P1-only visibility/edit; assignment revocation denial and refresh removal; assignment restore.
- Denied roles: ACCOUNTANT, PROCUREMENT, DATA_ENTRY, MANAGEMENT_VIEWER and SYSTEM_ADMIN. Downgrade with an edit open removes the mutation form.
- Membership revocation fail-closed and restore; profile revocation fail-closed/no-company and restore.
- Unchanged-authority focus/tab-return; Arabic/RTL; keyboard/focus restoration; narrow viewport.
- Exact-manifest browser cleanup and final verification: fixture Companies 0, Projects 0, memberships 0, assignments 0, browser Auth 0; Companies 14, settings 14, missing 0, orphan 0.

These are user-supplied accepted results, distinct from the previously executed automated/hosted SQL and isolated Chromium evidence. No additional browser cases, measurements or traces are claimed. Closure reran no automated verification or hosted queries; final browser cleanup counts are accepted from the user. No credentials are stored. No P6D/financial behavior, Staging/Production action or Slice 9 work occurred.

[Verification README](verification/p6c-slice8/README.md) retains the fixture IDs and original procedure as historical reference. Pending-acceptance and live-fixture notes are superseded by this closure; no fixture remains live according to the accepted final verification.

## Final lifecycle classification

| Category | Classification |
|---|---|
| Business/accounting | VERIFIED: approved metadata-only behavior; no P6D/financial effects |
| Security/authorization | VERIFIED: source, hosted SQL, controlled lifecycle and accepted authenticated role/assignment/tenant/revocation evidence |
| Database | VERIFIED: canonical Development application, constraints/grants/RLS/provenance/concurrency/alignment and accepted final cleanup |
| Deployment | Development migration VERIFIED; frontend release/production readiness and full pre-production audit DEFERRED; Staging/Production action NOT APPLICABLE |
| Testing | VERIFIED: accepted automated, hosted SQL, isolated Chromium and user-completed authenticated browser evidence |
| Documentation | VERIFIED: handoff, roadmap, authorization and Slice 8 records reconciled to accepted closure |

One local closure commit authorized: `Complete P6C Slice 8 project metadata`. No push or Slice 9. Overall P6C IN PROGRESS; P6D/P6E NOT STARTED. Development completion is not production readiness.

## File manifest

Modified:

- `PROJECT_HANDOFF.md`
- `PROJECT_ROADMAP.md`
- `docs/P4_AUTHORIZATION.md`
- `scripts/verify-p6c-behavior.mjs`
- `scripts/verify-p6c-boundary.mjs`
- `src/app/TenantReadyApplication.tsx`
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/master/ProductionMasterDataProvider.tsx`
- `src/master/masterRepositories.ts`
- `src/master/masterTypes.ts`

Created:

- `docs/P6C_SLICE_8_PROJECT_METADATA.md`
- `docs/verification/p6c-slice8/README.md`
- `docs/verification/p6c-slice8/browser-authority.sql`
- `docs/verification/p6c-slice8/browser-cleanup.sql`
- `docs/verification/p6c-slice8/browser-role.sql`
- `docs/verification/p6c-slice8/browser-setup.sql`
- `docs/verification/p6c-slice8/concurrency-cleanup.sql`
- `docs/verification/p6c-slice8/concurrency-edit-1.sql`
- `docs/verification/p6c-slice8/concurrency-edit-2.sql`
- `docs/verification/p6c-slice8/concurrency-setup.sql`
- `docs/verification/p6c-slice8/concurrency-verify.sql`
- `docs/verification/p6c-slice8/hosted-checks.sql`
- `docs/verification/p6c-slice8/preflight.sql`
- `docs/verification/p6c-slice8/verify.sql`
- `scripts/fixtures/p6c-project-metadata-interactions.tsx`
- `scripts/verify-p6c-project-metadata-interactions.mjs`
- `src/master/ProjectMetadataForm.tsx`
- `src/master/ProjectsList.tsx`
- `src/master/projectMetadataMutations.ts`
- `supabase/migrations/20260916140000_p6c_project_metadata.sql`
