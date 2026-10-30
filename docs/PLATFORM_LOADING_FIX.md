# Platform loading blocker correction — 2026-10-29

Stage: focused implementation/runtime acceptance correction in the existing console. No redesign, schema change, backup/migration rehearsal, SMTP test, privileged-account creation or financial write.

## Actual request evidence

A bounded read-only Development log query, covering the current15-minute window around13:02UTC (17:02Dubai), finds completed403 responses to `/rest/v1/rpc/get_platform_context`, and a separate signed-out401 stream. No Overview request occurs in that returned window. Exact-error follow-up around13:08UTC distinguishes SQLSTATE42501 with message exactly `Denied` from the anonymous function-permission denials. These are completed authorization failures, not evidence of a PostgreSQL timeout or MFA failure. No current browser tokens/storage/credentials were extracted. Multiple client streams exist; timestamps alone cannot prove which pending JavaScript promise belongs to the user's visible tab. The earlier owner/session inventory remains a historical snapshot, not a fresh assertion about current browser identity.

Local source confirms an independent frontend defect: context session/token acquisition and network requests had no application deadlines; each focus/visibility/Auth event launched another read and invalidated earlier results. An unresolved promise could leave loading true forever; overlapping reads could discard earlier completed results. MFA factor lookup used the same loading text and was also unbounded. Overview accepted null/malformed success data; null could leave its loader unresolved even after the request finished. No evidence proves an SDK lock deadlock or MFA failure in the user's tab; those must not be guessed from a spinner.

## Implemented correction

- Existing console and routing retained. Session lookup has a5-second deadline; context/Overview RPCs and individual MFA calls have10-second deadlines. Context path is at most approximately15seconds of active browser timer time (5session +10RPC), not an unbounded wait. Overview has a separate10-second deadline after authorization/MFA.
- `platformDeadline.ts` races even a never-settling SDK promise, propagates AbortSignal to PostgREST fetch, cleans timers/listeners and supports cancellation. SDK Auth methods without signal support may continue internally; their late read results do not revive timed-out UI. A timeout does not prove server nonexecution.
- `platformApi.ts` bounds transport calls, exposes only fixed operation labels/bounded error codes, retains explicit owner/step-up response validation and validates required Overview counts/timestamp. Auth errors preserve safe provider codes. Only recognized revoked-session errors recommend reauthentication; a network/session wait is never labeled an owner denial.
- Context reads coalesce while pending; old reads are canceled on unmount/identity change/MFA transition. Sequence guards ignore obsolete results. Failed reads remain visible instead of focus/poll retry loops erasing them. Explicit Retry creates a fresh read; real session transitions can revalidate. Known signed-out state does not poll privileged RPCs.
- Overview read errors show an operation/code and dedicated Retry. Null/malformed success responses show `get_platform_overview · INVALID_RESPONSE`, never another permanent spinner. Existing command idempotency/uncertain-result receipt behavior remains; timeout does not trigger automatic mutation retry.
- MFA lookup/enrollment/verification has bounded error handling. Unknown factor state continues to block enrollment; verified factors are preserved. Retrying lookup never invents or verifies a factor. No MFA/RLS/owner/Company/financial authorization bypass was introduced.

Safe UI diagnostics: `auth_session · REQUEST_TIMEOUT`, `get_platform_context · REQUEST_TIMEOUT`, `mfa_factors · REQUEST_TIMEOUT`, `get_platform_overview · REQUEST_TIMEOUT`; actual SQL/provider codes remain visible, including42501. Arbitrary provider messages, sessions, tokens, passwords and payloads are not retained/rendered as diagnostics.

## Files and verification

Implementation: `src/platform/platformDeadline.ts`, `platformApi.ts`, `PlatformApplication.tsx`, `platformText.ts`. Tests: `scripts/verify-platform-access.mjs`, `verify-platform-loading.mjs`, isolated `fixtures/platform-console.tsx`; npm script registration. Current handoff/roadmap/activation/console documentation reconciled. All applied migrations remain unchanged.

VERIFIED focused tests:25 access/deadline assertions;17 focused loading browser assertions, using deliberately unresolved Auth/context/MFA/Overview calls, real isolated PostgreSQL counter responses,20-event focus/visibility/Auth storms, late completion, stable error/poll behavior, malformed response, and explicit retry. Browser virtual time exercises the actual production deadline code; no shorter production timeout or synthetic production authentication was added.49 existing isolated browser regressions also pass, including owner/MFA, invitation/recovery, revocation and absence of UI financial writes. Final build passes; lint has zero errors and ten existing warnings; P6A import boundary and git diff --check pass. Targeted credential-shaped literal/build fixture-marker scans pass. The existing private preview was checked for the updated served bundle and signed-out runtime boot with external requests blocked; that smoke is not real owner acceptance.

DEFERRED: the user's actual authenticated browser after refreshing the updated bundle and successful hosted Overview counters. No actual owner Overview success is claimed. The current hosted403/42501 remains a real authorization rejection; a timeout fix cannot grant authority. Browser session state is not accessible through this agent's tools, so no claim is made about its exact internal SDK wait. The bounded UI now reports that phase safely if it stalls.

NOT APPLICABLE: accounting policy, hosted database or grant changes, migrations, backups, SMTP, new accounts or public deployment. No hosted write, commit or push. Security is VERIFIED locally/targeted request diagnostics, with real owner acceptance DEFERRED. Documentation is updated; production release is not authorized.

## One exact next action

Hard-refresh the existing http://127.0.0.1:5173/platform tab and allow up to15seconds for access validation. It must leave the initial spinner for normal sign-in/MFA, authorized console/Overview, or a precise operation/code with Retry. Report only that operation/code if it fails. Do not reset a password or repeat MFA unless a specific verified state explicitly requires it. No further login/reset request is a prerequisite for these code-side corrections.

Private safe evidence: `/tmp/narvo-owner-access/current-loading-api-logs.json` and `exact-denial.json`; no identifiers or tokens. No prior recovery artifacts were accessed or modified.
