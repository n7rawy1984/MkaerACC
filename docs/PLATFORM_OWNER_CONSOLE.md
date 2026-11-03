**P0 onboarding Stage A — 2026-10-31: DEVELOPMENT DATABASE APPLIED / 22/22 POSTFLIGHT VERIFIED.** Explicitly approved SHA-pinned `20261031120000_platform_invitation_onboarding.sql` applied only to `eqnzueginpkskbnqvgoc`; canonical history62. Only the recipient-read RPC was added: fixed empty search_path, authenticated-only client execution, recipient/session/Company authorization retained. All62 existing application-table fingerprints,152 prior functions and existing permissions/RLS are unchanged;528 journals balanced. No Auth-template/redirect change, function/frontend deployment, test records, emails, financial or backup operations. Preview access/origin and later hosted steps require separate authorization; real-recipient acceptance remains PENDING. See [Stage A evidence](release/development-onboarding-stage-a-result.json) and [remaining activation stages](PLATFORM_ONBOARDING_DEVELOPMENT_ACTIVATION.md). Earlier pending Stage A labels below are historical.

**P0 invitation onboarding — 2026-10-31: LOCAL FIX VERIFIED / HOSTED ACTIVATION PENDING.** New-user password→sign-out/sign-in→explicit acceptance→normal Company selection now preserves invitation intent through reload. Recipient-only read RPC and two-field invite-template patch are prepared; new migration is NOT applied, function/frontend NOT deployed, no real users/memberships/emails changed. Existing-user review/sign-in path does not duplicate users or use recovery as invitation delivery. Prior one-hour owner browsing remains PASS; real onboarding/sensitive-operation/Vercel acceptance remains PENDING. See [implementation, tests and exact approval-gated actions](PLATFORM_NEW_USER_ONBOARDING.md). Earlier functional findings describe the pre-fix checkpoint.

**Real-browser acceptance — 2026-10-31 (owner-reported PASS):** the existing real Platform Owner session remained usable for approximately one hour of navigation without repeated MFA prompts. This closes the sustained browsing acceptance check following the applied P1 migration and20/20 postflight. Invitation end-to-end acceptance, sensitive-operation real-session MFA/reconfirmation testing, and Vercel deployment acceptance remain **PENDING**. No invitation, privileged mutation or deployment is implied by the navigation result. This release batch is local documentation/staging/commit only; push and deployment require separate authorization. Earlier pending browsing/owner-access statements below are historical.

**P1 MFA UX correction — 2026-10-30: DEVELOPMENT MIGRATION APPLIED / POSTFLIGHT VERIFIED.** Explicitly approved SHA-pinned `20261030120000_platform_read_mfa_freshness.sql` applied only to eqnzueginpkskbnqvgoc after fresh guards and exact canonical dry-run. Hosted history61; all20 postflight checks pass, original60 history and54 data fingerprints unchanged, journals balanced; existing roles/grants/RLS/owner and fresh-TOTP mutation guards unchanged. AAL2 browsing no longer has a ten-minute freshness gate; local actions use genuine MFA plus explicit reconfirmation. Sustained real-session browsing is owner-reported PASS (31October); sensitive-operation real-session acceptance remains PENDING. No frontend/Edge/public deployment, email, backup or financial operation. See [scope and actual execution](PLATFORM_MFA_READ_WRITE_SEPARATION.md). Earlier pending-migration/owner-access statements below are historical.

**Owner correction APPLIED/VERIFIED (2026-10-29):** explicit approved Development transfer complete. Existing ebcf7115 Auth identity is sole ACTIVE PLATFORM_OWNER; old e1ef565b registry retained INACTIVE, epoch advanced. One audit event; all10 Auth/MFA/session/profile/membership/financial preservation checks pass. MFA factors unchanged; target still needs real enrollment/verification before Overview. See [actual execution record](PLATFORM_OWNER_TRANSFER.md). Older pending/old-owner-current statements below are historical; do not reapply the operation.

**Owner intent confirmed; execution approval pending (2026-10-29):** intended existing Auth identity is ebcf7115-6cd9-49be-af25-8e57b5befd75. The guarded single-active-owner transfer is prepared and20 isolated checks pass; no hosted changes. See [exact transfer review](PLATFORM_OWNER_TRANSFER.md). Earlier identity-confirmation pending statements are historical; execution approval remains required.

**Latest identity check (2026-10-29):** original8October owner Auth/profile/registry link is correct and ACTIVE/PLATFORM_OWNER. The29October identity used today has no registry entry and fails the exact owner predicate before MFA. Owner intent between the two existing UUIDs must be confirmed; no privilege change or account recreation performed. See [targeted identity check](PLATFORM_OWNER_IDENTITY_CHECK.md).

**Latest loading correction (2026-10-29):** bounded session/RPC/MFA handling and explicit context/Overview failure states now implemented; no indefinite read spinner. Current hosted context403/42501 remains an authorization error. Real refreshed-tab/Overview acceptance is deferred; no repeated sign-in/reset prerequisite is asserted. See [focused loading report](PLATFORM_LOADING_FIX.md). Earlier identity inventory is historical.

**Current real access blocker (2026-10-29):** get_platform_context403/42501 Denied; authenticated identity differs from the registered owner. Correct account switch/sign-in and real MFA required; no hosted privilege change is authorized or needed. Local diagnostics/account switching fixed,8 focused/49 browser checks pass. Actual hosted Overview acceptance remains pending. See [current access record](PLATFORM_OWNER_ACCESS_FIX.md).

**Recovery acceptance correction (2026-10-29):** local verified-session handling corrected; explicitly approved Development recovery template/redirect patch applied/read back.41 protocol/template and47 isolated browser checks pass; fresh real email/password/MFA acceptance is pending. Full-response configuration comparison limitation is documented. See [focused recovery fix](PLATFORM_PASSWORD_RECOVERY_FIX.md). No financial/migration, user, backup or public-deployment changes.

**Actual hosted Development checkpoint:** all four approved migrations are APPLIED; history60 and immediate financial/security postflight PASS. Approved owner only, zero Company financial membership. Independent recovery remains incomplete under the explicit Development-only owner risk exception. Real owner MFA and hosted email/function/browser acceptance remain pending; private real-Development app ready at `http://127.0.0.1:5173/platform`. No Production deployment or extra hosted configuration. See [actual execution record](PLATFORM_ACTIVATION_EXECUTION.md). Older unapplied/remote-unknown labels below are historical.

**Latest checkpoint:** SMTP delivery and exact four-migration linked dry-run are owner-verified PASS. Existing historical-user transport test does not prove new-recipient Platform invitations. Hosted templates still lack TokenHash and the delivery function is undeployed; local preparation is checked. Mandatory release gate still blocks activation. See the [single execution checklist/minimal sequence](PLATFORM_ACTIVATION_EXECUTION.md).

**Current target:** existing application `https://maker-eosin.vercel.app/platform`, existing Vercel/Supabase projects. No separate application/domain. Owner manages backup/recovery separately; no related agent operations or information requests. Mandatory release gates remain blocking. See the [single current checklist](PLATFORM_ACTIVATION_EXECUTION.md) for latest MFA/email work and verification.

**Latest execution:** [P0 activation checklist](PLATFORM_ACTIVATION_EXECUTION.md). Local email/callback preparation and guarded native-clone rehearsal complete; hosted activation remains blocked by mandatory independent recovery. Earlier dated checkpoints below are historical.

# NARVO ERP Platform Owner Console — local implementation, 2026-10-28

**P0-H8 update (2026-10-29):** current hosted compatibility/alignment/grants/financial and HDD-copy checks are verified within the [readiness record](PLATFORM_PRE_ACTIVATION_READINESS.md). Four migrations remain unapplied; actual-owner/provider/hosted acceptance and independent custody are not complete. The [activation procedure](PLATFORM_DEVELOPMENT_ACTIVATION_PLAN.md) is prepared only, not executed or authorized. Earlier dated test/status sections below remain historical evidence.

## Current P0 security checkpoint

**LOCAL SECURITY FIX COMPLETE / HOSTED SECURITY UNVERIFIED / REMOTE ACTIVATION NOT AUTHORIZED.** The stale-invitation restoration defect found in P0-H1 is corrected locally. Read [the correction record](PLATFORM_INVITATION_REVOCATION_SECURITY.md) for the root cause, authorization generations/status epochs, serialized control-plane lock contract, T01–T15 and hosted prerequisites. All preceding 59 migration files are preserved. Eight genuine independent local PostgreSQL-session races pass; hosted/actual-owner acceptance remains deferred.

## Scope and readiness

The product owner authorized continuous **local** implementation of all console batches A–G. See the supplied `NARVO_ERP_CODEX_AUTONOMOUS_PLATFORM_OWNER_EXECUTION_2026-10-28.md` and V1.6 master plan. This record supersedes the older next-session A–D priorities for development sequencing; it does not discard those requirements.

**Implemented locally; NOT activated on hosted Development, accepted by the actual owner, or production-ready.** No hosted mutation, role grant/bootstrap, migration application, Auth/configuration change, Company/user/invitation creation, email, financial mutation, commit, push or deployment was performed. The existing 56 migrations were not rewritten. Four platform migrations await hosted verification/activation; the fourth is the P0 forward security correction.

Baseline: `main`, `9da8612ac0f9e9e92efa0b9eb417af0311cfc2e3`. The two user-provided NARVO Markdown files were already untracked and were preserved. No prior source edits were present.

## Implemented surface

- `/platform`: verified platform-only counts and timestamps, pending setup/invitations and delivery failures.
- `/platform/customers`: searchable, paginated customer directory and create/edit.
- `/platform/entities`, `/platform/entities/new`, `/platform/entities/:id`: identity/details, BUSINESS/PERSONAL classification, optional customer relationship, designated administrator, Draft creation, metadata and lifecycle controls.
- `/platform/users`, `/platform/memberships`: approved membership grants/role changes/revocation and ordinary-user deactivation/reactivation. Global deactivation removes Auth sessions and protects each affected Company's last active Accounting Admin. No password setting or impersonation by administrators.
- `/platform/invitations`: durable pending/accepted/revoked invitations, queue/resend/revoke, delivery attempts and truthful delivery failures.
- `/platform/audit`: paginated append-only administrative events.
- `/platform/settings`: versioned support email and EN/AR notices.
- `/platform/subscriptions`: explicit non-billing foundation; optional plan labels are stored on entity metadata. No subscriptions/payment integration or entitlement enforcement is claimed.
- `/auth/callback`: explicit code or token-hash verification, recipient-bound invitation acceptance, and setting one's own password. Implicit URL-fragment credentials fail closed.
- `/auth/recovery`: self-service recovery request with a generic anti-enumeration response. Actual delivery remains provider-dependent.

English/Arabic, RTL/LTR, responsive labeled mobile rows, visible actions, native modal focus trapping/Escape/restoration, confirmation and reason fields, optimistic conflicts, pending-command recovery after reload, and fail-closed authority errors are implemented. Successful same-authority background checks preserve the console tree. Platform routes are resolved before Company membership routing; the owner needs zero Company memberships.

## Files and migrations

Application: `src/platform/{PlatformApplication.tsx,platformApi.ts,platformText.ts,platform.css,platformRecovery.ts,AuthCallback.tsx,RecoveryRequest.tsx}`. `src/auth/ProtectedApplication.tsx` adds the independent routes. `scripts/production-boundary.mjs` permits only the explicit new request-recovery storage module.

1. `20261028120000_platform_control_plane.sql`: reuse/explicit role on private registry, customer/entity metadata, receipts, append-only events, settings, live-session/MFA validation and safe queries.
2. `20261028121000_platform_commands.sql`: closed administrative use cases, atomic onboarding, normalized request hashing, lifecycle, membership/user administration, settings and paginated administrative directories.
3. `20261028122000_platform_invitations.sql`: invitation/acceptance state machine, outbox/leases, delivery acknowledgment and narrow grants.
4. `20261028123000_platform_invitation_revocation.sql`: atomic stale-invitation invalidation, Company-scoped email and stable user-ID generation fences, identity epochs, consistent administrative transaction gate and independent invitation authority checks. Existing pending invitations are conservatively revoked for authorized reissue; see correction record.

Server-only Auth delivery: `supabase/functions/platform-invitation-delivery/{index.ts,handler.mjs}`. It forwards the caller's validated token to the DB lease command and uses a server-only credential exclusively for Auth invitation and delivery acknowledgment. It is **not deployed**. The handler's injected ports are tested without network/email. The Deno/Supabase wrapper still requires hosted integration acceptance.

Tests/preview: `scripts/verify-platform-{database,security,delivery,browser,revocation,concurrency}.mjs`, `scripts/platform-fixture-server.mjs`, `scripts/preview-platform-console.mjs`, `scripts/fixtures/platform-console.tsx`. PGlite 0.5.12 is a pinned **development-only** dependency, with real PostgreSQL/pgcrypto and synthetic Supabase Auth scaffolding. It is never imported by production source.

## Security and business contract

Company and its existing IDs, financial RLS, permission maps, private accounting primitives and posted-history rules remain unchanged. No accounting/source/project/payroll module was edited. New administrative tables are private, forced-RLS, and have no browser DML. SECURITY DEFINER functions have fixed empty search paths; browser EXECUTE grants are restricted. The trusted service may acknowledge delivery but cannot execute caller administrative commands through a service-role context.

Platform authority derives from `auth.uid()`, ACTIVE profile and ACTIVE private registry row with explicit PLATFORM_OWNER role. Checks lock registry/profile/session rows and validate live `auth.sessions`, session expiry and account ban. Privileged data/commands require AAL2 in both JWT and current session, that session's currently verified TOTP factor, and signed TOTP authentication-method evidence within ten minutes. A fresh JWT `iat` is not a substitute. Missing/malformed/stale evidence fails closed. The hosted Auth schema and actual TOTP claims must be validated before activation. The upstream [Supabase Auth session model](https://github.com/supabase/auth/blob/master/internal/models/sessions.go) supplies the session AAL/factor association; its presence on the current hosted project is still an activation check.

The schema adds the explicit role to the existing registry, retaining its existing authority meaning; it registers nobody. Neither current email nor a Company SYSTEM_ADMIN membership authorizes platform access. No GUI platform-role grant, owner self-enrollment, privileged target accounting-membership assignment, or owner recovery bypass exists. Loss of owner MFA requires separately authorized protected recovery, not email-only platform elevation.

Administrative commands have closed names and field sets, actor-scoped UUID request keys, canonical JSON hashes and durable receipts. Authorization precedes receipt replay. Matching retries return the original receipt; mismatched payloads fail. A success and its audit commit together; failure rolls back the reservation and business effects. Audit stores safe changed-field names, versions, reasons and lifecycle values rather than full personal/financial payloads. Denied calls are errors, not falsely persisted success events; broad security-failure monitoring remains a later operational gate.

The private Company sidecar avoids backfilling existing organizations, legal identity or personal ownership. Legacy Companies remain unclassified/unlinked until an authorized administrative command explicitly supplies metadata. Customer grouping grants no financial access. Maker, Green, Owner Accounts, Villa 13 and Farm are not created, moved or corrected by these files.

New entities are **DRAFT / INACTIVE**, accounting setup INCOMPLETE. A supplied existing ACTIVE non-platform identity receives designated ACCOUNTING_ADMIN membership atomically; a missing identity leaves PENDING_ADMIN without a phantom user. An accepted admin invitation/assignment completes administrative onboarding, never accounting setup. Activation requires a live active Accounting Admin. No GL, Treasury, opening balance, capital, VAT or financial document is initialized.

Lifecycle uses the existing Company status gate: ACTIVE permits existing membership-based workflows; DRAFT/SUSPENDED/ARCHIVED set INACTIVE and freeze normal Company reads/writes. This follows existing behavior, not a new read-only financial bypass. All records remain. DRAFT → ACTIVE/ARCHIVED; ACTIVE → SUSPENDED/ARCHIVED; SUSPENDED → ACTIVE/ARCHIVED; ARCHIVED → SUSPENDED → ACTIVE. Reopening/reactivation remains available for legitimate settlements. Version checks and Company locks serialize administrative changes. A financial command already authorized in an earlier transaction is not promised to be cancelled by suspension: existing financial kernel transaction semantics are unchanged. Hosted multi-session timing requires acceptance. The correction adds a transaction gate for all platform mutations and invalidates old pending invitations on suspension/archive; reopening does not restore those invitations.

Memberships use existing roles with an explicit allowlist excluding Company SYSTEM_ADMIN elevation through this console. Targets cannot be the actor or a registered platform principal. Removing/downgrading the last active Accounting Admin is blocked; global user deactivation checks all affected Companies under ordered locks. Per-user transaction advisory locks serialize membership additions with user deactivation before enumerating affected Companies, including a grant into a previously unrelated Company. No ordinary Company role gains platform privileges. Existing independent multi-Company memberships remain authoritative.

Invitations bind normalized current verified Auth email, Company and role. Acceptance requires live session, active profile, unexpired/unrevoked invitation and still-active inviter authority. It does not overwrite an existing membership. The correction independently checks authorization generations and recipient/issuer status epochs; later access decisions invalidate pending invitations atomically, cancel their jobs and expose the reason to administrators. See the correction record for resend, reactivation and replay policy. Duplicate pending invitations are constrained. External Auth and PostgreSQL are non-atomic: a leased job records actual outcome; a lost acknowledgment is uncertain and expires for controlled retry. Emails are at-least-once; a delivered email cannot be recalled, but DB invitation revocation blocks subsequent acceptance. Existing Auth users may need direct authorized membership or the existing-user acceptance route when provider invitation delivery rejects an existing account; no password reset is silently substituted.

The recovery envelope in sessionStorage is actor-scoped business request data, never authority or accounting truth. It is written before sending and removed only after a verified matching receipt or explicit clearing of a rejected request. Uncertain requests must be recovered before another mutation. Auth tokens/QR secrets/passwords are never stored there.

## Run locally

After installing the repository's dependencies:

```sh
npm run verify:platform:db
npm run verify:platform:revocation
npm run verify:platform:delivery
npm run verify:platform:browser
npm run platform:preview
```

Preview: `http://127.0.0.1:4178/platform`. Synthetic MFA code **123456** belongs only to the isolated fixture; it is not recognized by production. The preview is loopback-only, uses in-memory synthetic PostgreSQL/Auth, sends no email, reads no hosted credentials and loses fixture data on shutdown. Stop with Ctrl+C. No server is left running by the acceptance tests.

Normal application entry is `/platform` in `supabase-auth` mode **after** separately authorized database/Auth activation. Pointing the existing frontend at its current hosted Development database will correctly fail closed until the migrations are applied. Do not deploy the verification build: it deliberately uses `https://example.invalid` and a synthetic publishable-key-shaped fixture, with no environment file edits.

## Verification evidence

Executed local results (rows marked retained were not rerun in the correction):

| Check | Result |
|---|---|
| `npm run verify:platform:db` / security script | PASS: 84 assertions; all 60 migrations replay; populated synthetic financial fingerprints unchanged |
| `npm run verify:platform:delivery` | PASS: 18 mocked contract assertions; zero emails/network |
| `npm run verify:platform:browser` | PASS: 27 Chromium assertions with real local PostgreSQL RPCs |
| TypeScript/Vite build | PASS with explicit synthetic public configuration; existing large-chunk advisory |
| `npm run lint` | PASS: zero errors, ten warnings (eight existing, two new async-query effect advisories) |
| `verify-p6a-boundary.mjs` | PASS: 178 production-auth modules |
| `verify-p6e.mjs` | PASS: configuration/import/storage boundaries |
| `verify-p6e-interactions.mjs` | PASS: existing Auth/Company fail-closed/browser regression |
| Company provisioning / first-owner generator checks | Retained prior implementation evidence: 16 + 16; not rerun in the P0 correction |
| `verify-historical-source-command.mjs` | Retained prior implementation evidence; not rerun in the P0 correction |
| Focused source secret-pattern scan | PASS: 22 platform application/server/migration/test files |
| Prior canonical migration hash comparison with HEAD | PASS: all 56 byte-for-byte unchanged |
| Financial/historical/accounting/Payroll/Attendance source diff | PASS: no edits |
| `git diff --check` | PASS |
| Existing `verify-p6c-boundary.mjs` | FAIL: unchanged baseline blanket RPC assertion |
| Existing `verify-executive-dashboard.mjs` | FAIL: unchanged baseline payroll-link assertion; independently reproduced on pristine HEAD export |
| P0 revocation / migration-59 upgrade | PASS: 44 assertions plus pre-fix exploit and forward-upgrade scenario |
| Local real PostgreSQL concurrency | PASS: eight controlled overlapping independent-session orderings; separate optional local test tool |
| Hosted alignment/dry-run/MFA/owner/email/multi-session tests | NOT RUN / remote activation boundary |

Evidence is generated under `/tmp/narvo-platform-evidence` by the browser suite (desktop EN and mobile AR screenshots, results JSON). Screenshot inspection found narrow mobile table columns; they were replaced with labeled rows and rechecked. Early test-locator and SQL ambiguity failures were fixed before final runs; they are not counted as passes. The preview server host is shared with the passing browser suite; its standalone wrapper passes Node syntax checking. Acceptance tests leave no server running.

The database harness applies all 60 canonical migrations to an ephemeral engine. Auth identities/sessions/factors are synthetic scaffolding, not Supabase GoTrue. Tests cover registry/profile/session/factor/ban/expiry revocation, real MFA timestamp vs JWT refresh, ordinary/Company SYSTEM_ADMIN denial, private-table and grant boundaries, provisioning/duplicates/rollback/replay, lifecycle optimistic conflicts, last-admin safeguards, verified-recipient invitation/expiry/revocation, delivery leases, audit immutability and unchanged populated synthetic journal/master fingerprints. Embedded scheduling verifies conflicting-version outcomes; it does **not** prove independent hosted multi-session races.

The browser suite runs the real production components against actual local platform RPCs using the isolated transport. Auth/MFA and external email are mocked. This is stronger than a visual mock and still does not claim actual Supabase session/MFA/email acceptance. Browser networking is restricted to loopback during tests.

Existing `verify:p6c-boundary` fails at the pre-existing blanket `.rpc(` restriction in `src/master/personMasterRepository.ts`. It was not changed or suppressed. Existing lint warnings/build chunk-size advisory are not security acceptance. Full pre-production audit, Firefox/device/zoom matrix, actual-owner recovery and hosted multi-session acceptance remain deferred.

The additional existing Executive Dashboard verifier fails at line 35: it expects MANAGEMENT_VIEWER to have no Payroll navigation link, while unchanged `HEAD:src/app/TenantReadyApplication.tsx` explicitly includes that role. The same failure was reproduced with `git archive HEAD` in `/tmp/narvo-platform-baseline.Q3nC0d`, sharing only installed dependencies. Neither that verifier nor Company/Payroll code was altered. The failed run is not reported as a complete Company-dashboard pass. The separate P6E Auth/tenant browser regression passes.

Final tracked modifications: seven files (AGENTS, handoff, roadmap, package/lock, production boundary and protected router). Twenty-six files remain untracked, including the two pre-existing supplied instruction documents and twenty-four implementation/test/documentation files. HEAD remains `9da8612ac0f9e9e92efa0b9eb417af0311cfc2e3`. Changes are intentionally uncommitted.

## Controlled remote activation — NOT executed

1. Obtain explicit authorization for a **Development-only** activation batch. Confirm project `eqnzueginpkskbnqvgoc`, current remote canonical alignment and actual existing owner registry/profile/session state read-only. Do not rerun first-owner bootstrap or imports.
2. Inspect hosted Auth sessions/factors schema and TOTP `amr` evidence against the new validator; verify session revocation and MFA recovery behavior. Rehearse on controlled synthetic Development fixtures. Confirm backup/recovery and pending migration dry-run before applying the four platform migrations through canonical history only.
3. Separately approve the required hosted TOTP configuration. Do not silently change public signup or weaken MFA. Confirm the owner's explicit identity remains the intended authorized registry principal.
4. Separately approve/deploy the delivery function and server-only secrets/configuration, including exact HTTPS `PLATFORM_APP_ORIGIN`, existing project URL, browser-safe key and server credential. Confirm JWT verification, CORS, SMTP, redirects and no sensitive logs. No wildcard app origin or caller-supplied redirect.
5. Configure approved invitation/recovery email templates for the explicit token-hash callback. Invitation RedirectTo already has `?invitation_id=...`, so an approved template can append `&token_hash={{ .TokenHash }}&type=invite`; the recovery redirect has no query and uses `?token_hash={{ .TokenHash }}&type=recovery`. Validate provider template escaping/allowlists and callback referrer/log handling. Default implicit fragment flows are intentionally rejected. Existing-user delivery behavior must be rehearsed.
6. Run hosted authorization/MFA/session/tenant matrices, genuine multi-session races, invitation delivery/acceptance/recovery, before/after financial fingerprints and actual-owner EN/AR browser acceptance. Do not use real Maker data as mutable fixtures. Apply no real memberships/entities/invites without specific authorization.
7. Frontend deployment requires separate approval, approved real browser-safe build configuration and smoke checks. Development acceptance is not a Production financial go-live authorization.

## Definition of done and deferrals

Business/accounting: **VERIFIED locally** for administrative-only semantics and synthetic unchanged financial history; actual ledger setup and all unrelated master-plan work DEFERRED. Security/authorization: **VERIFIED locally** for tested DB/transport/UI boundaries; real Supabase MFA/session/hosted race acceptance DEFERRED. Database: **VERIFIED locally** for canonical replay and focused constraints/RLS/grants; remote alignment/dry-run/apply DEFERRED. Deployment: **NOT PERFORMED**; hosted configuration and activation DEFERRED. Testing: final local results in report; hosted owner/browser/email/Firefox acceptance DEFERRED. Documentation: this record and current handoff/roadmap reconcile local implementation versus remote state.

Preserved backlog: Maker/Green/Owner separation, Villa 13 ownership/status correction, project lifecycle editing, party management, unit-rate subcontracts, custody reconciliation, historical date interpretation and save-button labeling, financial display/reporting/posting completion, wider Visual Foundation/NARVO branding, WPS and Production readiness. The Platform Owner hosted acceptance gate remains ahead of them.
