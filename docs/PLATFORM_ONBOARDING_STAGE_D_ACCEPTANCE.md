# Stage D — workspace acceptance

**Current recipient acceptance — 2026-11-01: VERIFIED.** A live `auth.getUser()` in the existing approved Development Preview confirms `n7rawy19840@gmail.com` / `0137311f-5ab7-491d-b101-8eda15b5830f`, not Platform Owner. The same session displays the exact test Company, ACCOUNTING_ADMIN, foundation COMPLETE, Trial valid through2026-12-01 and renewal2026-12-02. Read-only database evidence confirms its sole intended active membership and no Platform Owner registry entry. This new identity-qualified observation supersedes current-session pending labels only; earlier unattributed browser observations remain withdrawn. Exact11-account/Main Cash database evidence remains valid; no new complete recipient-bound listing or financial posting test is claimed. [Reconciliation and evidence](TEST_SESSION_IDENTITY_RECONCILIATION.md).

**Identity evidence correction — 2026-11-01:** the owner reports accidental Platform Owner sign-in during some prior recipient tests. Earlier recipient-specific browser attribution is **UNVERIFIED/WITHDRAWN**, while observed UI content and all valid database/migration/accounting/concurrency evidence are retained. This is an operator testing error, not an application defect. Current session verification and qualified acceptance are tracked in [the reconciliation](TEST_SESSION_IDENTITY_RECONCILIATION.md).

**DATABASE JOURNEY VERIFIED / EARLIER RECIPIENT BROWSER IDENTITY UNVERIFIED.** Reconciled 2026-11-01 02:16:44 Asia/Dubai. [Read-only evidence](release/development-onboarding-stage-d-acceptance-result.json).

## Real-browser acceptance

Historical operator-reported workspace observation (recipient identity was assumed and is now unverified):

- Company: **NARVO Invitation E2E — Development — 2026-11-01**.
- Code / UUID: `NARVO-INVITE-TEST-20261101` / `23ec33fa-8045-468d-bbdb-0c06d0a816f6`.
- Company ACTIVE; role ACCOUNTING_ADMIN; accounting workspace loaded successfully.

This is an unattributed browser observation, not verified recipient-session acceptance. The same attribution limit applies to the earlier agent-observed [workspace and Platform-denial checks](PLATFORM_ONBOARDING_STAGE_D_ACTIVATION.md). Private password/MFA handling was not observed by the agent.

## Safe read-only isolation verification

Fresh Development queries ran inside an explicit read-only transaction. The invitation is ACCEPTED by the exact recipient account. Its single ACTIVE ACCOUNTING_ADMIN membership matches the exact fixture; unrelated memberships0, membership-authorized active Companies1, platform-administrator registry entries0.

Live Company RLS remains enabled. The authenticated SELECT policy calls `is_company_member(id)`, whose actual hosted definition requires active user, exact `auth.uid()` membership, active membership and active Company. The authenticated database role has no BYPASSRLS. Consequently the recipient has no Company SELECT authority for unrelated Companies through this boundary. Earlier browser observations, whose recipient identity was not independently bound, show no Company-switch control and denial of Platform Owner access (42501). No unrelated Company financial content was opened.

**Limit:** these are current hosted authority/membership checks, not a new arbitrary authenticated cross-company REST probe or comprehensive financial/API isolation audit. No JWT impersonation or console-protection override was used. The earlier inconclusive local preference attempt remains excluded from passing evidence.

## Historical Stage D preservation and lifecycle snapshot

The following state/counts and completion labels are the original Stage D checkpoint, before subsequent separately authorized provisioning/subscription work. Current identity-bound acceptance above supersedes its browser-pending label; current Company version5/COMPLETE is recorded in the reconciliation.

All-membership and unrelated-Company full-row aggregate fingerprints still match the activation closure. Fixture Company/version3, membership, invitation and delivery fields are unchanged. GL accounts, Treasury accounts, projects, journals and journal lines remain0. No hosted mutation, permission/configuration change, transaction, accounting provisioning, deployment, Production/Vercel change, cleanup, Git commit/push/merge or email was performed.

Business/accounting **VERIFIED** for this bounded journey; accounting provisioning **DEFERRED**. Security/authorization **VERIFIED** for scoped membership/RLS with earlier browser identity attribution unverified; arbitrary cross-company API probing **DEFERRED**. Database **VERIFIED** for targeted reconciliation; schema/migrations **NOT APPLICABLE**. Deployment **NOT APPLICABLE**. Testing **VERIFIED** for targeted read-only checks; earlier recipient-specific browser identity **UNVERIFIED**; earlier Stage A/B/C suites were not repeated. Documentation **VERIFIED** through this report, JSON evidence and handoff/roadmap checkpoint; JSON parsing, evidence assertions and `git diff --check` pass.

Accounting setup remains INCOMPLETE. Independent external recipient Preview access remains separate from this assisted protected-browser test. Cleanup requires separate approval. Commercial readiness is not established by Stage D acceptance; Company accounting setup, subscriptions and wider product acceptance remain later gates. **Historical database acceptance remains valid; recipient-specific browser closure requires a current identity-bound observation.**
