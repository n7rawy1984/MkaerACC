**Stage D delivery — 2026-11-01: ONE INVITATION PROVIDER-DELIVERED / ACCEPTANCE AND ACTIVATION PENDING.** Genuine owner Preview UI/fresh MFA/explicit confirmations created only Draft NARVO-INVITE-TEST-20261101 (23ec33fa-8045-468d-bbdb-0c06d0a816f6), one ACCOUNTING_ADMIN invitation to n7rawy19840@gmail.com (086258d1-f916-4069-b269-6aa3eb132eb5) and one delivery. Outbox DELIVERED/attempts1/no error; recipient Auth count1, memberships0. Fixture remains Draft/Inactive with zero GL/Treasury/projects/journals. Inbox/password/sign-in/acceptance unverified; stop after delivery. One diagnostic MFA-field capture was removed locally/not used; incident retained in report. No existing Company/membership, financial, Production/Vercel, config, activation, cleanup or Git mutation. [Actual result and private recipient steps](PLATFORM_ONBOARDING_STAGE_D_DELIVERY.md); [execution evidence](release/development-onboarding-stage-d-execution.json). After acceptance confirmation request separate activation approval; no commercial readiness claimed. Earlier preparation/waiting labels are historical.

**Stage D execution checkpoint — 2026-11-01: SPECIFIED DRAFT COMPANY CREATED / INVITATION NOT YET CREATED OR SENT.** Genuine owner Preview UI created only NARVO-INVITE-TEST-20261101, UUID23ec33fa-8045-468d-bbdb-0c06d0a816f6. Read-only reconciliation confirms Draft/Inactive, no Customer/admin, zero GL accounts/Treasury/projects/journals/memberships; recipient Auth/membership counts0 and no invitation. Browser route/pointer changed unexpectedly during navigation; paused before invite submission and requested Chrome idle confirmation. Existing one-invitation/delivery approval remains valid; do not recreate Company. No finance, existing Company/membership, Production/Vercel, email, activation or cleanup action. [Current execution evidence](release/development-onboarding-stage-d-execution.json).

**Stage D execution — 2026-11-01: AUTHORIZED / AWAITING PRIVATE OWNER SIGN-IN.** One specified Draft fixture and one ACCOUNTING_ADMIN invitation/email to n7rawy19840@gmail.com are explicitly approved; stop after delivery. Fresh read-only guards pass and recipient/company collisions remain absent. Existing local Chrome reaches the approved protected Preview but NARVO is signed out; private owner sign-in/MFA requested. No Company, invitation, Auth user, membership or email was created; no service-role/SQL impersonation fallback. Creation/delivery approval remains valid after private sign-in and fresh guards; Company activation/cleanup still require separate approval. [Execution checkpoint](release/development-onboarding-stage-d-execution.json).

# Stage D — controlled real-recipient invitation test preparation

2026-11-01 (Dubai). **PREPARED ONLY / NO RECORDS OR EMAIL CREATED.** Target: MakerACC-Development `eqnzueginpkskbnqvgoc`. Recipient: `n7rawy19840@gmail.com`. This preparation does not authorize execution, recipient access grants, frontend/deployment changes or Production actions.

[Secret-free read-only evidence](release/development-onboarding-stage-d-preparation.json). Stage A/B/C evidence is retained, not retested as a general audit.

## Verified readiness and actual recipient state

Fresh GET checks confirm the reviewed delivery function remains ACTIVE, ID `59414c7a-6baf-476d-8a7b-376783404b76`, version1, JWT enabled and unchanged update marker. Full Auth configuration matches the accepted activation fingerprint. Corrected metadata comparison confirms all secret digests and exact approved origin remain unchanged; only previously allowed provider timestamps differ from that activation's before-snapshot. No function was invoked.

A targeted SQL transaction explicitly ran `BEGIN TRANSACTION READ ONLY` and returned only recipient booleans/counts, candidate fixture metadata and viewer permission keys:

- Recipient Auth accounts:0; memberships across all Companies:0; pending Platform invitations:0; no Platform registry identity. This is an eligible new-account case at inspection time.
- Recipient-read RPC exists. Password and email-confirmation flags are false because no account exists, not because an existing account was altered or tested.
- No Company/code/slug matches either the new proposal below or the older exact `P0-ONBOARDING-20261031` / `p0-onboarding-20261031` fixture proposal. No existing Company is selected or inferred safe from its name.
- Therefore the recipient has no current intended-company membership. The proposed Company does not yet exist, so its final UUID-scoped membership check must be repeated after authorized creation and immediately before queueing/sending. Recheck Auth/invitation collisions too; never recreate or reset a newly discovered existing identity.

Existing owner-authenticated Preview browsing is retained owner-reported evidence. This preparation has no authenticated browser-control connection and does not claim a recipient browser sign-in or access grant was performed.

## Exact proposed isolated fixture

| Field | Proposed value |
| --- | --- |
| Company name | `NARVO Invitation E2E — Development — 2026-11-01` |
| Company code | `NARVO-INVITE-TEST-20261101` |
| Tenant slug | `narvo-invite-test-20261101` |
| Entity kind / locale | `BUSINESS` / `en` |
| Initial lifecycle | `DRAFT`, underlying Company `INACTIVE` |
| Customer link / initial admin | Both unset; create no commercial Customer or initial membership |
| Legal fields / region | Leave optional legal name/TRN/address/region unset; do not invent legal data |
| Recipient | `n7rawy19840@gmail.com` |
| Proposed full-test role | `ACCOUNTING_ADMIN`, only in this new fixture |
| Finance | No chart/system mappings, Treasury, projects, opening balances, imports, expenses, journals, payments or posting |
| Generated IDs | Record actual new Company/invitation/user/membership IDs only after approval; none invented in advance |

**Role decision:** `MANAGEMENT_VIEWER` is the lowest general read-only role; hosted permission keys are `accounting.view`, `project.view`, `treasury.view`. It is sufficient for invitation/password/sign-in/acceptance testing. It is **not sufficient as the sole member of a new empty Company for workspace verification**, because the canonical `set_lifecycle` command requires an active `ACCOUNTING_ADMIN` before activation. Earlier approved onboarding preparation already identified this first-admin requirement.

Recommend `ACCOUNTING_ADMIN` solely for the new empty fixture to exercise the complete first-customer journey with one recipient and no additional identities/memberships. It has financial capabilities, so it must not be presented as a read-only role; the test authorizes navigation only and no financial command. No Platform role or owner financial membership is granted. Approval must explicitly name this role. If the owner instead chooses `MANAGEMENT_VIEWER`, stop at the Draft-company pending-activation outcome; full workspace entry remains deferred until a separately approved fixture Accounting Admin is provided. Do not silently upgrade a viewer or select an unrelated existing admin.

Canonical evidence: `20261028123000_platform_invitation_revocation.sql`, create_entity, invitation command, acceptance and lifecycle logic; original role permissions plus current hosted viewer permission readback. No migration or rule change is proposed.

## Browser and identity isolation

Use the existing **owner-controlled, already Vercel-authenticated Preview browser** for an assisted sequential test. Vercel hosting authorization and NARVO/Supabase identity are separate. No owner password, MFA seed/code, Vercel account, cookie or Supabase token is shared/exported to the recipient or tools.

1. Owner performs Platform operations privately in their genuine NARVO owner/AAL2 session.
2. Before testing the recipient, close other NARVO tabs in the same browser profile and sign out of NARVO. Do not clear the independent Vercel cookie. Avoid simultaneous owner and recipient tabs: Supabase sessions can be shared across tabs on the same origin.
3. Open the token-free Preview and callback route, confirm the NARVO owner is signed out, and let the recipient privately use their own inbox/password in this controlled browser. No password is assigned or viewed by the owner/agent. If an owner identity appears in the callback, stop and switch accounts rather than accepting.
4. If an independently Vercel-authorized second browser profile already exists, it can separate the actors; its access must be verified, not assumed. Do not create a grant to enable it under this preparation.
5. The controlled same-browser test proves assisted onboarding only. It does not prove that an external recipient on their own device can pass Preview protection. Independent access still needs named identity, capacity/scope inspection and separate access approval.

At any unexpected Vercel authorization screen, stop before using a credential-bearing link as the login/access-request URL. Do not use Anyone-with-link, bypass tokens, disable protection or share the owner's private account.

## Exact future test sequence — after explicit approval only

1. Recheck Development identity, function/configuration, fixture code/slug absence and the recipient's Auth/membership/invitation/Platform status. Any collision or changed identity stops this new-user plan for review. Verify both token-free Preview root and `/auth/callback` load in the intended browser.
2. Owner uses the actual console and real fresh MFA/explicit confirmation to create exactly the proposed Draft Company, with no Customer/initial-admin link. Capture the generated Company UUID and verify its zero memberships and zero fixture financial records. Read back recipient membership for that UUID:0.
3. Owner queues exactly one invitation for that Company UUID, exact mailbox and approved role. Record invitation ID/version and queued state. Queueing must not create membership or a duplicate user. No delivery yet if browser/access conditions are unresolved.
4. After the specifically approved email action, invoke Deliver once through the real console. Allow the existing function to claim/finalize its normal outbox and Supabase Auth to create the one recipient user/profile and send one invitation. Record only safe status/code/IDs. Provider submission is not inbox receipt. On failure/uncertain delivery, stop and inspect status; no automatic resend, second account, link generation or recovery-email workaround.
5. In the prepared recipient browser, open the actual inbox invitation privately. Verify the exact Preview hostname and invitation Company/role. Confirm Auth credentials disappear from the URL. Record no full link/hash/token/password or screenshots containing them. Verify membership is still0 after email verification. Refresh once before password setup and confirm the intended flow is reconstructible.
6. Recipient sets their own unique12–128-character password privately. Preserve any real MFA factor and follow existing challenge requirements; no factor reset. Verify global recipient sign-out completes and the callback retains only non-secret invitation intent. A password/global-sign-out failure stops for the offered bounded recovery, not an automatic password mutation replay.
7. Reload once while signed out. Sign in as this recipient with their own password on the same invitation route. Confirm correct Company/approved role, no password-replacement prompt, and membership still0. Owner credentials must never be entered as the recipient.
8. Recipient explicitly checks confirmation and Accepts once. Read back exactly one membership for the recipient/fixture/approved role; their memberships outside the fixture must remain0. Refresh/revisit the accepted state and confirm no second membership or Auth user. If the response is uncertain, use Check invitation status; do not blindly repeat mutations.
9. While Draft, attempt Open workspace and verify pending-activation guidance with no automatic fallback to another Company. For the approved first-admin option only: sign the recipient out, have the owner privately sign in and complete fresh MFA, then activate only this fixture through the normal command now that its active Accounting Admin exists. Record its current version and resulting ACTIVE state. Sign the owner out again before restoring the recipient's own session.
10. Recipient signs in with their own credentials and uses the normal accepted-invitation/Company-selection route. Verify TENANT_READY for the exact generated Company UUID, correct Company header and role, and empty/read-only inspection of the workspace. Create no accounting masters, configuration, transactions or test postings. Workspace navigation is not Company accounting provisioning.
11. Check final recipient Auth count1, fixture membership count1, no other Company membership for the recipient, correct invitation acceptance and lifecycle, and fixture financial-document/journal counts0. Retain safe evidence only. Do not open or modify unrelated financial Companies to manufacture a negative-access test.
12. Stop and report pass/fail for actual inbox, verification/password, sign-out/sign-in continuation, explicit acceptance, Draft handling and workspace entry. A failed step is not a completed end-to-end pass. No extra existing-user/revoked/expired/resend campaigns are authorized by the single happy-path test.

## Cleanup/retention procedure — prepare now, approve separately

Default: preserve clearly labelled fixture, invitation/outbox/audit history and recipient account for traceability. After acceptance testing, the owner may separately authorize **archive only this new fixture** with reason `Controlled Stage D invitation test complete`. If abandoned before acceptance, separately revoke only this test's pending invitation and archive the Draft fixture. Do not delete Companies, profiles, Auth users, journals or audit rows.

The sole fixture Accounting Admin membership must not be revoked or the user globally deactivated to bypass last-admin protection; the current commands guard that invariant. An archived/inactive fixture blocks normal workspace access while retaining history. Leave its sole admin membership retained unless a separate valid cleanup design is approved; do not add a dummy replacement admin. Global Auth-user deletion/deactivation/password reset/sign-out cleanup can affect other future sessions/memberships and is not approved automatically.

Recipient may sign out of NARVO after the test; the owner privately restores their own normal session. Do not alter Vercel protection or revoke unrelated access. No new Vercel grant is proposed in the assisted-browser option. If a separately authorized external grant is later used, removal must target exactly that grant under its own approved cleanup scope.

## Exact approvals required before execution

- **Fixture and invitation:** create one Draft Company using the table above, queue one invitation for `n7rawy19840@gmail.com` with explicitly approved `ACCOUNTING_ADMIN` (or choose viewer-limited variant), and retain the resulting normal audit/request/outbox records. No existing Company/membership changes.
- **One real email and recipient journey:** one Deliver action; allow the consequent new Auth user/profile, one inbox email, private password establishment/global recipient sign-out/sign-in, explicit acceptance and one fixture membership. No automatic resend/recovery fallback.
- **Workspace:** for the full-test admin option, activate only this fixture after acceptance and inspect only its normal workspace with no financial actions. Viewer-only approval cannot imply this activation.
- **Cleanup:** separately approve retention versus archive/revoke scope described above. No deletion/global user mutation or last-admin bypass.
- **Access, if needed:** independent recipient Vercel access remains a separate named grant approval; existing owner-operated authenticated-browser acceptance does not authorize it.

No approval is inferred from this preparation or from merely supplying the recipient address.

## Verification and lifecycle classification

Business/accounting **VERIFIED** unchanged and finance excluded; role/activation policy grounded in current commands. Security/authorization **VERIFIED** targeted existing eligibility and source boundary; real recipient/browser/MFA acceptance **DEFERRED**. Database **VERIFIED** read-only targeted membership/collision/permission query; migrations/grants/RLS changes **NOT APPLICABLE**. Deployment **VERIFIED** unchanged active function/Auth/origin readback; no redeployment. Testing **VERIFIED** bounded readiness readback; actual E2E and independent browser access **DEFERRED**. Documentation **VERIFIED** plan/evidence distinguish preparation from execution. No prior full audit, build or completed Stage A/B/C suite repeated.

Super Admin commercial readiness and Company accounting setup are not established by this proposed test.
