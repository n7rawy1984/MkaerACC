# Payroll Lite Step 3 — Register output

2026-09-28. **Payroll Lite Step 3 COMPLETE for Development.** Implementation and focused evidence are user-accepted. Production readiness and hosted signed-in browser smoke remain DEFERRED/non-blocking. Baseline confirmed before work: main, HEAD = origin/main = efadd1fd48b787f2b38b91926d7d9f9cc55f3090, ahead/behind 0/0, clean.

## Contract and implementation

Read-only Excel and browser Print / Save PDF actions are available on the reviewed draft and each posted payroll. Both outputs have the same 13 approved columns, Company, month, status, source identifier, included employees only and meaningful totals. Historical reversed postings are explicitly marked REVERSED. Company heading uses the active authorized Company's current display name; employee/payroll fields for POSTED come exclusively from the immutable snapshot.

DRAFT actions reread `read_payroll_draft` and require the selected period/version, matching Company/month, valid Attendance review, fresh inputs and valid draft review. POSTED actions reread `read_payroll_postings`, select the specified posting and validate its Company/month/period/version before consuming `snapshot.rows`. They do not read current profiles or Attendance and do not reconstruct cost, net, deductions or salary entitlements. Frozen snapshot's embedded period remains DRAFT by the existing POST contract; the enclosing posting determines output status.

Amounts remain exact BIGINT strings; totals use BigInt. All Excel monetary cells contain right-aligned, two-decimal **text**, deliberately preserving cents even beyond Excel numeric precision, with precomputed exact totals and no formulas. Payroll IDs retain leading zeros; user text cannot become spreadsheet formulas. Salary/day uses the existing exact display-only rounding helper. Days worked are calendar days less absence half-units; absence days display those half-units. Neither display calculation changes accounting. Monthly salary, gross, additions, other deductions and net use stored values.

Pinned `write-excel-file@4.1.1` with its fflate dependency is lazy-loaded (built writer chunk approximately 19.5 KB gzip). No export framework or custom PDF engine. The dedicated browser view has named A4 landscape page CSS, repeated table headings, non-splitting rows, one totals row, EN/AR direction and isolated numeric text. Application navigation and controls are hidden during print. Its Print action rereads and validates the source again. The large register scrolls inside its preview on narrow screens.

## Authorization / database / lifecycle

Only existing ACCOUNTANT / ACCOUNTING_ADMIN payroll readers have output controls. FOREMAN, MANAGEMENT_VIEWER and SYSTEM_ADMIN remain denied. Every action uses the existing authenticated RPC wrappers, including before/after session identity checks, and existing server authorization. The view is keyed to user, Company, role, month, source/version and locale; scope changes unmount sensitive preview and discard in-flight reads. No permission, grant, RLS, RPC, accounting command or migration changes. No browser payroll cache or persistent output store.

- Business/accounting: VERIFIED for output contract; existing accounting behavior unchanged.
- Security/authorization: VERIFIED by scoped source review and isolated role/session/RPC-denial tests; existing database enforcement reused. No new hosted authorization matrix was run.
- Database: NOT APPLICABLE to this read-only frontend package. Existing 47 migrations unchanged; no alignment/dry-run rerun or hosted mutation.
- Deployment: Development code only; Staging/Production actions NOT APPLICABLE. Production readiness DEFERRED.
- Testing: VERIFIED by focused isolated browser/SDK checks, build, lint, current static boundaries, focused secret scan and diff check. Hosted signed-in smoke DEFERRED/non-blocking. Historical accounting/browser matrices not rerun.
- Documentation: VERIFIED by this record and current roadmap/handoff sections.

## Focused evidence

`node scripts/verify-payroll-step3.mjs`: PASS. Real generated XLSX archives inspected for DRAFT/POSTED headings, Arabic labels, RTL workbook, exact cents and totals exceeding single-row limits, leading-zero IDs, formula-like text and absence of formulas. Browser exercises stale/unreviewed/version/Company/role/session denial, server-denied reads, frozen POSTED values despite changed live draft, excluded employees, print revalidation, reversed labels, RTL preview, A4 PDF dimensions and multi-page PDF with repeated table header CSS. Uses synthetic local transport only, no hosted credentials/data. Browser PDF generation occurs only in the test to verify browser printing.

`npm run build`: PASS (existing large-chunk advisory remains). `npm run lint`: PASS, four pre-existing warnings only. `npm run verify:p6a-boundary` and `npm run verify:p6c-boundary -- --static-only`: PASS. Focused changed-file secret scan and `git diff --check`: PASS.

## Changed files and limits

- `src/payroll/payrollRegister.ts`: output data contract, exact display/totals, labels.
- `src/payroll/payrollRegisterRepository.ts`: fresh authorized source reads.
- `src/payroll/payrollRegisterXlsx.ts`: XLSX writer adapter.
- `src/payroll/PayrollRegisterOutput.tsx`, `src/payroll/payrollRegister.css`: output actions and print preview.
- `src/payroll/PayrollApplication.tsx`, `src/payroll/PayrollPosting.tsx`: read-only integration and Company heading.
- `package.json`, `package-lock.json`: pinned small writer dependency.
- `scripts/verify-payroll-step3.mjs`, `scripts/fixtures/payroll-step3.tsx`: focused isolated evidence.
- This record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`: official state.

No blockers. Excel money cells intentionally are text, not spreadsheet-calculation inputs. Browser print settings remain under operator control. No WPS, bank submission, HR, P6E, accounting changes, Staging/Production actions or push.

## Development closure

User accepted Attendance Lite and Payroll Lite Steps 1–3 as COMPLETE for Development. The complete Step 3 diff was reviewed with no blocking findings; only stale completion wording was updated during closure. Accepted verification evidence above was not rerun. No hosted signed-in smoke, accounting/post/payment/reversal changes, migrations, WPS, P6E or Staging/Production actions. One local commit records this closure: `Complete Payroll Lite Step 3`. No push. Production readiness remains deferred; hosted signed-in smoke remains deferred/non-blocking.
