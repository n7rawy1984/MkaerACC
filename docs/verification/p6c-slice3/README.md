# P6C Slice 3 — temporary Development browser fixture

**CLEANUP COMPLETE — NO FIXTURE CURRENTLY PRESENT.** Slice 3 is VERIFIED COMPLETE following the user's authenticated manual acceptance. All fixture DB rows and the synthetic Auth user are removed, independently reconfirmed read-only. The manifest and setup/runbook below are historical/reusable instructions, not a live fixture. Overall P6C remains incomplete. Do not rerun create/cleanup or role scripts without a new authorized setup.

Environment: **MakerACC-Development**, linked ref `eqnzueginpkskbnqvgoc`. These files are controlled operational fixture SQL, not canonical migrations. Never execute on Staging/Production. Run complete files in the Development SQL Editor or the already-linked CLI. Check the project name/ref first; SQL identity guards are not a substitute for environment selection.

Auth identity: `dc9ad1f5-804d-4f33-ab65-5e796fec0616`, `p6c-slice3-user@example.test`. Exact ID/email match, unique ID-or-email match, and matching ACTIVE profile were verified before insert and rechecked inside creation. The password stays private; no file or command needs it. The existing profile was reused, not inserted/updated.

## Exact manifest

Every two-character suffix below expands to **`73000000-0000-4000-8000-0000000000` + suffix**. `create.sql` contains every full UUID and literal value. No randomly generated fixture UUID is used; timestamps use the actual database defaults and actor fields remain NULL.

| Resource | Suffix | Exact identity / configuration |
|---|---|---|
| Alpha Company | a1 | `P6C-S3-ALPHA`; `P6C Slice 3 Alpha`; legal name `P6C Slice 3 Alpha Synthetic LLC`; ACTIVE |
| Beta Company | a2 | `P6C-S3-BETA`; `P6C Slice 3 Beta`; legal name `P6C Slice 3 Beta Synthetic LLC`; ACTIVE |
| Alpha settings | a1 (Company PK) | slug `p6c-s3-alpha`; display `P6C S3 Alpha`; en; primary `#1d4ed8`, accent `#0891b2` |
| Beta settings | a2 (Company PK) | slug `p6c-s3-beta`; display `P6C S3 Beta`; ar; primary `#7e22ce`, accent `#c2410c` |
| Alpha membership | b1 | a1 / exact Auth user / MANAGEMENT_VIEWER / ACTIVE |
| Beta membership | b2 | a2 / exact Auth user / MANAGEMENT_VIEWER / ACTIVE |
| Alpha Project | c1 | a1 / `P6C-S3-PROJECT` / `P6C Slice 3 Assignment Project` / ACTIVE |
| Alpha assignment | d1 | a1 / c1 / exact Auth user / ACTIVE |

Both Companies have notes `Temporary P6C Slice 3 verification only`; optional business identity fields are NULL. Settings logo/favicon are NULL, using the existing brand fallback; no external assets are required. Project optional fields, including financial-value fields, are NULL. Beta has no Project, Account or Treasury.

All Accounts belong to Alpha. `e2`–`e7` have parent `e1`; `e1` and `e8` have NULL parent. Only `e7` has a system key or requires a party.

| ID suffix | Code | Exact name | Type / status | Test purpose |
|---|---|---|---|---|
| e1 | P6C-S3-1000 | P6C S3 Assets Root | ASSET / ACTIVE | Root, NULL parent/system key |
| e2 | P6C-S3-1010 | P6C S3 Cash GL — النقد | ASSET / ACTIVE | Child reference; mixed Arabic text; cash GL |
| e3 | P6C-S3-1020 | P6C S3 Petty Cash GL | ASSET / INACTIVE | Inactive child/GL |
| e4 | P6C-S3-1030 | P6C S3 Bank GL | ASSET / ACTIVE | Bank GL label |
| e5 | P6C-S3-1040 | P6C S3 Project Cash GL | ASSET / ACTIVE | GL detail hidden from Project Manager |
| e6 | P6C-S3-1050 | P6C S3 Project Bank GL | ASSET / ACTIVE | Second project Treasury GL |
| e7 | P6C-S3-1100 | P6C S3 Custody System — عهدة | ASSET / ACTIVE | `system_key=CUSTODY_ADVANCE`, `requires_party=true`; not a Treasury GL |
| e8 | P6C-S3-5000 | P6C S3 Expense Inactive | EXPENSE / INACTIVE | Non-ASSET type, inactive, NULL parent/system key |

Eight Accounts keep the parent and custody control Account separate from the five dedicated Treasury GL Accounts. This fixture is not a complete posting chart; never use it for financial commands.

All Treasury rows belong to Alpha. Each maps to its own same-Company ASSET GL Account. No opening balances, balance columns, movement, journal or transaction is created.

| ID suffix | Code / exact name | Type | GL | Project | Status / optional values |
|---|---|---|---|---|---|
| f1 | `P6C-S3-CASH` / P6C S3 Cash — نقد | CASH | e2 | NULL | ACTIVE; bank/reference/notes NULL |
| f2 | `P6C-S3-PETTY` / P6C S3 Petty Cash Inactive | PETTY_CASH | e3 | NULL | INACTIVE; bank/reference NULL; notes `Synthetic inactive reference` |
| f3 | `P6C-S3-BANK` / P6C S3 Main Bank | BANK | e4 | NULL | ACTIVE; bank `Synthetic Verification Bank`; reference `001234567890`; notes `Synthetic bank reference only` |
| f4 | `P6C-S3-PROJECT-CASH` / P6C S3 Site Cash — الموقع | PROJECT_CASH_BOX | e5 | c1 | ACTIVE; bank/reference/notes NULL |
| f5 | `P6C-S3-PROJECT-BANK` / P6C S3 Project Bank | PROJECT_BANK | e6 | c1 | ACTIVE; bank `Synthetic Project Bank`; reference `000987654321`; notes NULL |

## Applied-policy matrix

The actual Account/Treasury SELECT policies and `treasury.view` permission rows were reconfirmed before setup. Active profile/membership/Company remain required; master INACTIVE status does not exclude readable rows.

| Alpha role | Accounts | Treasury |
|---|---:|---:|
| ACCOUNTING_ADMIN | 8 | 5 |
| ACCOUNTANT | 8 | 5 |
| MANAGEMENT_VIEWER | 8 | 5 |
| PROJECT_MANAGER + ACTIVE assignment | 0 | 2: f4 and f5 only |
| PROJECT_MANAGER + INACTIVE/no assignment | 0 | 0 |
| DATA_ENTRY | 0 | 0 |
| PROCUREMENT | 0 | 0 |
| SYSTEM_ADMIN | 0 | 0 |

Beta remains MANAGEMENT_VIEWER, 0 Accounts / 0 Treasury / 0 Projects. Project Manager's visible Treasury references e5/e6 by real GL UUID, while Accounts RLS returns zero. The UI must show unavailable Account details and must not reveal their code/name. No policy surprise or schema blocker was found. Inactive Treasury/GL masters are valid for this read-only fixture; no financial command is tested or enabled.

## Scripts and execution status

- `preflight.sql`: executed read-only; exact identity/profile and all fixture UUID/code/slug/user collisions passed (zero collisions). It now fails the missing-identity guard because cleanup and Auth deletion are complete.
- `create.sql`: executed once, committed as one guarded transaction. Re-execution is prohibited and currently fails the missing-identity guard. No upsert or fallback identifiers.
- `verify.sql`: executed after creation; read-only counts and integrity assertions. Works again after cleanup. Out-of-scope tables are accessed only for the explicitly requested fixture-Company zero counts; financial row contents are never selected.
- `role-accounting_admin.sql`, `role-accountant.sql`, `role-management_viewer.sql`, `role-project_manager.sql`, `role-data_entry.sql`, `role-procurement.sql`, `role-system_admin.sql`: **retained for reuse**. Project Manager, System Admin and Management Viewer switches were exercised during the reported manual acceptance; other role runs are not claimed. Each checks exact Auth UUID/email/profile, both Company UUID/code/name identities, no unrelated user membership/assignment, and changes exactly the ACTIVE Alpha membership `b1`, with an exact affected-row assertion. Beta is not changed.
- `assignment-active.sql`, `assignment-inactive.sql`: **executed during reported manual acceptance, then fixture cleaned up**. Exact identity/Company/Project/user guards and one-row assertion; only assignment d1 changes.
- `cleanup.sql`: **executed successfully; cleanup complete**. Exact identity/email/Company/code/slug/row-count/dependency guards. Restore profile ACTIVE first if it was deliberately revoked. No CASCADE or broad deletion. The entire cleanup rolls back on any mismatch or FK failure.

Creation inserts only Companies/settings/memberships, Project/assignment, Accounts and Treasury masters. It does not change the user profile, applied RLS, grants, functions or canonical schema. Role and assignment switches are deliberate later verification actions, not automatic tests.

## Historical post-creation evidence

| Check | Verified result |
|---|---:|
| Exact Auth identity / ACTIVE profile | 1 / 1 |
| Fixture Companies / memberships / settings | 2 / 2 / 2 |
| Alpha Projects / assignments | 1 / 1 ACTIVE |
| Alpha Accounts / Treasury | 8 / 5 |
| Beta Projects / Accounts / Treasury | 0 / 0 / 0 |
| Project-scoped Treasury | 2, both on c1 |
| Invalid GL links / duplicate GL links / invalid Project links | 0 / 0 / 0 |
| Fixture financial and other out-of-scope Company-owned rows | 0 |
| Unrelated user memberships / assignments | 0 / 0 |
| Global Companies / settings | 16 / 16 (baseline 14 / 14) |
| Missing/orphan settings | 0, unchanged one-to-one integrity |

All Treasury GL Accounts are ASSET, same-Company and distinct; no reassignment occurred. At setup, both memberships were MANAGEMENT_VIEWER and the assignment ACTIVE; all are now deleted. Account/Treasury schema and canonical migration alignment/no-op dry-run were verified earlier in this same Slice 3 session; no migration file changed during fixture setup.

## Reusable browser runbook (accepted evidence below)

1. Sign in privately as `p6c-slice3-user@example.test`; select Alpha. Open `/accounts` directly and refresh: expect eight rows, root/child references, e7 system key/party requirement, inactive e3/e8 and EXPENSE mapping. Open `/treasury-accounts` directly: expect five rows, correct GL UUID/code/name, inactive petty cash, NULL bank fields, and leading-zero bank references. Check mixed Arabic/Latin text, EN/AR, RTL, narrow layout and distinct branding.
2. Execute **only** `role-project_manager.sql` when ready for this branch. Return focus to allow P6A role revalidation; verify the old snapshot disappears and the new role loads. Expect Accounts 0, Treasury exactly f4/f5. Their permanent GL UUIDs remain; e5/e6 code/name must not appear.
3. Execute `assignment-inactive.sql`, then **refresh** to force an RLS-backed master read (assignment-only changes do not invalidate snapshots on routine focus). Expect Accounts 0 / Treasury 0. Execute `assignment-active.sql` and refresh to restore 0 / 2.
4. Execute `role-system_admin.sql`, revalidate/refresh: expect 0 / 0, no financial tenant-data bypass. Restore `role-management_viewer.sql` for remaining tests: expect 8 / 5. The other four role files are available but separate redundant browser runs are not necessary for representative acceptance; policy inspection is not claimed as seven browser runs.
5. Switch Alpha → Beta: expect 0 Accounts, 0 Treasury, 0 Projects and Beta branding. Return to Alpha. With network throttling, delay Alpha reads, switch to Beta and release Alpha responses; no Alpha content may commit under Beta. Repeat with logout during pending requests. Refresh must restore only authorized context.
6. With unchanged identity/Company/role, repeatedly leave/return to the tab. Expect existing P6A authority reads only, no secure-loading regression, branding flash, master/settings reload or duplicate Account-label request. Navigating Accounts ↔ Treasury should reuse the scoped snapshots.
7. Check signed-out direct routes go to login; deferred `/journal`, `/expenses`, `/advances` and `/subcontracts/example` remain holding views when signed in. No balances or mutation controls. Inspect Network/console: no financial data/RPC request, privileged credential, cross-tenant data or unexpected error. Optionally block each Account/Treasury read to verify safe error and refresh recovery.
8. Record manual outcomes before cleanup. Overall P6C stays incomplete. No browser test is claimed by fixture creation.

## Cleanup procedure (completed for this run)

Do not clean up until manual verification is accepted and cleanup is authorized. Run complete `cleanup.sql` only in Development. It removes, in dependency-safe order:

1. Exact Project assignment.
2. Five exact Treasury rows, with ID/code/type/GL guards.
3. Exact Project.
4. Account children and non-parent Expense row before root e1, with ID/code/type/parent guards.
5. Exact memberships, settings (explicitly, without relying on the schema's Company-settings cascade), Companies, and profile.

Every deletion asserts exactly one affected row. Unexpected Company-owned data, extra user associations, changed fixture identities or surviving dependencies abort the transaction. No Auth user deletion is scripted. Run `verify.sql`: profile, fixture Companies/memberships/settings/Projects/assignments/Accounts/Treasury and out-of-scope counts must all be zero; global Company/settings counts should return to the original 14/14 if unrelated data has not changed, with zero mismatch. Auth identity should still be 1. **Only then manually delete the synthetic Auth user**, and rerun verification to confirm Auth identity is 0. Preserve unrelated/demo data and record cleanup completion here.

## Historical setup-stage lifecycle record

Fixture requirements/design, setup guards, FK/link/count integrity and fixture documentation: VERIFIED. Applied role policy discovery: VERIFIED; authenticated browser/runtime acceptance: DEFERRED. Application build/lint: NOT APPLICABLE to this fixture-only turn (application hashes unchanged; prior Slice 3 gates passed). Cleanup/switches: DEFERRED, not executed. Migration/RLS/grant change and deployment: NOT APPLICABLE. No financial data was created/changed; no Subcontracts, P6D/P6E, Staging/Production, commit or push work occurred. Construction Materials / Site Stores + Tool Custody remains future-only; existing grant hardening scope is unchanged.

## Final acceptance and cleanup — 2026-09-12

**P6C Slice 3 — VERIFIED COMPLETE.** The user supplied authenticated manual acceptance: MANAGEMENT_VIEWER saw 8 Accounts / 5 Treasury; root/child UUID and labels, CUSTODY_ADVANCE system key, requires_party=true, inactive ASSET/EXPENSE, NULL parent/system fields and Arabic text passed. All five Treasury types, permanent GL UUID/authorized labels, inactive petty cash, correct Project references, absent nullable bank fields and leading-zero references `001234567890` / `000987654321` passed without invented balances.

PROJECT_MANAGER with ACTIVE assignment saw 0 Accounts / 2 project Treasury; real GL UUIDs remained while hidden Account codes/names did not leak. INACTIVE assignment yielded 0/0; ACTIVE was restored. SYSTEM_ADMIN saw 0/0. Restoring MANAGEMENT_VIEWER recovered 8/5; Alpha→Beta showed Beta branding and 0 Projects/Accounts/Treasury without Alpha leakage. Repeated Beta tab-away/return retained the Company and presentation without secure-loading interruption, presentation-loading interruption, branding flash or stale Alpha content.

The user executed the guarded cleanup successfully, verified zero fixture database counts and global 14 Companies/14 settings with zero missing/orphan rows, then manually removed Auth user `dc9ad1f5-804d-4f33-ab65-5e796fec0616` / `p6c-slice3-user@example.test`. Final read-only Development verification independently reconfirmed all fixture counts zero and Auth absence. No fixture is currently present; operational scripts are retained as historical/reusable documentation, not live setup or migrations.

Final build, lint, P6A/P6C boundaries (including existing controlled behavior and list-rendering verification), focused credential/boundary scans and diff checks pass. Lint retains four established Fast Refresh warnings; build retains its demo chunk-size advisory. All 27 local/Development migrations align through `20260911123000`; linked dry-run is a no-op. No unrelated change or blocking defect was found. One local checkpoint is authorized; pushing remains the user's action.

Evidence limits: acceptance uses the supplied representative browser cases plus existing controlled tests and schema/source review. Separate Accounting Admin/Accountant/Data Entry/Procurement browser runs, timed browser races, error injection, exhaustive RTL/keyboard/direct-route tests and detailed network-request counts were not supplied and are not newly claimed. Pagination/realtime and assignment-only snapshot refresh limitations remain documented. The trusted service_role grant hardening note remains unchanged and non-blocking. Overall P6C remains incomplete; the next slice, Subcontracts, P6D and P6E have not started. No migration, RLS/grant change, financial-flow cutover or Staging/Production action occurred; no push.

Final lifecycle: business/accounting **VERIFIED** (read-only); security/authorization **VERIFIED** for inspected boundaries and representative authenticated acceptance; database **VERIFIED** (aligned history and cleaned fixture); testing **VERIFIED** with the explicit evidence limits above; documentation **VERIFIED**. Deployment **NOT APPLICABLE** to this checkpoint; Staging/Production and full production readiness **DEFERRED**. Development slice completion is not production readiness.
