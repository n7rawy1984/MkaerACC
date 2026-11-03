**Latest Stage B — 2026-10-31: APPLIED / 13/13 VERIFICATION PASS.** Approved Development invite subject/HTML and exact Preview redirect allowlist changes are now hosted and read back. Original six redirects and unrelated Auth settings preserved; two derived INVITE-customization flags accounted for by exact before-digest reconstruction. No rollback/other hosted operation. Function deployment/configuration, recipient Vercel access and real invitation testing remain pending. [Actual execution and remaining boundaries](PLATFORM_ONBOARDING_STAGE_B.md). Earlier template/allowlist preparation or unapplied statements below are historical.

# P0 new-user invitation onboarding — local completion, 2026-10-31

**LOCAL IMPLEMENTATION VERIFIED / STAGE A DATABASE APPLIED / HOSTED APPLICATION ACTIVATION AND REAL-RECIPIENT ACCEPTANCE PENDING.** Branch `release/platform-owner-console`, base commit `16cf326ca8ca68837892acbefdeffb43c7616640`. Stage A adds only the approved recipient-read RPC; no commit, push, merge, deployment, real email, hosted user/membership/Company mutation, financial mutation or Auth configuration change performed. No backups/recovery artifacts touched. The prior one-hour owner browsing PASS remains complete.

**Development-only activation plan:** [exact staged checklist and deployment scope](PLATFORM_ONBOARDING_DEVELOPMENT_ACTIVATION.md). The current no-Production instruction excludes deployment to `maker-eosin.vercel.app` despite its Development backend. A temporary Preview in the existing project must be pinned before its redirect/CORS settings are approved. The permanent-origin examples below describe the later application target; they do not authorize Production or a new project.

## Root causes and implemented solution

The previous callback displayed password setup and acceptance together, then hid the other action after either operation. Saving a password globally signed out without preserving an explicit sign-in/acceptance path. It had no recipient-readable Company/role/status contract, so it could not reconcile reload, password existence or an uncertain acceptance. Delivery also treated an existing confirmed Auth identity as an indistinguishable provider failure.

The existing invite/membership commands, signed Auth token verification, protected delivery leases, Company authorization, MFA and accounting code are retained. Invitation URLs continue to use `/auth/callback?invitation_id=UUID`; the UUID is an intent/lookup identifier, never a permission.

New recipient flow:

1. The existing trusted Auth invite verifies email through `verifyOtp` using the prepared TokenHash template. Callback credentials are removed from the URL before asynchronous work; no password, token or session is persisted by the new flow.
2. A new recipient-only RPC reads authoritative invitation context. It validates the actual authenticated identity, confirmed email, active profile, live non-expired/non-banned session, intended recipient, expiry/state and existing issuer/recipient authorization fences. It returns only Company ID/name, permitted role, state, user/invitation IDs, Company activity and a **password-required boolean**. No credential/hash/email value is returned. Reading never grants a membership.
3. A passwordless verified recipient sets a password before the UI offers acceptance. Password eligibility is server-derived, not a URL/localStorage flag. A reload can reconstruct eligibility from the current validated session and RPC without replaying the email token. Any existing verified TOTP factor is challenged before password change and remains intact. Memory-only session proof is checked before mutation; failed/changed/expired sessions fail closed.
4. Password save retains the existing global-sign-out requirement. The same non-secret invitation UUID remains in the callback URL. The existing sign-in form stays on that route and continues after real sign-in; refresh while signed out remains usable. Sign-out failure has its own retry and never repeats password mutation automatically.
5. The signed-in recipient reviews the Company and role, checks an explicit confirmation and chooses Accept. Only the unchanged `accept_platform_invitation` RPC creates membership. Password save, email verification and sign-in alone create none.
6. Acceptance is reconciled by reading authoritative state. Lost/uncertain results offer Check invitation status, not an automatic mutation replay. Already accepted invites display the accepted state; direct duplicate acceptance retains existing idempotency. Existing active memberships are not overwritten by an older invitation.
7. Open Company workspace invokes normal `AuthContext.chooseCompany`. Navigation happens only when the same user reaches TENANT_READY for the exact accepted Company (FOREMAN goes to Attendance). A Draft/inactive Company explains activation/retry; another available Company is never silently substituted. Workspace entry and all SDK/RPC waits are bounded.

Auth identity transitions clear recipient context. Distinct invitation routes reset their local state. Recovery-only callbacks remain in their existing handler; ordinary stored sessions still cannot open the general recovery password form. A verified intended passwordless invitee may establish their own credentials via the recipient flow; this is separate from password recovery.

## Existing users and delivery

Existing users use the invitation's **review link**, sign in as the intended existing account and explicitly accept; their password is not replaced and no duplicate identity is created. Platform invitation rows now expose a selectable, non-secret review URL and explain this distinction. Links use the current application origin, so a local link is not a publicly usable hosted invitation.

The delivery function continues to use Supabase Auth `inviteUserByEmail`, custom SMTP and the existing narrow lease/finalization RPCs. When Auth reports `email_exists`/`user_already_exists`, the handler records the existing `AUTH_DELIVERY_FAILED` outcome and returns the safe `EXISTING_USER_SIGN_IN_REQUIRED` code. The UI directs the owner to the review/sign-in path. It does not claim an existing-user email was delivered, create a second user, send recovery as an invitation, or bypass acceptance. No new direct-email provider/service is introduced. New/unconfirmed-recipient invite/resend behavior remains subject to actual hosted provider acceptance.

Supabase's [official invite implementation](https://github.com/supabase/auth/blob/master/internal/api/invite.go) rejects a confirmed existing identity with `email_exists` and uses the existing identity for unconfirmed invitation delivery. This explains the supported branch, but is not a claim that a particular hosted provider build has been runtime-tested here. See also [inviteUserByEmail](https://supabase.com/docs/reference/javascript/auth-admin-inviteuserbyemail).

## Exact database change — APPLIED to Development in approved Stage A

`supabase/migrations/20261031120000_platform_invitation_onboarding.sql`

SHA-256: `7a241df355449563f638dd691dfd3eed5eda60cf54924c3b434519215dedb1d4`.

Adds only `public.get_my_platform_invitation(uuid)`, SECURITY DEFINER with fixed empty search_path. EXECUTE is revoked from PUBLIC/anon/authenticated/service_role, then granted only to authenticated. The function's body rechecks the actual recipient; callers cannot select an actor. It computes a password-presence boolean inside PostgreSQL, without downloading or returning Auth credential material. No table/column/RLS/financial function, write/acceptance/mutation guard or existing grant is replaced; all prior61 migration files are byte-identical to the committed base.

Owner explicitly approved database-only Stage A. Fresh target/history/hash guards and canonical dry-run selected exactly this file, using existing private credentials and `--skip-vault`, without login-role initialization. The migration was applied to `eqnzueginpkskbnqvgoc` at 2026-10-31T15:54:12.740282+00:00. Local/remote history now matches62 versions. All22 immediate/final postflight checks pass:62 existing application-table fingerprints and152 existing function definitions/grants unchanged;528 journals/1102 lines/248 historical records preserved and journals balanced. PUBLIC/anon/service_role cannot execute the new function; authenticated execution retains recipient validation. [Execution evidence](release/development-onboarding-stage-a-result.json) is local/uncommitted. No later hosted stage is authorized or executed. Private guard evidence: `/tmp/narvo-onboarding-stage-a/`.

## Hosted configuration inspection and remaining actions (Stage A completed)

Read-only inspection of Development confirms:

- Site URL remains `https://maker-eosin.vercel.app`.
- Existing allowlist contains that application, localhost/127.0.0.1 origins and all three `/auth/callback` entries.
- Recovery HTML exactly matches the previously approved template; custom SMTP host is configured. Domain/SMTP transport is previously owner-verified; do not repeat or reconfigure it.
- Invite HTML does not match the prepared template.
- `platform-invitation-delivery` is not deployed.

Prepared **two-field Auth patch**, not applied: `docs/release/development-invitation-auth.patch.json` (SHA-256 `d42d8590cc9c45d2e30ab62340efa3236b2dedf848fd374fbfd21f7b617de071`). Exact scope: invitation subject `NARVO ERP invitation` and invitation HTML equal to `supabase/templates/platform-invite.html`. That HTML preserves the validated `RedirectTo` carrying `invitation_id`, appending TokenHash and `type=invite`. Site URL, redirect allowlist, recovery template, SMTP, signup policy, MFA and users are unchanged by this patch.

No callback allowlist expansion is needed for the current same-Site-URL HTTPS application contract; actual rendered link/origin must still be verified. Supabase's [redirect implementation](https://github.com/supabase/auth/blob/master/internal/utilities/request.go) accepts the Site URL origin; [official redirect guidance](https://supabase.com/docs/guides/auth/redirect-urls) documents allowlisting. A future optional existing-project Preview requires its own specifically approved callback/CORS origin; no wildcard domain or separate permanent app is introduced here.

Ordered activation preparation, each hosted/deployment action separately authorized:

1. **COMPLETED — Stage A:** approved recipient-read migration applied after fresh guards; history62 and22/22 postflight verified. Do not reapply it. No destructive rollback/reset.
2. Apply only the reviewed two-field invitation Auth patch and read it back. Preserve existing SMTP and recovery settings.
3. Deploy the prepared function only to Development with JWT verification retained. Set server-only `PLATFORM_APP_ORIGIN=https://maker-eosin.vercel.app`; use Supabase runtime credentials, never Vite secrets. Prepared command: `node_modules/@supabase/cli-linux-x64/bin/supabase functions deploy platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc`. No command executed here.
4. Verify Vercel Git behavior/environment, obtain separate frontend push/deployment authorization, and publish the matching app through the existing project. A local console cannot call the function with its production-only CORS origin; do not weaken CORS to make local testing appear hosted acceptance. Existing root SPA rewrites route `/auth/callback`; hosted path/cache/log-redaction behavior still needs acceptance.
5. Only after all endpoints/templates/route versions are compatible, authorize an explicit recipient/Company/role and send one controlled invitation. No additional email is authorized by this local implementation task.

## Files changed in this batch

- Runtime: `src/platform/InvitationOnboarding.tsx` (new); `AuthCallback.tsx` dispatch; `platformApi.ts` typed recipient RPC; `platformText.ts` EN/AR guidance; `PlatformApplication.tsx` review link and existing-user delivery guidance.
- Server preparation: new forward recipient-read migration; `supabase/functions/platform-invitation-delivery/index.ts` and `handler.mjs` safe existing-user response; new two-field invitation Auth patch. Prepared invite HTML itself is retained unchanged.
- Tests/tooling: new `scripts/verify-platform-onboarding.mjs`, `verify-platform-onboarding-browser.mjs`; `package.json` commands; synthetic fixture/server/scaffold updates; browser, delivery, full platform SQL and frozen-P1 test adjustments. The P1 test explicitly retains its61-file horizon; the onboarding test validates the62-file batch and all prior61 bytes. No historical four-migration release allowlist is silently broadened.
- Documentation: this record and narrow current-state pointers in handoff/roadmap/console/activation/template runbook/functional review. The functional review was pre-existing untracked work from the immediately preceding task and is preserved.

## Verification results and limits

- **18** new isolated PostgreSQL assertions PASS: own-recipient context; no read-side membership; wrong/unknown recipient denial; missing/expired sessions; server-derived password requirement; exact intended membership; accepted-state reconciliation/idempotency; foreign Company isolation; expired/revoked read and acceptance rejection; no anonymous/service execute; no financial posting. Exact62-file allowlist and all prior61 bytes match.
- **22** onboarding browser assertions PASS using actual UI/normal AuthContext, synthetic Auth transport and isolated canonical SQL: new passwordless flow, reload before password, explicit sign-in, confirmation, one membership, accepted reload, correct workspace, existing-user password preservation, Draft Company pending access, wrong identity, expired Auth credential, explicit status/sign-in recovery, revoked invitation, no duplicate Auth identities or journals.
- **50** existing browser regression assertions PASS, including owner MFA, recovery/sign-out retry, queue, EN/AR/mobile/focus and revocation. The old nonexistent-invitation callback assertion now correctly expects denial rather than a premature Accept button.
- **84** platform SQL/security regression assertions PASS over62 migrations with unchanged synthetic financial fingerprints; **48** frozen P1 authorization assertions PASS, confirming stale AAL2 browsing and unchanged fresh-TOTP mutation guards.
- **41** callback/template contract assertions PASS; Edge entrypoint TypeScript/SDK/JWT contract PASS; existing delivery contract assertions plus safe stale-MFA and existing-user response checks PASS. All external providers are mocked; zero email/network provider execution in tests.
- Final onboarding browser recheck22/22 PASS after identity-transition handling; build PASS2731 modules; lint0 errors/ten existing warnings; P6A boundary PASS182 production Auth modules; git diff whitespace, local reference, prior61 migration byte, targeted credential-signature and built fixture-marker checks PASS. Existing large-bundle advisory retained. Initial validation caught a malformed JSX tag, nullable SDK response handling and browser timing assumptions; corrected locally before these final passes. No pass is claimed for the initial failed runs.

No native/local Supabase Auth server or live Deno/provider execution is claimed. Synthetic Auth transport tests cannot prove real token issuance/password behavior, SMTP delivery, real MFA, actual provider resend behavior, or deployed routing. Hosted activation and the following real acceptance are mandatory remaining evidence, not completed tests.

## Exact real-user acceptance test — future separate authorization

1. Approve the exact Development Company, intended permitted role, recipient address and any retained test records. For a new user use an address that has never had an Auth account; separately authorize an existing-account case. Do not use the owner or add owner financial memberships.
2. Owner signs in normally, completes real MFA and explicitly confirms a fresh-TOTP invitation. Confirm one invitation row and queued status; Company/customer relationships remain as approved.
3. Explicitly attempt delivery. Verify trusted function outcome and actual inbox receipt. Record only result/code, never the full credential URL or token. For an existing confirmed identity, verify the clear review-link path; no duplicate Auth account/recovery-email fallback.
4. Open the new-user email in a separate recipient browser. Verify Company and role and that the password form appears first. Refresh once; continue from the validated session without token in the address bar. Set a unique password privately. Confirm membership still absent.
5. Verify global sign-out completes and sign-in appears on the same invitation route. Reload while signed out; sign in with the password. Confirm the intended Company/role review, no password replacement prompt and no membership until explicit acceptance.
6. Check confirmation and accept once. Verify one matching membership, no second user or other-Company grants. Refresh/revisit; confirm accepted state and no duplicate grant. If an existing membership already exists, verify review-required failure without role overwrite.
7. If the Company is Draft, verify pending-activation guidance and no automatic fallback into another Company. Owner activation is a separately authorized operation requiring an active Accounting Admin; do not treat invitation acceptance as activation. Once activated, retry normal Company access and verify the exact Company header/role (FOREMAN goes to Attendance).
8. Under separately authorized fixture scope, verify expired/revoked/wrong-recipient invitations and expired sessions fail; uncertain acceptance reconciles safely, and password/global-sign-out errors offer a bounded retry. Verify the recipient cannot read another Company's records; perform no financial postings in this onboarding test.
9. Preserve all MFA factors and financial fingerprints; retain the earlier one-hour owner navigation result. Record operational cleanup/retention decisions explicitly rather than deleting accounts or Companies automatically.

## Readiness and remaining blockers

The local new-user journey is implemented and testable; existing authenticated recipients have a defined explicit-acceptance path. Hosted use is **NO-GO until the recipient RPC, invitation template, function and matching frontend are approved/activated and real acceptance passes**. No owner action is requested merely to repeat the completed browsing/SMTP audits.

Company activation and an accepted membership do not provision accounts, system mappings, Treasury or funding/opening balances. The first customer's separately approved accounting-readiness checklist, agreed paid-service scope and existing pre-production/operations gates remain outside this bounded fix. Subscriptions/billing are not made complete by onboarding.

Lifecycle: business/accounting **VERIFIED** unchanged boundary and no financial effect; security/authorization **VERIFIED** local recipient/session/explicit-acceptance tests, real provider/MFA acceptance **DEFERRED**; database **VERIFIED** local migration/allowlist/dry-run, hosted application **DEFERRED**; deployment **DEFERRED** pending separate authorization; testing **VERIFIED** local evidence with limits above; documentation **VERIFIED** current local/prepared vs hosted status. Independent disaster recovery remains incomplete/owner-managed; no backup operations performed.
