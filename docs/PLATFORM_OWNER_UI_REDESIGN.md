# Platform Owner Console — local UI modernization

2026-11-01. Lifecycle: design and local implementation/verification; no hosted action authorized. The accepted subscription lifecycle and current dirty implementation are the baseline. Database/RPC/authority contracts stay unchanged. Production-quality presentation is the target; commercial and Production readiness are separate gates.

## Inspection and design plan

The existing nine routes share one working command/recovery/MFA controller. Current gaps: ungrouped wrapping navigation; little distinction between identity, data and operational status; raw metrics without context; long instructions before page titles; heavily wrapped headers and actions; no explicit loaded-page sorting/filtering; plain loading/empty states; unlabelled choice selects; minimal modal hierarchy. Native modal focus containment/Escape/restore and uncertain-response recovery already exist and must be retained.

Design: navy navigation, teal primary actions, warm light canvas, white surfaces, subtle borders, restrained shadows,14px body/clear30px page titles, system Inter-compatible English and system Arabic fonts (no remote font dependency).4/8px spacing rhythm,12–18px radii, textual status badges with non-color cues, accessible focus and reduced-motion support. Desktop persistent sidebar; tablet/mobile native-dialog navigation, compact header and independently scrollable semantic tables. No invented financial metrics, trends, activity timelines or growth percentages.

Architecture/sequence:

1. `PlatformShell.tsx`: grouped existing routes, shared navigation, header, language/session controls, mobile native navigation dialog and skip link.
2. `platformUi.tsx`: shared badge/cell formatting, loading/empty states, operational overview cards/chart, preserving actual metrics and checked-at timestamp.
3. Existing `PlatformApplication.tsx`: retain command/controller/recovery boundaries, integrate new presentation and page descriptions, explicitly page-scoped filter/sort controls, accessible table regions and clearer editor/reconfirmation presentation. Existing RPCs/search/pagination untouched.
4. `platform.css`: scoped tokens/layout/typography/forms/table/dialog/RTL/responsive states. No accounting-workspace/global-theme redesign.
5. Translation parity, isolated local real-RPC browser regression/accessibility and responsive screenshots; build/lint/boundary checks. No hosted tests, migrations or deployment.

Filters/sorting apply only to the25 loaded rows and are labelled accordingly. Search continues to use the existing server RPC and resets pagination. Do not present loaded counts as platform-wide totals. Overview uses only the existing nine authoritative metrics; lifecycle chart displays actual active/suspended/archived plus derived remainder, no fabricated time series. Unknown values remain unknown rather than becoming zero.

Implementation and actual verification results will be recorded below after execution. Hosted visual acceptance and protected Preview deployment require separate approval.

## Implemented presentation

The existing9 routes now use the shared shell/header/grouped navigation, native mobile menu, page descriptions and shared visual tokens. Overview has four real-RPC metrics, a lifecycle distribution and operational follow-up counts with authoritative checked-at timestamp. No trends/revenue/financial data are invented or requested. Current lifecycle source counts drive the remainder segment; screenshots use disposable synthetic fixtures, not hosted customer data.

Directories retain existing global RPC search/pagination and gain explicit loaded-page status/action filtering, locale-aware sorting (audit newest first), visible/loaded counts, clear-search empty state, loading skeletons, textual badges and localized calendar display. Wide semantic tables have named keyboard-scrollable regions and desktop sticky actions; mobile scrolling stays inside the table. Details retain all returned data; structured audit metadata is expandable. Important company/invitation/subscription guidance is available as a disclosure rather than dominating page titles. Subscription management has a shorter visual action with the original full accessible name.

Native editor dialogs are centered and responsive, with sticky headers, labelled choice selectors, readable confirmation panels and preserved focus/Escape behavior. MFA, editor business-input serialization, command/delivery/idempotency/recovery and authority handlers match the captured pre-redesign baseline. Existing transport/RPC/grants/migrations remain unchanged. New `usePlatformText.ts` shares translation lookup without adding Fast Refresh warnings. English/Arabic text parity and logical-direction CSS cover both directions; fonts/icons introduce no remote runtime requests.

Files: `src/platform/PlatformApplication.tsx`, `PlatformShell.tsx`, `platformUi.tsx`, `usePlatformText.ts`, `platformText.ts`, `platform.css`; `scripts/verify-platform-ui.mjs`; loopback fixture HTML title/lang/viewport only in `scripts/platform-fixture-server.mjs`; one npm script in `package.json`. No dependency/lockfile, accounting-workspace, migration or backend source change. Prior uncommitted work is retained.

## Local verification method and scope

All new browser work uses headless Chromium, loopback-only Vite and disposable PGlite replaying the canonical migrations with synthetic identities/MFA. It does not inspect or modify owner/recipient hosted sessions. Fixture seeding creates only synthetic local companies/subscriptions/customers/invitations; no hosted mutation or email. The redesign matrix takes a before/after fixture snapshot to prove its page navigation/search/sort/filter/editor-cancel checks perform no Company/subscription/audit mutation. Existing command browser suites independently use their own synthetic fixtures.

Accessibility tool: `axe-core@4.14.0` installed under `/tmp`, with no application dependency. Reproduce:

```sh
npm install --prefix /tmp/narvo-owner-redesign-tools --no-save --package-lock=false --ignore-scripts --no-audit --no-fund axe-core@4.14.0
PLATFORM_AXE_SOURCE=/tmp/narvo-owner-redesign-tools/node_modules/axe-core/axe.min.js npm run verify:platform:ui
```

The suite covers9 real-RPC routes at1440/820/390px in English/Arabic, page-contained overflow, captions/labelled regions, real overview counts, loaded-page filter/sort scope, server search/page reset, modal and navigation focus/Escape/restore, no financial queries, read error/retry/stale clearing and loading states. Axe runs WCAG2 A/AA,2.1 AA and2.2 AA tagged checks across route/locale/mobile and editor/menu states. Automated checks are not full WCAG certification or a substitute for assistive-technology/user review.

Problems corrected during local verification: hidden mobile navigation must not leave a second closed dialog in the DOM; a decorative avatar needed aria-hidden instead of an invalid generic-span accessible label; sort/filter selects now have explicit accessible names. Harness hydration and Arabic MFA-label selection were corrected, without changing application Auth behavior. Local listen initially required sandbox escalation; there was no hosted fallback. A later build was terminated during concurrent resource pressure; final build validation must be taken from the completed sequential run, not inferred from the earlier successful intermediate build.

A legacy P6C static scan rejects `.rpc(` in `src/master/CompanyAccountingSetupStatus.tsx`. That file matches the accepted manual-subscription Preview package byte-for-byte and was not changed here; it is not a newly introduced redesign failure. The broad rule predates these accepted member status reads. The scan was not weakened to manufacture a pass; reconcile its scope in a separate maintenance batch. The P6A production-auth import boundary passes. No general security/accounting audit was performed.

Final executed counts, screenshots and completion categories will be appended after the matrix and final build finish. No new Preview is approved or deployed. Owner visual approval of local English/RTL/responsive screenshots, then separate approval for a protected Development Preview package/build/deploy and read-only hosted owner acceptance remain required. No schema activation or company/subscription operation is part of this redesign. Commercial and Production readiness remain separate.

## Final verified local checkpoint

**LOCAL IMPLEMENTATION AND BROWSER VERIFICATION PASS.** [Machine-readable evidence](release/local-platform-owner-ui-redesign-result.json).

- New UI matrix: **144 assertions PASS**, all9 routes in English/Arabic at1440/820/390px; **43 axe-core4.14 scans, zero reported violations**, no browser runtime errors. Same synthetic Company/subscription/audit state before/after UI read/cancel checks. Real RPC metric counts, filters/sort/search/server pagination, editor/native mobile menu focus/Escape/restore, errors/retry/stale clearing and loading passed.
- Existing local workflow regressions: **50 console +19 MFA +9 subscription browser assertions PASS**, including scoped authority/revocation, editor confirmations, same-request recovery and preserved subscription rendering. No concurrency/database suite was repeated independently; canonical migration replay is only fixture setup.
- **Final `npm run build` PASS**, exit0,2736 transformed modules. Final successful run used a persistent local terminal after terminated sandbox/resource-pressure attempts. Existing large-chunk advisory remains (authenticated bundle796.02kB minified/174.46kB gzip); no unrelated bundle refactor.
- **Lint PASS**, the same10 existing warnings, no new warnings. **P6A import boundary PASS** across187 modules; syntax and diff checks PASS; parsed translation parity249 EN/AR keys. Legacy P6C failure above remains documented and unchanged; not presented as a pass.
- Protected handler-block comparison and API/recovery/migration hashes PASS. No new dependency, backend/schema/migration, accounting-workspace, real Company/subscription/membership/financial change, hosted configuration, deployment or Git-history action.
- Agent inspected representative English/Arabic desktop/mobile screenshots. Axe incomplete items include color-contrast and empty-table `th-has-data-cells`; nine declared text/status/navigation color-pairs were checked separately, minimum ratio5.19. Offscreen/empty-table/assistive behavior still needs human acceptance; no full WCAG certification claimed. Firefox/Safari and real screen-reader acceptance are not performed.

The earlier full-reload test harness timed out under local load; the passing matrix uses the actual sidebar/mobile menu within one authenticated synthetic session per locale, with bounded scans and progress evidence. No app safeguard or test assertion was removed to force a pass. No user Chrome process/session was stopped or changed.

### Representative actual local browser captures

- [English desktop Overview](release/platform-owner-redesign/overview-en-1440.png), [Arabic desktop Overview](release/platform-owner-redesign/overview-ar-1440.png).
- [English tablet](release/platform-owner-redesign/overview-en-820.png), [Arabic tablet](release/platform-owner-redesign/overview-ar-820.png).
- [English mobile](release/platform-owner-redesign/overview-en-390.png), [Arabic mobile](release/platform-owner-redesign/overview-ar-390.png).
- [Subscriptions desktop](release/platform-owner-redesign/subscriptions-en-desktop.png), [Arabic mobile subscriptions](release/platform-owner-redesign/subscriptions-ar-390.png).
- [Accounting entities](release/platform-owner-redesign/entities-en-desktop.png), [Invitations](release/platform-owner-redesign/invitations-en-desktop.png).

Screenshots are synthetic local test records; charts show actual fixture RPC counts, not fabricated production metrics. All9 routes were exercised even where only representative captures are retained.

### Completion and remaining gates

Business/UI requirements **VERIFIED locally**; commercial/Production readiness **DEFERRED**. Authorization/controller integrity **VERIFIED** through unchanged blocks and targeted UI regressions, no new general audit. Database schema work **NOT APPLICABLE**. Deployment **DEFERRED**. Automated and agent visual verification **VERIFIED**; owner visual/accessibility/device acceptance **DEFERRED**. Documentation **VERIFIED** through this record, evidence and official memory.

Next action is owner review of the local captures. Then separately authorize one reviewed, manifest-pinned protected Preview package/build/deployment in the existing maker project using verified Development browser-safe values, followed by read-only owner acceptance. Exclude all company/subscription/invitation/accounting mutations, Production aliases/main, Auth/MFA/SMTP/Edge configuration and Preview protection changes. No migration is needed. This report grants no deployment approval and starts no accounting-workspace redesign or subsequent roadmap phase.

## Authorized Development Preview deployment — execution checkpoint

Owner confirmed human visual approval and separately authorized the Development Preview deployment. The prior deferred deployment/visual labels above describe the local checkpoint and are superseded by this execution record.

Exactly one deployment: **dpl_DPX8Ui7xBMuTmzfTkuGbK61SMjfz**, **READY**, [protected Preview](https://maker-9eixk2rgu-n7rawy1984-8059s-projects.vercel.app/platform). Existing maker project/team, existing Preview configuration and Supabase Development `eqnzueginpkskbnqvgoc` verified. Manifest pins251 files: only four reviewed existing-file changes plus three new presentation components relative to the accepted subscription Preview. Isolated clean install/build, compiled Development-only URL, protected API/recovery hashes, secret scan and exact upload dry-run passed. No migrations, data mutations, environment changes or Git-history operations. Production alias/main link and Preview protection unchanged after submission.

All nine routes require Vercel authentication. The existing authorized Chrome browser reached the new deployment and displayed NARVO sign-in; no session was transferred or protection bypassed. **Authenticated nine-screen hosted read-only acceptance is pending private owner sign-in/MFA.** Existing local144 UI assertions,43 accessibility scans and78 workflow assertions remain valid; they are not substituted for pending hosted browser checks.

[Secret-free deployment evidence](release/development-platform-owner-ui-preview-result.json).

### Final hosted verification — READY with invitation-origin limitation

The owner privately signed in/completed MFA on the new Preview and replied Ready. Agent read-only native Chrome observations verified all nine redesigned screens with settled real data/empty states: Overview18 entities/17 active/0 Customers/290 users; Customers0; Entities18; Users25-row first page; Memberships25-row first page; Invitations1 Accepted/Delivered; Subscriptions18; Audit13 existing events; Settings1/version1. Initial captures that showed normal loading states were replaced by settled views. No forms were submitted. Existing Bareq Management Viewer membership on Maker is visible; this is a user membership, not a second Company.

Live deployed SDK `auth.getUser()` and server `get_platform_context()` confirmed owner `ebcf7115-6cd9-49be-af25-8e57b5befd75` / `naghamel7ayah@gmail.com`, PLATFORM_OWNER, `step_up_required:false`, no errors, Development project `eqnzueginpkskbnqvgoc`. Only selected safe identity/project fields were displayed. The incomplete first diagnostic input produced no successful result and was replaced; only the later live result establishes identity. DevTools were closed and the authenticated owner session returned to Overview. Final Vercel readback confirms READY/non-Production target, unchanged Production alias/main link, Preview protection and environment metadata.

**Remaining integration blocker:** one non-delivery invitation OPTIONS request for the new Preview returned **403**, with `Access-Control-Allow-Origin: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app`. The unchanged function intentionally permits only its previously approved origin. Invitation directory rendering is verified, but invitation delivery **from the new Preview origin is blocked**. No invitation was claimed or sent; no CORS, Edge, Auth redirect, access or hosted configuration was changed. Do not present all administrative mutation workflows as hosted-retested or invitation delivery on this origin as working. Separately authorize Development origin/redirect/access alignment if required; shared configuration impact must be reviewed before any change. No automatic fix or further deployment.

Business/UI **VERIFIED** for nine hosted reads; invitation delivery from new origin **BLOCKED**. Authorization **VERIFIED**. Database work **NOT APPLICABLE**. Deployment **VERIFIED** Development Preview only. Testing **VERIFIED** within read-only scope; mutation reexecution and hosted full RTL/device matrix **DEFERRED**, prior accepted local evidence retained. Documentation **VERIFIED**. Historical data preserved by no mutation/no migration scope; earlier accepted fingerprint evidence remains valid and was not rerun as a general audit. Commercial and Production readiness remain separate.

[Actual Preview captures](release/platform-owner-redesign-preview/overview.png), [runtime identity](release/platform-owner-redesign-preview/runtime-identity.png), and the structured deployment result above record exact evidence.

### Invitation-origin blocker resolved — 2026-11-01

Separately authorized Development-only origin alignment is now **VERIFIED**. The new and previous Previews both return exact-origin OPTIONS204; unknown origin403; anonymous POST401 for each. The canonical origin and callback routing remain unchanged. One optional additional-origin setting and one narrowly tested Edge code deployment (ACTIVE v3/JWT enabled) were applied; no frontend/Production/Auth/database change or email. The earlier403/blocker paragraphs above are historical and superseded for CORS access. [Exact change and evidence](PLATFORM_PREVIEW_INVITATION_ORIGINS.md).
