# M2 — Company workspace redesign

2026-11-01. Local presentation implementation; no hosted migration, financial command, configuration change, deployment or Git-history action. Builds on accepted M1 operator corrections and existing accounting modules. Current lifecycle stage: implementation and local verification; owner visual acceptance and any Preview release are later gates.

## Design and architecture

Dark navy Company sidebar, teal actions, light surfaces, consistent KPI cards, module containers, focus indicators and logical RTL spacing. Eight collapsible groups: Dashboard; Master Data; Projects; Financial Operations; Contracts & Subcontractors; Employees & Payroll; Accounting & Reports; Settings. The mobile/tablet navigation uses a native modal dialog with Escape, focus containment and opener restoration. Existing company branding, authoritative Company identity/code, language switch, sign-out and Company selection remain available.

`src/workspace/CompanyWorkspaceShell.tsx` provides chrome inside the existing authenticated tenant/master providers. `workspaceNavigation.ts` filters links by existing roles; it grants no authority. `workspaceText.ts` and `useWorkspaceText.ts` reuse the existing English/Arabic locale. `workspace.css` is Company-scoped and does not style Platform Owner pages.

`WorkspaceQuickActions.tsx` reuses existing expense/payment permission predicates. The existing read-only subscription RPC is shared through `workspaceSubscriptionContext.ts` and `CompanySubscriptionProvider`, keyed by actor/Company/role. New Expense requires verified FULL access; expired/cancelled subscriptions preserve the role-permitted supplier settlement shortcut. Unknown or foreign Company subscription results cannot enable transaction shortcuts. Existing module/server restrictions remain authoritative; these links execute no commands.

`AccountingCycle.tsx` implements six stages: setup, monthly operations, posting, reporting, projects/contracts, closing. Stage links use the same role-filtered navigation. Reporting is explicitly Under development; period closing Requires accounting verification. Available labels refer to the described existing capabilities, not a completed end-to-end accounting cycle. `WorkspaceReports.tsx` exposes existing Company-scoped posted journal/expense exports to the existing three accounting-reader roles; it introduces no accounting calculation.

Existing Payroll and Attendance receive an optional embedded presentation mode. Their content, authorization and command handlers are unchanged except replacing an inner main landmark with section. Foreman retains the existing isolated Attendance route. Platform Owner routing remains independent of Company membership and does not acquire financial access.

## Financial provenance and preserved behavior

- Posted expense net, supplier outstanding, subcontractor payable and retention held use unchanged `dashboardRead.ts`, `dashboardSummary.ts`, `useDashboardRead.ts` and exact integer/AED formatting. Posted expense net excludes VAT, subcontract certificates and Payroll; it is not total project cost.
- Active project counts/statuses, recent expenses and chart values reuse existing authorized readers. Historical overview retains its original/current source totals, month-basis selector, processing states and charts, with explicit separation from posted balances.
- No authoritative live Treasury balance is supplied by the existing dashboard reader; show a scoped Treasury navigation link and clear explanation instead. No invented profitability, completion percentages, pending counts, financial statements or aggregate payment totals.
- Existing source/module filters remain. No global project/month filter is introduced across incompatible posted/source bases.
- Existing financial routes, forms, review/post distinction, idempotency/recovery, RPCs, RLS, MFA, membership and subscription rules remain. M1 exact subcontract AED, canonical date evidence and accessible source Save remain intact.
- Chart colors are presentation only. Decorative Recharts graphics disable their added accessibility layer because an adjacent exact-value description list already provides accessible values; hidden charts must not receive keyboard focus. Inherited muted copy/table header contrast is corrected within the Company shell. Subscription ISO dates use LTR isolation within Arabic copy.
- Maker remains a Company. Barq is a MANAGEMENT_VIEWER identity associated with Maker, never a separate Company. Synthetic screenshots deliberately contain fixture names and amounts; they are not evidence of hosted financial balances.

## Files in this batch

New runtime files: all nine files in `src/workspace/`: `CompanyWorkspaceShell.tsx`, `WorkspaceQuickActions.tsx`, `AccountingCycle.tsx`, `WorkspaceReports.tsx`, `workspaceNavigation.ts`, `workspaceText.ts`, `useWorkspaceText.ts`, `workspaceSubscriptionContext.ts`, `workspace.css`.

Modified existing runtime files: `src/auth/ProtectedApplication.tsx`, `src/app/TenantReadyApplication.tsx`, `src/dashboard/ExecutiveDashboard.tsx`, `src/dashboard/DashboardChart.tsx`, `src/master/CompanySubscriptionStatus.tsx`, `src/attendance/AttendanceApplication.tsx`, `src/payroll/PayrollApplication.tsx`.

Focused fixtures/runners: `scripts/fixtures/company-workspace.tsx`, `scripts/verify-company-workspace.mjs`, `scripts/verify-company-workspace-browser.mjs`. Phase evidence below and current handoff/roadmap are updated. No dependency/package, SQL or Edge changes.

## Verification and limits

23 navigation/translation/preservation checks (181 protected files); 133 browser assertions across two completed runs; 9 axe WCAG scans with zero violations and four dashboard color-contrast incompletes for manual review; 42 M1 money/date checks; existing isolated expense interaction regression PASS.

Final machine-readable results: [local result](release/local-company-workspace-redesign-result.json). All browser transport is synthetic, external browser requests blocked, write RPC/table methods forbidden. Existing authenticated owner/recipient browser sessions were not used or logged out.

Local browser coverage: nineteen actual routes; exact existing financial fixture values; eight groups; EN/AR at1440/820/390; dashboard/cycle overflow and status labels; native mobile keyboard behavior; accounting, viewer, project and System Admin presentation boundaries; expired/cancelled/unknown/foreign subscription shortcuts; Company identity transition; M1 date/save/money preservation; zero synthetic writes and unchanged synthetic records. Financial module route checks include valid empty data and do not claim full posting coverage. An existing isolated expense interaction regression additionally verifies exact money, lost-response/remount recovery, failed-read/no-repost, role/Company boundaries and narrow Arabic rendering.

Protected source hashes compare against the actual pre-M2 working tree, preserving 181 financial/report/source aggregation/M1/SQL/Edge/Platform Owner files. Payroll/Attendance content is compared with the pre-M2 content allowing only the main→section semantic tag change. No hosted financial fingerprint is rerun: preservation follows from no hosted requests/writes plus unchanged protected implementation; previous accepted hosted evidence remains historical evidence.

Automated WCAG scans are limited to rendered fixture states, not a complete accessibility certification. Remaining incomplete checks require human review. Owner visual acceptance, real assistive technology, Firefox/Safari and hosted redesigned Company sessions remain deferred. Original M1 historical-date intent remains unresolved pending source evidence; M2 does not reinterpret dates. Full financial statements, approved opening balances, reconciliation and fiscal closing remain future accounting work.

## Exact local visual acceptance

1. Open http://127.0.0.1:5173/ in an existing authorized Company user's private browser session; sign in privately if needed. The unchanged local mode is `supabase-auth`, targeting Development `eqnzueginpkskbnqvgoc`. A Platform Owner account alone does not grant Company financial access.
2. Select the intended Company through existing memberships. Review the dashboard, posted/source distinction, charts, sidebar groups and current Company identity. Open `/accounting-cycle` and `/accounting-reports`.
3. Navigate existing master, expense, Treasury, subcontract, Attendance and Payroll pages. Review forms without submitting; verify M1 AED/date/save presentation. Do not create or post financial data for visual acceptance.
4. Switch English/Arabic and resize to desktop/tablet/mobile; review the drawer, keyboard focus, labels, tables and dialogs. In a separate already-authorized viewer session, verify read-only presentation. Do not share credentials or assume a browser session's identity.
5. Provide visual feedback. Any protected Preview deployment requires separate authorization; this batch stops locally.

## Lifecycle classification

Business/accounting: VERIFIED for presentation/provenance preservation; no new financial policy. Security/authorization: VERIFIED for focused role/tenant/subscription presentation and unchanged authoritative boundaries; no broad audit. Database: NOT APPLICABLE (no schema or hosted data work). Deployment: DEFERRED; no Preview/Production release. Testing: local automated and agent screenshot review VERIFIED; owner visual/hosted/multi-browser/assistive-technology acceptance DEFERRED. Documentation: final evidence and handoff reconciled after verification. Local M2 does not imply commercial/Production readiness.

## Synthetic visual captures

[Desktop English](release/company-workspace-redesign/dashboard-en-1440.png), [desktop Arabic](release/company-workspace-redesign/dashboard-ar-1440.png), [mobile English](release/company-workspace-redesign/dashboard-en-390.png), [mobile Arabic](release/company-workspace-redesign/dashboard-ar-390.png), [Accounting Cycle English](release/company-workspace-redesign/cycle-en-1440.png), [Accounting Cycle Arabic mobile](release/company-workspace-redesign/cycle-ar-390.png). Agent inspected actual desktop and Arabic mobile captures; owner visual approval remains outstanding.

## Final local checkpoint

Build PASS (exit0,2746 modules); lint PASS (exit0,same10 existing warnings); syntax and `git diff --check` PASS. Existing large authenticated bundle advisory remains (820.12kB minified/181.85kB gzip); no unrelated chunk refactor was added. The local server responds HTTP200 at the stated URL. No configuration files were edited.

Completed runners: `M2_BASELINE_SHA256=/tmp/narvo-m2/before-sha256.json M2_BEFORE_DIRECTORY=/tmp/narvo-m2/before node scripts/verify-company-workspace.mjs`; `WORKSPACE_BROWSER_SECTION=presentation` and `WORKSPACE_BROWSER_SECTION=boundaries` with `node scripts/verify-company-workspace-browser.mjs` (axe source supplied via `WORKSPACE_AXE_SOURCE=/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js`, existing4.14 tool); `node scripts/verify-m1-operator.mjs`; `node scripts/verify-p6d-expense-post-interactions.mjs`; `npm run build`; `npm run lint`. The optional baseline paths refer to the actual pre-M2 snapshot; protected before/current hashes are retained in the result.

Initial verification exposed chart focus and contrast issues, now corrected. A synthetic tenant-switch test incorrectly used duplicate SIGNED_IN; existing Auth deliberately ignores that event for the same known user. The corrected fixture uses USER_UPDATED and passed. No Auth implementation change was required. Completed evidence comes from the final two passing browser sections, not interrupted exploratory runs.

**M2 local implementation and browser verification complete. Owner visual acceptance and any deployment remain pending.**
