# P6E — Production Data Mode / LocalStorage Retirement

2026-09-29. **P6E COMPLETE for Development.** Implementation and focused evidence are user-accepted. This package implements only the three user-approved gaps. Baseline: main, HEAD = origin/main = bc3f678cda9c70b8598659d30e58985eb7c4ad79, ahead/behind 0/0, clean. Production readiness remains outstanding; hosted signed-in smoke and PRE_DEMO_UAT remain deferred/non-blocking.

## Frozen scope and result

1. **Authority revalidation:** a current failed identity/profile/membership/Company read enters the existing recoverable `IDENTITY_LOAD_ERROR` state even during background revalidation. Protected children unmount, blocking their content/actions. Retry must perform authoritative revalidation before access resumes. Successful same-authority focus/visibility checks preserve the existing ready state and user drafts. Existing request/generation/user guards still discard obsolete responses. A failed check can discard unsaved UI drafts; existing scoped recovery envelopes remain intact.
2. **Configuration:** one shared validator serves runtime configuration and Vite's pre-bundle build gate. Only explicit `supabase-auth`, or `local-demo` on the development server, is supported. Production demo builds fail. Supabase requires a valid HTTPS URL (HTTP loopback allowed only in development) and a nonempty browser-safe key. Accepted keys are `sb_publishable_` format or structurally valid legacy HS256 JWT keys with role `anon`. This classification does not authenticate JWTs; Supabase remains responsible for actual key validity/authorization. Secret/service-role keys and recognizable privileged values/names in public `VITE_*` configuration are rejected before bundling. Errors contain no values. No actual private environment files or credentials were printed.
3. **Dependency/storage boundary:** shared TypeScript-AST traversal follows static imports, re-exports and literal dynamic imports/require calls, rejects unresolved local aliases/nonliteral dynamic dependencies, and forbids production paths into demo state/storage/seed/pages/providers and local accounting engines. Existing P6A/P6C static guards and the production build use this guard. Shared locale/config entry paths are included. No new library dependency. External package internals are outside this application-source graph.

The old P6C static assertion requiring ready-state preservation after a failed background check was updated to the newly frozen P6E behavior. Successful routine preservation remains checked. Financial, Attendance and Payroll source/commands were not changed.

## Storage contract

| Storage | Classification / retained use |
|---|---|
| localStorage `cas:v1:locale` | A: presentation preference, existing i18n module only |
| localStorage `makeracc:p6a:active-company:<userId>` | A: preference only, checked against authoritative active memberships/Companies |
| Supabase `makeracc:p6a:auth` session persistence | A: ordinary user authentication state, existing SDK configuration unchanged; no privileged credentials |
| sessionStorage financial/Payroll recovery | Existing explicit file allowlist; scoped pending request/idempotency envelopes, never authority for balances, permissions or successful posting |
| localStorage `cas:v1:*` demo business repositories | B: isolated demo data, not production dependencies; no deletion/import |

No C production-authoritative browser-storage leak was identified in the bounded assessment. No blanket storage removal or new production business cache. The guard restricts application localStorage access to Auth preferences and i18n; sessionStorage access is restricted to the existing 17 recovery UI files. Normal React display/form state is not a replacement database. Neutral branding fallback remains presentation-only.

## Focused evidence

- `node scripts/verify-p6e.mjs` PASS: public/legacy-anon configuration; missing/invalid mode and URL/key; malformed/privileged keys; local-demo production rejection; actual Vite configuration resolution rejects service-role input before build processing without echoing it; temporary dynamic-import/re-export/static-import violation fixtures; nonliteral imports; unapproved localStorage/sessionStorage; real application dependency guard.
- `node scripts/verify-p6e-interactions.mjs` PASS: isolated Chromium using actual Auth, error UI and production master provider with synthetic transport. Tampered remembered Company cannot select unauthorized scope; profile/membership/Company read failures block and Retry recovers; successful focus preserves drafts; inactive profile/membership/Company removes access; delayed sign-out/old-user responses cannot restore scope; preloaded demo Companies/Projects never replace database results on navigation/reload or failed reads; locale and scoped recovery envelopes persist without granting business authority.
- `npm run build` PASS, including configuration and import gates. Existing large-chunk advisory remains.
- `npm run lint` PASS; four pre-existing warnings only.
- `npm run verify:p6a-boundary` and `npm run verify:p6c-boundary -- --static-only` PASS. Production/shared graph: 145 modules; demo graph: 54; master modules: 42.
- Focused changed-file secret scan and `git diff --check` PASS.

No historical P6A/P6C/P6D/Payroll browser matrices or historical behavior suites rerun. No hosted queries or signed-in hosted smoke. Browser evidence is isolated, not a claim of production validation.

## Lifecycle and files

- Business/accounting: VERIFIED for the frozen data-authority contract; existing financial workflows unchanged.
- Security/authorization: VERIFIED for focused configuration, identity-error and dependency/storage boundaries. Full Production Security & Accounting Integrity Audit DEFERRED to the separate pre-go-live gate.
- Database/migrations: NOT APPLICABLE; no schema, RLS, grants or migration changes. Existing canonical migrations untouched.
- Deployment: build configuration gates VERIFIED locally; no environment changes. Staging/Production actions NOT APPLICABLE; Production readiness DEFERRED.
- Testing: focused checks VERIFIED; hosted signed-in smoke/PRE_DEMO_UAT DEFERRED/non-blocking.
- Documentation: VERIFIED by this record and current roadmap/handoff status.

Changed files: `src/auth/AuthContext.tsx`, `src/App.tsx`, `src/lib/supabase.ts`, new `src/config/productionConfig.ts`; `vite.config.ts`, `.env.example`; shared `scripts/production-boundary.mjs` and declaration; existing P6A/P6C boundary scripts; new `scripts/verify-p6e.mjs`, `scripts/verify-p6e-interactions.mjs`, `scripts/fixtures/p6e.tsx`; this record, roadmap and handoff.

No blockers. No WPS, Payroll expansion, financial/P6D changes, offline accounting, deployment infrastructure expansion, full production audit, PRE_DEMO_UAT execution, Staging/Production actions or push. Development completion does not authorize production use.

## Interruption recovery — 2026-09-29

Confirmed main, HEAD = origin/main = bc3f678cda9c70b8598659d30e58985eb7c4ad79, ahead/behind 0/0. The dirty tree contained only the 16 expected P6E files (9 tracked modifications, 7 new files). Reviewed the full diff, new files and three frozen requirements before editing. All three implementation gaps and focused tests were already present; no blocking unsafe/inconsistent partial implementation was found. Preserved all source/test work without redesign. Remaining work was completion verification and two stale current roadmap summaries, now reconciled. No reset, checkout/revert, git clean, discarded untracked work, financial/Payroll source changes, migrations, commit/push or Staging/Production access.

Recovery verification: both focused P6E scripts, build, lint, current P6A/P6C static boundaries, focused 16-file secret scan and diff check PASS on 2026-09-29. Four pre-existing lint warnings and the existing build chunk-size advisory remain. No historical browser matrices or hosted verification ran. Proposed P6E COMPLETE for Development; Production readiness remains deferred.

## Development closure — 2026-09-29

P6E COMPLETE for Development, accepted by the user. Reviewed all 16 changed/new files as a coherent P6E-only package with no blocking findings. Only stale completion wording was updated during closure; accepted tests and verification were not rerun. No new phase, PRE_DEMO_UAT, production-readiness work, migrations, financial/Payroll/WPS changes or Staging/Production actions. One local commit records closure: `Complete P6E production data mode`. No push. Production readiness remains deferred; the existing chunk-size advisory and four pre-existing lint warnings remain non-blocking.
