# Commercial Customer onboarding — local implementation

**Latest R0 gate — 2026-11-02:** Emerald Enterprise identity and local visual implementation are human-approved. The [read-only impact/recovery assessment](R0_PRODUCTION_IMPACT_AND_RECOVERY_ASSESSMENT.md) verifies history64, the unchanged pending migration65 hash, Maker eligibility and all18 Companies. Activation remains **NO-GO** pending recovery assurance and explicit impact/activation decisions; no hosted writes or deployments occurred. Earlier local implementation and visual-pending records below retain their historical scope.

2026-11-02 (Asia/Dubai). **Local implementation; hosted activation NOT authorized or performed.** Production and Development currently share `eqnzueginpkskbnqvgoc`. This work used disposable local databases and loopback synthetic browser fixtures only. Existing deployed Production remains unchanged.

## Architecture and operator experience

`/platform/onboarding` adds a resumable owner workspace using the existing protected owner shell, searchable Customer choice, administrative forms, command transport, saved request recovery, MFA and explicit reconfirmation. Creation of a Customer opens its scoped portfolio; Company creation opens that exact Company's checklist. Existing Customers and Accounting Entities link directly into scoped onboarding. Customers can expand their linked Companies and progress in the directory, then open the full paginated portfolio. One Customer can own multiple independent accounting Companies; contact information grants no membership or accounting access.

The six displayed steps are Customer → Company creation → Accounting Administrator → Accounting Foundation → Subscription → Commercial Readiness. Company activation is a separate setup action after administrator acceptance and before provisioning. The Company creation step does not misrepresent a Draft as ACTIVE; the activation prerequisite remains part of the server readiness result and available actions. Pending administrator invitations show a wait state and link to the existing invitation delivery/review screen. No duplicate invitation is created on refresh, focus, reload or reopening the portfolio. Progress reads refresh on focus/every minute and on explicit refresh; errors show unverified progress rather than success. Scoped request results prevent stale progress from being shown for another filter.

All mutations reuse existing RPCs: `platform_admin_command`, `platform_invitation_command`, `accept_platform_invitation`, `provision_company_accounting`, `set_company_subscription`. No new permission or billing system. Owner-only `get_platform_onboarding` joins existing relationships and returns administrative progress only, never Company financial records. English/LTR and Arabic/RTL reuse the existing responsive shell/dialogs. Current local route: `http://127.0.0.1:5173/platform/onboarding` when the existing development server is running. Do not submit locally against the shared database: use the isolated fixture command for synthetic visual review.

## Authoritative readiness and access

For every non-exempt Company, ordinary new business requires all of:

1. An existing Customer referenced by `platform_entities.customer_id`.
2. ACTIVE public Company and ACTIVE platform lifecycle.
3. An ACTIVE ACCOUNTING_ADMIN membership with ACTIVE profile. Pending invitations do not qualify. Existing explicit owner assignment of an existing administrator remains supported alongside invitation acceptance; no new consent/permission registry is introduced.
4. COMPLETE foundation status **and** durable `company_accounting_provisions` evidence.
5. An effective TRIAL or ACTIVE subscription for that Company, evaluated using inclusive Asia/Dubai dates.

`private.company_commercial_readiness` is the shared derivation used by owner progress, member subscription access and the existing subscription business guard. `get_my_company_subscription` retains its contract and adds the readiness result; the owner subscription directory now uses the same FULL/LIMITED decision. The existing20 triggers continue covering new business/master inserts and specified operational draft edits. Missing Customer/admin/foundation/subscription, future start, expiry and cancellation cannot be bypassed by valid subscription metadata alone or by disabled-button manipulation. Company RLS, financial permission checks and lifecycle remain independent authoritative boundaries.

Readiness is computed, not an independently mutable COMPLETE flag. Removing a Customer link or losing the administrator invalidates business readiness. Owner commands and business inserts serialize on the existing Company row. The readiness helper is VOLATILE so queries after a lock wait see the committed decision, rather than a statement-start snapshot. Four independent native schedules verify this boundary.

LIMITED access preserves existing authorized reads and permitted settlement/reversal and master-maintenance paths. No financial posting/reversal function is changed. The previous expired/cancelled settlement evidence is retained; these tests do not claim a new successful hosted settlement or posting. Subscription changes still use the existing normalized requests, row locks, version checks, durable receipts and immutable audit. No gateway, payment ledger, accounting revenue or cash movement is created.

## Protected foundation initialization without a circular prerequisite

Activation still requires the existing administrator rule, not commercial readiness. The existing provisioner still requires a genuine fresh-MFA owner, exact ACTIVE Company/code/version, active administrator, original platform creation evidence, empty accounting state and fixed baseline intent.

Immediately before the existing account/Treasury inserts, the provisioner opens a private transaction-scoped initialization record tied to Company, `txid_current()` and authenticated owner. The business guard recognizes it **only for account and Treasury INSERTs**. It cannot authorize ordinary business or another Company/transaction. Browser/anon/service-role have no table access; there is no caller-settable GUC or public bypass RPC. The scope is deleted before completion; exceptions roll back scope, accounts, Treasury, receipt, readiness and audit together. Existing same-intent provisioning recovery remains duplicate-free. Native concurrency verifies another connection cannot inherit this exception.

## Exact legacy compatibility policy

`private.company_legacy_eligibility` is a narrow private registry, not an automatic absence-of-subscription rule. The forward migration seeds only the Company already bearing unique code `MAKER`, provided it has no platform `create_entity` audit. It captures that existing Company's ID once as configuration data. There are no tenant UUID constants or Maker branches in readiness/accounting logic, no general browser exemption command and no future Company-insert exemption trigger.

The existing Maker receives no Company, membership, chart, Treasury, financial or subscription update. Its existing identity and access remain intact; its accounting foundation is not rerun. New Companies, including similarly named Companies, cannot inherit eligibility. Other existing test Companies are **not** silently exempted. Additional legacy eligibility would require explicitly reviewed IDs and separate authorization; do not broaden the seed or infer eligibility from age, names or missing subscriptions.

An eligible ACTIVE internal Company keeps business access without Customer/foundation commercial enrollment and without a subscription. If a subscription is explicitly assigned, its effective expiry/cancellation limits still apply; eligibility cannot bypass that subscription. Internal eligibility is not commercial completion or proof of payment. No paying-customer/revenue metric is invented; portfolio progress labels eligible Companies as internal legacy rather than commercially completed.

## Local changes

- New forward-only migration: `supabase/migrations/20261102120000_commercial_company_onboarding.sql` (65th canonical migration; **unapplied hosted**).
- New reusable owner workspace/portfolio: `src/platform/CommercialOnboarding.tsx`.
- Existing owner integrations: `src/platform/PlatformApplication.tsx`, `PlatformShell.tsx`, `platformApi.ts`, `platformText.ts`, `platform.css`.
- Member access explanations only: `src/master/CompanySubscriptionStatus.tsx`, `src/workspace/workspaceText.ts`, `useWorkspaceUiText.ts`.
- Local fixture RPC allowlists: `scripts/platform-fixture-server.mjs`, `scripts/fixtures/platform-console.tsx`.
- Focused runners: `scripts/verify-commercial-onboarding.mjs`, `verify-commercial-onboarding-browser.mjs`, `verify-commercial-onboarding-native.py`; package scripts added without dependency/lockfile changes.
- This report, execution JSON/screenshots, handoff and roadmap checkpoint. All earlier uncommitted work retained. No original applied migration rewritten.

## Verification and limits

See `docs/release/local-commercial-onboarding-result.json` and its referenced database/browser/native evidence for final executed counts and hashes. The disposable tests exercise actual canonical RPCs and trigger enforcement. Cases cover complete onboarding, pending invitation/reload/acceptance, every missing readiness prerequisite, expiry/cancellation/renewal, explicit legacy eligibility, independent Company subscriptions within one Customer, foreign-role denials, MFA/reconfirmation, protected initialization before or after subscription assignment, duplicate recovery and late-failure rollback.

Existing Company/membership rows are compared before/after migration. Every existing function other than the four intentionally replaced readiness/provisioning/projection functions is verified byte-identical, including financial posting/reversal and authorization functions. Four genuinely independent native PostgreSQL schedules observe lock waits for cancellation, Customer unlink, renewal and provisioning-versus-business. No hosted test or real credential is used. Synthetic Auth/MFA tests are not new hosted MFA acceptance.

Screenshots in `docs/release/commercial-onboarding-screenshots/`: pending administrator, completed onboarding, Customer portfolio and Arabic390px mobile portfolio. Agent visual inspection is recorded; human visual acceptance is still required. Focused axe findings and any incomplete rules are recorded separately from manual accessibility certification. No unrelated broad audit or old concurrency suite repeated.

## Hosted impact and safe activation sequence — separate approval required

1. Review this local migration, source manifest, screenshots, behavior and explicit Maker eligibility seed. **Because the DB is shared, applying it affects the existing Production application immediately.** It is not an isolated Development activation.
2. Fresh read-only guards must verify the exact shared project, approved Production baseline,64 applied canonical migrations, sole pending65th migration/hash, exact existing Maker identity/code and absence of platform creation evidence. Review an impact inventory before approving application: only Maker is seeded; other unenrolled Companies become LIMITED. In particular the existing Stage D test Company currently has no Customer association and will be LIMITED until separately associated. This implementation does not authorize that association or any other record change. Stop if a legitimate Company needs an unapproved exemption.
3. Establish an approved tested restoration/recovery plan for schema and configuration, and record Company/membership/accounting/audit baselines. Perform an isolated single-file linked dry-run showing only this migration. Neither dry-run nor hosted inspection was performed in this local batch.
4. With explicit **shared hosted/Production-impact authorization**, apply only the reviewed migration. Read-only postflight: canonical history65; exact eligibility row(s), no initialization scope rows; Maker and all existing business rows unchanged; forced RLS/grants/functions/triggers; computed owner/member readiness; no provisioning, subscription or financial mutations. Initial progress/access changes are derived, not business-data rewrites.
5. Build a newly reviewed clean allowlisted frontend package with the same verified Supabase project and browser-safe configuration. Separately authorize one protected candidate/Preview deployment, then genuine owner/member read-only smoke and human visual acceptance. Preserve Auth/MFA/invitation configuration. Promote only with explicit approval. No deployment is included in this task.
6. Separately approve one fresh synthetic commercial Customer/Company/admin invitation/foundation/subscription acceptance, with exact identities and Treasury inputs. Do not use Maker for provisioning or create a replacement Maker. Full new hosted financial operations require their own approved business inputs and scope.

Forward-only rollback limitation: reverting the frontend does **not** remove database readiness enforcement. Never drop the eligibility registry/scope/receipts, erase audit, delete subscriptions, rewrite applied SQL or temporarily restore generic UNMANAGED/FULL access. A confirmed hosted defect requires a reviewed forward correction or an explicitly authorized functioning recovery plan. Historical data cleanup is unrelated and unauthorized.

## Remaining integration limits / completion categories

- **VERIFIED locally:** coherent assisted owner onboarding, shared readiness, private explicit legacy eligibility, Company portfolio, preserved finance/authorization contracts, targeted SQL/browser/concurrency checks.
- **DEFERRED:** human visual acceptance, fresh shared-environment integrity/dry-run, migration/deployment authorization and execution, genuine hosted onboarding acceptance. Existing-user invitations retain the existing sign-in/review-link handoff; automatic existing-user email is not added.
- **NOT APPLICABLE:** payment gateway, commercial invoice accounting, financial posting changes, Maker recreation/reprovisioning or data cleanup. OWNER_CURRENT/funding policy remains separately unresolved and is not inferred from foundation readiness.
- Business/accounting VERIFIED for the approved local onboarding/access policy; financial semantics unchanged. Security/authorization VERIFIED locally with existing authority/Company boundaries. Database VERIFIED local65 replay/RLS/grants/atomicity/concurrency; hosted checks DEFERRED. Deployment NOT EXECUTED. Testing VERIFIED at the documented scope; real hosted/browser and full assistive-technology acceptance DEFERRED. Documentation/traceability recorded. Local completion is not a claim of full commercial go-live readiness.

## R0 local visual-acceptance follow-up — 2026-11-02

The completed focused review adds only local presentation clarity for Company lifecycle, effective subscription and inclusive dates, next action/wait/resume and filtered empty feedback. See [R0 report](R0_COMMERCIAL_ONBOARDING_VISUAL_ACCEPTANCE.md) and [human review gallery](release/r0-commercial-onboarding-visual/index.html) for executed counts, new source hashes, screenshots and limits. Original local implementation evidence above is preserved unchanged; its source hashes predate these two UI/CSS changes. Command transport, readiness, authorization, recovery, financial functions and all canonical migrations are unchanged. Human visual approval is still pending. Migration65 is not hosted; frontend is not deployed; no hosted operation or Maker change occurred.
