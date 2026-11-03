# R0 Commercial Onboarding — local visual and functional acceptance

**Human local visual approval recorded — 2026-11-02.** The Product Owner approved Emerald Enterprise as the official identity and accepted the local visual implementation, closing the pending local visual gate documented here. This acceptance covers local presentation evidence; genuine hosted commercial onboarding and release acceptance remain pending. Earlier pending labels below are historical. See [R0 impact/recovery assessment](R0_PRODUCTION_IMPACT_AND_RECOVERY_ASSESSMENT.md). No hosted activation/deployment is authorized by this approval.

2026-11-02, Asia/Dubai. **LOCAL REVIEW PASS — HUMAN VISUAL APPROVAL PENDING.** This is the first R0 release-acceptance step, not hosted activation or production/commercial readiness.

[Human review gallery](release/r0-commercial-onboarding-visual/index.html) · [Executed result](release/r0-commercial-onboarding-visual/after/result.json) · [Original local implementation](COMMERCIAL_CUSTOMER_ONBOARDING.md).

## Scope, safety and reproducibility

Reviewed the existing `/platform/onboarding` journey within the existing Platform Owner shell/design system. Constitution and R0/SAAS-01/QA-01/OPS-02 boundaries remain binding. The initial dirty working tree was captured by file hashes before this batch; earlier unrelated work and historical evidence remain intact.

Runner: `node scripts/verify-r0-onboarding-visual.mjs`. Uses existing `startPlatformFixtureServer`, in-memory PGlite replay of all65 unchanged canonical migrations and actual administrative RPCs under synthetic authenticated claims. Owner/admin identities use example.invalid addresses; MFA is simulated. Vite binds only127.0.0.1 on an ephemeral port. The fixture replaces the Supabase client module. A new isolated Chromium context blocks service workers and all browser requests outside the exact local origin. No external browser request was attempted in the passing run. The runner closes its browser/server/database in `finally`.

No hosted database connection, migration application, email delivery, live Auth/configuration action, Customer/Company/subscription/membership mutation, Maker operation, deployment, commit or push. Local synthetic Company activation, provisioning and subscriptions are genuine disposable SQL command execution, not hosted acceptance. The recipient acceptance transition uses the actual local RPC between owner review steps; no real inbox or recipient browser acceptance is claimed. No financial journal was created, even in the disposable fixture.

## Business-owner journey review

| Review area | Observed local behavior | Evidence |
|---|---|---|
| Owner entry/navigation | Console navigation enters onboarding; active route/title retained; narrow Arabic drawer works with keyboard and Escape/focus restoration |01,28 |
| Customer creation/selection | Existing shared modal validates creation; resulting Customer opens its scoped portfolio; selecting Customer resumes it |02,03,25 |
| Company creation/association | Customer preselected and persisted; Company creation opens exact checklist; Draft is now explicitly distinct from Active |04–06 |
| Administrator invitation/waiting | ACCOUNTING_ADMIN selected; pending acceptance explained; invitation review link works; reload retains one invitation; no activation action until acceptance |07–11 |
| Activation/protected foundation | Accepted administrator enables activation; confirmation and reason required; foundation action is separate; stale MFA triggers verification then explicit reconfirmation, with zero accounts before reconfirmation and11 afterward |12–17 |
| Manual subscription | Existing configuration form records explicit dates/state/manual payment metadata only; no actual collection or journal; missing/active/expired/future/cancelled/trial states visibly distinguished |18–24 |
| Readiness/completion | Six server-derived checklist states retained; Company status and subscription metadata supplement them; ready wording appears only for server-ready Company |20–24 |
| Multi-Company portfolio | One Customer holds two independent Companies: ready Trial Company and Draft pending Company; directory expansion and full portfolio navigation work |25–29 |
| Loading/empty/error | Fresh read hides stale readiness; loading is visible; progress error makes no success claim and explicit refresh recovers; no search matches differs from empty portfolio; duplicate Customer is rejected |01,30–33 |
| Responsive/bilingual/accessibility | English LTR and Arabic RTL;1440px desktop,820px tablet,390px mobile and360px narrow mobile; shared native dialogs scroll to accessible lower fields/confirmation |All captures; separate modal-bottom images |

Screenshot numbers refer to gallery filenames; suffixes distinguish language/width/state. All monetary/payment-looking entries and2020–2099 service dates are clearly synthetic inputs, not actual subscriptions or paying customers.

The interface now answers: completed steps are checked; the next-action message identifies action versus waiting; confirmed progress can be resumed from onboarding/portfolio; Draft creation differs from accounting readiness; subscription effective state and inclusive service dates are visible. Existing technical receipt references and administrative confirmation/MFA safeguards remain.

## Confirmed findings and bounded local fixes

| Classification | Confirmed issue and path | Local correction |
|---|---|---|
| confirmed defect — UX clarity | `CommercialOnboarding.tsx` collapsed missing, expired, cancelled and scheduled subscriptions to Pending; active and Trial to Complete. The owner could not identify the actual service state in this journey | Show localized **server-derived** effective state, with inclusive dates; do not recompute access/dates in browser |
| confirmed defect — UX clarity | Company creation displayed Complete while lifecycle was absent; after administrator acceptance, foundation was highlighted but the actual next action was activation | Show localized lifecycle badge, activation prerequisite and next-action/waiting guidance; add explicit confirmed-progress/resume explanation |
| confirmed defect — empty-state feedback | A search with no matches displayed “No companies in this portfolio. Create a Company…” even when the portfolio had Companies | Display no-matches/clear-search guidance for a nonempty filter |
| expected/intentional behavior | Native modal blocks the background language control and other page controls; no submission merely from fresh MFA | Reviewers close without submitting, switch language and reopen; tests preserve synthetic values for equivalent captures. No modal/security redesign |
| expected/intentional behavior | Native modal Tab sequence may visit browser chrome; underlying application stays inert | Keyboard assertion rejects underlying-app focus, allows native browser-chrome behavior, and verifies Escape restores trigger focus. No custom focus trap added |

Runtime changes are limited to `src/platform/CommercialOnboarding.tsx` and scoped additions to `src/platform/platform.css`. Existing read effects, CustomerPortfolio behavior and all seven command-open sites remain byte-identical. No transport/API/recovery/financial command, PlatformApplication authorization, Auth/session implementation, SQL/RLS/grant or readiness formula changed. Names/dates/statuses use existing authorized RPC projections; unknown states display unverified rather than invent success.

## Verification performed and evidence limits

- **147 focused assertions PASS** in the completed run, producing **41 screenshots** including modal-bottom confirmation views.
- **31 focused axe WCAG2A/AA/2.1AA scans:0 violations**. Incomplete scan groups: 3; exact rule IDs/node counts are in the result and gallery. Automated axe is not complete keyboard, screen-reader, contrast or Arabic-copy certification.
- All captured pages have no document overflow at their actual recorded viewport; EN/AR direction checked. Agent visually inspected representative desktop, tablet, Arabic mobile, pending/activation, completed/expired and portfolio views.
- Customer association, safe reload without duplicate invitation, local acceptance/activation, protected provisioning/reconfirmation, independent Company subscriptions, actual effective-state transitions, error/retry and duplicate rejection exercise actual disposable RPCs.
- `npm run build` PASS; existing >500kB chunk advisory remains. `npm run lint` PASS with the same10 pre-existing warnings, none introduced in the reviewed UI. Runner syntax, `git diff --check`, focused secret/whitespace scan, migration/source preservation and documentation/gallery links verified separately.
- Prior49 local SQL checks and4 independent native PostgreSQL schedules remain historical E1 evidence and were **not rerun** for these presentation-only changes. Original E1 result/screenshots are retained; this batch has its own result/hash manifest.

Baseline captures were diagnostic comparisons, not a completed passing suite. Initial runner attempts required corrections to native-dialog language handling, collapsed-select synchronization, the existing subscription business-input contract and locator scope. One run ended externally before completion. These interrupted attempts are not counted as verification passes. Final `after/result.json` alone defines the passing assertion/scan counts; no application logic was changed to satisfy those harness assumptions.

Not performed: hosted queries/alignment/dry-run, real MFA/email/recipient flow, live Customer onboarding, hosted financial posting or settlement, Firefox/Safari or screen-reader acceptance, full Production Security & Accounting Integrity Audit, production deployment. Existing unrelated low-impact issues are not reopened by this focused review.

## Human acceptance and deployment stop

Review the [gallery](release/r0-commercial-onboarding-visual/index.html), especially Draft Company, administrator waiting/activation, completed Company, expired subscription and Arabic mobile portfolio. Human decisions: approve English/Arabic terminology and tone, spacing/hierarchy/contrast and mobile scrolling density, clarity of next action/wait/resume/readiness, and manual subscription configuration. Human visual approval remains **PENDING**, not inferred from these automated results.

No remaining confirmed blocking UI defect was found within the completed local review scope. Human approval is the next stop. The UI changes require a newly reviewed frontend package/hash manifest; the old frozen package is not this new local package.

Hosted/deployment blockers remain unchanged: shared Production/Development database impact and exact legacy/access inventory; fresh canonical alignment/single-file dry-run; approved tested backup/restoration/recovery; separately authorized migration65 activation and postflight; separately authorized frontend candidate/Preview/deployment; genuine identity-bound hosted visual/onboarding acceptance. Applying the migration changes the currently deployed app immediately; frontend rollback cannot undo DB enforcement. No approval is requested or assumed for those actions here.

Maker is unchanged: existing internal legacy Company, no recreation/reprovisioning/enrollment or separate accounting engine. The pending migration's approved explicit compatibility policy remains intact. Migration `20261102120000_commercial_company_onboarding.sql` remains locally present/unapplied hosted; this frontend remains undeployed.

## Completion categories

| Lens | Classification |
|---|---|
| Business/accounting | VERIFIED local administrative journey/presentation; financial semantics unchanged. Real commercial/accounting acceptance DEFERRED. |
| Security/authorization | VERIFIED fixture isolation, preserved command/auth boundaries and no external requests; genuine hosted MFA/identity acceptance DEFERRED. |
| Database | VERIFIED unchanged65 canonical file hashes; disposable replay/commands used for UI. Hosted alignment/dry-run/application DEFERRED. |
| Deployment | NOT APPLICABLE to execution; no deployment. Shared environment/recovery/authorization gates DEFERRED. |
| Testing | VERIFIED focused Chromium/axe/build/lint/source checks; human visual/assistive technology and hosted evidence DEFERRED. |
| Documentation | VERIFIED phase report/gallery/current checkpoint references; old E1 evidence preserved and source-hash differences explicitly attributed to these two local UI files. |

Final readiness: **ready for human visual approval of the local R0 onboarding UI; stop before hosted activation or deployment.**
