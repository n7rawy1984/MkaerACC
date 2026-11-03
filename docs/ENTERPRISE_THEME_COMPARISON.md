> **Current decision (2026-11-02): Theme B — NARVO Emerald Enterprise approved for local implementation.** See [implementation and acceptance evidence](#emerald-enterprise-local-implementation). Earlier Theme A recommendation below is historical.

**Product Owner approval — 2026-11-02:** “NARVO Emerald Enterprise is officially approved as the product's visual identity. The local visual implementation is accepted.” Human local visual approval is now **RECORDED**. Earlier pending-acceptance labels below describe the historical review checkpoint. This does not authorize hosted activation or deployment. See [R0 impact/recovery assessment](R0_PRODUCTION_IMPACT_AND_RECOVERY_ASSESSMENT.md) for the nine incomplete accessibility groups and release NO-GO.

# NARVO ERP — Enterprise theme comparison

2026-11-02, Asia/Dubai. **DESIGN EXPLORATION ONLY. No theme selected or adopted.**

[Interactive comparison gallery](release/enterprise-theme-comparison/index.html) · [Rendered results and exact pairs](release/enterprise-theme-comparison/result.json) · [Proposed tokens](release/enterprise-theme-comparison/tokens.json).

## Scope and source

Compared three color identities over the **same current application components**, not new dashboard mockups. The supplied request was read completely (283 lines; SHA256 `21a8cb0b20f0b051d96b1ce2e4a495dad425589fb238e1d4214db30294569b52`). Its final-report section ends mid-item “Three completed theme”; the preceding objectives, screens, constraints and deliverables are complete and were followed. Nothing was inferred to authorize product adoption, live changes or deployment.

Lifecycle stage: design research, preview architecture and visual verification. Existing implementation and R0 workflow behavior are reused. Product-owner visual preference, future adoption design and release gates remain deferred. All pre-existing repository files, including prior dirty work and the R0 implementation/evidence, are preserved byte-for-byte; only new preview tooling, gallery assets and this supporting report are added. Canonical roadmap/handoff milestones have not been advanced. R0's human approval/hosted activation status is unchanged.

## Existing visual-system findings

- Platform Owner uses `src/platform/platform.css`, `PlatformShell`, `platformUi` and shared administrative dialogs/tables/status badges. It has scoped `--po-ink`, `--po-muted`, `--po-line`, `--po-teal`, `--po-teal-dark` and `--po-canvas` variables, alongside hardcoded accent, surface and status colors.
- Company Workspace uses `workspace.css`, `workspaceSuite.css`, `cycleFoundation.css`, `workspaceUi`, shared Card/Badge components and existing Expenses tables. Its `--ws-*`, `--suite-*`, `--cycle-*` and tenant variables coexist with utility colors and hardcoded surfaces/gradients.
- Existing geometry, navigation, component hierarchy, typography, spacing, responsive breakpoints, RTL behavior and exact monetary formatting are reused. Current color definitions are not yet one exhaustive semantic system. In particular, the selected-navigation inset accent and dark selected-Company card needed separate inverse pairings in the preview.
- The smallest safe comparison mechanism is an **additive preview-only adapter** requiring `html[data-narvo-theme]`. It is loaded by a dedicated loopback fixture server, never imported by a product entry point. No mass replacement in source, styling framework, package installation, new runtime settings or default-theme mutation.

## Three completed proposals

| Theme | Sidebar | App background | Primary action | Primary text | Decorative border | Direction |
|---|---|---|---|---|---|---|
| A — Executive Blue |#111C33|#F6F8FC|#2454C5|#17243B|#DFE5EF|Established financial authority; blue actions distinct from green completion|
| B — Emerald Finance |#102A27|#F5F8F6|#087E68|#172C28|#DEE9E3|Restrained, premium green identity; neutral ordinary financial values|
| C — Modern Teal |#102B38|#F5F9FA|#087C91|#19303A|#DFE8ED|Contemporary data-oriented SaaS; closest to the existing visual language|

The six suggested foundation values for each theme are retained. Surface/elevated surface is white. Additional colors define accessible hover, inverse, selection and text-on-tint pairs. Modern Teal's primary passes against white but measured4.373:1 against its secondary-action tint, so **actionText#076A7C** is a separate foreground role; its primary action remains#087C91. Emerald's text-on-tint role is#076B59; Executive Blue uses#2454C5. A foreground cannot be assumed valid on every surface.

Semantic mappings include background, main/elevated/subtle surfaces, sidebar/navigation/inverse text, primary/secondary/muted text, decorative borders versus strong input boundaries, primary/hover/secondary actions, focus on light and dark surfaces, selected navigation, table header/row hover, default/error input, disabled text/background/border, success/warning/danger/info/neutral/pending, and explicit favorable/adverse financial variance. Shared semantic colors stay constant across themes; brand colors are the comparison variable.

Amounts stay neutral in real Expenses/dashboard views. The state playground gives explicit labeled variance examples for gain/loss color, and separately shows confirmed0.00 versus unavailable—. Subscription Active, workflow Complete, pending invitation, expired/cancelled and failed requests retain visible labels; no color grants authority or changes readiness. The playground illustrates the proposed role vocabulary; existing shared status components retain their current labels/tone grouping in the application captures. Any future finer status mapping needs a separately reviewed adoption change.

## Screen, language and device matrix

**90 captures**:10 screen/state variants×3 themes×3 layouts, including81 application screenshots and9 semantic-state screenshots.

1. Platform Owner overview.
2. Incomplete Company onboarding.
3. Pending administrator invitation.
4. Ready Company with Active subscription.
5. Limited Company with expired subscription.
6. Customer directory with expanded multi-Company portfolio.
7. Company portfolio table.
8. Company Workspace six-stage accounting dashboard.
9. Dense Expenses register with realistic synthetic AED values, dates, filters and badges.
10. Semantic controls/status/table/financial-meaning state board.

Layouts: English LTR1440×1000; Arabic RTL1440×1000; Arabic RTL390×844. Full-page screenshots retain the complete existing layouts; scrollable dense tables remain inside their existing regions. Native controls and numeric alignment remain under the existing component/CSS behavior. Fonts are awaited before geometry baselines; the same content and bounding geometry are asserted across all three themes per screen/layout. The gallery preserves screen/device selection while switching highlight or full-size theme inspection; the three static state iframes allow real hover and keyboard focus without submitting any command.

## Isolation and fixture architecture

`verify-enterprise-themes.mjs` uses Vite on127.0.0.1/ephemeral port with `configFile:false`. Its module override uses the existing synthetic Platform Owner and Company Workspace fixtures, replacing the Supabase module **only in this preview server**. Platform projections are static deterministic objects; unknown administrative command requests are rejected. No PostgreSQL instance, migration replay, hosted Supabase project, real credentials, invitation delivery, email or real Company data is involved.

Company fixture values are adjusted only in the preview loader for a synthetic Horizon Company and realistic exact minor-unit strings/dates. No original fixture file or application calculation is modified. All three themes consume the same fixture dataset. A new Chromium context blocks service workers and every request outside the exact loopback origin. The final browser session records zero external browser requests, zero mutation requests, zero browser errors and unchanged Company fixture tables. A process-time interruption required resuming the remaining groups: the completed earlier groups retain their screenshots, contrast/axe results and assertions recovered from the deterministic completed-group pipeline. The final counters for network/mutation/runtime events cover the resumed session; earlier session event arrays were not persisted. The exact-origin request block and read-only fixture architecture applied to both sessions. Controls in the standalone state pages are non-submitting samples.

## Rendered contrast and interaction evidence

**279 assertions**;90 captures;42 scoped axe scans (WCAG2A/AA/2.1AA/2.2AA). Exact computed pairs, thresholds, example selectors, incomplete cases and state measurements are retained in the result. No failing ratio is rounded into a pass.

| Theme | White on primary action | Minimum normal active text | Minimum tested control/focus contrast | Text-node observations | Complex observations for manual review |
|---|---|---|---|---|---|
| A — Executive Blue | 6.668:1 | 5.651:1 | 3.877:1 | 4103 | 0 |
| B — Emerald Finance | 5.006:1 | 5.006:1 | 3.810:1 | 4104 | 0 |
| C — Modern Teal | 4.881:1 | 4.881:1 | 3.851:1 | 4104 | 0 |

Text measurements resolve actual computed colors and alpha-compose ancestor backgrounds. Modern CSS OKLCH values are converted through browser canvas flat-color rendering rather than incorrectly parsed as RGB; screenshot antialiasing is not used. Large text thresholds are determined from computed size/weight; normal text requires4.5:1, large text3:1. Opacity or background-image cases are explicitly retained for manual review instead of assigned a fabricated pass. Repeated node observations across screens are not unique component counts.

State probes exercise actual selected/hover navigation, primary/secondary/destructive default and hover, input/default error borders, light and inverse focus, warning/error/info messages, muted copy, table hover and disabled text. Focus contrast uses the surface adjacent to the offset outline, not the interior filled-button background. Disabled controls are WCAG-exempt; the proposed palette still checks a voluntary4.5:1 text target. Pale decorative separators are not asserted to satisfy interactive-boundary3:1; strong input/control borders serve that distinct role.

Active computed text failures:0. State-pair failures:0. Axe color-contrast findings:0. Other axe finding occurrences:3. Incomplete scan groups:6.

The existing Customer portfolio produces the same target-size finding across themes; this is an inherited **layout finding requiring manual review**, not a theme contrast result or newly reproduced accounting/security defect. Its exact targets and summaries are in the machine result. No production markup or target dimensions were patched in this color exploration. Native control rendering, keyboard/focus appearance in other browsers, complex/background cases, screen readers, color-vision considerations, Arabic copy quality and long-duration accountant comfort remain human/assistive-technology acceptance. Automated tests do not certify WCAG2.2 conformance of NARVO.

## Gallery verification

The file-only gallery passed13 interaction assertions and2 scoped axe scans at1440px and390px with0 confirmed violations. Tests cover equivalent screen/device context, theme emphasis, full-size theme switching, Escape, focus restoration, no page-level horizontal overflow, no external requests and no runtime errors. A preview-only fix made the narrow contrast table a labeled keyboard-focusable scroll region. The390px scan retains6 incomplete color-contrast nodes for manual review; this is not a claimed pass for those nodes. [Gallery verification](release/enterprise-theme-comparison/gallery-verification.json) records the exact results.

## Reference principles

[IBM Carbon color guidance](https://www.carbondesignsystem.com/building-blocks/foundations/color/overview) informs layered neutral surfaces, color roles and tokens. [Atlassian color guidance](https://atlassian.design/foundations/color/) informs naming by purpose/emphasis/state instead of raw hue. These are principles, not copied UI layouts or brand identities.

Contrast targets follow [W3C text contrast](https://www.w3.org/WAI/WCAG22/Understanding/contrast-minimum.html), [non-text contrast](https://www.w3.org/WAI/WCAG22/Understanding/non-text-contrast.html) and [visible focus](https://www.w3.org/WAI/WCAG22/Understanding/focus-visible.html). Inactive-component exceptions are documented separately from voluntary design targets. These source references do not supply product certification.

## Recommendation and human decisions

**Recommend A — Executive Blue as the first direction to consider.** Its action contrast is strongest of these three base colors, and the blue brand separates primary action from green completion and financial gain more readily. Muted blue-gray neutrals support dense records without coloring every metric. B is the most distinctive alternative if a green identity is preferred; C offers continuity with the current NARVO language. All three are professionally viable preview candidates, subject to the recorded limits and owner preference.

Human decisions: preferred brand direction; Arabic/English readability and perceived hierarchy on the same dense register; long-session comfort; acceptable semantic grouping; review of inherited target-size/automated-incomplete cases; and whether a later separately authorized semantic-token adoption proposal is wanted. No selection is inferred from this report. Future adoption must inventory all application/export/white-label scopes, preserve configured tenant boundaries and test focus/hover/disabled/validation states before any default-theme or deployment change.

## Files, reproduction and completion

New supporting tooling only: `scripts/fixtures/enterprise-themes.mjs`, `enterprise-theme-preview.css`, `enterprise-theme-data.mjs`, `enterprise-theme-measurement.mjs`; `scripts/verify-enterprise-themes.mjs`; `scripts/build-enterprise-theme-gallery.mjs`; `scripts/verify-enterprise-theme-gallery.mjs`. Artifacts live under `docs/release/enterprise-theme-comparison/`; this report is `docs/ENTERPRISE_THEME_COMPARISON.md`. No package/lockfile/framework changes. Existing application, migration, fixture, roadmap/handoff and earlier evidence files remain unchanged.

Reproduce with installed project Vite/React/Playwright and the existing local axe tool at `/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js`: `node scripts/verify-enterprise-themes.mjs`, then `node scripts/build-enterprise-theme-gallery.mjs` and `node scripts/verify-enterprise-theme-gallery.mjs`. Loopback/browser execution may require the local sandbox's reviewed process permission. Open gallery `index.html` directly; screenshots/state playgrounds need no server. The axe path is an existing session tool, not a new package dependency; absence requires supplying the equivalent approved tool before rerunning.

Recorded smoke attempts are diagnostics, not final acceptance. Preview corrections addressed residual accents, scoped foreground/background pairs, OKLCH parsing, native-language persistence, font stabilization, a probe selector and fresh-page resets and excluding cached geometry/text inside closed disclosures. The completed-group recovery list is recorded in `result.json`; orchestration changes only added fresh-page comparison resets, excluding non-visible closed-disclosure content and recovery, without changing the captured palette/fixtures. Only complete `result.json` defines final counts/status; diagnostic progress files are not passes. Syntax/targeted lint, gallery interaction/accessibility, artifact links, secret patterns and full pre-existing-file preservation are checked separately. Production build/business/RLS/migration/hosted tests are NOT APPLICABLE because no product/runtime/schema changes are made; no broad accounting or security audit was performed.

| Lifecycle lens | Classification |
|---|---|
| Business/accounting | VERIFIED synthetic visual meaning and untouched product; real financial acceptance NOT APPLICABLE. |
| Security/authorization | VERIFIED read-only isolated previews, no external/mutation requests, existing sources preserved; live authority/session review NOT APPLICABLE. |
| Database | NOT APPLICABLE; no database connected or migration executed; canonical files preserved. |
| Deployment | NOT APPLICABLE; no default theme, hosting, Preview or Production change. |
| Testing | VERIFIED scoped rendered comparisons/contrast and preview checks; full assistive-technology/long-session/human visual acceptance DEFERRED. |
| Documentation | VERIFIED proposals, evidence, limitations and recommendation; canonical release states unchanged. |

Final readiness: **three local design proposals ready for human comparison; no product-theme adoption or release authorized.**


## Emerald Enterprise local implementation

**2026-11-02 — PRODUCT OWNER SELECTED THEME B. LOCAL UI IMPLEMENTATION VERIFIED; HUMAN VISUAL ACCEPTANCE PENDING.** The comparison/recommendation above is historical research. The selected direction is **NARVO Emerald Enterprise**, not Executive Blue. No hosted activation, deployment, invitation or financial command was authorized or performed.

[Before/after acceptance gallery](release/emerald-enterprise/index.html) · [final results](release/emerald-enterprise/result.json) · [full route/state inventory](release/emerald-enterprise/inventory.json) · [color token map](release/emerald-enterprise/tokens.json) · [source preservation](release/emerald-enterprise/preservation.json).

### Architecture and bounded layers

Stage: approved visual design → local implementation → fixture verification. Existing accounting, administrative, membership, subscription and session boundaries remain authoritative. The local default styling changed; the deployed product did not. This is independent of the still-pending R0 human/hosted approval gates.

- **A, foundations:** `emeraldTokens.css` holds the complete49-role Theme B map, plus shared font,4/8/12/16/24/32px spacing scale,8px control/12px card/16px dialog radii and restrained shadows. `emerald.css` holds scoped primitive refinements. Existing scoped `--po-*`, `--ws-*`, `--suite-*` aliases resolve to semantic tokens. Existing CSS color declarations are consolidated, with explicit inverse/status/control pairings; no competing framework, dependency or duplicated page system.
- **B, Platform:** consistent navigation/inverse hover, card surfaces, strong form boundaries, readable controls, portfolio targets, commercial steps and distinct status roles. All implemented owner directories, onboarding states and existing editors are reviewed. No command-open handler/readiness formula changes.
- **C, Company:** the same identity covers masters, financial workflows, source/posted registers, HR and reports. Shared dense tables use tabular digits; reading and form text receive a more consistent hierarchy. Existing module availability stays truthful. The six-stage accounting cycle remains; gradients and decorative multicolor category icons give way to neutral/brand surfaces. No mock production figures or future module implementation.
- **D, responsive/accessibility:** logical borders/menu placement, keyboard focus, larger row controls, scrollable dense tables, native report-modal isolation/focus restoration, error grouping and reduced motion. Scoped component overrides take precedence over legacy utility rules without a global `!important` reset.

Each layer was diff-reviewed against the saved starting snapshot, with subsequent fixture checks for the shared components/routes. Existing handlers were compared independently. Main route evidence was refreshed for final styles; dashboard/cycle/payroll were rechecked after their final icon/menu changes. No unrelated dirty work was reverted.

Core Theme B values are retained: sidebar#102A27; background#F5F8F6; surface#FFFFFF; primary#087E68; action text#076B59; hover#066553; text#172C28; secondary#36564A; muted#4A6258; separator#DEE9E3; input border#70887E; selected navigation#185A4B; table header#EDF3EF; row hover#E7F3ED. Pale separators are decorative; interactive boundaries use the stronger token. No new unrelated hue was introduced. The shadow alpha derives from the sidebar hue.

Shared semantic roles: Active/Full/Trial→information; completed/posted/reviewed/accepted/delivered/paid→success; expired/limited/unpaid→warning; pending/draft/queued/scheduled→pending; failed/suspended/revoked→danger; cancelled/reversed/inactive/unknown→neutral. Labels remain visible. This function determines appearance only, never access/readiness. Ordinary amounts remain neutral; explicit favorable/adverse difference tokens are reserved. A missing dash is not verified zero or an error.

Platform default brand colors are updated in `tenantSettings.ts` and initial CSS variables. Existing tenant settings/provider, names, logos and configured colors remain data driven; controls explicitly using `--tenant-primary` retain that hook. A final scoped CSS correction and browser probe ensure generic button defaults do not override an explicit tenant-color class. A configured tenant color can differ from Emerald and needs its own contrast acceptance. No hosted branding record was read or modified. Demo/auth screens are outside the authenticated-console rollout.

### Exact product files and shared components changed

- `src/platform/platformUi.tsx`
- `src/workspace/cycleFoundation.css`
- `src/workspace/workspace.css`
- `src/workspace/workspaceSuite.css`
- `src/workspace/workspaceUi.tsx`
- `src/components/ui/Badge.tsx`
- `src/financial/ExpenseReadPanel.tsx`
- `src/index.css`
- `src/platform/platform.css`
- `src/reports/ReportExport.tsx`
- `src/reports/financialReport.css`
- `src/tenant/tenantSettings.ts`
- `src/styles/emeraldTokens.css`
- `src/styles/emerald.css`
- `src/components/ui/statusTone.ts`

Shared components affected: Platform StatusBadge, Company StatusBadge, Badge, common CSS primitives for PageHeader/ContentSection/FinancialSummaryCard/DataTable/FilterBar/navigation/forms, Expense summary group, and ReportExport modal. No data repository, monetary formatter/calculator, posting/reversal command, transport, SQL, Auth provider or permission function changed. Supporting new tools are `scripts/fixtures/emerald-server.mjs`, `verify-emerald-enterprise.mjs`, `verify-emerald-interactions.mjs`, `collect-emerald-evidence.py`, `build-emerald-gallery.py` and `verify-emerald-gallery.mjs` under `scripts/`. Historical evidence remains separate.

### Full route inventory and reviewed scope

Platform: `/platform` overview; `/platform/onboarding`; `/platform/customers`; `/platform/entities`; `/platform/entities/:id`; `/platform/entities/new` (same Company editor also exercised by its directory action); `/platform/users`; `/platform/memberships`; `/platform/invitations`; `/platform/subscriptions`; `/platform/audit`; `/platform/settings`.

Company: `/` dashboard; `/company-profile`; `/projects`; `/parties` (including Employee records); `/expense-categories`; `/accounts`; `/treasury-accounts`; `/subcontracts`; `/expenses`; `/supplier-payments`; `/subcontractor-advances`; `/subcontractor-certificates`; `/subcontractor-payments`; `/retention-releases`; `/retention-payments`; `/attendance`; `/payroll`; `/accounting-cycle`; `/accounting-reports`. `/historical-imports` redirects to Expenses source review. Auth-state redirect aliases retain existing routing; the unmatched deferred route adds no module.

For every listed main screen: typography/heading, card/form/table structure, buttons, visible statuses, normal/empty/error patterns, English/Arabic direction and mobile geometry were inspected in source and fixtures. Runtime states do not cover every possible failure on every route. HR profiles, Employee list, subcontract creation, Expense creation, Customer/Company/subscription dialogs, populated report preview and explicit Expense loading/empty/error states have supplemental evidence. The inventory distinguishes sources, aliases and inline workflows. FOREMAN standalone Attendance shares the scoped primitives but role-specific runtime acceptance is deferred; Auth/login/recovery/MFA and future modules remain outside scope.

### Financial table/form usability

The synthetic Expenses register has55 documents and a paginated/scrollable posted subset. Exact minor-unit strings flow through the unchanged formatters. Source cash remains separately labeled from posted Expenses; a posted total is still page-scoped, not a Company balance. Table amounts are neutral, tabular and isolated as before; numeric cells can scroll without ellipsis/truncation. Existing negative variation data remains negative. Large-value exactness, verified-zero versus unknown and immutable summary inputs pass existing pure regression checks, including values beyond Number precision.

Complex Treasury Expense and subcontract forms, payroll profile fields and subscription dates use shared input borders/focus/label sizes. No form was submitted. Destructive labels remain explicit; existing red actions retain destructive styling. Posting/reversal controls preserve event handlers, Company scope and role conditions. Some legacy inline controls still use neutral secondary styling with explicit destructive labels; complete semantic button prop adoption is a later maintenance opportunity. The legacy Company active-nav variant uses primary Emerald (3.034:1 against its dark sidebar), while the Owner console uses the darker selected token with a contrasting edge. Both are within the approved palette; final variant unification and long badge-label wrapping remain human visual decisions. Report preview keeps existing monetary cells, data selection and print/export calculations; screen typography/chrome and focus behavior changed. Native print dialog/save-to-PDF, Excel file opening and print-density acceptance were not performed.

### Accessibility findings and disposition

- **Fixed, pre-existing:** Customer portfolio small link targets: shared table links/buttons now have at least32px block target and padding; mobile buttons40px. Target-size finding is absent in the final scoped scans. Existing portfolio links are siblings rather than nested anchors; inspected interactive rows contain distinct controls.
- **Fixed, pre-existing:** Expenses summary's `aria-label` on a generic div caused an incomplete prohibited-ARIA check. `role="group"` supplies valid semantics; financial summary content is unchanged.
- **Fixed, pre-existing:** report preview claimed modality while background controls remained reachable. Native `<dialog>` supplies browser modal isolation, Escape and focus containment. The PDF trigger is captured before asynchronous loading disables it and restored after close. A focus-restoration regression in the initial native-dialog adaptation was detected and fixed before acceptance.
- **Fixed, confirmed mobile defect:** expanded All-records export popover extended beyond the RTL viewport. It now opens toward the available toolbar space using logical inline-end positioning and a viewport-bounded width. Payroll is recaptured in all three layouts after the change.
- **Fixed during token rollout:** the subcontract required marker measured3.755:1 on white and now uses danger text; muted text on selected/hovered dark surfaces was below4.5:1. Explicit inverse pairings correct the selected owner/Company card and hovered brand text.
- **Pre-existing/deferred:** custom tenant brand-color contrast, uncommon native/browser controls, unexercised per-field business validation, every role-specific branch and every table failure mode need their own acceptance. Existing generic Field error spans are not comprehensively linked to every native input across legacy forms; those unused/error branches are not claimed verified. No full screen-reader or cross-browser audit.

Final scan finding occurrences:0; incomplete scan groups:9. Exact incomplete rule IDs/node counts and confirmed-finding targets are retained, not silently treated as passes. Automated results do not certify WCAG2.2 conformance. Native modal browser-chrome focus is permitted; underlying application controls remain inert during the keyboard probes.

### Focused verification

- Final evidence:45 baseline captures (44 English desktop plus1 Arabic mobile diagnostic);122 final captures covering English desktop1440×1000, Arabic desktop1440×1000 and Arabic mobile390×844, with supplemental forms/dialogs at English desktop and Arabic mobile. Baselines use saved pre-change source, equivalent synthetic data and the same fixtures; no hosted data. The before/after Payroll mobile export-menu diagnostic is retained as a direct regression comparison.
- 204 final route direction/overflow assertions pass;139 supplemental completed interaction assertions. Main routes have no page-level overflow after the menu correction; dense tables and report previews retain intentional internal scroll regions.
- 59 scoped axe WCAG2/2.1/2.2A/AA scans. Measured active-text failures:0; lowest measured normal active-text ratio:4.501:1. Meaningful input boundaries and visible focus are checked on actual controls; default strong border/white pairing is3.810:1. Decorative borders are not asserted to meet interactive-boundary contrast. Disabled controls are exempt; opacity/background complexity is reported in raw measurements.
- Existing M2.2 focused regression:36 assertions pass, including preserved event/financial props against the starting source and large exact-money/zero-versus-unknown cases. Report `act()` generation/export/session logic remains byte-identical; the PDF trigger wrapper and modal focus lifecycle are presentation changes. ExpenseReadPanel differs only by its summary group role.
- Build PASS, with the existing >500kB chunk advisory. Lint PASS, same10 existing warnings. Focused runner syntax/lint, `git diff --check`, source-preservation, whitespace/secret-pattern and evidence-link checks are recorded in the manifest. Gallery interaction/accessibility checks have separate evidence:20 assertions,2 scoped axe scans with0 violations,6 actual product control measurements and a50-row internally scrollable table check. [Gallery verification](release/emerald-enterprise/gallery-verification.json).

Initial attempts are diagnostics, not passes: missing synthetic subscription/payroll read projections and action locators were corrected in test tooling; navigation timeouts required isolated Vite caches and DOM-ready navigation; the long Company process hit its runtime limit and resumed from persisted completed captures/checks. Failed report-focus/menu checks caused the bounded fixes described above. An overly broad gradient-removal edit was caught, the original stylesheet structure restored with balanced replacements, all145 CSS blocks preserved and the affected views recaptured. The final combined result replaces earlier screenshots/checks for refreshed states; raw diagnostic results are not release approval. No test was silently skipped. Field-validation branches, provider Auth/RLS behavior, actual email, financial writes, hosted alignment/dry-run, native print/Excel and human assistive-technology acceptance were not executed.

Reproduction after implementation: `node scripts/verify-emerald-enterprise.mjs --platform`, `node scripts/verify-emerald-enterprise.mjs --company` (use `--resume` only with its matching persisted partial result), `node scripts/verify-emerald-interactions.mjs`, `python3 scripts/collect-emerald-evidence.py`, then `python3 scripts/build-emerald-gallery.py` and `node scripts/verify-emerald-gallery.mjs`. Chromium and the existing `/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js` session tool must be available; no dependency was added. Before captures require the saved `/tmp/emerald-baseline` source snapshot and fail closed if it is absent; archived screenshots remain the reviewable baseline. The gallery runs directly from its folder.

### Preservation, limits and readiness

The starting working tree contained1220 files, including substantial identified pending work. Only the exact listed UI/presentation files and official checkpoint documentation changed; the preservation manifest lists all changed hashes. All150 protected SQL/Auth/financial command files are unchanged. The pending Commercial Onboarding SQL, its readiness/commands, Maker records, subscription rules, canonical migrations and earlier release artifacts remain intact. No new package/framework dependency.

| Lifecycle category | Classification |
|---|---|
| Business/accounting | VERIFIED unchanged source/event/formatting boundaries and synthetic presentation; real financial execution NOT APPLICABLE. |
| Security/authorization | VERIFIED fixture isolation, no external/mutation requests and preserved authority code; live Auth/RLS/tenant audit DEFERRED/outside scope. |
| Database | NOT APPLICABLE: no database connection, SQL/migration change, alignment query or dry-run. |
| Deployment | NOT APPLICABLE to execution: no hosted/configuration/deployment action; local UI differs from the live package. |
| Testing | VERIFIED scoped fixture/browser/contrast/keyboard/build/lint/regression evidence; screen-reader/cross-browser/human visual acceptance DEFERRED. |
| Documentation | VERIFIED current selection, inventory, implementation, failures/fixes, test limits and local-only readiness; historical research retained. |

**Stop: ready for human visual acceptance of the local Emerald identity, subject to the recorded findings.** Review Arabic mobile typography, dense table scrolling, complex form spacing, subscription/status meaning, report preview and the six-stage dashboard's reading density. Approve terminology/hierarchy/brand feel before any later release proposal. No theme implementation implies hosted onboarding activation. Existing shared-database impact, recovery, migration65 and separately authorized frontend release gates remain unchanged.
