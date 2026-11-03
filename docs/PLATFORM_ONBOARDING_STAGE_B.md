# Stage B — Development invitation configuration

2026-10-31. **APPLIED TO DEVELOPMENT / 13/13 FINAL VERIFICATION CHECKS PASS.** Earlier preparation/proposed-action text below records the reviewed scope and rollback plan. Current lifecycle: deployment accepted by owner; preparing controlled invitation configuration. Stage A and successful246-file Preview build are retained without repeating audits.

## Actual execution — 2026-10-31

Owner explicitly authorized only the two SHA-pinned patches and reviewed guarded rollback. Fresh healthy Development identity, exact patch/rollback hashes, the three reviewed before-values, and two identical complete Auth GETs all passed. The allowlist PATCH was applied first with immediate full readback; the invitation subject/HTML PATCH followed. Exactly two forward PATCH requests, no other hosted writes.

**Final13/13 checks PASS.** Subject and HTML exactly match the approved invitation patch. The allowlist exactly matches its approved patch: all six previous entries/order retained, only the plain accepted-Preview callback and escaped-query invitation pattern appended, eight total. Final readback stable.

### Readback diagnostic and provenance

The initial strict full-response comparison stopped after the invitation PATCH because Supabase automatically changed two customization markers:

- `mailer_subjects_custom_contents.MAILER_SUBJECTS_INVITE`: false → true.
- `mailer_templates_custom_contents.MAILER_TEMPLATES_INVITE_CONTENT`: false → true.

The rollback guard correctly refused a write while these differences were unclassified. Subsequent **read-only** diagnosis proved their exact scope: setting only these two booleans back to false in memory reproduces the fresh before-snapshot SHA-256 exactly. All238 other top-level Auth values and every non-invitation entry of both maps are preserved. This includes Site URL, SMTP, recovery/other templates, MFA and signup configuration. No derived maps were PATCHed. The original stopped verification/rollback-guard records are retained; the resolved result does not conceal them or count unrelated drift as acceptable.

No rollback was performed or necessary. The reviewed rollback files remain unchanged; future use must recheck current values and concurrent drift. The provider may update these derived markers when restoring invite fields; a field-specific comparison must classify only those invitation markers, preserving every other map entry/value.

[Exact execution evidence](release/development-onboarding-stage-b-result.json). Private diagnostic/guard evidence: `/tmp/narvo-stage-b-execution/`. No credentials or full Auth response exported; only approved template/redirect content, digests, booleans and field names recorded.

**STOP after Stage B.** No Vercel access/protection change, Edge Function/configuration/deployment, email/link generation, users/Company/memberships, financial data, frontend deployment, Git or backup operation. Recipient Vercel access, function deployment/exact Preview origin, hosted template rendering and real-recipient onboarding still require their separately authorized stages. No real invitation acceptance is claimed by this configuration result.

Lifecycle: exact configuration scope/target/hash guards, Auth preservation, readback and documentation **VERIFIED**. Business/financial implementation changes **NOT APPLICABLE**. Recipient access/delivery/onboarding acceptance **DEFERRED**. No previous audit/regression suite repeated for configuration-only work.

## Accepted target and evidence

- Development Supabase `eqnzueginpkskbnqvgoc` / MakerACC-Development, healthy, freshly inspected read-only.
- Existing Vercel maker project `prj_n03DWya5Gr1uB82qtY084FvsC7q4`, team `team_HozmwrkzbERtyer2nIT25MWv`.
- Exact immutable Preview: https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app; deployment `dpl_9uerokdducUaR4V35BvDDbyfnqZH`, READY.
- **OWNER-REPORTED browser acceptance PASS:** authenticated Vercel browser loaded the Platform Console and actual Overview with Development data. This is real owner viewing evidence, not recipient onboarding/password/membership acceptance.

## Exact existing invitation configuration

Current subject: `You've been invited`.

Current hosted HTML, inspected directly without email delivery:

```html
<h2>You've been invited</h2>

<p>You've been invited to create an account. Follow the link below to accept.</p>
<p><a href="{{ .ConfirmationURL }}">Accept invitation</a></p>
```

It uses ConfirmationURL; the prepared application/function contract uses TokenHash plus `type=invite` and retains `invitation_id`. Recovery template still exactly matches the approved local recovery HTML; custom SMTP is configured. No SMTP values were exported. Site URL remains `https://maker-eosin.vercel.app`.

## Proposed B1 — exact two-field invitation-template patch

Development Management API endpoint: `PATCH /v1/projects/eqnzueginpkskbnqvgoc/config/auth` (proposed only).

[docs/release/development-invitation-auth.patch.json](release/development-invitation-auth.patch.json), SHA-256 `d42d8590cc9c45d2e30ab62340efa3236b2dedf848fd374fbfd21f7b617de071`:

```json
{
  "mailer_subjects_invite": "NARVO ERP invitation",
  "mailer_templates_invite_content": "<!doctype html>\n<html lang=\"en\"><head><meta charset=\"utf-8\"><meta name=\"referrer\" content=\"no-referrer\"></head><body>\n  <h1>NARVO ERP invitation</h1>\n  <p>Verify your email to review your company invitation. Company access is checked again when you accept.</p>\n  <p><a href=\"{{ .RedirectTo }}&amp;token_hash={{ .TokenHash }}&amp;type=invite\">Review invitation</a></p>\n  <p>If you did not expect this invitation, ignore this message. Do not forward this link.</p>\n</body></html>\n"
}
```

This is the same reviewed template; no new runtime/source change. The delivery function must supply `RedirectTo=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback?invitation_id=UUID`. The template appends the hash/type after that existing query; the browser validates the credential using supported Supabase invite verification, then checks recipient/session/invitation authority. This template does not grant Company access.

**Shared-project impact:** the invitation template is project-wide, not scoped to this Preview hostname. Other invitation senders must use this query-bearing RedirectTo contract; Dashboard/generic invitations without invitation context are not proven compatible. Do not use those senders or send any invitation during this configuration-only stage. Existing sign-in, recovery template, SMTP and already-issued emails are not changed. The Production frontend's shared Development project is not a separate Auth configuration silo.

## Proposed B2 — separate one-field redirect patch

Required callback page: `https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback`.

Append exactly these two patterns, preserving all existing six entries and their order:

```text
https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback
https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback\?invitation_id=*
```

The first supports the existing plain-callback recovery path in `RecoveryRequest.tsx`; the second supports the invitation query generated by the delivery handler. The backslash makes `?` literal under the documented Supabase glob syntax, while `*` covers the invitation identifier. No hostname wildcard or unrestricted path glob is introduced. Callback parameters and database recipient/session checks remain authoritative; the allowlist is not membership authorization.

Exact one-field API body, [docs/release/development-preview-invitation-redirect.patch.json](release/development-preview-invitation-redirect.patch.json), SHA-256 `a1864be838f3f408dfab84b2e47e187678e2344fb035e37343d09d9d1b36e925`:

```json
{
  "uri_allow_list": "https://maker-eosin.vercel.app,http://localhost:5173,http://127.0.0.1:5173,https://maker-eosin.vercel.app/auth/callback,http://localhost:5173/auth/callback,http://127.0.0.1:5173/auth/callback,https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback,https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app/auth/callback\\?invitation_id=*"
}
```

Supabase documents [redirect allowlists and escaped glob characters](https://supabase.com/docs/guides/auth/redirect-urls); its [Auth redirect validator](https://github.com/supabase/auth/blob/master/internal/utilities/request.go) checks the redirect including its query (excluding fragment), and [configuration](https://github.com/supabase/auth/blob/master/internal/conf/configuration.go) compiles allowlist patterns with gobwas/glob. This supports the narrow query-bearing entry; hosted matching remains a later real-recipient acceptance check, not a result of this preparation.

## Vercel protection — confirmed blocker until recipient access exists

Current protection: `all_except_custom_domains`; account plan Hobby. An unauthenticated GET of the exact Preview callback returns **HTTP302 to vercel.com**. The owner's successful browser has Vercel authorization; that does **not** establish access for an arbitrary recipient. Stage B cannot honestly claim invited users will pass protection yet.

Safest procedure, **proposed only and outside the B1/B2 Auth-patch approval**:

1. Select one owner-controlled dedicated test recipient later. They use their own Vercel identity; no sharing of owner credentials.
2. Recipient first opens the plain Preview root URL, with no Auth token or invitation. Use the deployment Share/access-request workflow; the owner approves only that named external collaborator. Prefer request approval to sending an additional Vercel invite email; Vercel may still notify the owner of the request.
3. In the Share dialog select the immutable deployment/commit URL, not the default moving branch link; confirm actual scope. The source upload has no Git branch/commit metadata. If the UI only offers a broader access scope, stop and report it rather than silently granting project/team access. Do not add team members, enable Anyone-with-link, create bearer share links/automation bypasses, add public protection exceptions or disable protection.
4. Hobby permits one external collaborator. Check whether that slot is available; current occupancy and a specific recipient's access were **not verified** in this read-only preparation. Do not revoke another collaborator or upgrade/change plan automatically.
5. Before any Supabase invitation email, recipient proves the NARVO sign-in page loads in the intended browser/profile through this exact hostname. After separately authorized email delivery, open its link in that same browser, avoiding an unprepared mail in-app browser. Do not use the credential-bearing callback as the access-request/login starting point. Supabase sign-out/password setup does not intentionally clear the independent Vercel authorization cookie.
6. Verify that recipient can load the callback in the prepared browser. A lost/expired Vercel session must stop for Vercel sign-in; do not weaken protection or mark onboarding passed.

Vercel documents [individual external deployment sharing](https://vercel.com/docs/deployments/sharing-deployments), without team membership, and [access requests and Hobby limits](https://vercel.com/docs/deployment-protection/methods-to-protect-deployments/vercel-authentication). These are provider capabilities, not evidence that this unnamed recipient has access. Access-request grants can have branch scope according to the provider; inspect actual scope before approval. Revoke the specific grant after the controlled test. No Vercel grant/request/share link was created here.

## Controlled application and rollback plan (requires explicit approval)

1. Recheck exact named Development target, current three before-values and reviewed patch hashes. Stop on drift. Capture only these non-secret configuration fields as before-values; never export full Auth settings or credentials.
2. Apply B2's single allowlist field first, preserving all six existing entries. Read back the exact8 entries.
3. Apply B1's two invite fields. Read back exact subject/HTML. Verify all unrelated Auth fields via an in-memory comparison/fingerprint; do not log their values. Site URL, SMTP, recovery/other templates, signup policy and MFA must stay unchanged.
4. Do not generate a link, create a user, send mail or deploy a function as verification. Stop after readback. Provider template rendering and actual recipient route acceptance remain pending.
5. If a readback fails, stop. With rollback authorization, restore only B1/B2 fields still matching this batch's applied values, in reverse order: invite subject/HTML first, then allowlist. Never replace the entire Auth response or overwrite a concurrent change. If drift exists, prepare a minimal merge/removal and stop for review.

Exact rollback bodies restore the inspected generic invitation and six-entry allowlist:

- [Invitation rollback](release/development-invitation-auth.rollback.json), SHA-256 `8d9201020703db91e28055b33d0fdeacf675d713f7d5bd745e5eb3609768204f`.
- [Redirect rollback](release/development-preview-invitation-redirect.rollback.json), SHA-256 `e984bfa46aa084eb5e2a02f05f60bf64edc80236082206b78c547e1574cb4c31`.

Rollback changes future email rendering/allowed destinations only. It cannot recall an email, revoke an issued Auth session/token or undo membership acceptance; none is authorized or performed in this configuration-only stage. Vercel access rollback, if later approved, revokes only the named external collaborator in the Share dialog; protection stays enabled.

## Verification and decision

**17/17 local contract checks PASS:** exact patch fields, unchanged six original redirects, two exact-host additions, synthetic email URL/UUID/hash/type continuity, documented glob-subset allow/deny cases and exact rollback values. No full build/regression suite repeated because no application source changed. These checks do not claim actual hosted template rendering or redirect enforcement was exercised. [Machine-readable preparation record](release/development-onboarding-stage-b-plan.json).

Business/accounting preservation and configuration scope **VERIFIED**; no financial implementation changes **NOT APPLICABLE**. Read-only hosted inspection, local patch contracts and documentation **VERIFIED**. Hosted config application/readback, per-recipient Vercel access and real invitation/password/membership/Company-workspace acceptance **DEFERRED**.

**GO to request B1/B2 Development configuration-only approval. NO-GO to real-recipient invitations** until the access gate, approved delivery function/exact Preview origin, and explicitly approved test recipient/Company/email are ready. All invitations/emails, records, Edge Functions/configuration, frontend/Git/Production changes and backup operations remain excluded.
