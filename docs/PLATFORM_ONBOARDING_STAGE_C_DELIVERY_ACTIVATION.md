# Stage C — Development invitation delivery activation verified

2026-11-01,00:06 Dubai (2026-10-31,20:06 UTC). **DEVELOPMENT DELIVERY ACTIVATION VERIFIED / RECIPIENT ACCESS AND STAGE D PENDING.** This is the one newly authorized conditional retry following the Vary verifier correction. No additional deployment or authenticated delivery operation occurred. No rollback was needed.

[Exact secret-free execution evidence](release/development-onboarding-stage-c-vary-activation-result.json). Previous failed/rolled-back attempts remain preserved as historical records, not current hosted state.

## Narrow verifier correction and local evidence

Added only local verification files:

- [Vary parser](../scripts/platform_invitation_vary.py): combine repeated header lines, split comma-separated members, trim HTTP whitespace, normalize case and compare exact field-name membership. Additional valid members and ordering are accepted; Origin is required. Empty/missing Origin and invalid field names fail.
- [Focused regression tests](../scripts/verify-platform-invitation-vary.py):13/13 PASS. Includes Origin alone, both requested Accept-Encoding orderings, missing Origin, case/whitespace, repeated header lines, duplicates, additional fields, absent/empty headers, substring rejection and malformed names.

Run: `PYTHONDONTWRITEBYTECODE=1 python3 scripts/verify-platform-invitation-vary.py`. Python AST syntax checks passed for both files and the local operator scripts. Existing strict checks for exact approved Allow-Origin,204/empty body, no-store, allowed methods/headers were unchanged. The corrected metadata verifier was unchanged and SHA-checked against its accepted evidence. No application/Edge Function source, financial behavior, database rule or Auth policy was edited. No full build/general audit/regression suite was repeated.

The private operator runner imports this tested parser; it combines all response Vary lines before validation. Its narrowly reviewed diff and execution-script fingerprints are retained with operator evidence. No HTTP check was weakened into accepting a wildcard application origin or missing Origin token.

## Fresh guards and deployment

- Healthy exact `MakerACC-Development / eqnzueginpkskbnqvgoc`; no function or origin setting existed before this attempt. Local search showed only this function consumes the shared origin setting.
- Approved three-file package and canonical source hashes matched digest `1f276731c4f7d4a086850251b15ff92703fc1179e74d739a5a09364fd457bce8`. Private staging contained only those reviewed files. CLI2.115.0 and source SDK import remained unchanged.
- Seven provider default digests were stable in fresh reads; safe per-entry evidence was retained. Full Auth fingerprint and Stage B accepted values matched the retained baseline. Read-only Preview identity/READY/protection checks passed; no Vercel mutation.
- Exactly one server-side setting was applied: `PLATFORM_APP_ORIGIN=https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app`.
- Exactly one function deployed: `platform-invitation-delivery`; ID **`59414c7a-6baf-476d-8a7b-376783404b76`**, version **1**, status **ACTIVE**, **`verify_jwt=true`**. New ID/version were recorded rather than reusing either deleted attempt's identity. Actual entrypoint matched the reviewed function.
- Downloaded `index.ts` SHA256 `b7cfd692c59cc8a6030fa29bb2defa176435431ba629c802273b9e09a766976e` and `handler.mjs` SHA256 `86d75636e02dddca69b602dc4acdbb4a240c923a0b746924e4ddccf7ed701d2f` exactly match the approved source. Actor/user validation, fresh-MFA lease claim, finalization and server/browser boundaries are unchanged.
- Origin digest, all provider secret digests, unrelated user-managed metadata and full Auth configuration passed after origin set, after deployment and after the two probes. Only the seven explicitly allowed provider timestamps refreshed; no other secret metadata change was accepted. Final function ID/version/update marker, ACTIVE status and JWT flag were stable.

## The two hosted non-delivery smoke checks

| Probe | Actual result | Evidence boundary |
| --- | --- | --- |
| OPTIONS, approved Preview origin, no credentials/UUID | **PASS:204**, empty body; exact approved Allow-Origin; methods `POST, OPTIONS`; headers `authorization, apikey, content-type, x-client-info`; `Cache-Control: no-store`; `Vary: Accept-Encoding, Origin` parsed as `{accept-encoding, origin}` | Confirms handler runtime/configured CORS contract. No claim/delivery/finalization invoked. |
| POST `{}`, no Authorization/apikey/UUID | **PASS:401**, missing-Authorization rejection classified at gateway | Confirms unauthenticated JWT gateway rejection. Does not claim handler identity/MFA/database checks were exercised. |

The gateway401 uses the provider's generic CORS headers, including wildcard Allow-Origin; it is a different response layer from the handler's exact-origin OPTIONS response. It contains no protected financial/recipient data and does not establish application CORS configuration. The two responses were not conflated. There was no authenticated POST or retry of either probe.

## Final state, lifecycle and limits

The function remains ACTIVE and the approved origin remains configured. No rollback command was run. Exactly two hosted mutation commands (one setting, one function deployment) and exactly two non-delivery function requests occurred. No Production/Staging, frontend/Vercel, Auth/Stage A/B/template/SMTP, DB/schema/RLS/grant, users/Companies/memberships/invitations, financial-data, email/Auth-link, Git commit/push/merge or recipient-access operation occurred.

| Category | Classification and limits |
| --- | --- |
| Business/accounting | VERIFIED: no behavior/data mutation. Company accounting provisioning remains separate. |
| Security/authorization | VERIFIED: exact source/JWT metadata, preserved secrets/Auth settings and gateway missing-JWT rejection. DEFERRED: authenticated actor/MFA/claim/finish and real invitation acceptance. |
| Database | NOT APPLICABLE: no migrations, RLS/grants/schema/data changes; no unnecessary alignment/dry-run/audit rerun. |
| Deployment | VERIFIED: exact Development target/package, ACTIVE function, origin/source readback, two passing probes and final stability. Production release remains outside scope. |
| Testing | VERIFIED:13 focused local tests, syntax checks, fresh preservation/source checks and hosted OPTIONS204/POST401. DEFERRED: real provider delivery/inbox/password/sign-out/sign-in/acceptance/workspace. |
| Documentation | VERIFIED: current outcome/evidence and handoff/roadmap pointers updated; previous attempts retained. |

**Stage C delivery activation is verified within this Development/non-delivery scope.** It does not prove a real invitation was delivered, that a recipient can pass Vercel protection, or that Super Admin is commercially ready.

Remaining access requirements: identify the dedicated recipient and independent Vercel identity; inspect actual Hobby external-collaborator capacity and deployment/branch grant scope; obtain separate approval for the named scope; then prove token-free ordinary Preview and `/auth/callback` access in the same browser/profile that will open the email. No bypass, protection relaxation, team addition or grant is authorized by this result.

Stage D requires separate approval specifying recipient, dedicated Company, role, test-record scope and controlled email delivery. Existing-user handling, real Auth token/password/session behavior, explicit acceptance and workspace entry remain future actual-user evidence. Preserve the agreed later sequence: Company accounting setup, manual subscriptions, Super Admin design, acceptance/closure, original roadmap/urgent experience work, then Company Dashboard reference implementation.

**STOP after this authorized execution.** No further hosted operation, invitation or access grant is included.
