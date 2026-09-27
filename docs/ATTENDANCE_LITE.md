# Attendance Lite — V1 Development implementation

**COMPLETE for Development — 2026-09-27.** Starting baseline: clean `main`, HEAD = local `origin/main` = `44972403d534824467eba49fdab2daa08241d097`, ahead/behind 0/0.

## Approved boundary

Attendance is an operational source with **zero accounting effect**. Reuse Company-owned Party(type=EMPLOYEE). Record only HALF_DAY/FULL_DAY salary-deductible absence exceptions; no live exception means present only for an eligible employee/date. No Payroll Profile, salary, payroll calculation/posting/payment, WPS, export, P6E, or completed-financial-workflow change.

P6C remains COMPLETE. P6D Checkpoints 1–10 remain Development-complete; the financial V1 core is now sufficient/frozen by user approval, without declaring every optional P6D capability complete. Corrected Replacement Expense and other optional workflows stay deferred. The user explicitly authorized Attendance Lite ahead of the historical full-Foundation-before-Payroll sequence. P6E NOT STARTED, PRE_DEMO_UAT deferred/non-blocking, Production readiness DEFERRED.

## Data model and canonical migrations

- `20260927120000_attendance_foreman_role.sql`: adds only FOREMAN. PostgreSQL requires this enum value to commit before it is used in permission mappings.
- `20260927121000_attendance_lite.sql`: employee site assignments, attendance exceptions, periods, immutable audit, narrow permissions, scoped commands and projections.

Applied only to positively identified `MakerACC-Development` (`eqnzueginpkskbnqvgoc`). Before this batch all 41 canonical migrations aligned. After application all 43 local/remote canonical migrations align and the final linked dry-run is a no-op; no applied migration was rewritten.

`employee_site_assignments`: Company, EMPLOYEE Party, Project, inclusive start/end dates, optimistic version, server-derived actor/timestamps. A Company transaction lock plus the range-overlap guard prevents overlapping sites for the same employee. Identity/start date is immutable; Admin can change the end date with an expected version and required reason. New assignments require an active Employee and nonclosed Project. Existing dated assignments remain the authoritative historical eligibility; later Party status does not erase past attendance. Assignment changes cannot strand recorded history or alter a locked month's eligibility. Transfers end the prior interval before starting the next.

`attendance_exceptions`: one retained row per Company/Employee/date, Project, HALF_DAY/FULL_DAY, optional note, void flag, version, original and latest actor/timestamps, correction reason. Voiding preserves the row; restoring uses the same row/version/owner. No hard deletion. One retained row avoids duplicate active records after retries or restoration.

`attendance_periods`: Company/month, revision, reviewed revision/actor/time and nullable lock time. Month is its first date. Review is a confirmation against an exact revision, not an approval or journal event.

`attendance_audit`: immutable before/after documents for assignments, exceptions and periods, plus assignment-correction reasons. No browser audit writes or history deletion.

All four tables have ENABLE/FORCE RLS, restrictive Company-consistent foreign keys, and SELECT-only authenticated/service grants. The browser mutates only through specialized attendance commands.

## Authorization and Foreman isolation

FOREMAN has exactly `attendance.record`; no inherited Project Manager/Data Entry/financial permissions. Every scoped command requires the authenticated actor's active profile, Company and membership. Foreman additionally needs an active existing `project_assignments` user assignment and the Employee's matching site/date eligibility. The existing user-assignment administration/provisioning path is reused; Foreman cannot self-assign or manage employees.

Accounting Admin has attendance.record/review/manage. Accountant has attendance.review only. All other roles, including SYSTEM_ADMIN, are denied attendance commands by default. Existing SYSTEM_ADMIN assignment administration is unchanged; it confers no attendance/financial read bypass.

Foreman has no direct rows from the four attendance tables or the EMPLOYEE Party master. Scoped `attendance_context`/`attendance_day` functions return site names, employee identifiers/names and attendance entries only. Raw attendance/audit SELECT is staff-only. All six public specialized functions use fixed empty search paths, minimal authenticated EXECUTE and explicit permission checks; seven private helpers have no anonymous/authenticated/service EXECUTE.

`ProtectedApplication` routes FOREMAN exclusively to `/attendance`, before the master provider mounts. There is no financial/master navigation or payroll/salary fetch. Company/actor/role changes remount the attendance scope; requests check session identity and current component lifetime before sending and accepting results. RLS remains authoritative if an assignment or role is revoked while a snapshot is displayed; refresh is needed to replace an already displayed snapshot. No realtime-revocation claim.

## UI and operating workflow

EN/AR `/attendance` provides assigned Project/date selection, eligible employee roster, Half/Full Day entry, optional note, own correction/void, provenance, loading/empty/error states and refresh. Future dates are denied by the server; the UI uses the server's **UTC calendar day** as its maximum. No Company timezone setting was introduced.

Foreman may correct/void only original own entries while still authorized and the month is open. Admin may correct any entry; all corrections/voids require a reason. Original recorded-by provenance is preserved even after an Admin correction. Expected versions reject stale saves. Duplicate submissions are coalesced within the mounted form. After any uncertain/error response, the form requires authoritative refresh before re-entry; it does not automatically resend or overwrite with a newer version.

Staff monthly review lists effective assignments, absence exceptions (including marked voids), per-assignment absence days and actor provenance. Admin can add site assignments or change end dates. Correction of an absence uses the daily view. Accountant/Admin explicitly confirm that assignments and exceptions were reviewed. New or corrected absence and assignment changes invalidate affected open review snapshots; conservative assignment invalidation may also require re-review of later open periods.

Existing EMPLOYEE Party provisioning is required; this package does not introduce broad employee/HR creation. Review includes zero-exception employees through the assignment roster. It does not prove a Foreman submitted every expected day and does not introduce daily presence rows.

## Month lock / future payroll integration

Exception writes, assignment changes, review confirmation and the future lock helper acquire the same Company transaction lock. `private.lock_attendance_month(company, month, expected_revision)` accepts only an open, reviewed, unchanged period. It must be called inside a future authorized payroll POST transaction so posting failure rolls back the lock too. It has **no browser EXECUTE**, no UI and no scheduler/caller in this implementation. Focused tests exercise it only inside a rolled-back trusted transaction.

After lock, even Admin cannot change month attendance or assignment coverage. There is no public unlock endpoint. Payroll reversal/replacement/reopening policy remains a later Payroll design decision; no payroll command was implemented.

## Verification and evidence limits

- Focused repository/real SDK transport verifier PASS: exact business inputs, integer half units, date validation, correction ownership, lock gates, identity/lifetime checks and no financial/demo/direct writes.
- Rollback-only Development matrix **84 checks PASS**: employee/site/date eligibility, overlap rejection, duplicate employee/date, half/full values, required reason, stale versions, void/restore/provenance/audit, future-date rejection, Foreman own entries and revoked assignment, inactive profile/membership, other-tenant read/write denial, role/review matrix, review invalidation, exact review revision, locked-month edits, safe later transfer, no hard deletion, zero journal effects and denied existing financial-table reads/permissions.
- Isolated real Chromium using actual Attendance components and in-memory transport PASS: EN/AR/390px, entry/correction/void, reason required, lost-response refresh without reposting, original-recorder gate, Admin correction, Accountant review, denied roles and locked view. Admin assignment creation/end-date editing and exact payload checks also PASS.
- Hosted final read-only checks: all four Attendance tables empty after rollback; forced RLS 4/4; constrained public definers 6/6; forbidden table grants 0; exposed private helpers 0; anonymous commands 0; extra Foreman permissions 0; canonical migrations 43.
- DB lint: no new Attendance findings. It reports one pre-existing `private.post_supplier_payment` unused-variable warning; unchanged and non-blocking.
- Final build PASS. Lint: zero errors, four existing Fast Refresh warnings after removal of new warnings. Focused secret scan across all 18 changed/new files and `git diff --check` PASS. Build has the non-blocking >500 kB chunk-size advisory; no deployment occurred.
- Current P6A/P6C static boundaries pass. The default P6C boundary wrapper initially also began historical in-memory behavior checks through Slice 6; it was stopped and rerun with `--static-only`. No historical P6C/financial browser suites ran.

Not performed: new multi-connection race tests; hosted signed-in browser/PostgREST acceptance; exhaustive keyboard/accessibility tests; full Production Security & Accounting Integrity Audit; payroll integration. SQL uses actual authenticated roles/RLS and rollback-only fixture changes, distinct from isolated browser transport. A short operator smoke with an existing Foreman/Admin session remains deferred/non-blocking, following the established Development checkpoint policy. No permanent Auth users or synthetic attendance were created.

## Changed files

- Two canonical migrations listed above.
- `src/attendance/{AttendanceApplication.tsx,attendanceRepository.ts,attendanceText.ts}`.
- `src/auth/ProtectedApplication.tsx`, `src/app/TenantReadyApplication.tsx`, `src/i18n/{en,ar}.ts`, public-only regenerated `src/types/database.generated.ts`.
- `scripts/verify-attendance.mjs`, `scripts/verify-attendance-interactions.mjs`, `scripts/fixtures/attendance-interactions.tsx`.
- `scripts/sql/attendance/{hosted-checks.sql,final-checks.sql}`.
- This record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`.

## Lifecycle / readiness

Requirements/design approved, implementation and proportional Development verification complete, and official records reconciled. User-accepted closure state: **Attendance Lite COMPLETE for Development**, with the explicit deferrals below. This is not frontend deployment or production-launch approval.

| Category | Classification |
|---|---|
| Business/accounting | VERIFIED approved Attendance scope; no accounting effect. Payroll accounting NOT APPLICABLE to this batch. |
| Security/authorization | VERIFIED focused active actor/tenant/project/employee/date controls, ownership, RLS and financial denials. Full pre-production audit DEFERRED. |
| Database | VERIFIED canonical Development migrations, constraints, grants, audit, locking boundary and rollback tests. |
| Deployment | Development migration application VERIFIED. Frontend release, Staging/Production and production readiness DEFERRED. |
| Testing | VERIFIED focused automated/hosted and isolated browser evidence above; operator smoke and multi-connection races DEFERRED. |
| Documentation | VERIFIED roadmap, handoff and this phase record match implemented scope and actual evidence; limitations explicitly deferred. |

No accounting or implementation blocker identified. Payroll recognition/allocation/adjustment policies remain outside this package. No payroll calculation/posting, WPS, exports, P6E, push, Staging or Production action.

## Accepted Development closure

The user accepted the implementation, existing evidence and explicit deferrals, and authorized one local commit: `Complete Attendance Lite`. Closure reviewed the complete 18-file Attendance diff and updated only stale closure wording in this record, the roadmap and handoff. No tests, verification or hosted signed-in browser smoke were rerun. The earlier passing results above remain the accepted evidence; Production readiness and hosted signed-in smoke remain deferred, with the smoke non-blocking.
