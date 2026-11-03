# Stage D — isolated Development company activated

**Current recipient acceptance — 2026-11-01: VERIFIED.** A live `auth.getUser()` in the existing approved Development Preview confirms `n7rawy19840@gmail.com` / `0137311f-5ab7-491d-b101-8eda15b5830f`, not Platform Owner. The same session displays the exact test Company, ACCOUNTING_ADMIN, foundation COMPLETE, Trial valid through2026-12-01 and renewal2026-12-02. Read-only database evidence confirms its sole intended active membership and no Platform Owner registry entry. This new identity-qualified observation supersedes current-session pending labels only; earlier unattributed browser observations remain withdrawn. Exact11-account/Main Cash database evidence remains valid; no new complete recipient-bound listing or financial posting test is claimed. [Reconciliation and evidence](TEST_SESSION_IDENTITY_RECONCILIATION.md).

**Identity evidence correction — 2026-11-01:** the owner reports accidental Platform Owner sign-in during some prior recipient tests. Earlier recipient-specific browser attribution is **UNVERIFIED/WITHDRAWN**, while observed UI content and all valid database/migration/accounting/concurrency evidence are retained. This is an operator testing error, not an application defect. Current session verification and qualified acceptance are tracked in [the reconciliation](TEST_SESSION_IDENTITY_RECONCILIATION.md).

2026-11-01, final reconciliation 02:04:34 Asia/Dubai (2026-10-31 22:04:34 UTC). **ACTIVATION VERIFIED / EARLIER RECIPIENT BROWSER IDENTITY UNVERIFIED.** Separate owner authorization covered only this fixture's activation and bounded access verification. [Execution evidence](release/development-onboarding-stage-d-activation-result.json).

## Exact result

- Development project: `eqnzueginpkskbnqvgoc`.
- Company: `NARVO Invitation E2E — Development — 2026-11-01`, code `NARVO-INVITE-TEST-20261101`, UUID `23ec33fa-8045-468d-bbdb-0c06d0a816f6`.
- Before activation: DRAFT / INACTIVE, entity version2, ADMIN_ASSIGNED. Invitation `086258d1-f916-4069-b269-6aa3eb132eb5` ACCEPTED/version2 by the exact mailbox's Auth account; confirmed email and active profile. Exactly one ACTIVE ACCOUNTING_ADMIN membership, belonging to this UUID; no other recipient memberships.
- After activation: ACTIVE / ACTIVE, entity version3, ADMIN_ASSIGNED; accounting setup remains INCOMPLETE. Membership, invitation and delivery state did not change. Delivery remains DELIVERED/attempts1; no email was sent in this batch.
- GL accounts, Treasury accounts, projects, journals and journal lines remain0. No accounting provisioning or transaction action was performed.

## Execution and access evidence

The existing genuine owner console was filtered by the exact company code before Change lifecycle. ACTIVE and the reason `Owner-approved Stage D isolated Development invitation E2E activation; no accounting setup or financial activity.` were selected and the administrative confirmation checked. The first submission required fresh owner MFA. The owner completed verification privately and the UI subsequently showed the exact Company UUID as confirmed. Readback confirmed activation; no second activation command was submitted.

A Chrome session, then assumed to be the recipient, was on the accepted invitation. Its authenticated user ID was not independently established. Open Company workspace succeeded, displaying the exact fixture and ACCOUNTING_ADMIN. Reload and final navigation to the Preview root also succeeded. The recipient has no company-switch control, consistent with exactly one authorized membership. [Workspace capture](release/development-onboarding-stage-d-workspace.png).

Live hosted Company RLS is enabled. Its authenticated SELECT policy is `companies_read_active_membership`, using `is_company_member(id)`. The actual function requires an active user and membership matching `auth.uid()`, the target Company, ACTIVE membership and ACTIVE Company. The recipient has no membership in any unrelated Company, so this read authority excludes every unrelated Company. No unrelated financial content was opened. Earlier browser navigation to `/platform`, with recipient identity assumed rather than verified, was rejected: account not authorized as Platform Owner, `get_platform_context`, SQLSTATE42501. [Denial capture](release/development-onboarding-stage-d-platform-denied.png).

**Evidence limit:** no arbitrary authenticated cross-company REST request was executed. A supplementary local preference-selection test was inconclusive: keyboard input was unreliable and Chrome blocked console clipboard input. Paste protection was not overridden; this attempt is excluded from passing evidence. Recipient authority is established by exact hosted memberships and RLS. The workspace and Platform-denial observations remain unattributed browser evidence, not recipient identity proof. It is not presented as a full cross-tenant penetration test.

Read-only management queries ran inside explicit read-only transactions and used existing operator authentication in memory. Before/after aggregate full-row fingerprints of all memberships and all unrelated Companies match exactly. Accepted invitation/delivery fields also match. No actor impersonation or JWT fabrication was used. Captures exclude address-bar credentials, authentication fields and invitation links. Earlier delivery capture incident remains recorded in the historical delivery report.

## Scope, lifecycle and remaining gates

- Business/accounting **VERIFIED** for activation only and zero fixture financial records; actual Company accounting provisioning **DEFERRED**.
- Security/authorization **VERIFIED** for accepted identity/membership, genuine owner action/fresh MFA, hosted membership/RLS authority; earlier workspace/Platform-denial browser identity UNVERIFIED. Arbitrary cross-company API probe **DEFERRED / NOT PERFORMED**; independent external Vercel access **DEFERRED**.
- Database **VERIFIED** for exact fixture state/readbacks and preserved memberships/unrelated Companies. Schema, migrations, grants or RLS modifications **NOT APPLICABLE**.
- Deployment **NOT APPLICABLE**: no deployment or Production/Staging/Vercel/Auth/invitation-delivery configuration change.
- Testing **VERIFIED** for bounded hosted reconciliation and recipient browser behavior; no build/lint or previous Stage A/B/C suites rerun because application source/schema/configuration were unchanged. The local evidence assertions and `git diff --check` passed.
- Documentation **VERIFIED**: this report, JSON evidence and current handoff/roadmap checkpoint; historical delivery/preparation records retained.

No existing Company or membership, financial records, Auth configuration, delivery configuration, Vercel protection/grants, Production, Git history or cleanup was modified. Private passwords and MFA values were not handled by the agent in this batch. Recipient acceptance was performed privately and corroborated by accepted_by/confirmed-email state, rather than observing password entry.

The database invitation acceptance/activation path remains verified; earlier recipient-specific browser attribution is withdrawn pending current live identity binding. Super Admin commercial readiness, financial onboarding, independent recipient Preview access, subscriptions, wider acceptance and cleanup remain separate work. **Stopped after the authorized activation and verification.**

## Owner-session reconfirmation — 2026-11-01 02:08 Dubai

On the owner's request to continue activation, refreshed the existing Platform Owner Accounting entities list filtered by the exact approved company code. It already shows Active / Administrator assigned / Accounting setup incomplete. Fresh read-only Development reconciliation confirms ACTIVE/version3, the invitation ACCEPTED by the exact recipient, and the matching ACTIVE ACCOUNTING_ADMIN membership. **No activation command was repeated and no hosted data was changed.** Read-only viewing required no fresh MFA. The recipient's next action is to open the Preview root in their separate session, or Open Company workspace from the accepted invitation; earlier workspace observation remains above with recipient identity attribution unverified. No recipient session was used in this reconfirmation. [Target-only recheck evidence](release/development-onboarding-stage-d-activation-recheck.json).

## Final recipient workspace acceptance

The owner subsequently confirmed successful real-browser accounting workspace access as ACCOUNTING_ADMIN for this ACTIVE Company. The historical report, now corrected to withdraw unsupported recipient browser identity attribution, is recorded in [the acceptance closure](PLATFORM_ONBOARDING_STAGE_D_ACCEPTANCE.md), including fresh read-only isolation checks and remaining limitations. No further activation or hosted change was made.
