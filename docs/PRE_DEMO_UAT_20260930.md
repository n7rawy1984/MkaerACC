# Development Demo Preparation / PRE_DEMO_UAT — 2026-09-30

## Accepted closure — Single-Company V1 Demo Ready

The user accepted the single-Company Development rehearsal as PASS and the V1 flow as ready for Company presentation. No product/accounting defect or demonstrated demo blocker was found; no application/accounting changes were required. **Cross-Company UAT is deferred unless separately authorized**, so PRE_DEMO_UAT is not globally/unconditionally closed. **Production readiness remains deferred. Operator-controlled credentials are required before the live human demo.**

This documentation-only closure preserves the current synthetic fixture, including the retained posted/partially paid August Payroll and reviewed/locked Attendance. No cleanup, reversal, hosted action, test rerun or new phase. One local commit: `Complete V1 demo rehearsal`; no push. Earlier no-commit statements describe the rehearsal before this authorized closure.

## Result and boundary

**Bounded single-Company Development demo rehearsal PASS. No demonstrated product blocker. PRE_DEMO_UAT is not unconditionally closed:** true switching between two authorized Companies remains untested under the explicit one-Company fixture limit. Production readiness remains DEFERRED. No completed development phase was reopened.

Baseline: `main`, HEAD = origin/main = `1bcf80410885f86432a06acd5e257e77186c6f84`, ahead/behind 0/0, clean before documentation. Recovered the prior session without recreating the Company or discarding work. Prior `/tmp` scripts had expired; hosted data was intact. Preserved the prior evidence for the current-source build, eight password logins, Accounting Admin Subcontract edit, and authority-failure blocking. Recovered remaining work through fixed, bounded scripts.

Actual signed-in Chromium used the local preview of the current release with MakerACC-Development Auth/Postgres, not mocked business responses. Temporary request failures/delay were injected only for recovery/loading checks. Current build configuration passes the shared production configuration guard: `supabase-auth`, browser-safe key, Development target. No secrets recorded. The previous current-source build PASS is reused; source did not change.

## Fixture retained

One Company: `V1-DEMO-20260929` / `d3292026-0929-4000-8000-000000000001`, synthetic branding and active status. Eight dedicated synthetic users have active memberships: Accounting Admin, Accountant, Management Viewer, Foreman, Procurement, Project Manager, Data Entry and System Admin. Auth users and masters were created in the prior session; this recovery created no replacement users or Company.

Two Projects, Supplier/Subcontractor Parties, two EMPLOYEE Parties, an Expense Category, Bank Treasury with permanent ASSET GL, required system accounts including active LIABILITY `SALARY_PAYABLE`, and two Subcontracts are retained. Foreman and Project Manager have only Project 1 assignments. Two dated employee site assignments and Payroll Profiles support August 2026. Financial/Attendance/Payroll changes used canonical application commands. Controlled authority toggles affected only this Company's dedicated Admin/Company and were restored.

## Executed bounded UAT

| Check | Evidence/result |
| --- | --- |
| Subcontract roles | Admin/Procurement see two and can edit; both descriptive saves verified. Accountant/Viewer read-only; Project Manager sees only assigned Project's one Subcontract; Data Entry/System Admin have zero rows. |
| Role downgrade | Open Admin edit form disappears after genuine application focus revalidation; restoration succeeds. |
| Revocations | Profile, membership and Company deactivation each block protected UI; restoration/retry succeeds. |
| P6E retry | Previously evidenced failure blocks UI. Successful authoritative retry confirmed; expected route is `/`, then normal navigation resumes. |
| Foreman | Attendance-only navigation; no Payroll navigation. |
| Selected denied controls | Accountant has no Expense reversal; Management Viewer/System Admin cannot open Payroll or export it. |
| Company selection | Sole authorized Company selected; invalid remembered Company is rejected/replaced by server-validated scope on reload. This does **not** prove switching between two populated tenants. |
| Expense READ | Empty/populated states; real 50/1-row pages with no overlap; Previous, refresh, loading, safe error and recovery. |
| Treasury Expense | Browser POST: 123.45 net + 6.17 VAT = 129.62 gross; authoritative reload and immutable reversal. |
| Supplier | Browser credit Expense 210.00 gross; payment 50.00; outstanding 160.00. Disposable payment reversal restores liability. |
| Subcontract | Browser Advance 1000.00; Certificate preparation/approval with work 2000.00, retention 200.00, recovery 100.00, payable 1700.00; payment 500.00 leaves 1200.00. Retention Release 100.00 leaves 100.00 unreleased; payment 40.00 leaves 60.00 unpaid release. |
| P6D reversal smoke | Supplier Payment, Retention Payment, Retention Release, Subcontractor Payment, Certificate, and Advance reversed through actual UI in dependency order; refreshed REVERSED states and journal receipts captured. Treasury Expense reversal also passed. |
| Attendance/Payroll | Foreman half-day absence on 2026-08-10; Accountant monthly review, draft generation, 100.00 earned-salary bonus, refresh, allocation/classification and version-bound review; Admin POST; August locks. |
| Payroll values/payment | Frozen net entitlements 3150.00 and 6200.00; 1000.00 Salary Payment leaves 2150.00 and 6200.00 outstanding. |
| Output/presentation | Reviewed DRAFT Excel and frozen POSTED EN/AR Excel; 13 columns, IDs `0001`/`0002`, exact two-decimal values and total 9350.00, no formulas. EN/AR RTL preview and Chromium A4 landscape PDF (841.92 × 594.96 pt), controls hidden. Payroll/Expense 390px checks pass; Arabic screenshots visually inspected. |

The existing application navigation used by these flows worked. No WPS or deferred feature was required. Broad historical role/browser matrices were not rerun; this table records the bounded session, not every sub-item of every old checklist. Browser-generated print output was checked; no claim of a human-operated OS print dialog or physical printer test.

## Final Development data

- 51 Expenses: Treasury demo Expense and 49 one-fils paging fixtures are REVERSED; one Supplier Credit Expense remains POSTED (210.00 outstanding after payment reversal).
- One Supplier Payment and one each of Subcontract Advance, Certificate, Payment, Retention Release and Retention Payment are REVERSED. Immutable journals/history retained.
- One half-day Attendance exception; August reviewed and locked. One Payroll draft/earned-bonus adjustment, one frozen posting, two entitlements and one unreversed Salary Payment retained.
- All eight memberships active; Company and tested Admin profile restored. One valid Salary Payable mapping; zero unbalanced journals in this fixture's final read-only aggregation.
- No unrelated tenant data changed. No migration/schema/RLS/accounting implementation changed.

The paging fixtures are the minimum 49 extra records required with the existing two Expenses and fixed 50-row page size. They were created through public-user `post_expense` and immediately reversed through `reverse_expense`; no direct financial writes or live paging cost remain.

## Defects, fixes and evidence

No confirmed application defect. Harness issues corrected only in temporary scripts: expected retry route, empty-list visibility, duplicate amount locators, successful empty RPC responses, preserved receipt after reload, and XLSX shared-string decoding. Successful mutations were recovered from saved receipts/authoritative reads and were not blindly repeated. No product fix was made.

Durable evidence: [results.json](verification/pre-demo-uat-20260930/results.json). Temporary scripts, screenshots, XLSX files and PDFs are at `/tmp/maker-v1-demo-recovery/` and may expire. They contain synthetic fixture data; credentials/session tokens were not persisted as artifacts. New scripts retrieved only scoped fixture login links in memory, never exposed privileged credentials to the application, and used normal authenticated actors for financial commands.

## Readiness and next action

Use the retained fixture for a single-Company Development demonstration. August is already POSTED and partially paid: demonstrate its frozen history/output; do not attempt to regenerate that posted month. A fresh end-to-end August posting would require a separately deliberate canonical correction/reversal cycle. Operator credential handoff was not completed: before a live human demo, set operator-controlled credentials for the dedicated synthetic users through approved Development Auth administration, then use normal login. Test passwords/login tokens are not distributed in this record. This is an access prerequisite, not a demonstrated application defect.

True multi-Company switching requires a separately authorized two-Company fixture. It remains an explicit coverage gap, not a discovered defect or a blocker for this single-Company demonstration. External operator acceptance is not implied by automated Chromium success.

Lifecycle classification: business/workflow **VERIFIED** for the bounded flows; security/authorization **VERIFIED** for listed UAT only (cross-Company switch/full audit **DEFERRED**); database fixture/history readback **VERIFIED**, migrations **NOT APPLICABLE**; Development configuration/release **VERIFIED**, deployment/Production readiness **DEFERRED**; focused browser/output testing **VERIFIED**, historical matrices **NOT APPLICABLE** to this session; documentation **VERIFIED** after final review.

No full audit, new feature, WPS, backup/restore rehearsal, pre-go-live operations, Staging/Production action, reset/clean/revert, commit or push.
