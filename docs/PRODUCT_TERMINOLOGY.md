# Product terminology correction

Implemented locally: 804 existing English/Arabic text values corrected; 14 role translations added for three display locations. This count measures text values across both languages, not 804 distinct business concepts.

Replaced tutorial/development language with business terminology across navigation, page headings, master data, financial operations, historical records, payroll/attendance, onboarding, subscriptions, status/error messages and export headings. Financial summary includes posted records and imported activity; imported reports are explicitly identified and never presented as general ledger balances or complete financial statements. Payment certificates use «مستخلصات»; retention uses «محتجزات»; Companies use «الشركات». Internal-company access without a required commercial subscription remains explicit.

Historical record controls now say Archive / أرشفة because the existing operation retains original records and audit history. Only wording changed; request modes, statuses and archival behavior remain unchanged.

Verification: Production build, final text-only Vite rebuild and 35 localization/presentation check groups pass. Seven actual UI routes pass in English and Arabic using isolated fixtures with external requests blocked. The archive confirmation is checked without submission. All original translation keys/placeholders and database query/mutation calls remain unchanged. 173 protected source/migration files remain byte-identical. Existing bundle-size warning and five lint warnings in unchanged files remain. No business clarification is pending. [Results](release/terminology-correction-result.json).

Business/accounting changes NOT APPLICABLE; presentation/permission boundary and focused testing VERIFIED; database changes NOT APPLICABLE; deployment DEFERRED; documentation VERIFIED. No hosted access, migrations, commits, pushes or deployments. Five themes and green styling remain unchanged. Exhaustive human linguistic acceptance of every rendered state is not claimed.

Application files changed:

- `src/attendance/attendanceText.ts`
- `src/auth/CompanySelectPage.tsx`
- `src/historical/HistoricalImports.tsx`
- `src/historical/HistoricalOverview.tsx`
- `src/historical/SourceEditor.tsx`
- `src/historical/sourcePosting.ts`
- `src/i18n/ar.ts`
- `src/i18n/en.ts`
- `src/i18n/roleLabels.ts`
- `src/master/CompanyAccountingSetupStatus.tsx`
- `src/master/CompanySubscriptionStatus.tsx`
- `src/payroll/PayrollPosting.tsx`
- `src/payroll/payrollRegister.ts`
- `src/payroll/payrollText.ts`
- `src/platform/CommercialOnboarding.tsx`
- `src/platform/platformText.ts`
- `src/reports/postedExpenseReport.ts`
- `src/reports/postedJournalReport.ts`
- `src/reports/sourceReports.ts`
- `src/workspace/CompanyWorkspaceShell.tsx`
- `src/workspace/CycleFoundation.tsx`
- `src/workspace/cycleText.ts`
- `src/workspace/moduleRegistry.ts`
- `src/workspace/useWorkspaceUiText.ts`
- `src/workspace/workspaceText.ts`

Focused checks: `scripts/verify-terminology.mjs`, `scripts/verify-terminology-browser.mjs`. The source-preservation check uses the pre-change local snapshot; `TERMINOLOGY_BASELINE` can identify another equivalent snapshot. Handoff and roadmap checkpoints record this implementation.
