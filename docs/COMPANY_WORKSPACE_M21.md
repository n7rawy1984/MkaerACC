# M2.1 — Reference-driven Company dashboard foundation

2026-11-01. Local implementation and verification; human visual acceptance is a separate gate. The previous M2 generic dashboard composition was rejected by the owner. Its valid financial/authorization evidence remains; its visual direction is superseded by the supplied reference.

## Reference and implemented composition

Inspected the actual [MakerACC infographic](NARVO_DASHBOARD_REFERENCE.jpeg) before implementation. Preserved its navy navigation, numbered white/cyan section frames, colorful master icons, blue/green/orange three-month columns, connected posting diagram, four report panels, project/contract lifecycle and closing flow. Retained NARVO branding. English flows left-to-right; Arabic mirrors the composition and connectors with its sidebar on the right. Wide layouts use eight setup cards, three month columns and four report panels; mobile stacks months, wraps stages and retains accessible labels.

The reference contains illustrative amounts and apparent completed statements. None were transcribed into application data. Supported detail metrics show real scoped read results; incomplete statements show an em dash and explicit Under development status. Added readable unavailable explanations and role restrictions even where the reference contains only icons/amounts. This is structural visual fidelity, not a claimed pixel-identical reproduction or human approval.

The root Company dashboard and `/accounting-cycle` share the integrated six-section component. The root also preserves the existing detailed financial/historical overview in an expandable section, mounted only when opened. That retains its exact charts, original/current source totals, filters, project statuses, recent expenses, exports and workflows without making generic KPI cards the main composition. Expanding it invokes the existing readers; it introduces no alternate accounting model.

## Integrated components and registry

`CycleFoundation.tsx`: authenticated Company orchestration plus reusable `WorkflowStage`, `WorkflowCard`, `MonthlyActivityColumn`, `FinancialMetricCard`, `MetricValue`, `ProcessDiagram`, `ReportPreview` and `CapabilityBadge`. Workflow/process cards navigate only to implemented role-permitted read routes. Unavailable cards are ordinary non-interactive elements, not disabled fake links.

`moduleRegistry.ts` extends the existing `workspaceNavigation.ts` role contract rather than creating another permission system. Each entry records ID, display/translation key, route/null, implementation status, existing-route access requirement, subscription policy and navigation availability. Planned translations are keyed through `moduleTranslations`; existing labels reuse workspace translations. `moduleForRole` derives route visibility from existing navigation. Subscription metadata describes existing policy; it does not replace RPC enforcement. Existing quick actions still use the original permission predicates and verified Company subscription context. Expiry/cancellation preserve reads and permitted settlements; new Expense requires FULL access.

`metricState.ts`: a small presentation-only state adapter and exact source-evidence aggregation using existing `sourceCurrentAmount`, `sourceDirection`, `sourceReportingMonth` and `dashboardAED`. All monetary sums use BigInt and return minor-unit strings. No persisted amount, posting rule or financial calculation contract changed. A reusable three-month range defaults to August–October2026 and handles year boundaries. SOURCE/DATE basis remains an explicit user choice; no historical dates are reinterpreted.

`cycleText.ts` supplies matching English/Arabic keys; `cycleFoundation.css` scopes the composition, state styles, connected flows, responsive layout and contrast. `WorkspaceQuickActions` adds an optional compact presentation while preserving predicates, routes and subscription checks. `AccountingCycle` delegates to the shared foundation; `ExecutiveDashboard` provides the existing detailed view as an expandable child.

## Data and unavailable inventory

| Element | Existing source / exact meaning | Missing/error behavior |
| --- | --- | --- |
| Posted expense net | Existing `useDashboardRead` + `summarizeDashboard`, complete paginated posted Expense reads, net excluding VAT/Payroll/certificates | Loading/error/denied never become zero |
| Supplier outstanding | Existing Company-scoped supplier outstanding reader | Same explicit states |
| Subcontractor outstanding | Existing certificate payable plus released-unpaid retention | Same explicit states; no duplicate cost |
| Retention held | Existing Company-scoped retention available reader | Same explicit states |
| Monthly source cash inflow/outflow | Existing `useHistoricalSources`, matching active GENERAL evidence and selected SOURCE/DATE month; current corrected amount | No matching evidence is UNAVAILABLE, not zero; errors remain ERROR |
| Monthly source Payroll | Existing authorized PAYROLL source evidence, separately labeled | Missing amount/evidence UNAVAILABLE; never added to source cash totals |
| Monthly custody advances, subcontractor payments, materials | No authoritative monthly breakdown is connected to these cards | UNAVAILABLE with explanation; no description-based classification |
| Trial Balance / Income Statement / Balance Sheet | No verified statement reader implemented | Static decorative document shape, em dash, Under development; no invented financial lines/results |
| Setup | Existing Company/COA/Treasury/projects/parties/subcontracts routes; account edits remain scoped to their existing abilities | Assets and standalone Employee master unavailable; existing Payroll profile functionality remains reachable through Payroll |
| Posting | Existing Expense review/post workflow and journal exports | No standalone rules editor or interactive ledger claimed; explanation distinguishes internal business-document rules and exports |
| Projects/contracts | Existing subcontract, certificate and payment routes | Execution tracking, complete project costs/profitability and project reports remain unavailable |
| Closing | Existing transaction review links | Reconciliation, fiscal closing, final statements and next-period workflow are explicitly incomplete/unverified |

### Five metric states

- LOADING: visible loading text; no retained amount is presented as current verification.
- AVAILABLE: exact verified amount formatted with the existing AED utility.
- VERIFIED_ZERO: only an actual verified zero amount or a successful complete posted read/aggregation establishes zero. Explicit corrected source zero can establish zero; no matching monthly rows cannot.
- UNAVAILABLE: professional em dash with a clear reason (missing evidence, unsupported integration or denied role).
- ERROR: em dash and verification failure; dashboard provides a safe read-refresh button. Refresh creates no business record.

No accounting balance is inferred from imported cash evidence. Monthly cards are scoped evidence, not a completeness assertion about all real cash activity. Unknown/malformed source amounts never fall back to zero. Existing posted aggregation remains unchanged.

## Verification scope

Final counts, actual commands, protected hashes and build/lint results are recorded in [machine evidence](release/local-company-workspace-m21-result.json). Synthetic browser transport reuses the existing real-component Company fixture; external requests are blocked and mutation RPC/table methods forbidden. Controlled fixture changes test errors, true zeros and forbidden tenant responses; they are not hosted mutations.

Coverage: six-section/card/process/report counts; actual source and unchanged posted fixture amounts; missing October evidence; explicit versus absent zero; failed/loading reads; foreign-Company response rejection; viewer/no implicit System Admin finance; expired/cancelled quick actions; root/dedicated-cycle integration; existing detailed charts/export controls; English/Arabic at1440/820/390; no overflow; focused WCAG scans. Earlier M2 layout-specific screenshot assertions describe the superseded layout; M2.1's focused runner is the current composition gate. Existing module business behavior and prior tests are retained as historical evidence, not relabeled as freshly executed.

Protected hashes cover financial handlers/readers, source semantics, M1, Auth, subscription status, SQL/Edge, reports and Platform Owner files. No schema, RLS, RPC, financial posting/reversal, membership, historical record or hosted configuration changes. No database tests/migration dry-run are needed for this frontend-only batch. No existing authenticated browser was logged out or used for mutation.

## Remaining M3–M5 work

These are future acceptance/design gates, not implementation claims or authorization to begin them:

- M3: establish authoritative monthly operation/read contracts and coverage; integrate advances/payments/material categories only after their accounting source and treatment are verified. Preserve exact money, Company scope and permitted settlements.
- M4: design and verify full statements and project/contract cost reporting, including correct dimensions, reconciliations and missing-reader handling. Existing operational detail exports remain distinct from full financial statements.
- M5: define and implement fiscal reconciliation/closing/next-period lifecycle, opening balances and required accounting verification; then focused acceptance and operational readiness. Fixed assets/standalone Employee scope requires its own approved policy and phase.

Original M1 historical date intent still requires source evidence before any data correction. Human visual review, real assistive technology, Firefox/Safari and any hosted redesigned Company acceptance remain deferred. Full Production/commercial readiness is not implied.

## Local visual acceptance

Open **http://127.0.0.1:5173/** in an existing authorized Company user session; sign in privately if necessary and select the intended Company. The unchanged local configuration uses Development `eqnzueginpkskbnqvgoc` in `supabase-auth` mode. A Platform Owner account alone does not grant Company finance access. Review `/accounting-cycle` as well, toggle English/Arabic, resize, change only reporting filters, expand the detailed overview and navigate existing modules without submitting mutations.

Compare the synthetic captures and original reference through the accompanying comparison page. Fixture amounts in screenshots are synthetic; the real local app uses existing authorized data. Stop here for owner visual feedback. No migration, hosted configuration/data change, deployment or Git-history action is authorized by this result.

## Lifecycle classification

Business/accounting VERIFIED for presentation/provenance; no new posting policy. Security/authorization VERIFIED for focused UI access/unchanged authority and synthetic boundaries; no broad audit. Database NOT APPLICABLE (no change). Deployment DEFERRED. Local tests and screenshot comparison VERIFIED when recorded below; human visual/hosted/multi-browser/assistive acceptance DEFERRED. Documentation reconciled with actual evidence. No commercial-readiness claim.

## Final verification checkpoint

**LOCAL IMPLEMENTATION AND VERIFICATION PASS; HUMAN VISUAL ACCEPTANCE PENDING.**34 exact metric/range/registry/translation/preservation checks pass,185 protected files unchanged.56 real-component synthetic browser assertions pass (38 visual +18 boundary); zero runtime errors. Four axe WCAG scans (EN/AR desktop/mobile) report zero violations; four color-contrast incompletes remain for human review. Desktop/tablet/mobile screenshots at1440/820/390 were captured; agent compared the actual reference, English/Arabic desktop, mobile and side-by-side capture. The initial month-basis exact-label assertion exposed an ambiguous control name; an explicit localized accessible label was added and the final visual run passed.

`npm run build` PASS, exit0,2751 modules. Existing chunk advisory retained (authenticated JS839.43kB/gzip188.25kB). `npm run lint` PASS, same10 existing warnings/no new warning. Registry strict standalone typecheck, script syntax, targeted credential-literal scan and `git diff --check` PASS. No dependency or environment files edited.

Commands: `M21_BASELINE_SHA256=/tmp/narvo-m21/before-sha256.json node scripts/verify-cycle-foundation.mjs`; `WORKSPACE_AXE_SOURCE=/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js CYCLE_BROWSER_SECTION=visual node scripts/verify-cycle-foundation-browser.mjs`; `CYCLE_BROWSER_SECTION=boundaries node scripts/verify-cycle-foundation-browser.mjs`; `npm run build`; `npm run lint`. The optional baseline contains the actual pre-M2.1 working tree; matching protected before/current hashes are retained in machine evidence. With no baseline the pure runner intentionally does not claim source preservation.

[Interactive comparison](release/company-workspace-m21/reference-comparison.html) · [side-by-side capture](release/company-workspace-m21/reference-comparison.png) · [English desktop](release/company-workspace-m21/cycle-en-1440.png) · [Arabic desktop](release/company-workspace-m21/cycle-ar-1440.png) · [English mobile](release/company-workspace-m21/cycle-en-390.png) · [Arabic mobile](release/company-workspace-m21/cycle-ar-390.png). The comparison can also be opened locally at http://127.0.0.1:5173/docs/release/company-workspace-m21/reference-comparison.html.
