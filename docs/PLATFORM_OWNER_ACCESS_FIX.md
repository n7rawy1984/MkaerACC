# Real owner access diagnosis — 2026-10-29

Stage: targeted hosted-authentication acceptance diagnosis and local error-recovery implementation. No repeated migration, backup, SMTP or general audit. Target only MakerACC-Development `eqnzueginpkskbnqvgoc`.

## Verified failure and root cause

Bounded hosted API logs show `POST /rest/v1/rpc/get_platform_context` returning403 for authenticated requests, before any Overview request. Corresponding PostgreSQL records have SQLSTATE42501 and the exact message `Denied`. A separate signed-out request stream returns401 with a function-permission denial; these are distinct events, not an Overview failure. Log correlation is based on path and timing, not a shared trace ID. No private browser storage, JWTs or credentials were extracted.

Read-only Development metadata at12:17UTC (16:17Dubai) confirms the sole registered PLATFORM_OWNER remains active, with active profile, confirmed Auth identity, no ban, zero accounting memberships, zero hosted Auth sessions and zero verified TOTP factors. A separate read-only snapshot finds exactly one recent hosted session, created12:13:05UTC, AAL1, not expired, with zero verified TOTP factors, belonging to an account outside the owner registry. That aligns with the authenticated403/Denied request stream starting12:13 and the user's current denial. It is an account-authority mismatch; the registered owner's role was not lost. The actual owner's missing session and missing factor require real sign-in and enrollment, not a grant to this other identity.

`get_platform_context` and `get_platform_overview` are postgres-owned SECURITY DEFINER functions with fixed empty search_path, authenticated EXECUTE allowed and anonymous EXECUTE denied. Private platform_actor has no client EXECUTE. Owner registry SELECT is not granted to authenticated; authorization is through the constrained functions. Existing private registry RLS state is unchanged. The context function can return step_up_required for a legitimate owner without fresh MFA; an unauthorized identity is correctly rejected before that stage. No Session revoked or MFA_REQUIRED diagnosis is claimed for these authenticated failure records. Local .env configuration matches Development Auth and the publishable key type.

## Confirmed local defect and correction

The prior UI collapsed a wrong-account denial and revoked-session denial into the same generic retry panel. Repeated Retry cannot change the identity. The transport now preserves the static RPC name, bounded code and exact known denial reason; it never retains or renders arbitrary provider details, request payloads or tokens. The UI gives distinct account-authority/session-expiry guidance, displays `get_platform_context · 42501`, and provides **Sign in with another account** using the existing real Auth sign-out/sign-in path. Correct owner MFA enrollment/challenge remains mandatory. No factor, owner role, Company membership or hosted permission was changed.

Files: src/platform/platformApi.ts, PlatformApplication.tsx, platformText.ts; scripts/verify-platform-access.mjs, verify-platform-browser.mjs; package.json verification script; handoff/roadmap/activation/console records. No migration/SQL change. Rebuilt existing private loopback preview; no Vercel/public deployment, commit or push.

## Evidence and completion

- VERIFIED testing:8 focused access assertions;49 isolated browser assertions including denied identity diagnostics, account switching, actual local RPC owner/MFA enforcement, recovery and tenant/financial boundaries; production build; lint with zero errors/ten existing warnings; P6A import boundary; git diff --check; focused credential-shaped literal and build fixture-marker scans.
- VERIFIED security/database/configuration: targeted hosted identity/session/registry/RPC/grant checks above. All hosted database access was read-only and returned safe booleans/counts/error codes; no financial records queried or modified. No hosted writes in this batch.
- DEFERRED real acceptance: authenticated registered-owner session, real TOTP enrollment/verification, successful actual get_platform_overview and displayed hosted counters. Sidebar rendering and local fixtures do not prove this success.
- NOT APPLICABLE: new accounting behavior, tenant permission changes, migrations, backup/SMTP operations or public deployment.
- VERIFIED documentation: current records point here and preserve the previously completed60-migration checkpoint.

Safe private evidence: /tmp/narvo-owner-access/{database-evidence.json,identities-evidence.json,api-logs.json,exact-denial.json}. These omit personal identifiers, passwords, tokens and financial rows. Log access uses the supported [bounded read-only Management API query](https://supabase.com/docs/guides/observability/advanced-log-filtering).

## Exact next action

Owner must hard-refresh http://127.0.0.1:5173/platform, choose **Sign in with another account**, and sign in with the existing identity already registered as PLATFORM_OWNER. Enroll and verify the real authenticator when prompted; report only whether actual Overview counters load or the exact displayed operation/code. Do not share passwords, QR seeds, codes or email URLs. If the existing registered owner cannot be identified/accessed, identify that operational blocker privately; do not promote the current account, create another administrator or grant accounting membership as a workaround. No further agent-side implementation can substitute for this required user interaction.
