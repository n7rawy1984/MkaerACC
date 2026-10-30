# Password recovery acceptance correction — 2026-10-29

Lifecycle: targeted Auth implementation/verification; approved hosted recovery template/redirect patch published; real acceptance pending. No database migration or business/financial change is needed.

## Confirmed root cause

Read-only inspection verified MakerACC-Development (`eqnzueginpkskbnqvgoc`): Site URL `https://maker-eosin.vercel.app`; redirect allowlist contained only the existing site and localhost/127.0.0.1 port5173 roots; recovery email used `{{ .ConfirmationURL }}` rather than TokenHash. The browser client deliberately has `detectSessionInUrl:false` and rejects implicit fragments. `/platform` previously rendered the normal sign-in screen without processing a recovery landing. Together these are incompatible. The exact private email link was not collected or logged, so its intermediate redirect chain is not independently observed. Supabase Auth also enforces AAL2 for changing a password when MFA is enabled; the prior callback offered no challenge, so recovery now includes the existing-factor verification step. See [the provider enforcement](https://github.com/supabase/auth/blob/master/internal/api/user.go).

The callback also failed to require a session from successful verification, offered password editing to ordinary stored sessions, and could render Sign in while AuthProvider was catching up. These reachable callback defects are corrected.

## Implemented boundaries

- Recovery credentials/errors arriving at `/platform` (or another application landing path) are routed to the callback. Callback credentials are immediately removed from browser history; legacy implicit fragments are rejected with a fresh-request link.
- TokenHash is verified using supported `verifyOtp({token_hash,type:'recovery'})`; errors, expired/replayed tokens and absent sessions fail closed. PKCE password editing requires the SDK's verified recovery redirect type.
- Only the successfully verified recovery/invite session can display the password form. Ordinary sessions can still accept invitations through the server-authorized command; they cannot open password recovery.
- Before `updateUser({password})`, the session/user must still match the verified session and Auth `getUser` must validate it. Replaced/revoked sessions are rejected. Password success is followed by global sign-out; failure to confirm sign-out is reported separately and retry never repeats the password mutation.
- If a verified TOTP factor exists, the recovery form requires its real authenticator code. `challengeAndVerify` must succeed and the returned upgraded session must belong to the same verified user and pass session/server validation before password update. Invalid MFA never updates the password. No factor is enrolled or removed.
- No MFA factor enrollment/removal, registry/permission changes or financial calls were added. Existing MFA enforcement remains in force. No sensitive logging was added.

## Exact hosted change and authorization

Owner explicitly authorized [the two-field patch](release/development-recovery-auth.patch.json). It replaces only the recovery template with [the prepared TokenHash template](../supabase/templates/platform-recovery.html), including SiteURL callback fallback, and appends exact `/auth/callback` paths for the existing Vercel site and two existing loopback origins. Existing Site URL, SMTP, MFA, invitation template and user records are preserved. No wildcard, extra project or deployment is introduced. Local config.toml does not publish hosted settings.

Hosted publication: APPLIED after explicit owner authorization. Two initial identity GETs returned HTTP502 without reaching PATCH; a later identity/config precondition passed and the approved two-field PATCH completed. Fresh read-back exactly matches both requested values. Site URL, enabled TOTP enrollment/verification, disabled signup, custom SMTP/sender and the invitation ConfirmationURL contract were separately checked against earlier observations. No emails or user writes occurred.

Verification limitation: the immediate whole-response comparison flagged an additional difference beyond the two requested fields; it stopped further writes. The script did not preserve the before/after field-name diff, so that additional response difference cannot be conclusively identified. Supabase exposes a derived custom-template flag map as well as template bodies, but this is only a possible explanation, not a proven attribution. Do not claim full-field preservation. Read-only follow-up verified the exact approved values and the critical settings listed above; no corrective or unrelated PATCH was attempted. Safe read-back evidence: `/tmp/narvo-password-recovery/config-readback.json`.

## Verification

VERIFIED: 41 local callback/protocol assertions; 47 isolated browser assertions including invitation compatibility, recovery landing, expired credential, bare-session denial, URL scrubbing, invalid recovery MFA denial, preservation of verified factors, validated MFA token upgrade, password/sign-out behavior and existing MFA/provisioning/revocation paths. Provider one-time behavior is modeled locally; no real Auth tokens/users were used. Production build, lint (zero errors, ten existing warnings), P6A boundary and diff whitespace checks pass. Browser fixture database is disposable PGlite, not hosted Supabase.

DEFERRED: actual hosted Go-template rendering/delivery, real email recovery including expired/replayed provider tokens, real password update and preserved-factor sign-in acceptance. No real email was sent or hosted user modified. Real SMTP transport was previously verified by the owner; this does not prove this corrected flow. No public/Production deployment occurred. Existing private preview requires a hard refresh after rebuild.

NOT APPLICABLE: accounting policy, new database objects/migrations, tenant permission changes. All60 applied migrations remain frozen. Independent disaster recovery remains incomplete and owner-managed; no backup operations occurred.

## Owner retest (approved hosted patch read-back succeeded)

1. Keep the local application running; hard-refresh `http://127.0.0.1:5173/platform`.
2. Use its password recovery link (`/auth/recovery`) to request ONE fresh email for the existing owner. Use this application request, not a dashboard reset: it explicitly supplies the local `/auth/callback` redirect. Never paste the email URL here.
3. Open that new link in the same local browser. It must show Set New Password, with credentials removed from the address bar. Old ConfirmationURL emails must be discarded; they intentionally fail safely.
4. Enter a strong new password (at least12 characters), plus the current code from your existing authenticator if prompted, and save. Expect password-updated/sign-out confirmation. Sign in again at `/platform` using the new password and the existing real authenticator; privileged access must still require MFA.
5. Reopen the already-used email link: expect a safe invalid/expired-link message and no password form. Test an expired link separately when available. Do not share tokens, passwords or codes.

Supported flow: [Supabase password-based Auth](https://supabase.com/docs/guides/auth/passwords), [redirect allowlist](https://supabase.com/docs/guides/auth/redirect-urls).

Changed files for this correction: `src/auth/ProtectedApplication.tsx`; `src/platform/AuthCallback.tsx`, `callbackSession.ts`, `platformText.ts`; recovery template; exact Development Auth patch; callback/browser tests and their isolated fixture; current handoff/roadmap/activation/console/template documentation. No SQL file changed. The real Development preview was rebuilt at the existing loopback origin. Build/lint/boundary/whitespace and targeted credential-shaped literal/fixture-marker scans pass; no public deployment or commit.
