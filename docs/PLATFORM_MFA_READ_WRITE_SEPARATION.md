# P1: AAL2 browsing and fresh-TOTP mutations — 2026-10-30

Status: exact Development migration explicitly APPROVED, APPLIED and postflight VERIFIED. No frontend/Edge Function/public deployment performed in this batch. Owner reports real Overview and Customers now load following the approved owner transfer; this supersedes older pending-owner-access statements. On2026-10-31 the owner reported that the real session remained usable for approximately one hour without repeated MFA prompts: sustained navigation acceptance PASS. Invitation end-to-end, sensitive-operation real-session and Vercel deployment acceptance remain PENDING.

## Confirmed cause

Targeted read-only inspection of MakerACC-Development (`eqnzueginpkskbnqvgoc`) confirmed hosted history60 and the actual function definitions. `get_platform_context` calls `private.platform_actor(true)` and converts PostgreSQL42501 `MFA_REQUIRED` into `step_up_required=true`. All four console read RPCs call the same default-true guard. That guard requires signed TOTP AMR within ten minutes, even for an otherwise valid AAL2 session. The frontend's existing minute/focus/Auth-event context checks therefore replace the entire console with MFA. JWT refresh changes issuance time, not the genuine signed TOTP authentication time. This is a shared read/mutation policy defect; it does not indicate an incorrect current owner identity.

## Exact approved database scope

Applied forward-only migration: `supabase/migrations/20261030120000_platform_read_mfa_freshness.sql`.

SHA-256: `263a8c7c18206a4f4f138e5f6ce279a91f3482bd8ea668e034799c6776e3aace`.

- Add private SECURITY DEFINER `platform_read_actor()` with fixed empty search_path and no PUBLIC/anon/authenticated/service_role EXECUTE. Reuse `platform_actor(false)` for active registry/profile, owner role, live non-expired session and non-banned identity; additionally require signed JWT AAL2, live session AAL2 and its verified TOTP factor. No AMR age limit for reads.
- Replace `get_platform_context()` to request initial MFA only when this read guard reports `MFA_REQUIRED`; other authority/session denials remain denials.
- Replace only the guard call in `get_platform_overview`, `list_platform_entities`, `platform_directory`, and `list_platform_invitations`. Their query bodies, signatures and existing EXECUTE privileges are preserved, including invitation invalidation reasons.
- Leave `platform_actor`, all privileged mutation functions and the ten-minute signed-TOTP condition byte-for-byte unchanged. No table, RLS, membership, role, accounting function, financial data or existing migration changes.

Canonical linked dry-run PASS: healthy named Development target, existing private credential, exactly this one pending migration, exit0, no hosted login-role initialization. Private evidence: `/tmp/narvo-p1-mfa/canonical-dry-run.json`; hosted definitions: `hosted-functions.json` in the same temporary evidence directory. The owner subsequently approved this exact file/hash; the guarded execution and postflight below are complete. This migration is now applied/frozen.

## Application behavior

`PlatformApplication.tsx` preserves the verified console on same-identity MFA events while rechecking context in the background. Sensitive mutation42501/MFA_REQUIRED opens an action-scoped genuine Supabase challenge. Verification alone never executes the pending action: the user must review the intended input, check confirmation and submit again. The existing command/request UUID is retained for idempotency. Cancellation, denial and uncertain outcomes do not automatically replay mutations. Identity changes/sign-out clear access; revoked ownership, AAL1, factor removal and expired sessions remain blocked by the server. No cached/fabricated production MFA state is introduced.

Invitation email attempts now require explicit confirmation and understand the delivery function's safe `MFA_REQUIRED` response. The function entrypoint preserves that exact denial from the database claim RPC; generic failures disclose no details. Claim/lease authorization and fresh-TOTP enforcement remain unchanged. Local function preparation is not hosted function deployment; no email was sent. Delivery deadlines remain bounded and ambiguous results are never automatically retried.

## Verification

- 48 isolated PostgreSQL assertions PASS: AAL2 reads after660seconds; AAL1/non-owner/inactive-profile/inactive-owner/expired-session/factor removal blocked; stale TOTP and password-only AMR mutations rejected; fresh TOTP mutation permitted; all prior60 migration bytes preserved; read bodies differ only in guard; mutation definitions/ACLs/RLS unchanged; no tenant financial access or Company membership added.
- 49 existing browser assertions PASS against canonical local PostgreSQL and synthetic Auth transport.
- 84 platform database/security regression assertions PASS with all61 canonical migrations and unchanged synthetic financial fingerprints. The first run stopped at its historical hardcoded60 count; the test now checks exactly61 and the candidate filename. No SQL defect was hidden by changing the count; all subsequent authorization and financial assertions passed.
- 19 targeted P1 browser assertions PASS, including stale navigation/token refresh, invalid TOTP, explicit reconfirmation, same-request resume, cancellation, revocation and mock delivery step-up. No real email/provider calls.
- Delivery contract:21 existing assertions plus3 new safe-MFA-denial assertions PASS; Edge entrypoint TypeScript/SDK/JWT contract PASS.
- Build PASS (2730 modules); lint0 errors /10 existing warnings; P6A production import boundary PASS; git diff whitespace and targeted source/build secret/fixture marker checks PASS. Build retains the existing large-chunk advisory.
- Fixtures run canonical SQL in isolated PGlite PostgreSQL with synthetic Auth transport/claims. They are local-only and are not production authorization evidence.
- The original four-migration `verify:platform:release` remains a frozen P0 batch guard and is not the gate for a61-migration tree. New `verify:platform:mfa` verifies the original56 bytes and four frozen hashes before testing exactly this61st candidate; it does not silently loosen that historical release allowlist.
- Real hosted AAL2 browsing beyond ten minutes: owner-reported PASS on2026-10-31, approximately one hour without repeated MFA prompts. Real sensitive mutation step-up/reconfirmation, invitation end-to-end and Vercel deployment acceptance remain PENDING. Approved migration application is complete. No production readiness claim.

## Actual Development execution and next acceptance

The owner explicitly approved the exact migration/hash. Fresh target identity, all prior60 local migration bytes/hashes, remote60 history, schema/function/privilege drift, active intended owner and financial preflight passed. Canonical linked dry-run selected exactly the approved file, using the existing private credential with no login-role initialization. Immediate guards passed again before apply. CLI apply exited0 with exactly the approved candidate; no roles/seeds/Vault operations or other project.

Immediate postflight at `2026-10-29T20:47:18.214472+00:00` (`2026-10-30 00:47:18 Dubai`) passed all20 checks:

- Hosted history61; original60 history rows unchanged.
- All54 fresh preflight data counts/fingerprints unchanged, including registry, Companies/memberships, profiles and financial tables.528 journals,1102 lines,248 historical source records; zero unbalanced journals.
- All20 platform function bodies exactly match the canonical SQL. All unrelated function definitions and all existing function privileges unchanged; sensitive mutation definitions/ten-minute guard unchanged.
- Only one new private helper; fixed empty search_path, SECURITY DEFINER, no anonymous/authenticated/service EXECUTE.
- Tables, columns, constraints, RLS policies, existing roles/memberships, schema/default grants and current owner registry unchanged.

Durable sanitized result: [Development execution result](release/development-mfa-read-write-result.json). Private preflight/postflight snapshots and sanitized CLI evidence remain under `/tmp/narvo-p1-mfa/approved-*`; these are verification metadata/fingerprints, not recovery artifacts. No backup/key operations, public deployment, Auth-user change, email or financial mutation occurred.

Sustained browsing was subsequently confirmed by the owner on2026-10-31: approximately one hour of real-session navigation without repeated MFA prompts. Do not repeat this completed acceptance test or request another sign-in/enrollment. Next release step: reviewed local release commit only; verify Vercel Git deployment behavior and obtain separate push/deployment authorization before any remote delivery. Real administrative mutation acceptance requires separately authorized inputs and explicit confirmation; no hosted test records were created here. Local UI build is ready; frontend and Edge Function deployments remain excluded. Do not reapply this migration or rewrite it; any later correction must be forward-only.

## Lifecycle classification

Business/accounting: VERIFIED unchanged financial semantics; no financial operations. Security/authorization: VERIFIED local guard split/server-enforced mutation freshness and owner-reported real-session sustained browsing; sensitive-operation real-session and invitation acceptance DEFERRED. Database: VERIFIED local forward migration and linked dry-run; hosted application VERIFIED by actual catalog/history/data postflight. Deployment: VERIFIED local preparation; external deployment DEFERRED/not authorized. Testing: local evidence above and owner-reported one-hour browsing VERIFIED; invitation end-to-end, sensitive-operation real-session and Vercel deployment acceptance DEFERRED. Documentation: VERIFIED current checkpoint added to handoff/roadmap/console/checklist. Independent disaster recovery remains incomplete and owner-managed; no backup/key operations performed.
