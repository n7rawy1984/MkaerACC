**Latest recovery correction:** owner approved the exact recovery-only template/allowlist patch in `docs/release/development-recovery-auth.patch.json`; now applied and exact values verified by hosted read-back. Full-response comparison limitation and verified critical settings are documented in the focused recovery record. The recovery template now falls back to SiteURL/auth/callback if RedirectTo is empty; application-issued recovery requests still use an explicit query-free callback. Invitation template remains unchanged. See [focused recovery record](../../docs/PLATFORM_PASSWORD_RECOVERY_FIX.md). Older preparation-only statements below predate this approval.

**Database prerequisite complete:** all four approved migrations are applied and postflight passed. The reviewed templates/function are prepared; no hosted template patch, SMTP change, function deployment or additional email was performed by this batch. Real invitation acceptance remains unverified.

# Platform email deployment preparation

These files are local preparation. The owner has verified Resend/custom SMTP delivery using an existing historical Auth user. Sender: `NARVO ERP <no-reply@elnahrawy.com>`. This is transport evidence, not Platform invitation/new-user acceptance. The agent changed no hosted template, Auth setting or function. Read-only inspection on2026-10-29 confirms hosted invite/recovery templates still lack TokenHash and the delivery function remains undeployed.

`platform-invite.html` requires the delivery function's exact RedirectTo contract:
`https://maker-eosin.vercel.app/auth/callback?invitation_id=UUID`.
`platform-recovery.html` requires the application's query-free recovery RedirectTo:
`https://maker-eosin.vercel.app/auth/callback`.
The different `&`/`?` separators are intentional. Do not reuse these templates for other redirect contracts without testing them.

Target: existing application `https://maker-eosin.vercel.app/platform`; no new Vercel project/domain. After all mandatory release gates and four Development migrations pass, set the two hosted Auth email templates to these reviewed files through the Development dashboard. Local `config.toml` does not publish them. Preserve existing provider settings and signup policy. Authorize the exact callback origin/path and invitation query contract; avoid broad preview-domain wildcards. Verify an actual rendered URL before acceptance. No automatic config push is part of this preparation.

The platform invitation UUID is a lookup identifier, not a bearer permission. Supabase Auth generates and verifies its own one-time token hash; this application does not store raw email tokens. Platform acceptance separately validates the authenticated, confirmed recipient, Company/role, expiry, invitation state and current issuer/recipient access fences. A valid Auth email token cannot reinstate revoked Company access. Actual Auth token expiry/replay and existing-user delivery still need provider acceptance; local URL tests do not prove those behaviors.

Server delivery deploys only `platform-invitation-delivery` to `eqnzueginpkskbnqvgoc`, after the database gate. Prepared command, **not executed**:

```sh
node_modules/@supabase/cli-linux-x64/bin/supabase functions deploy platform-invitation-delivery --project-ref eqnzueginpkskbnqvgoc
```

Keep JWT verification enabled. The handler also validates the actual user using Auth and forwards that user's JWT to the database's fresh-MFA claim RPC. Do not replace it with a service-role administrative claim.

| Configuration | Placement / action |
| --- | --- |
| `SUPABASE_URL`, `SUPABASE_ANON_KEY`, `SUPABASE_SERVICE_ROLE_KEY` | Supabase server runtime; confirm availability without logging values. Never copy the service credential into Vite. |
| `PLATFORM_APP_ORIGIN` | Server-only `https://maker-eosin.vercel.app` (no path/query/fragment); the adjacent function `.env.example` prepares this non-secret value. Publish through the function environment only after gates pass. |
| `VITE_APP_DATA_MODE` | Existing application: `supabase-auth`; optional temporary Preview uses Preview scope. |
| `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY` | Existing browser-safe Development URL/key; verify the existing application environment before release. Optional temporary Preview uses Preview scope. Never a password/service key. |
| Provider SMTP settings | Hosted Auth configuration only, if required by approved recipients. No SMTP credentials needed by this function. |

Custom SMTP is now configured and transport delivery verified by the owner. Do not request another provider/domain setup or modify the working SMTP configuration. Preserve its server-side credentials. No further email is authorized by this checkpoint. Hosted invite and recovery templates must still be published from the prepared files after the release/database gates, then demonstrated with specifically authorized recipients. See the [single current execution checklist](../../docs/PLATFORM_ACTIVATION_EXECUTION.md).

After recipient authorization, test new-recipient invitation, existing-user handling, rendered callback, one-time Auth verification, expired/revoked/replayed invitation, provider failure and uncertain acknowledgement. Existing-user `inviteUserByEmail` behavior is unverified; do not switch to password recovery or another email flow as an administrative invitation workaround. Use the existing authorized membership workflow for existing identities when appropriate. Outbox success means provider submission, not inbox receipt; an uncertain acknowledgement may require investigation before retrying.

The callback removes credentials from browser history before Auth calls. Referrer policy is `no-referrer`; templates contain no external resources or analytics. Hosting/proxy access logs can still receive callback query strings: configure query redaction/exclusion before real acceptance and never attach raw callback URLs to reports. Email link scanners may consume one-time links; verify actual provider/client behavior. The app rejects implicit fragments and ambiguous/duplicate credentials.

Local verification: `npm run verify:platform:callback`, `npm run verify:platform:delivery`, `npm run verify:platform:function`, `npm run verify:platform:browser`. The function check validates the pinned SDK/entrypoint types with a minimal Deno type declaration; it does not execute Deno, bundle remotely or validate live runtime secrets. Callback URL tests substitute documented scalar placeholders; they do not execute hosted Go rendering or send mail. No Docker/local Supabase Auth stack or hosted Deno wrapper integration was run in this batch. See [official template variables](https://supabase.com/docs/guides/auth/auth-email-templates) and [local template configuration](https://supabase.com/docs/guides/local-development/customizing-email-templates).
