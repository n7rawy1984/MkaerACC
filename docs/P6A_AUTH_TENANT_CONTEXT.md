# P6A — Auth Session and Tenant Context

Date: 2026-08-31. Status: verified complete on 2026-09-04.

## Scope

P6A adds the production frontend identity boundary only: Supabase email/password sign-in, persisted session lifecycle, verified P2 profile/membership loading, active Company selection, tenant switching, protected routing, logout, retry/no-company/configuration states, and a tenant-ready holding shell.

P6A adds no database migration and performs no master-data or financial cutover. In `supabase-auth`, all accounting paths resolve to the holding shell; they cannot mount the localStorage application. P6B–P6E remain separate future work.

## Application modes and fail-closed behavior

`VITE_APP_DATA_MODE` must be explicit:

- `local-demo` is accepted only under the Vite development environment and dynamically imports `src/app/DemoApplication.tsx`. Existing routes and `cas:v1:*` demo books remain unchanged.
- `supabase-auth` dynamically imports `src/auth/ProtectedApplication.tsx`. Its static dependency graph contains no demo pages, `AppDataContext`, repositories, browser migrations, database adapter, or seed entry point.
- A missing/unknown mode, production `local-demo`, or missing/invalid browser-safe Supabase configuration renders a configuration error. It never falls back to demo data.

The production Auth branch reads only the existing `cas:v1:locale` presentation preference; it never reads or writes `cas:v1:*` accounting collections. `npm run verify:p6a-boundary` enforces the static import boundary and seed-path exclusion.

## Browser client and session transport

The singleton typed browser client uses only `VITE_SUPABASE_URL` and `VITE_SUPABASE_PUBLISHABLE_KEY`, with `persistSession`, `autoRefreshToken`, a stable `makeracc:p6a:auth` storage key, and `detectSessionInUrl: false`.

`detectSessionInUrl: false` is specific to P6A password login. Invite acceptance and password recovery are deferred onboarding requirements and must reevaluate this option before those flows are introduced. There is no signup, OAuth, magic-link, MFA, reset-password, or invitation-acceptance UI in P6A.

One `onAuthStateChange` subscription handles `INITIAL_SESSION`, `SIGNED_IN`, `SIGNED_OUT`, `TOKEN_REFRESHED`, and `USER_UPDATED`. Its callback performs only synchronous transport/state updates. Identity database work runs afterward in a React effect. Token refresh updates transport without treating cached claims or tenant choice as authorization truth.

## Identity and tenant authority

Each identity bootstrap first validates the current JWT with the installed Supabase JS `auth.getClaims()` API. It then uses existing P2 RLS to load the authenticated user's own `ACTIVE` profile, own `ACTIVE` memberships, and corresponding RLS-visible `ACTIVE` Companies. No convenience RPC or alternate authorization model was added. `SYSTEM_ADMIN` receives no non-member browser access.

The explicit states are `INITIALIZING_AUTH`, `SIGNED_OUT`, `LOADING_IDENTITY`, `NO_ACTIVE_COMPANY`, `SELECTING_COMPANY`, `TENANT_READY`, and `IDENTITY_LOAD_ERROR`; configuration errors are resolved before the Auth provider mounts. Protected UI never renders in unresolved/error states.

Resolution is authoritative: zero valid memberships produces no-company, one auto-selects, and multiple require selection unless the remembered Company is still in the newly loaded membership collection. The active tenant is always the selected membership object, never a URL/query/slug or untrusted stored ID.

The per-user preference key is `makeracc:p6a:active-company:<auth-user-id>`. A stale or forged value is removed after fresh membership validation. Company switching re-runs claims/profile/membership/Company validation before committing. Initial load, sign-in, `USER_UPDATED`, focus/visibility return, explicit retry, and Company switch revalidate identity. Network/database failures fail closed.

Every auth generation and identity request has a monotonically changing guard. Results may update state only if the request, generation, user, and live session still match. `SIGNED_OUT` invalidates outstanding requests and clears profile, memberships, tenant and protected state synchronously. Normal logout removes only that user's tenant preference and calls `signOut({ scope: "local" })`; it never calls `localStorage.clear()` or mutates demo accounting data.

## Routes and presentation

The application retains one `BrowserRouter`. Signed-out users are confined to `/login`; unresolved authenticated users resolve to `/select-company`, `/no-company`, or `/auth-error`. Tenant-ready users see a neutral bilingual holding shell with Company, role, optional Company switch, language control, logout, and a clear production-cutover-pending notice. All legacy accounting URLs resolve to that holding shell in Auth mode.

English/Arabic strings are typed in the existing dictionaries, and the existing document-level RTL behavior remains authoritative.

## Environment and deployment boundary

Before activating `supabase-auth` on Vercel, configure its browser-safe URL and publishable key plus `VITE_APP_DATA_MODE=supabase-auth`. P6A did not modify Vercel configuration or any hosted environment variables. Database passwords, service-role keys, personal tokens, and management tokens remain forbidden in `VITE_*` values.

## Verification

Automated checks cover the TypeScript/Vite production build, the production-auth static import graph, lint, package audit, unchanged migration history, and targeted secret/signup/hybrid-write/demo-dependency scans. The canonical migrations remain aligned with `MakerACC-Development` through `20260910120000`.

The full risk-proportionate hosted browser/Auth smoke matrix completed on 2026-09-04 with synthetic users and Companies in `MakerACC-Development`. It passed valid/invalid login, duplicate-submit prevention, session restoration, logout and cross-tab logout, invalid persisted-session fail-closed behavior, zero/one/multiple membership resolution, inactive profile/membership/Company exclusion, forged/stale preference rejection, Company switching, protected accounting URLs, focus/visibility revocation and recovery, English/Arabic/RTL, keyboard smoke accessibility, and local-demo/localStorage isolation. Network inspection found only Auth/JWKS and P2 identity reads: no master/financial mutation, accounting-table request, financial RPC, or privileged browser secret was present.

The deliberately timed stale identity-response race is classified `BEST-EFFORT / NOT PRACTICALLY REPRODUCIBLE`. Source review confirms deterministic request-generation, current-user and live-session guards plus synchronous invalidation; cross-tab logout and live membership/profile revocation provide supporting runtime evidence. No confirmed P6A defect remains. P6B–P6E and the master/financial Supabase frontend cutover have not started. Staging and Production databases were untouched, and the full Production Security & Accounting Integrity Audit remains a future pre-production gate.

## Post-closure cleanup

Cleanup was verified complete on 2026-09-05. Only `MakerACC-Development` was affected: five synthetic P6A memberships, three synthetic P6A Companies, four synthetic P6A profiles and their four Auth users were removed without `CASCADE`, with read-only verification returning zero matching rows after each cleanup stage. Historical P2 and other synthetic users were not removed.

On the hosted browser, cleanup removed only `makeracc:p6a:auth`, `makeracc:p6a:demo-hashes` and `makeracc:p6a:active-company:*`; no P6A keys remained. All 15 `cas:v1:*` keys, including the separately counted locale preference, remained preserved. Local `.env.local` remained in `supabase-auth`, Vercel was never changed to `local-demo`, and no privileged secret was exposed or added.
