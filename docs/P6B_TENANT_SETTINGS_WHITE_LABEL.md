# P6B — Tenant Settings and White-Label Foundation

Date: 2026-09-05. Status: verified complete on Development.

## Architecture and schema

P6B adds `public.company_settings` through canonical migration `20260911120000_p6b_company_settings.sql` and forward correction `20260911123000_p6b_collision_safe_slugs.sql`. It is an owned one-to-one presentation child of `companies`; Company remains the tenant, security, and accounting root. The primary-key FK uses `ON DELETE CASCADE` only because a settings row has no meaning after its Company is legitimately deleted. No accounting relationship or deletion rule changed.

The row contains a stable routing/display-only slug, optional application display name, default locale, optional HTTPS logo/favicon references, bounded primary/accent colors, and actor/timestamps. Actor FKs use `ON DELETE SET NULL`: branding provenance is useful but must not trap deletion of a non-financial Auth identity. Slugs are lowercase, 3–63 characters, URL-safe, and globally case-insensitively unique. URLs are trimmed HTTPS-only values up to 2,048 characters. Colors are exact six-digit hex values.

Every Company existing at migration time receives exactly one row. The initial migration used a normalized Company code plus an eight-character UUID fragment; review identified that as improbable rather than guaranteed collision safety. The forward correction uses a bounded normalized prefix plus the full Company UUID, giving deterministic uniqueness within 63 characters before closure. `app_display_name` and asset references remain null; Company name and bundled assets are the safe fallbacks.

## Authorization

RLS is enabled and forced. Authenticated SELECT uses the existing `is_company_member(company_id)` helper, which requires an active profile, active membership, and active Company. Anonymous access is absent. `authenticated` receives SELECT only and has no INSERT, UPDATE, DELETE policy or grant. No browser mutation RPC or settings UI exists. Trusted `service_role` receives SELECT/INSERT/UPDATE for later provisioning and no DELETE.

The slug never authorizes access and is not used by routes, financial commands, or accounting references.

## Frontend lifecycle

The normalized `TenantSettings` model is shared by isolated adapters. In `supabase-auth`, a separate settings provider mounts only after P6A reaches `TENANT_READY`, receives its authorized Company ID, and reads exactly that RLS-protected settings row. It has loading, ready, missing, and error states. A keyed provider, request generation, Auth-user/live-session checks, and effect cleanup prevent a stale tenant response from applying after a user or Company transition.

Before resolution and on switch, logout, revocation, error, or unmount, presentation resets to neutral title, bundled favicon, and default CSS tokens. Missing settings do not change P6A authorization truth and show a safe configuration message.

Ready settings drive the authenticated shell identity, shared demo sidebar identity, logo/fallback icon, document title/favicon, and fixed `--tenant-primary`/`--tenant-accent` variables. Tenant content is never rendered as HTML, CSS, SVG markup, or script. Images use normal `<img>` rendering, `referrerPolicy="no-referrer"`, and a neutral fallback on failure.

`companies.name` remains business/trade identity, `companies.legal_name` remains legal identity, and `app_display_name` is presentation identity. The existing explicit browser locale preference wins. Without it, the always-populated P2 profile locale normally wins; tenant default remains available where no stronger preference exists and for future provisioning. No profile schema semantics changed.

Local demo uses a demo-only provider and the same normalized model. It imports no Supabase settings loader, adds no settings localStorage repository, and does not migrate or rewrite any `cas:v1:*` accounting/master collection.

## Verification performed

- Pre-apply local/remote history matched through `20260910120000`.
- Linked dry-run selected only the P6B migration.
- Migration applied only to linked `MakerACC-Development`.
- Public generated types were regenerated through the linked CLI workflow and reviewed.
- Post-apply migration history aligns through `20260911123000`; linked dry-run is a no-op.
- Hosted database lint found no P6B issue; it reports only the known pre-existing P5C unused-variable warning.
- An anonymous Data API SELECT against `company_settings` returned HTTP 401, confirming anonymous read denial.
- Build, lint, static Auth/demo dependency boundary, Company-settings mutation scan, `git diff --check`, and focused source scans are required final gates for this batch.

The controlled Development hosted matrix subsequently verified 16 Companies/16 settings rows, no missing/orphan settings, slug format and uniqueness, every approved constraint rejection, forced RLS, the single SELECT policy/grant, anonymous denial, active same-Company reads, cross-tenant filtering, browser mutation/ownership denial, inactive profile/membership/Company revocation and recovery, and zero P6B fixture rows in unrelated Company-owned base tables.

The local Auth-mode browser smoke verified authorized Alpha identity/legal name/title/favicon fallback/colors, EN/AR/RTL and explicit-locale persistence, refresh/session restoration, logout reset, neutral multi-Company selection, Alpha → neutral switch → Beta without stale branding, broken-logo fallback, and missing-settings neutral behavior without loss of tenant authorization.

A reproducible route-state defect was then confirmed: after `NO_ACTIVE_COMPANY` recovery or Company selection reached `TENANT_READY`, the ready wildcard rendered the correct shell while retaining `/no-company` or `/select-company`. The cause was a missing canonical redirect for obsolete Auth-state paths in the `TENANT_READY` route table. The correction declaratively replaces `/login`, `/no-company`, `/select-company`, and `/auth-error` with `/` using history replacement only after authoritative tenant resolution. Ordinary protected accounting paths still render only the holding shell, and pathname never authorizes access. Automated boundary coverage now asserts all four canonical routes.

## Manual browser verification

Use synthetic records only in `MakerACC-Development`, record console/network evidence, and clean up only fixtures created for this run:

1. Start signed out with no tenant settings applied; verify neutral title, bundled favicon, and default CSS tokens.
2. Sign in as an active member and verify the authorized Company settings request is the only new Data API request. Confirm display/business/legal identity, title, favicon, logo, and exact CSS token values.
3. Configure two authorized synthetic Companies differently, switch A → B, and verify A's title/favicon/logo/colors disappear before B loads and never repaint afterward.
4. Refresh with a persisted session, then log out; verify branding restores after refresh and resets immediately on logout.
5. Inactivate the profile, membership, and Company in separate controlled cases; trigger P6A focus revalidation and verify protected branding clears with access. Restore each fixture before the next case.
6. Verify a missing settings row produces neutral branding plus the safe configuration message without corrupting the authorized tenant state.
7. Verify a valid HTTPS logo renders, a broken HTTPS logo falls back to the neutral icon, and favicon failure does not remove the bundled fallback on the next reset.
8. Verify EN, AR, document `lang`/`dir`, RTL layout, and that an explicit stored user locale wins over profile and tenant defaults.
9. Exercise anonymous, same-tenant, cross-tenant, inactive-profile, inactive-membership, and inactive-Company SELECT cases; verify browser INSERT, UPDATE, DELETE, and `company_id` changes are denied.
10. Switch to development `local-demo`, confirm equivalent identity without a settings network request and unchanged `cas:v1:*` accounting/master data, then return to `supabase-auth`.
11. Confirm network traffic contains no master/accounting table requests, financial RPCs, settings mutations, or privileged credentials, and confirm zero unexpected console errors.

The complete matrix passed. Post-fix verification confirmed canonical `/` recovery from stale `/select-company` and `/no-company`, neutral switch state, Alpha/Beta selection without branding leakage, history replacement, safe re-resolution to a remaining valid tenant, and holding-shell-only behavior at `/expenses` and `/journal`. A valid non-null HTTPS logo/favicon rendered with `no-referrer`; the references were restored to null afterward. Local-demo retained its accounting data and remained isolated before returning to `supabase-auth`. Final Auth-mode network inspection contained only JWKS, profile, membership, Company, and settings reads; there were no master/financial requests or settings mutations. The final console was clean.

P6B is therefore verified complete.

## Post-closure cleanup

Development-only cleanup was verified complete on 2026-09-05. The exact P6B Alpha/Beta memberships and Companies, their owned settings rows, and the single guarded synthetic profile/Auth user were removed without a broad or explicit `CASCADE` command. Final verification returned zero matching Companies, settings, memberships, profile, and Auth user. Global one-to-one integrity remained exact at 14 Companies/14 settings rows with zero missing or orphan settings.

Browser cleanup removed all `makeracc:p6a:*` temporary Auth/tenant keys while preserving all 15 historical `cas:v1:*` local-demo keys. Unrelated historical P2 fixtures/users, Staging, and Production were untouched. The occasional Chromium DevTools `startTime`/`reportAllChanges` exception remains documented browser-tooling noise, not a MakerACC error.

## Definition of Done

- Business/accounting: **VERIFIED** — presentation configuration only; P5 behavior and accounting truth are unchanged.
- Security/authorization: **VERIFIED** — active tenant membership remains authoritative; forced RLS, cross-tenant denial, revocation, read-only browser access, mutation denial, and stale-transition behavior passed.
- Database: **VERIFIED** — the two canonical migrations are applied only to Development, aligned, constraint-tested, and dry-run current.
- Deployment: **DEFERRED** — Staging/Production rollout remains a later explicitly authorized activity; no environment configuration changed.
- Testing: **VERIFIED** — hosted matrix, browser matrix, post-fix route re-smoke, build, lint, static boundaries, network/console checks, and diff checks passed.
- Documentation: **VERIFIED** — phase record, roadmap, and handoff reflect actual completion and deferrals.

## Deferrals

Settings UI/mutations, upload/Storage, public slug discovery/routing, slug history, custom domains, arbitrary themes/fonts/layouts, expanded login branding, branded documents/messages, PWA manifest branding, multi-currency and broader formatting, subscriptions/entitlements/provisioning UI, P6C–P6E, P7 audit events, Staging/Production rollout, and the full pre-production audit remain deferred. Historical local-demo dashboard card/statistic clipping is a separate cosmetic UI/UX improvement and did not affect P6B isolation or acceptance.
