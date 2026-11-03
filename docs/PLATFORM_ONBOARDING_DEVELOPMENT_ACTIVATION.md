**Latest Stage B — 2026-10-31: APPLIED / 13/13 VERIFICATION PASS.** Approved Development invite subject/HTML and exact Preview redirect allowlist changes are now hosted and read back. Original six redirects and unrelated Auth settings preserved; two derived INVITE-customization flags accounted for by exact before-digest reconstruction. No rollback/other hosted operation. Function deployment/configuration, recipient Vercel access and real invitation testing remain pending. [Actual execution and remaining boundaries](PLATFORM_ONBOARDING_STAGE_B.md). Earlier template/allowlist preparation or unapplied statements below are historical.

**Latest — owner authenticated Preview acceptance PASS; Stage B prepared only.** [Exact current invite/redirect patches, recipient-access gate and rollback](PLATFORM_ONBOARDING_STAGE_B.md). No Stage B hosted action is authorized/applied; function and real-recipient/email gates remain pending.

**Latest Preview retry — 2026-10-31: READY.** Owner-approved declaration-only packaging correction produced246 files; clean build/source lint/current boundaries passed. One approved retry created `dpl_9uerokdducUaR4V35BvDDbyfnqZH` at https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app. Hosted build passes; all three route GETs reach Vercel authentication. Production alias/environment/branch/protection unchanged. Authenticated browser and invitation acceptance remain pending; retry authorization consumed. [Exact result and remaining gates](PLATFORM_PREVIEW_READINESS.md). Earlier failed245-file/preparation statements below are historical.

**Latest Preview execution — 2026-10-31:** one approved245-file upload created `dpl_5dgDTSZHa7icom1APbbYHbG3Yd4Q`, but TypeScript build failed (TS7016: upload omitted existing `scripts/production-boundary.d.mts`). Production/environment/protection unchanged; no Preview alias assigned. No usable Preview or runtime acceptance is claimed. Required246-file packaging correction and another deployment need separate approval. [Actual result](PLATFORM_PREVIEW_READINESS.md). Prior plan-only/unexecuted statements below are historical; Auth/function/recipient gates remain pending.

# P0 onboarding — exact Development activation checklist

2026-10-31. Execution companion to the authoritative [accepted implementation reference](PLATFORM_NEW_USER_ONBOARDING.md). **STAGE A DATABASE VERIFIED; ONE AUTHORIZED FRONTEND PREVIEW ATTEMPT FAILED BUILD. NO RETRY OR OTHER HOSTED CHANGES AUTHORIZED.** The no-Production restriction refines that reference's eventual `maker-eosin.vercel.app` rollout into a temporary **Preview in the same existing Vercel project**. No new permanent application/project/domain is proposed.

## Stage A execution — 2026-10-31

Owner approved only the exact recipient-read migration below. Fresh Development identity,61-version history and unchanged source hashes passed; canonical linked dry-run selected exactly this file. Application succeeded; remote/local history now62. **22/22 postflight checks PASS:** all62 existing application-table fingerprints and152 existing functions/grants preserved; existing roles, memberships, RLS, constraints, triggers and schema/default permissions unchanged; new function body/search_path/security-definer/execute scope verified;528 journals/1102 lines/248 historical records unchanged and journals balanced. A local PUBLIC ACL substring assertion initially matched authenticated; direct `aclexplode(grantee=0)` confirmed no PUBLIC execution, and the assertion was corrected without a database change. [Exact result](release/development-onboarding-stage-a-result.json).

Stage A completion: business/accounting preservation **VERIFIED**; database/security boundaries **VERIFIED**; targeted hosted catalog/data/history tests **VERIFIED**; documentation **VERIFIED**. Deployment, hosted real-recipient/browser onboarding and sensitive-operation acceptance **DEFERRED** to separately authorized stages. Prior accepted local regression suites were not repeated for unchanged implementation.

**STOP after Stage A.** No Auth patch/redirect, function deployment/configuration, Vercel deployment, test records or emails were performed. Subsequent preparation/acceptance gates below remain separate. Existing-project Vercel access/environment verification is now complete; a separately authorized Preview deployment and its exact origin are still required before approval of the Preview-specific compatibility batch. Prior61/pending-RPC descriptions below record the pre-application checkpoint.

## 1. Confirmed state and the frontend boundary

- Branch `release/platform-owner-console`; HEAD `16cf326ca8ca68837892acbefdeffb43c7616640`. The accepted onboarding delta is uncommitted; deploying HEAD alone would omit it. No commit/push/merge is part of this plan's present authorization.
- Fresh read-only target verification: healthy **MakerACC-Development / `eqnzueginpkskbnqvgoc`**; exact61 applied canonical versions; only `20261031120000` is pending; recipient RPC absent; invitation rows0; delivery function absent. Prior61 files remain byte-identical to HEAD.
- Site URL `https://maker-eosin.vercel.app`; recovery template matches the approved version; custom SMTP configured; invitation template does not match the prepared version. Completed regression results, real owner browsing and SMTP transport evidence are retained, not rerun.
- **`https://maker-eosin.vercel.app` is the existing Vercel Production frontend.** Its Supabase Development backend does not make a deployment to that alias Development-only. Do not deploy/promote to it or change its environment/aliases.
- Current local Development frontend: `http://127.0.0.1:5173/platform`, callback `http://127.0.0.1:5173/auth/callback`. It is loopback-only, cannot serve a remote recipient, and the accepted HTTPS-only function origin configuration cannot simply be pointed at HTTP loopback.
- The correct hosted Development-test URL is the **actual immutable URL returned by an explicitly authorized Preview deployment in project maker**, followed by `/platform` or `/auth/callback`. No current Preview carrying this onboarding delta has been verified. Historical Preview URLs are not presumed current or reassigned.
- Authenticated Vercel CLI65.9.0 access is now verified. Existing project/team IDs, Production branch main and effective Preview Development URL/public key are confirmed; no branch-specific overrides. No local project link is needed with an explicit existing project ID. [Exact read-only verification and approval scope](PLATFORM_PREVIEW_READINESS.md). Preview deployment remains unexecuted and needs separate approval.

Vercel documents [Preview versus Production environments](https://vercel.com/docs/deployments/environments) and [explicit deploy targets](https://vercel.com/docs/cli/deploy). Authenticated project inspection now confirms Git `main` as Production and protection `all_except_custom_domains`. No Git push is required for an explicitly authorized CLI/API Preview source deployment.

## 2. Pinned deployment scope

The [activation manifest](release/development-onboarding-activation-manifest.json) pins the current accepted source, database migration and function artifacts. It is a scope/evidence manifest, not deployment authorization.

### Database — one additive recipient read function

File: `supabase/migrations/20261031120000_platform_invitation_onboarding.sql`.

SHA-256: `7a241df355449563f638dd691dfd3eed5eda60cf54924c3b434519215dedb1d4`.

Adds only `public.get_my_platform_invitation(uuid)` with `SECURITY DEFINER`, fixed empty search_path and caller `auth.uid()`. It validates active profile, confirmed non-banned Auth identity, exact live session, recipient email match, accepted-by identity where relevant, expiry and existing issuer/recipient authorization fences. Returned Company metadata is limited to the intended invitation; password presence is a boolean computed inside PostgreSQL, never a hash/credential export.

Execute is first revoked from PUBLIC/anon/authenticated/service_role, then granted **only to authenticated**. This is not a Company membership, global administrator grant or general financial read privilege; the function body must authorize the actual recipient. Existing tables, RLS, mutation/acceptance RPCs, financial permissions, MFA requirements and61 applied migrations remain unchanged. The18 focused SQL tests already cover wrong recipient, unknown invitation, expired/missing session, revoked/expired invitation, exact Company and execute boundaries. No repeat suite is required for unchanged SQL.

### Edge Function — one Development function

`platform-invitation-delivery`, files:

- `supabase/functions/platform-invitation-delivery/index.ts` — SHA `b7cfd692c59cc8a6030fa29bb2defa176435431ba629c802273b9e09a766976e`.
- `supabase/functions/platform-invitation-delivery/handler.mjs` — SHA `86d75636e02dddca69b602dc4acdbb4a240c923a0b746924e4ddccf7ed701d2f`.
- `[functions.platform-invitation-delivery] verify_jwt=true` remains required in `supabase/config.toml`.

Deploy the prepared handler/entrypoint together. Real owner JWT goes to the unchanged fresh-TOTP claim RPC; only trusted server runtime uses the service credential for Auth invitation/finalization. Existing-user failure is explicitly sign-in/review guidance, not duplicate creation or recovery mail. New delivery still uses validated custom SMTP through Supabase Auth.

**For this Preview-only batch, server `PLATFORM_APP_ORIGIN` must be the exact verified Preview HTTPS origin, not `maker-eosin.vercel.app` and not localhost.** The checked-in example describes the later permanent application target; do not use it blindly for Preview. Supabase function secrets/configuration are project-level, so check for another consumer before changing this variable. No server credentials go into Vite or source. Keep gateway JWT verification enabled.

### Frontend — complete existing application build

Deploy the full existing application containing base16cf326 plus the accepted onboarding delta; do not deploy isolated TSX files or HEAD alone. Relevant runtime changes are:

- `src/platform/InvitationOnboarding.tsx` — password/reload/sign-in/review/acceptance/exact-Company navigation.
- `src/platform/AuthCallback.tsx` — invitation dispatch and keyed invitation state; recovery-only behavior retained.
- `src/platform/platformApi.ts` — typed recipient-read RPC.
- `src/platform/platformText.ts` — EN/AR guidance.
- `src/platform/PlatformApplication.tsx` — review link and existing-user delivery response.
- Existing protected routing/AuthContext, Company Workspace and accounting code from the base remain in the complete build; no workspace redesign or accounting change is included.

Preview build environment only: `VITE_APP_DATA_MODE=supabase-auth`, `VITE_SUPABASE_URL=https://eqnzueginpkskbnqvgoc.supabase.co`, existing browser-safe publishable key. Do not edit Production environment values. Use the prepared `deploy/platform-preview.vercel.json` SPA rewrites and callback no-store/referrer/noindex headers. This file is not root configuration and must be explicitly selected.

Frontend source digest: `257278fafc25104c5530bf38daab861b6bcfc6b0c3464baab6e54dfeea47f0f7` over the245-file allowlist in the manifest. It includes required build files, `src`, `public`, and `scripts/production-boundary.mjs` imported by Vite. Excludes `.git`, `.env.local`, secrets, Supabase operator state, docs, test fixtures, dumps, backups, node_modules and prebuilt dist. Prepare a disposable upload directory from this allowlist after authorization; configure only browser-safe Preview environment through the existing project. Rebuild for that environment rather than uploading an arbitrary prior dist.

Database, function, template and frontend are one **compatibility batch**, not an atomic deployment: stage them in the order below and send no invitations until all checks pass.

## 3. Exact two-field invitation-template patch

File: `docs/release/development-invitation-auth.patch.json`.

SHA-256: `d42d8590cc9c45d2e30ab62340efa3236b2dedf848fd374fbfd21f7b617de071`.

The literal API body follows; it changes only the invite subject/HTML. It does not change Site URL, redirect allowlist, recovery or other templates, SMTP, signup policy, MFA or users.

```json
{
  "mailer_subjects_invite": "NARVO ERP invitation",
  "mailer_templates_invite_content": "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"referrer\" content=\"no-referrer\"></head><body>\n  <h1>NARVO ERP invitation</h1>\n  <p>Verify your email to review your company invitation. Company access is checked again when you accept.</p>\n  <p><a href=\"{{ .RedirectTo }}&amp;token_hash={{ .TokenHash }}&amp;type=invite\">Review invitation</a></p>\n  <p>If you did not expect this invitation, ignore this message. Do not forward this link.</p>\n</body></html>\n"
}
```

This template requires `RedirectTo` to contain the invitation query before appending `&token_hash`. The prepared function generates exactly that contract. It is global to this Supabase project's **new Auth invitation emails**: unrelated dashboard/custom invitation senders with a different redirect contract must not send during this controlled test. If coexistence is required, review template compatibility separately before applying. Existing account sessions and unrelated recovery emails are not changed by the two-field patch, but “Development” is not a guarantee of no shared-user impact.

## 4. Callback/origin configuration — Preview must be pinned first

Keep the existing Site URL **unchanged**. Current redirect allowlist:

```text
https://maker-eosin.vercel.app
http://localhost:5173
http://127.0.0.1:5173
https://maker-eosin.vercel.app/auth/callback
http://localhost:5173/auth/callback
http://127.0.0.1:5173/auth/callback
```

Once Preview has returned its verified immutable origin `P`, define:

- Console: `P/platform`.
- Invitation review/callback: `P/auth/callback?invitation_id=<generated UUID>`.
- Auth verification email: that callback plus `&token_hash=<provider value>&type=invite`; never record a real credential URL.
- Function CORS and generated link origin: exactly `P`.

Prepare a **separate one-field redirect patch** preserving all existing entries and appending only the exact Preview host's `/auth/callback?invitation_id=*` pattern, or the exact full callback URLs for the specifically authorized test invitations when their IDs are available. No `*.vercel.app`, generic host wildcard or Production Site URL change. Do not invent `P`; the exact resulting API body must be shown and authorized once it is known. [Supabase redirect guidance](https://supabase.com/docs/guides/auth/redirect-urls) documents allowlisting.

Preview password recovery is deliberately outside this invitation acceptance: the recovery template, global Site URL and query-free recovery allowlist stay as approved. Avoid sending recovery mail from Preview; if it becomes a required test, its exact Preview callback needs separate approval. The new-recipient password setup already uses the verified invite flow without recovery mail.

## 5. Ordered execution checklist and approval boundaries

### Stage A — database only; concrete and ready for separate approval

- [ ] Approve only the migration/file/hash/Development project above.
- [ ] Fresh guarded target identity,61-version/prior-file hash alignment, absence of the new RPC and one-candidate canonical linked dry-run; stop on unexpected drift. Use the existing private password; no passwordless hosted login-role creation.
- [ ] Capture a minimal read-only pre-apply data/authorization/history baseline appropriate to this additive change. No repeat broad audit or regression suite.
- [ ] Apply the single canonical migration with linked CLI and `--skip-vault`; no roles/seeds/other migration/project.
- [ ] Immediate postflight: history62; original61 history preserved; new body/search_path/execute grants match; all other functions/RLS/grants and baseline data/Company links/financial fingerprints unchanged. Stop on failure without reset/destructive rollback.
- [ ] Report Stage A actual results. This approval does **not** authorize templates, function/config deployment, Preview upload, test records or emails.

### Stage B1 — existing-project Preview preparation/deployment; approval and connection required

- [ ] Owner configures an existing authorized Vercel connection locally, without sharing secrets. Read back exact existing maker project ID/team, Git Production mapping, current Production deployment/alias and Preview settings. Stop rather than create another project.
- [ ] Separately authorize one **Preview-only** deployment of the pinned full frontend and Preview-scoped browser configuration; no Production config/alias/promotion/Git push.
- [ ] Stage only the manifest upload allowlist, confirm source digest and linked existing IDs. Use the existing project's Preview environment and explicit Preview config. Prepared invocation, not executed:

```sh
vercel deploy --target=preview --local-config deploy/platform-preview.vercel.json
```

- [ ] Require READY Preview, record immutable URL/deployment ID, verify backend compile target and signed-out `/platform` and `/auth/callback` deep links/headers. Ensure the owner and dedicated test-recipient browser can pass existing Preview deployment protection without publishing or disabling it broadly. No credentials/tokens in callback URLs to bypass hosting protection.
- [ ] Verify the Production alias/deployment/environment remains unchanged. Pin `P` and materialize the exact narrow redirect patch and function origin value. No mail yet.

No additional build/regression run is required now because accepted source is unchanged. A real deployment rebuild for Preview configuration is required later; changed source/configuration would invalidate the relevant accepted evidence.

### Stage B2 — shared Development Auth/function activation; exact Preview scope approved separately

- [ ] Review and explicitly approve: the exact two-field invite patch, the now-concrete one-field allowlist addition, exact `PLATFORM_APP_ORIGIN=P` configuration and one function deployment.
- [ ] Preserve/read back unrelated Auth template, SMTP, Site URL, signup and MFA settings; pause unrelated invitation sends operationally during configuration. Apply only the approved fields.
- [ ] Deploy only `platform-invitation-delivery` to `eqnzueginpkskbnqvgoc`, with verify_jwt retained and existing runtime credentials. No invite endpoint invocation in smoke checks. Prepared command, not executed:

```sh
node_modules/@supabase/cli-linux-x64/bin/supabase functions deploy platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc
```

- [ ] Verify deployed entrypoint/handler version, exact CORS origin, JWT rejection when unauthenticated, required runtime configuration presence without values, and intended generated callback contract. No recipient creation or email until Stage C is authorized.
- [ ] **STOP for the real-user acceptance test.** Report compatible endpoint/configuration results and the exact test URL. All hosted writes so far must match the explicit Stage A/B approvals.

### Stage C — dedicated fixture and real-recipient acceptance; not currently authorized

Proposed fixture, not created:

| Item | Exact proposed value/scope |
| --- | --- |
| Company code | `P0-ONBOARDING-20261031` |
| Company display name | `NARVO onboarding acceptance — Development` |
| Slug | `p0-onboarding-20261031` |
| Initial state | DRAFT; initial admin unset; no commercial Customer link |
| Recipient | One owner-controlled dedicated **new** test mailbox, supplied and authorized before sending; no existing account recreated |
| Invitation role | ACCOUNTING_ADMIN **only in the new test Company**, needed for ordinary guarded activation; never PLATFORM_OWNER/SYSTEM_ADMIN |
| Finance | No chart, Treasury, opening balance, transaction, posting, import or financial setup |
| Retention | Keep clearly labelled test records; no automatic deletion or existing-record cleanup |

If code/slug/mailbox already exists, **stop** and review rather than adopt or overwrite. New Company UUID is generated by the normal command and recorded after creation; existing Company/customer ownership is untouched. The real owner performs fresh-MFA-confirmed actions via the actual console, not synthetic hosted JWTs or service-role bypasses.

Test sequence after explicit fixture/email approval:

1. Owner creates the new Draft Company and one invitation for the exact test mailbox/role. Record only new IDs and safe states. Do not send until owner/recipient can access `P` through Preview protection.
2. Owner explicitly attempts one delivery. The function may create the new Auth identity/profile through Supabase Auth; verify actual inbox receipt without exposing the link. Provider submission alone is not inbox acceptance.
3. Recipient opens the email in a separate authorized browser profile: verify exact Company/role, token removed from visible URL and password-first UI. Refresh once, set password privately; verify no membership yet.
4. Confirm global sign-out affects only this dedicated recipient, then sign in on the same invitation route. Refresh while signed out as covered by the accepted plan. No membership until confirmation + Accept.
5. Explicitly accept; verify exactly one correct Company membership. Reload/revisit and reconcile accepted state without duplication. Draft Company must show pending activation, not open another Company.
6. Owner explicitly activates **only the new test Company** after its active Accounting Admin exists. Recipient retries and reaches its exact workspace/header/role. Inspect access only; create no accounting data.
7. Confirm test recipient has no other Company membership/access. Compare preserved existing financial and Company/customer-link fingerprints against the appropriate pre-test baseline, allowing only the enumerated new test/Auth/membership/audit rows.
8. Stop and report. Existing-user/revoked/expired/uncertain-response live cases need explicit additional fixture/email scope; do not create multiple identities or send extra mail automatically. Local negative-case tests are already accepted and need not be repeated as a general audit.

## 6. Existing-user and Production impact assessment

| Operation | Actual boundary / possible impact |
| --- | --- |
| Add recipient-read RPC | Additive Development function and one execute grant; checks actual intended recipient; no existing row, broad financial role or ownership change. Project is shared with the current Production frontend. |
| Change invite HTML/subject | Shared across all new Supabase Auth invitation messages; could affect other invitation senders/redirect contracts. Existing sessions, passwords and recovery template are not rewritten. Hold until controlled scope is approved. |
| Add Preview redirect | Shared Auth configuration; preserve existing entries and append only the concrete Preview callback contract. No Site URL switch or hostname wildcard. |
| Deploy function/set origin | New function in shared backend; origin variable is server project configuration. Verify no existing consumer; pin only the test Preview. No current real-recipient call is authorized. |
| Preview deploy | Existing project's Preview environment only; can expose the app at a new protected URL, but still talks to shared Development data. Preserve deployment protection and Supabase authorization. Verify no Production alias/environment change. |
| Deploy to maker-eosin / push or merge main / promote Preview | **EXCLUDED Production action.** Not permitted by this plan or a Development backend approval. |
| Real acceptance | Adds one specified test Company, Auth user/profile, invitation, membership and audit/delivery records; no existing customer mapping or financial records changed. Requires separate explicit recipient/fixture/email approval. |

Do not claim zero possible live-user impact just because the Supabase project is named Development. No existing user requires MFA reset or repeated one-hour browsing/SMTP audits for this batch.

## 7. Exact remaining blockers / decision

1. New recipient-read migration needs explicit approval before application.
2. Authenticated access to the existing Vercel project and verified Preview identity/protection are unavailable locally. The exact hosted Development-test URL cannot truthfully be confirmed before an authorized Preview exists.
3. The Preview origin-dependent redirect/CORS patch cannot be made exact until that URL is pinned. The two-field invite-template patch itself is already exact and shown above, but shared Auth/function activation remains separately gated.
4. One dedicated recipient mailbox and fixture/email/Company-activation approval are needed before the live test. No real address, key, token or password should be invented or logged.

**GO for the separately approved database-only Stage A. NO-GO for Production or unspecified Preview/Auth/email operations.** After each explicit approval execute only that concrete scope, retain actual evidence, and stop at the next boundary; after Stage B stop for real-user acceptance. No build, regression, recovery or general security audit was repeated during this planning batch.
