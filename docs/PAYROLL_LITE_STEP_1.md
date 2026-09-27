# Payroll Lite — Step 1

**COMPLETE for Development.** Profiles, calculation-only DRAFT register, generic manual adjustments and draft review. Baseline was clean `main`, HEAD = fetched `origin/main` = `46e23de446ddd4654d8c385c738183bcc7440298`, ahead/behind 0/0.

Attendance Lite remains COMPLETE. P6D financial V1 core remains sufficient/frozen. Payroll posting/payment, WPS, Excel/PDF and P6E are NOT STARTED. PRE_DEMO_UAT remains deferred/non-blocking; Production readiness DEFERRED. No accounting effect, attendance month lock, push, Staging or Production action.

## Model / Development migration

`20260928120000_payroll_lite_drafts.sql` applied only to verified `MakerACC-Development` (`eqnzueginpkskbnqvgoc`). Previous 43 migrations aligned; this is migration 44. No applied migration was rewritten.

- `payroll_profiles`: Company-owned extension of Party(type=EMPLOYEE), Company-unique case-insensitive Payroll ID, descriptive Payroll Type/Profession/Work Station/Payment Type, optional same-Company default Project, BIGINT monthly salary, Active/Inactive, optimistic version and actor/time provenance.
- `payroll_draft_periods`: one Company/month, server-derived calendar days, constrained DRAFT-only state, version, input hash, attendance revision, adjustment/calculation revisions and review provenance.
- `payroll_draft_rows`: stable employee/period identity, inclusion flag, copied profile/name fields, exact calculated BIGINT amounts and integer absence units. Excluded rows are retained; live adjustments must be voided before excluding an employee. Nothing silently deletes adjustment history.
- `payroll_draft_adjustments`: row-scoped ADDITION/DEDUCTION, positive exact amount, required description, optimistic version, void flag, original/latest actor/time and required change reason for edit/void.
- `payroll_draft_audit`: immutable before/after records for profile, period, row and adjustment changes. No hard delete.

## Calculation and draft lifecycle

The private PostgreSQL helper uses numeric intermediates: `absence_deduction = round(S::numeric * U / (2 * D))`; gross = S minus that deduction; net = gross plus additions minus other deductions. PostgreSQL round-half-away-from-zero is applied **once** to the deduction. Calendar days are derived from the selected month (28/29/30/31, including leap years). Zero absence preserves the exact monthly salary. Constraints enforce 0 <= U <= 2D, net >= 0 and consistent stored amounts.

Salary, adjustment sums and final monetary values are bounded to 9,000,000,000,000,000 minor units. Overflow/negative net is rejected atomically, never clamped. All application-facing monetary RPC projections return decimal **strings**; generated numeric/null argument types are narrowly overridden at the repository boundary. Browser inputs/displays use BigInt, never Number money. Salary/Day is an explicitly approximate, display-only rounded quotient; it is never reused in deduction calculation. Day equivalents use integer half units. No JavaScript payroll calculation engine.

Generate/refresh requires a current Attendance monthly review. The source hash captures profile versions/values, employee name/status, Attendance period/review provenance and nonvoid monthly HALF_DAY/FULL_DAY sums. Source material is read as one coherent SQL snapshot. Profile/attendance changes do not rewrite saved draft rows: the read/review paths flag them stale. Adjustment changes advance a separate revision, permitting multiple changes before an **explicit** refresh. Refresh atomically recalculates rows and clears draft review. Confirming a draft review is version-bound and fails if inputs/calculations are stale.

Profile, draft and adjustment mutations reuse the Attendance Company transaction lock to serialize with Attendance updates/review. They never invoke the attendance-month lock helper. Party metadata changes are detected by the source hash. A later change can make a displayed snapshot stale; reload and every mutation/review enforce current server state. No realtime-refresh or multi-connection race-test claim.

Adjustments carry no accounting classification/mapping. Add/edit requires current profile/attendance inputs; void remains available to clear adjustments when inputs become stale or an employee is excluded. Candidate adjustment totals must remain within bounds and nonnegative against the saved base; clear deductions before removing supporting additions if necessary. A refresh against changed salary/absence may still reject negative net, requiring adjustment cleanup. Stable IDs plus expected versions prevent duplicate same-ID effects and stale overwrite; uncertain UI outcomes require authoritative reload, never automatic reposting.

## Authorization / EN-AR UI

Only ACCOUNTING_ADMIN and ACCOUNTANT receive `payroll.manage`, covering private profile and draft preparation/review. **MANAGEMENT_VIEWER remains denied**, because broader payroll readership has not been approved. FOREMAN, SYSTEM_ADMIN, Project Manager, Data Entry and Procurement receive no Payroll rows or command access. Authenticated active profile/Company/membership checks derive the actor server-side. Same-Company foreign keys protect all dimensions. Five tables have forced RLS and SELECT-only browser grants; six constrained fixed-empty-search-path definer RPCs own mutations/projections. Private helpers and generic accounting primitives are not browser-executable.

EN/AR production `/payroll` provides profile list/create/edit/status, exact salary entry/display, monthly register, attendance-review state, explicit generation/refresh, retained stale values, adjustment add/edit/void, draft review, errors/reload and responsive cards. No posting/payment/export control. The FOREMAN attendance-only route still intercepts other routes before master-data loading. PayrollContent denies unapproved roles without a salary request. Actor/Company/role remounts and request lifetime/session checks reject stale results. No payroll data is persisted to browser storage.

## Evidence and limits

- Development rollback matrix: **127 checks PASS**. Canonical calculation boundaries/ties/single rounding, month lengths/leap year, zero/half/full/multiple absences, large exact strings, additions/deductions/voids, negative-net/overflow rejection, attendance review, source/adjustment stale detection, explicit refresh, profile status/inclusion, audit/no delete, role/tenant denial and zero journal/attendance-lock effect. Every fixture/role/master change rolled back; no new Auth users.
- Focused repository/real SDK transport PASS: exact string amounts, input/response validation, daily display only, scope/role/session/lifetime gates, profile and adjustment payloads and no financial/demo/direct-write access.
- Isolated actual-component Chromium PASS: profile create/edit/active-inactive, attendance gate, draft generation/explicit refresh, stale unchanged amounts, adjustment add/edit/void, uncertain response/reload without duplication, review, denied roles, EN/AR and 390px. In-memory transport, not hosted authenticated browser evidence.
- Build PASS (existing non-blocking >500 kB chunk advisory). Lint PASS, four pre-existing Fast Refresh warnings. P6A/P6C **static-only** boundaries PASS; no historical P6C/P6D/Attendance browser matrices were run. Public-schema DB lint clean.
- Final read-only DB checks: Payroll profiles/periods/rows/adjustments/audit all 0 after rollback; attendance exceptions and locked periods 0; forced RLS 5/5, constrained definers 6/6, forbidden table grants/anonymous commands/exposed helpers/unauthorized payroll roles all 0. Canonical count 44; linked dry-run no-op.
- Changed-file secret scan across all 17 changed/new files and `git diff --check` PASS.

Not performed: signed-in hosted browser/PostgREST smoke; new multi-connection race suite; full production audit or deployment. These are explicit evidence limits, not claimed passes. Focused SQL/RLS and isolated UI/SDK evidence support Development completion; short existing-session operator smoke remains deferred/non-blocking.

## Decisions / exclusions

No Step 1 blocker. This is the approved **full-month fixed salary** model: active profile plus active EMPLOYEE determines draft inclusion; no employment-date proration, historical salary schedule, mid-month rate split or multi-site cost allocation is inferred. Attendance review confirms exceptions, not a full timesheet. Profile/default-site/payment-type descriptors create no accounting treatment. Zero-value/empty drafts are allowed for calculation; any future nonzero posting rule belongs to Payroll POST.

Management Viewer payroll access stays denied pending explicit policy. Recognition date/cost allocation, Salary Payable, adjustment accounting meanings, payments/reversal, WPS, exports and production go-live gates remain later decisions/work. Step 1 does not resolve or implement them.

## Files and readiness

Migration above; `src/payroll/{PayrollApplication.tsx,payrollRepository.ts,payrollText.ts}`; route/navigation in `src/auth/ProtectedApplication.tsx` and `src/app/TenantReadyApplication.tsx`; navigation labels in `src/i18n/{en,ar}.ts`; public generated types; `scripts/verify-payroll-step1{,-interactions}.mjs`; `scripts/fixtures/payroll-step1-interactions.tsx`; `scripts/sql/payroll-step1/{hosted-checks.sql,final-checks.sql}`; this record, handoff and roadmap.

| Lifecycle category | Classification |
|---|---|
| Business/calculation | VERIFIED approved exact draft arithmetic and no accounting effect; posting policy NOT APPLICABLE here. |
| Security/authorization | VERIFIED focused identity, tenant, salary privacy, command/RLS/grant and denied-role paths. Production audit DEFERRED. |
| Database | VERIFIED canonical Development migration, constraints, audit, forced RLS, rollback and private helper boundary. |
| Deployment | Development migration VERIFIED; frontend release, Staging/Production and production readiness DEFERRED. |
| Testing | VERIFIED focused SQL, repository/SDK, isolated browser, build/lint/static boundaries; hosted browser and multi-connection races DEFERRED. |
| Documentation | VERIFIED handoff, roadmap and this checkpoint match actual scope/evidence; all deferrals recorded. |

## Accepted Development closure

The user accepted Step 1 as COMPLETE for Development with the evidence and deferrals above. The complete 17-file Step 1 diff was reviewed without a closure blocker and is recorded in one local commit, `Complete Payroll Lite Step 1`. Closure reran no tests or verification and performed no hosted signed-in browser smoke. Payroll posting/payment, WPS, Excel/PDF and P6E remain NOT STARTED. No push or Staging/Production action.
