# P6C Slice 8 — Project Descriptive Metadata UPDATE — VERIFIED COMPLETE

**VERIFIED COMPLETE** (2026-09-17), including user-completed authenticated hosted browser acceptance and final cleanup. Development only. P6C IN PROGRESS; P6D/P6E NOT STARTED. One local closure commit only; no push or Slice 9. See [phase record](../../P6C_SLICE_8_PROJECT_METADATA.md).

## Executed evidence

- Preflight: linked project positively identified as MakerACC-Development (`eqnzueginpkskbnqvgoc`); all 30 baseline migrations aligned. Live Project columns, constraints, triggers, grants, forced RLS and role/assignment policies matched canonical history. Global Companies/settings 14/14, missing/orphan 0/0.
- `20260916140000_p6c_project_metadata.sql`: single selected migration in linked dry-run; canonically applied to Development. Do not edit or reapply via SQL Editor.
- `hosted-checks.sql`: **108/108 PASS**, rollback-only. Existing synthetic actor reused, no Auth creation; temporary profile/membership changes rolled back. No accounting document/journal fixture.
- Concurrent `concurrency-edit-1.sql` / `concurrency-edit-2.sql`: **1/0 affected rows**, Editor 1 won; correct actor and advanced token verified. Guarded cleanup executed; reused Auth actor/profile retained untouched.
- `verify.sql`: fixture Companies/Projects/memberships/assignments and browser Auth count **0**; global Companies/settings **14/14**, missing/orphan **0/0**.
- Focused repository/provider checks: payload allowlist, normalization/Unicode name length, exact loaded token, zero-row conflicts, allowed/denied roles, late write/read isolation, selective refresh and committed-write/read-failure recovery. Shared Category/Supplier/Company essential behavior regressions pass.
- Project isolated real Chromium PASS: lower-row keyboard/focus, populated fields, edit/clear, exact payload/token, CLOSED description edit, stale conflict, selective refresh/recovery, assigned Project Manager, assignment revocation, denied roles, tenant switch/delayed save, open-form downgrade, focus/tab return, RTL/390px viewport, profile revocation/logout.
- Company and Supplier isolated Chromium regressions PASS. These use actual UI/providers with fake transport; they are not hosted authenticated browser evidence.
- Build PASS (existing demo chunk advisory); lint 0 errors/4 pre-existing warnings; P6A boundary and P6C boundary/behavior PASS. Focused real-secret scan and diff check PASS.
- Final 31 migrations aligned; linked dry-run up to date; public DB lint no schema errors.

## Authenticated fixture reference — acceptance and cleanup complete

The disposable fixture identity was `p6c-s8-browser@example.test`. Its browser Auth count is now zero in the user-supplied final verification. The scripts retain UUID placeholders for reference; passwords/tokens must never be stored. This section describes the fixture procedure, not a new setup request.

| Fixture | Deterministic ID |
|---|---|
| Alpha Company | `78200000-0000-4000-8000-0000000000a1` |
| Beta Company | `78200000-0000-4000-8000-0000000000a2` |
| Alpha ACTIVE Project P1 (assigned) | `78200000-0000-4000-8000-0000000000b1` |
| Alpha CLOSED Project P2 (unassigned) | `78200000-0000-4000-8000-0000000000b2` |
| Beta PLANNING Project P3 | `78200000-0000-4000-8000-0000000000b3` |
| P1 assignment to synthetic actor | `78200000-0000-4000-8000-0000000000c1` |

Both memberships initially ACCOUNTING_ADMIN. Alpha/Beta have distinct settings. There are no accounting documents, journals, Parties, Subcontracts or Treasury fixtures. `browser-setup.sql` checks identity/profile, migration, UUID/code/slug/assignment collisions before creating the exact manifest. Expected temporary global Companies/settings: 16/16 from the verified 14/14 baseline; verify the baseline again before setup.

`browser-role.sql` changes only Alpha's exact synthetic membership role. `browser-authority.sql` changes only the exact fixture assignment, Alpha membership or synthetic profile status; default target is assignment and default status INACTIVE. Choose target/status in the temporary copy; restore ACTIVE deliberately after each revocation test. Restoring an assignment requires active profile/membership first.

## Original authenticated acceptance procedure (historical reference only)

1. Open `/projects` (also `/`) as ACCOUNTING_ADMIN in Alpha. P1/P2 display; edit each via keyboard. Form opens beside its row with populated name/client/location/contract number/notes. Cancel restores focus. Name is required, trimmed, maximum 200 Unicode characters. Optional whitespace clears to NULL; internal spaces/newlines/Arabic persist and contract number `000123` remains text. No create/delete/code/date/status/amount controls.
2. Save descriptions on ACTIVE P1 and CLOSED P2. Verify persistence and unchanged code/status/dates/monetary fields. Network shows one `projects` UPDATE with company_id/id/exact original updated_at and only the five allowed fields, followed by Projects-only reread. No settings/all-master reload or provider remount.
3. Two tabs on the same original token: first save succeeds, second conflicts without overwriting; refresh/review before a new edit. Check unknown-network outcome is not silently retried. If simulating an acknowledged write followed by read failure, distinguish “saved, could not refresh”; recovery rereads without another write.
4. Switch Alpha/Beta and back, including while a save is delayed. P3/Beta state must never show Alpha rows/draft/result. Logout clears tenant UI. Verify Company/Supplier/Category existing operations still work through their existing fixtures/authorized data only; do not create unrelated fixtures here.
5. Set Alpha PROJECT_MANAGER with `browser-role.sql`, revalidate (tab return), then refresh Projects if necessary. Only assigned P1 is visible/editable; P2 must not be accessible even with guessed UUID. Save P1 successfully. Revoke its assignment with `browser-authority.sql`: next attempted write is denied/zero-row conflict; Projects refresh removes P1. Restore assignment and refresh. Assignment-only changes do not trigger new Auth membership state or realtime master reload: RLS is immediate; the loaded UI remains a snapshot until query/refresh.
6. Cycle ACCOUNTANT, PROCUREMENT, DATA_ENTRY, MANAGEMENT_VIEWER, SYSTEM_ADMIN. None gets Edit; SYSTEM_ADMIN has no Project rows. Downgrade while editing: revalidated role remount removes form. Restore ACCOUNTING_ADMIN. Revoke Alpha membership: focus revalidation removes Alpha authority (Beta may remain). Restore it and explicitly select Alpha. Revoke profile: focus moves to no-company with no old tenant data. Restore active profile and reselect deliberately.
7. Focus/tab return with unchanged authority retains draft/data and branding without blocking “Loading securely”. Check English/Arabic/RTL, keyboard opening/cancel/save/focus, narrow layout, text rendering, console/network errors and absence of financial requests.
8. Execute `browser-cleanup.sql` with the exact synthetic UUID. It validates Companies, Projects, assignment, memberships/settings and unexpected Company/actor dependencies before exact deletes, including the disposable profile/Auth identity. No broad delete or explicit CASCADE. `verify.sql` must return zero fixture counts and 14/14 global integrity with missing/orphan 0/0. Remove isolated browser Auth/tenant state; preserve unrelated demo keys.
9. Record actual results and limitations before verified completion. The accepted results below now close Slice 8. Closure authorizes one local commit only; no push or Slice 9.

## Final accepted authenticated evidence (2026-09-17)

The user completed authenticated hosted browser acceptance successfully and supplied these accepted results:

- ACCOUNTING_ADMIN in Alpha: descriptive edits on ACTIVE and CLOSED Projects; optional clear-to-NULL; leading-zero contract number preservation; no code/status/date/financial mutation controls.
- Two-tab stale conflict protection; Alpha/Beta isolation and Beta Project mutation.
- PROJECT_MANAGER assigned-P1-only visibility/edit; assignment revocation denial and refresh removal; assignment restore.
- Denied roles: ACCOUNTANT, PROCUREMENT, DATA_ENTRY, MANAGEMENT_VIEWER and SYSTEM_ADMIN. Downgrade with an edit open removes the mutation form.
- Membership revocation fail-closed and restore; profile revocation fail-closed/no-company and restore.
- Unchanged-authority focus/tab-return; Arabic/RTL; keyboard/focus restoration; narrow viewport.
- Exact-manifest browser cleanup and final verification: fixture Companies 0, Projects 0, memberships 0, assignments 0, browser Auth 0; Companies 14, settings 14, missing 0, orphan 0.

These are user-supplied accepted results, distinct from the previously executed automated/hosted SQL and isolated Chromium evidence. No additional browser cases, measurements or traces are claimed. Closure reran no automated verification or hosted queries; final browser cleanup counts are accepted from the user. No credentials are stored. No P6D/financial behavior, Staging/Production action or Slice 9 work occurred.

The original procedure above is not a claim that individual cases beyond those reported were executed. The 108-check suite and concurrency used separate `780…`/`781…` manifests. No further fixture setup or credential decision is pending. Business/accounting, security/authorization, database, testing and documentation are VERIFIED; Development migration acceptance VERIFIED; frontend release/production readiness DEFERRED; Staging/Production action NOT APPLICABLE.
