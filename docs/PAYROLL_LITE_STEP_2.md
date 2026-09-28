# Payroll Lite — Step 2

**COMPLETE for Development.** Baseline `main`, HEAD = origin/main = `90ba54f04678100f6d6bce9c98f9ac38cac5803d`, clean, 0/0. Frozen accounting contract implemented without WPS, exports, P6E, Staging/Production or push. Attendance and Step 1 remain complete. Production readiness and signed-in hosted browser smoke remain deferred; isolated real-component browser evidence is described below.

## Canonical Development migrations

Only verified MakerACC-Development (`eqnzueginpkskbnqvgoc`) was affected. **47 migrations aligned; linked dry-run no-op.**

- `20260928130000_payroll_salary_payable_key.sql`: separate enum transaction for `SALARY_PAYABLE`.
- `20260928131000_payroll_lite_posting.sql`: LIABILITY mapping constraint, six forced-RLS append-only tables, private live-period index, permissions, specialized commands, posted-draft guard and restrictive journal privacy. A syntax error rolled this migration back before its successful application; no applied history was edited.
- `20260928132000_payroll_posting_alias_correction.sql`: forward correction of two PL/pgSQL loop-record/table-alias ambiguities found by DB lint and the first rollback matrix. Public DB lint is now clean.

Public tables: `payroll_draft_accounting`, `payroll_postings`, `payroll_entitlements`, `salary_payments`, `salary_payment_reversals`, `payroll_reversals`. Posted events cannot be updated/deleted. Composite foreign keys enforce Company consistency. Private `live_payroll_periods` enforces one live posting per Company/month. Existing draft rows retain their identity; a controlled reversal advances the draft revision, and the next immutable posting links `replaces_id` to the prior reversed posting.

## Commands and accounting

- `prepare_payroll_accounting`: explicitly confirm one Project or Company-overhead allocation per included employee; classify every live adjustment. Immutable plan binds the resulting draft version, clears review, and cannot survive a later refresh/edit as current approval.
- `post_payroll`: ACCOUNTING_ADMIN; fresh, reviewed draft and current Attendance review; supported plan; completed month in Asia/Dubai. Locks employee source metadata and Company command sequence. Atomically snapshots exact string-valued draft inputs/adjustments/plan, posts recognition, creates employee entitlements and locks Attendance. Recognition date is month-end. Zero employee rows have no journal lines; all-zero payroll rejects.
- `pay_salary`: ACCOUNTANT/Admin; one live employee entitlement, positive amount within authoritative unpaid balance, actual nonfuture payment date on/after recognition, compatible active same-Company Treasury with active ASSET GL. Multiple partial payments supported. Inactive employees and closed Projects do not block settlement.
- `reverse_salary_payment`: Admin; exact original journal inversion, reason/date/actor; restores outstanding; unique reversal. Same-key replay returns original outcome.
- `reverse_payroll`: Admin; rejects live salary payments and dates before linked payment reversals; exact recognition inversion. Removes only the private live-period index, unlocks Attendance, invalidates Attendance/draft reviews and advances the draft version. Correct Attendance, review Attendance, refresh draft, reconfirm plan, review and post a linked replacement. Old snapshots remain immutable.
- `read_payroll_postings`: authorized snapshots, entitlements/outstanding, payments/reversals, current plan and permitted Treasury choices. All monetary RPC fields use strings.

All four financial commands reserve normalized SHA-256 requests through the existing private kernel, reuse a deterministic Company lock, protect source uniqueness and complete document/journal atomically. No caller supplies arbitrary journal lines/system GL accounts. No new generic posting/reversal surface.

Recognition: Dr existing `PROJECT_COST` (Project) or `COMPANY_EXPENSE` (overhead), Cr `SALARY_PAYABLE`, for exact net earned salary. Both sides preserve employee and allocation. Salary payment: Dr the **posted entitlement's** Salary Payable account, Cr selected Treasury's permanent GL, preserving employee/Project/Treasury; never recreates payroll cost. Reversals preserve all original dimensions. No VAT or employee-advance accounting is inferred.

Salary Payable is a Company-unique stable key with LIABILITY classification. Each tenant must deliberately configure its active mapping through trusted account provisioning; this batch does not guess accounts from names or automatically insert accounts into existing tenants. Missing/invalid mappings fail closed. Cost mappings must be active EXPENSE accounts. Existing kernel limit of 1,000 journal lines means at most 500 positive employee entitlements per posting; zero rows do not consume lines.

## Classifications and allocation

Absence reduces salary cost/payable through unchanged exact Step 1 calculation. Live ADDITION adjustments require `EARNED_SALARY_ADDITION` (additional earned salary/bonus); live DEDUCTION adjustments require `CURRENT_SALARY_REDUCTION` (current-month entitlement reduction). Both follow the same employee cost allocation. Unsupported strings, unclassified adjustments and stale plans reject. Human confirmation attests meaning; descriptions/signs never automatically supply it. Loans, employee advances/recoveries, third-party deductions, reimbursements and fines are unsupported.

Profile Project is a default only: the employee/month allocation must be explicitly confirmed. Null means Company overhead; nonnull means one eligible same-Company Project. Work Station and Attendance assignments do not determine allocation. No split allocation, proration, historical salary schedule or additional payroll feature was introduced.

## Security, privacy and UI

`payroll.manage`: ACCOUNTANT/Admin; `payroll.post`: Admin; `payroll.pay`: ACCOUNTANT/Admin; `payroll.reverse`: Admin. Active identity/Company/membership and permission are authoritative in DB. All other roles, including FOREMAN, MANAGEMENT_VIEWER and SYSTEM_ADMIN, have no Payroll access. Existing Foreman early attendance-only routing remains intact.

Six new public tables have forced RLS and SELECT-only authenticated/service-role grants. Seven public definers have fixed empty search paths and authenticated-only execute; private helpers remain inaccessible. `payroll_journal_visible` returns only an actor-scoped boolean. Two restrictive SELECT policies cover raw journal headers/lines, including recognition/payment reversals through the original source. Existing permissive accounting-read policies cannot bypass these payroll restrictions. Other journal-read helpers were reviewed: private custody/subcontract-advance balance helpers are account-scoped and do not expose salary data.

EN/AR `/payroll`: explicit allocation/classification, renewed review, Approve & Post, posted employee entitlement/outstanding, partial-payment history, payment/reversal confirmations, controlled correction guidance, and authoritative refresh. Posted draft controls are hidden/disabled. Failed reads fail closed. Actors/Companies/months remount state and session/lifetime checks reject stale results.

Financial request recovery follows the existing financial-workflow convention: only a pending command is stored in **user/Company-scoped sessionStorage**, including exact string payment inputs and the frozen idempotency key. This is the narrow Step 2 exception to Step 1's no-payroll-storage statement; no profile/register cache or private credentials are stored. Successful receipt clears the pending record. Reload/remount restores the same request, blocks new actions, and permits identical replay; known definite initial SQL rejection clears the attempt. Corrupt recovery data blocks mutation. No automatic reposting. Reversal confirmation states that real payments must not be erased merely to unlock payroll.

## Focused evidence

- **114 hosted rollback checks PASS**: real recognition and allocation lines, classifications and unsupported meanings, mapping validation, review dependency, Attendance lock, uniqueness/replay, partial/multiple payments, overpayment, closed/inactive settlement, incompatible Treasury, payment date, reversal dependencies, exact per-dimension reversals, replacement/fresh review, zero/all-zero, maximum BIGINT string transport, direct-write denial, tenant/role privacy for events and all salary journal types. All matrix fixtures rolled back.
- **Four actual concurrent-request scenarios PASS**: same-key POST resolves once for both callers; two overpaying payments accept exactly one; same-key payment reversal resolves once for both; payroll reversal versus new payment accepts exactly one and preserves dependency.
- Concurrency used one dedicated synthetic company `95610000-0000-4000-8000-000000000001` / `PAYROLL-STEP2-RACE`, with an existing synthetic actor and no new Auth user. Closed via canonical reversals, then Company/membership deactivated. Retained immutable history: one payroll plus reversal and one payment plus reversal (four journals), net zero per account/employee/Project/Treasury. No live payroll or locked Attendance; no nonfixture posted payroll; no missing Company settings. Fixture is deliberately retained, not deleted around immutability.
- Focused repository/real SDK PASS: maximum exact string amount, scope, identity/lifetime checks, scoped frozen recovery and identical replay payload, corrupt-state denial.
- Isolated actual-component Chromium PASS: allocation/classification, review gate, POST, partial/full settlement, saved same-key recovery across remount, reversal dependency, payment/payroll reversal and EN/AR/390px. In-memory transport; **not** hosted signed-in browser evidence.
- Build PASS; lint PASS with four pre-existing Fast Refresh warnings. Current P6A and P6C **static-only** boundaries PASS. No historical P6C/P6D/Attendance/Step 1 matrices rerun. Two Step 1 fixture/static-scope compatibility edits keep the new read-only panel compatible; its historical assertions were not rerun.
- Final read-only DB review: forced RLS 6, constrained authenticated-only definers 7, restrictive journal policies 2; forbidden DML grants/exposed private helpers 0; nonfixture postings/live payroll/locked Attendance/active fixture memberships/active fixture Companies/missing settings/nonzero fixture dimensions all 0.
- Focused secret scan across all 22 changed/new files PASS; `git diff --check` PASS.

No current implementation blocker. Tenant account configuration is required before operational POST. Signed-in hosted browser smoke, production audit, frontend deployment, Staging/Production readiness remain deferred. No WPS, Excel/PDF, P6E or push.

## Files and lifecycle

Three migrations above; `src/payroll/{PayrollApplication.tsx,payrollText.ts,PayrollPosting.tsx,payrollPostingRepository.ts,payrollPostingAttempt.ts}`; public generated types; three `scripts/verify-payroll-step2*.mjs`; `scripts/fixtures/payroll-step2-interactions.tsx`; `scripts/sql/payroll-step2/{hosted-checks,concurrency-setup,concurrency-close,final-checks}.sql`; two Step 1 test compatibility edits; this record, handoff and roadmap.

| Category | Classification |
|---|---|
| Business/accounting | VERIFIED frozen recognition, settlement, classification, correction and exact-money contract. |
| Security/authorization | VERIFIED focused actor/role/tenant, direct-write, immutable events, private kernel, raw-journal privacy and command races. Full production audit DEFERRED. |
| Database | VERIFIED three canonical forward Development migrations, 47 aligned, no-op dry-run, public DB lint and final grants/fixture state. |
| Deployment | Development DB action VERIFIED; per-tenant mapping required. Frontend deployment and Staging/Production DEFERRED. |
| Testing | VERIFIED focused hosted rollback, concurrency, SDK and isolated EN/AR UI; hosted signed-in smoke DEFERRED/non-blocking. |
| Documentation | VERIFIED current handoff/roadmap and this record distinguish implemented scope, retained fixtures and deferrals. |

## Accepted Development closure

The user accepted Payroll Lite Step 2 as COMPLETE for Development with the evidence and deferrals above. The full 22-file Step 2 diff was reviewed without a closure blocker and is recorded in one local commit, `Complete Payroll Lite Step 2`. Closure reran no tests and performed no hosted signed-in smoke. Each Company must configure a valid `SALARY_PAYABLE` mapping before operational Payroll POST. Production readiness remains deferred; hosted signed-in smoke remains deferred/non-blocking. WPS, Excel/PDF and P6E remain NOT STARTED. No push or Staging/Production action.
