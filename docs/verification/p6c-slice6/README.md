# P6C Slice 6 verification — Supplier Party mutation — VERIFIED COMPLETE

## Final accepted evidence — 2026-09-16

The user completed the final database, authenticated browser and local verification externally and supplied the accepted results below. This documentation closure records that evidence; it does not claim a new execution of those checks.

- **Hosted database: 104/104 PASS.** Migration `20260913123000_p6c_supplier_party_mutations.sql` is applied to MakerACC-Development only. Local/remote migration history is aligned; final linked dry-run: **Remote database is up to date**.
- **Concurrency: PASS.** Competing creates produced one success and one SQLSTATE `23505`; competing edits from the same exact token affected **1** and **0** rows. Final state was verified and the concurrency fixture fully cleaned.
- **Authenticated browser: PASS.** ACCOUNTING_ADMIN create/edit/deactivate/reactivate; PROCUREMENT controls/deactivate/reactivate; MANAGEMENT_VIEWER read-only; non-Supplier rows without controls; Alpha/Beta isolation; duplicate rejection; two-tab stale-edit conflict; refresh recovery; role downgrade during open edit; membership revocation fail-closed; profile revocation to `/no-company`; focus/tab return without blocking “Loading securely”, unnecessary master reloads or stale tenant/branding flash; Arabic/RTL and Supplier-only rendering.
- **Local gates: PASS.** Build (only the existing Vite >500k demo-chunk advisory); lint (exactly four pre-existing Fast Refresh warnings, zero errors); Supplier Chromium interaction regression; P6A boundary; P6C boundary; P6C behavior; `git diff --check`; focused real-secret scan.
- **Cleanup: VERIFIED.** Fixture Companies/settings/memberships/Parties/profile/Auth user are all **0**. Global Companies **14**, settings **14**, missing settings **0**, orphan settings **0**. Browser cleanup used the exact generated Party UUID manifest; no broad deletes or CASCADE cleanup. Both cleanup scripts retain the PL/pgSQL ambiguity correction from `companies` to `fixture_companies`. No fixture remains live.

Business/accounting scope, security/authorization, Development database/migration, testing and documentation: **VERIFIED**. Development environment boundary and migration acceptance: **VERIFIED**. Staging/Production action: **NOT APPLICABLE** (none occurred). Frontend release, production readiness and the full pre-production audit: **DEFERRED** to their later gates. No P6D/financial mutation path was introduced; P6D remains **NOT STARTED**. Overall P6C remains **IN PROGRESS**; Slice 7 was not started.

Local frontend regression: `node scripts/verify-p6c-supplier-interactions.mjs` runs a fresh isolated Chromium profile and in-memory transport, with no real fixture or credentials. Playwright is a pinned development dependency in package.json/package-lock.json. From a clean checkout run `npm ci`, then `npx playwright install chromium` once to install the matching browser. On Linux, missing browser OS libraries may require `npx playwright install --with-deps chromium`. The test does not download browsers automatically. Optionally set `CHROMIUM_PATH` to an existing compatible browser executable. It opens a temporary localhost Vite server and closes browser/server afterward. No runtime dependency or external Playwright module path is used. Alternatively set `P6C_BROWSER_INTERACTIONS=1` for the existing P6C behavior/boundary command. Missing browser execution is explicitly reported, never counted as browser PASS.

Before this fix, the click test reproduced Edit at y=-3997 and confirmation at y=-3314 for a lower row. After fixing inline panel placement/focus, the browser suite passed real edit/status/create commands through the actual provider/repository, exact token/Parties-only refresh checks, conflict/recovery, role/scope guards and narrow RTL visibility. Final real Alpha/Beta authenticated acceptance also passed; isolated transport coverage remains separate from hosted Auth/RLS evidence.


## Archived operational procedures

The procedures and SQL templates below are retained for traceability and separately authorized future verification. The original PREPARED/NOT EXECUTED comments in SQL templates (and the migration preparation comment) describe their drafting stage, not current acceptance status; the final accepted evidence above supersedes them. Do not recreate or clean fixtures as part of closure. The applied migration is preserved byte-for-byte.

## Original environment and execution order (completed)

Only **MakerACC-Development**, project ref `eqnzueginpkskbnqvgoc`. Independently confirm the linked project's name/ref before any query or command. These scripts cannot prove the remote environment from SQL alone. Never execute this directory as a batch. Fixture scripts are operational tools, not migrations. Do not use Staging/Production, real identities, real accounting data, or prior slices' fixtures.

1. Review the implementation and the single pending `20260913123000_p6c_supplier_party_mutations.sql` migration. Confirm baseline local/applied history has 28 migrations through `20260913120000`, with no drift or unexpected pending versions. Stop on mismatch.
2. Run the read-only `preflight.sql` and retain baseline columns, grants, policies, FKs, triggers, shared timestamp function, permission mappings and global Company/settings counts. The CLI may expose only the last SELECT: execute SELECTs individually or use a client preserving all result sets. Inspect canonical versus actual metadata before applying.
3. Run build/lint and the existing P6A/P6C boundary/behavior scripts externally. Final local PASS is recorded above.
4. User-controlled Development dry-run must select only Slice 6; apply through the canonical migration workflow, never SQL Editor DDL. Post-apply history should align at 29 versions, with a no-op linked dry-run. Do not activate this frontend against the old Party grant/trigger contract.
5. Run `preflight.sql` again and `hosted-checks.sql` with stop-on-error. The latter is prepared to use actual database roles/claims in one rollback transaction. If execution stops on an exception, explicitly roll back/close the connection; never commit a partially run test. It does not create login credentials or call financial posting commands.
6. Run the separately controlled concurrency cases below, then browser acceptance. Record actual outputs and limits separately. Hosted role simulation is not authenticated browser evidence.
7. Review and authorize exact-manifest cleanup only after evidence is captured. Run final read-only verification and reconcile the phase record/handoff/roadmap. Do not mark complete before required verification and cleanup.

## Hosted checks

`hosted-checks.sql` prepares rollback-only identities/Companies/Parties and one zero-value Project/Subcontract reference fixture. It tests:

- Accounting Admin and Procurement create/edit/deactivate/reactivate; all five denied roles; anonymous and inactive profile/membership/Company.
- Protected INSERT/UPDATE columns, tenant reassignment, non-Supplier types, ownership-bearing browser upsert, DELETE/TRUNCATE denial, cross-tenant existing UUIDs.
- Unicode/whitespace normalization, nullable codes, leading-zero text, duplicate names, inactive codes, hidden Owner collision, and cross-Company code reuse.
- Browser/trusted provenance, creation immutability, exact/no-op/stale tokens; all five trusted non-Supplier branches preserve their existing text and timestamp semantics.
- Referenced Subcontractor type protection and restrictive FK behavior; full Party constraint metadata remains part of preflight/post-apply inspection.
- Financial row fingerprints and function definitions unchanged during the tests; no financial command is invoked.
- Effective exact grants, forced RLS, both restrictive type policies, three expected Party triggers (tenant guard, subcontractor guard, one timestamp owner), invoker security, empty search_path and no direct preparation EXECUTE.

Read policy regression must also compare pre/post `parties_read_sensitive_roles` definitions and exercise the browser matrix. Uniqueness failures may reveal only that the code is unavailable, never the hidden conflicting Party's name/type/UUID or raw server detail. This is a scoped verification suite, not the full pre-production audit.

## Concurrency manifest and procedure

| Object | Exact identity |
|---|---|
| Non-login synthetic Auth/profile | `76100000-0000-4000-8000-000000000001`, `p6c-s6-concurrency@example.test` |
| Company/settings | `76100000-0000-4000-8000-0000000000a1`, `P6C-S6-CONCURRENCY` |
| Initial Supplier | `76100000-0000-4000-8000-0000000000f1`, code `EDIT`, token `2000-01-01T00:00:00Z` |
| Competing-create Supplier | DB-generated UUID; exactly one normalized `RACE` row; record the returned UUID |

Run `concurrency-setup.sql` once after collision checks. Launch `concurrency-create-1.sql` and `concurrency-create-2.sql` in separate sessions with overlapping execution (session 1 waits four seconds while holding its insert). Require one success and one SQLSTATE 23505, exactly one row. A failed session must roll back/close. Then launch edit-1/edit-2 similarly from their shared exact token; capture affected-row counts **1 and 0**. Do not reinitialize/retry against modified fixtures and claim a concurrent result.

`concurrency-verify.sql` should report total=2, competing_create_rows=1, edited_rows=1. Row counts alone do not replace the two captured edit outputs. Copy the generated RACE UUID into `makeracc.created_party_ids` in the execution copy of `concurrency-cleanup.sql`, review, and run only after acceptance. The cleanup removes only this non-login identity and its verified fixture. Failure/partial setup needs focused diagnosis and an explicitly reviewed exact manifest; do not weaken guards.

## Browser manifest

Provision `p6c-slice6-user@example.test` through trusted Supabase Auth, without storing a password/token in the repository. Record its exact generated Auth UUID privately as an operational identifier; fill `makeracc.fixture_user` in an execution copy of `browser-setup.sql`. The empty default fails closed.

| Object | Exact identity |
|---|---|
| Alpha Company/settings | `76200000-0000-4000-8000-0000000000a1`, `P6C-S6-BROWSER-A` |
| Beta Company/settings | `76200000-0000-4000-8000-0000000000a2`, `P6C-S6-BROWSER-B` |
| Initial Parties | `76200000-0000-4000-8000-0000000000f1` through `...f7`, Alpha only |
| f1/f2 | Active Supplier `SUP` with TRN `001234567890123`; inactive Supplier `INACTIVE` |
| f3–f7 | OWNER / CUSTODIAN / EMPLOYEE / SUBCONTRACTOR / OTHER |
| Memberships | Confirmed actor: Alpha Accounting Admin; Beta Management Viewer |

Beta starts empty; settings have distinct colors/names. No Project/assignment/financial fixture is needed for this Supplier matrix. Record **every** Supplier UUID created through browser acceptance for cleanup. `browser-role.sql` requires the exact confirmed user and an explicit enum role, and updates only that actor's active Alpha membership; restore Accounting Admin after tests. Profile/membership/Company revocation cases need separately reviewed exact-ID operator changes and restoration, never broader updates.

## Authenticated acceptance matrix

| Actor | Party reads | Supplier mutation |
|---|---|---|
| ACCOUNTING_ADMIN | All six types | Create/edit/deactivate/reactivate |
| PROCUREMENT | Supplier/Subcontractor/Custodian/Other; no Owner/Employee | Same Supplier operations only |
| ACCOUNTANT, MANAGEMENT_VIEWER | All six types | None |
| DATA_ENTRY | Operational four types | None |
| PROJECT_MANAGER | None, with or without assignment | None |
| SYSTEM_ADMIN | None | None |
| Anonymous / inactive authority / unrelated tenant | No authorized rows | None |

Required manual cases:

1. Signed-out direct `/parties` routes to login. Sign in, Alpha list and direct reload preserve exact type/status/null/leading-zero data and branding. Beta is a valid empty list. Existing non-Supplier rendering remains intact.
2. Run both allowed roles' create/edit/deactivate/reactivate. Create has no type/status/Company/provenance fields. Inactive Supplier remains editable. Only Supplier rows have actions; no delete or financial control exists. Capture request JSON: only approved business fields and create scope; type/status creation values are absent.
3. Normalized/inactive-code duplicate rejection; Procurement collides with hidden OWNER code and sees only the generic unavailable-code message. No hidden identity/raw detail in UI. Multiple null codes and duplicate names are valid; no numeric conversion for TRN/phone.
4. Two tabs load one Supplier token. Save in A, then save stale B: conflict and explicit refresh/review required. Network preserves timestamp microseconds exactly. Double-click submits once. No automatic create retry after uncertain transport. Any uncertainty is a request to review, not proof of failure.
5. Fail the write response separately from the post-save Parties read. Confirm uncertainty versus “saved, refresh required” messages. Repeated failed refresh retains the committed-write distinction. Explicit refresh clears forms; recovery requires review. A plain refresh failure never claims a Supplier was saved.
6. Delay write/read responses across Company switch, role downgrade, logout, session loss and different-user login. Old data/feedback must not enter the new scope. Requests already committed in their original authorized Company are not undone by navigation.
7. Downgrade Alpha to Management Viewer on another trusted session, return focus: controls disappear and old form context is invalid. Check all denied roles. Revocation fails closed when detected; restore and recover through existing Auth flow.
8. Repeated unchanged tab returns preserve open form, branding and master snapshot. Network shows only P6A authority revalidation: no blocking secure loader, settings request or seven-resource reload. Successful Supplier save refreshes only Parties; category save still refreshes only categories. Switching routes during an in-flight save must not corrupt either operation state.
9. Verify EN/AR, RTL, keyboard labels/tab order, narrow layouts, Unicode and long contact text as plain text. No raw HTML/links generated from contact fields. Console has no unexpected errors. Cross-tab locale persistence behavior remains unchanged.
10. Deferred financial routes remain holding views. Network has no financial writes/RPCs. Verify demo separately without altering its existing `cas:v1:*` collections or importing production masters.

## Cleanup and final evidence

`browser-cleanup.sql` is deliberately destructive **prepared material**, not authorization to execute it now. Fill the exact browser UUID and JSON array of all generated Supplier IDs. It refuses missing/extra Party IDs, unexpected Company-owned rows, outside actor dependencies, authority mismatches, or missing settings. Delete only fixture Parties, memberships, Companies (their nonfinancial settings FK is owned), then profile. Delete the recorded Auth user through trusted Authentication administration after the database transaction commits. No cascade command or broad cleanup is used. Keep unrelated P2 fixtures intact.

`verify.sql` reports fixture absence and Company/settings integrity. Compare global counts with preflight, not an assumed 14/14; fill the recorded browser UUID in its execution copy to verify exact profile/Auth absence after Auth deletion. Clear only test Auth/tenant preferences in the browser; preserve all `cas:v1:*` keys. Append actual acceptance, cleanup, alignment and limitations to official memory only after execution.

External local checks: `npm run build`, `npm run lint`, `npm run verify:p6a-boundary`, `npm run verify:p6c-boundary`, `node scripts/verify-p6c-behavior.mjs`, focused secret scan, `git diff --check`. Boundary invokes behavior, so a separate behavior run is optional when already included and unchanged. Existing four Fast Refresh warnings/demo chunk advisory must not be reclassified as new regressions.

Verification-tool follow-up (2026-09-14): the prior external Playwright installation was an undeclared prerequisite. The repository now pins Playwright 1.62.1 as a development dependency; no existing declared dependency provided browser/layout automation. The isolated fixture uses an external store instead of mutating window during React render and exports its component for Fast Refresh. Local checks PASS: lint (exactly the four pre-existing warnings, zero errors), Supplier interaction script with the declared package and existing matching Chromium, P6C boundary, P6C behavior, and diff whitespace check. No production UI or SQL changed in that tooling follow-up. Final authenticated acceptance and cleanup are now complete as recorded above.
