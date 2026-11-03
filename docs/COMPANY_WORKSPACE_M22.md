# M2.2 — Complete Company workspace UI modernization

2026-11-02. Resumed the interrupted local checkpoint without resetting, discarding or rebuilding the existing M1/M2/M2.1/M2.2 work. Implementation and focused local verification are complete; **human visual acceptance remains pending**. No M3, hosted action, migration, deployment or Git-history change was performed.

## Design and shared architecture

The existing Company workspace now shares a compact navy/teal shell, clear page title and breadcrumb, active Company context, language switch, account menu, grouped navigation and compact subscription/foundation notices. Existing Company switching and sign-out remain available. The account menu closes with Escape; the native mobile navigation dialog retains focus and returns it to the trigger. A contextual New Expense shortcut requires the existing role and a verified Company-matching FULL subscription snapshot; unknown or limited access never enables new business entry. Database/RPC authorization remains authoritative.

`workspaceUi.tsx` reuses existing Card/Badge primitives for PageHeader, ContentSection, FinancialSummaryCard, DataTable, FilterBar, StatusBadge, ActionToolbar, EmptyState, LoadingState, ErrorState, FormField, DetailPanel, WorkspaceDrawer and ExpandableText. `useWorkspaceUiText.ts` contains paired English/Arabic labels. `workspaceSuite.css` scopes visual rules to Company/standalone Attendance interfaces; Platform Owner styles are unchanged. Arabic mirrors navigation and layout; money/reference identifiers retain readable bidirectional isolation. Existing module date/month controls remain authoritative; no fictitious global fiscal-period selector was introduced.

The approved M2.1 six-section dashboard composition, module registry and readers remain intact. Its inner title is an h2 beneath the shared page h1; there is no replacement generic KPI dashboard.

## Completed routes

| Routes | Implemented presentation scope |
| --- | --- |
| `/`, `/accounting-cycle` | Unified shell/header around the preserved six-section integrated dashboard and expandable existing detailed overview. |
| `/expenses` | Compact source filters, secondary advanced filters with active count, grouped exports, readable source/register sections, exact scoped summary cards, dense posted table, full-description disclosure, accessible correction/reversal details and existing business-entry forms. |
| `/projects`, `/parties` | Shared action bars, record cards, lifecycle badges, consistent metadata and existing forms. |
| `/company-profile`, `/expense-categories` | Consistent details/module layout and existing authorized actions. |
| `/accounts`, `/treasury-accounts` | Consistent master record layout/statuses and preserved Treasury-to-GL identity/mapping details. |
| `/supplier-payments` | Existing payment workflow in the shared responsive module layout. |
| `/subcontracts`, `/subcontractor-advances`, `/subcontractor-certificates`, `/subcontractor-payments` | Consistent existing contract/financial modules; M1 exact AED subcontract presentation retained. |
| `/retention-releases`, `/retention-payments` | Existing controls and permission boundaries retained in the shared layout. |
| `/attendance`, `/payroll` | Shared page hierarchy and existing period controls; standalone Foreman Attendance remains isolated from financial navigation. |
| `/accounting-reports` | Unified header and existing read-only report/export capabilities. |

All 19 routes were exercised. This does not claim every financial route has a newly tested populated transaction lifecycle: some synthetic payment/retention states are empty. Master modules retain existing record cards rather than being rewritten as new data grids. The concrete density overhaul is the Expenses register and existing imported-source table.

## Expenses: presentation without accounting changes

Source evidence remains distinct from posted accounting. Search, sorting, paging, date basis, active/archive, cash direction, payment and accounting filters retain their existing handlers. Advanced fields may collapse without resetting values. Export builders and scopes are unchanged; the all-record export is a secondary disclosure rather than duplicate prominent buttons.

The posted table preserves the existing 50-row page, date evidence, exact canonical AED formatting, lifecycle, identity metadata, corrections, specialized reversal controls and original command props. Desktop action columns stay visible while wide tables scroll; mobile scroll stays inside a labelled region. Long descriptions can be fully disclosed. A final screenshot check found status labels splitting mid-word; their column now has a minimum width and preserves whole labels.

Posted summary counts/net/gross use exact BigInt minor-unit arithmetic and explicitly cover **POSTED rows on the current loaded page only**. Draft/reversed rows are excluded. They are not Company balances. Loading/error states show unavailable rather than zero. Unknown invoice-only/Payroll source evidence remains unavailable; zero is shown only for a known successful filtered aggregate. No financial storage, VAT, retention, journal, posting, reversal or source-correction semantics changed.

Source-editor close now restores focus to the originating action (or its table region when the row disappears). The SourceEditor implementation and financial command components remain unchanged. Expired/cancelled subscriptions retain existing posted reads and permitted reversal/settlement contracts; presentation prevents shortcuts/forms for new expense business. No new permission system was introduced.

## Files changed relative to the pre-M2.2 checkpoint

New presentation files:

- `src/workspace/workspaceUi.tsx`, `useWorkspaceUiText.ts`, `workspaceSuite.css`.
- `src/workspace/expensePagePresentation.ts`, `sourceSummaryPresentation.ts`, `workspaceBusinessAccess.ts`.

Existing presentation integration:

- `src/workspace/CompanyWorkspaceShell.tsx`, `WorkspaceReports.tsx`, `CycleFoundation.tsx`, `cycleFoundation.css`.
- `src/app/TenantReadyApplication.tsx`.
- `src/financial/ExpenseReadPanel.tsx`, `src/historical/HistoricalImports.tsx`.
- `src/master/CompanyProfilePanel.tsx`, `ProjectsList.tsx`, `PartiesList.tsx`, `AccountMasterLists.tsx`, `PersonMasterCreationPanel.tsx`, `SubcontractCreationPanel.tsx`.
- `src/attendance/AttendanceApplication.tsx`, `src/payroll/PayrollApplication.tsx` (embedding/header changes; content/command implementation byte-identical).

Verification:

- New `scripts/verify-workspace-m22.mjs`, `scripts/verify-workspace-m22-browser.mjs`.
- Existing source-interaction runner/fixture updated for the current route composition and advanced-filter disclosure; original edit/archive/export assertions preserved.
- Expense POST interaction runner uses bounded 60-second navigation/timeouts for cold-start reliability; financial assertions unchanged.

The machine result records changed-file hashes and 193 protected source hashes against the pre-M2.2 filesystem snapshot. Pre-existing dirty Platform/Auth/migration work was preserved; Git's full dirty list is not the M2.2 change list.

## Verification evidence

[Exact local result](release/local-company-workspace-m22-result.json) and [archived logs/results/screenshots](release/company-workspace-m22/index.html).

- 37 unit/preservation checks PASS: exact money above Number range, zero/unknown source behavior, translation parity, Company-matching subscription state, syntax and preservation of 193 financial/read/Auth/RLS/SQL/Platform/M1/M2.1 sources.
- 99 main Chromium assertions PASS across 19 routes: shared page hierarchy/navigation, 50-row Expenses, M1 money/date controls, forms and correction details, source-editor focus restoration, EN/AR at 1440/820/390, six dashboard sections, viewer restrictions, expired/cancelled shortcuts/forms, mobile dialog focus/Escape, no runtime errors and no navigation mutations.
- 17 additional Chromium assertions PASS: eight Arabic mobile routes, isolated Foreman Attendance, full bilingual description, failed/verified-zero summary states, populated Treasury/COA mapping details, account-menu Escape and zero mutation endpoints/runtime errors.
- Eight axe WCAG A/AA scans: **zero reported violations**. Source-editor and Expenses scans retain `aria-prohibited-attr` and `color-contrast` incomplete entries; dashboard retains `color-contrast` incomplete. Projects/reports scans have none. Incomplete checks are **not passes** and require manual review; no claim of complete accessibility certification.
- Existing synthetic Expense POST/recovery regression PASS: exact inputs, same-request lost-response/remount recovery, receipt recovery without reposting, scoped refresh, roles/Company isolation and EN/AR/mobile. No real financial operation was performed.
- Existing synthetic source regression PASS: General/Payroll separation, edit/save/archive/restore, immutable original controls, corrected totals, audit, export, filtering/pagination, viewer restrictions and EN/AR/mobile. The fixture mounts the actual source summary and actual posted-journal export without assuming a superseded dashboard heading order.
- Final build PASS; lint PASS with the same 10 pre-existing warnings. Existing >500 kB chunk-size advisory remains. Script syntax and `git diff --check` PASS.

Browser tests launch independent headless Chromium profiles, serve actual application components with synthetic clients and block non-local network requests. Navigation fixtures reject mutation endpoints; dedicated financial interaction regressions use synthetic command clients. They do not replace real hosted financial posting acceptance. Previously completed hosted lifecycle/concurrency evidence was not repeated or relabelled as M2.2 execution.

## Screenshots and local human review

35 representative images are archived under `docs/release/company-workspace-m22/`: matching before/after desktop captures for nine routes, Expenses EN/AR at three widths, eight Arabic mobile internal routes, posted table and populated Treasury/COA examples. [Comparison gallery](release/company-workspace-m22/index.html) provides matching pairs. Fixtures are synthetic; their Maker label and illustrative values are not claims about hosted Maker balances. Before/after Expenses, mobile Arabic Projects and populated Treasury were visually inspected; agent inspection is not owner approval.

The existing local server is reachable (HTTP 200): **http://127.0.0.1:5173/expenses**. Start at **http://127.0.0.1:5173/** to review the retained dashboard, then navigate existing modules. Existing Development Supabase configuration and authenticated sessions were preserved; sign in privately if the browser has no valid session. Do not submit business actions during visual review.

Remaining gates: owner visual feedback/acceptance, manual review of axe incomplete items, and any specifically requested adjustments. Firefox/Safari and real assistive-technology acceptance were not performed. A Preview deployment requires separate authorization and environment/package verification. Production readiness and unfinished M3 functional/report capabilities remain outside M2.2.

## Proportional completion classification

| Category | Status and boundary |
| --- | --- |
| Business/accounting | VERIFIED locally: financial components/semantics preserved, M1 fixes retained, summaries explicitly scoped. No new accounting policy or live posting acceptance claimed. |
| Security/authorization | VERIFIED within affected UI: existing Company/role/subscription gates preserved; financial/Auth/SQL sources unchanged. Database authority retained; no broad audit. |
| Database | NOT APPLICABLE to implementation: no schema/migration/data changes. Existing canonical migration sources preserved; no hosted alignment/dry-run needed. |
| Deployment | DEFERRED: local build only; no hosted action or configuration change. |
| Testing | VERIFIED automated/local synthetic runtime and screenshots; DEFERRED owner visual approval, manual accessibility items and additional browser engines. |
| Documentation | VERIFIED: this report, result, gallery, handoff and roadmap reflect actual local scope and deferred gates. |
