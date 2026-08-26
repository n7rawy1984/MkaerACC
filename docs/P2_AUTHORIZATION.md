# P2 Auth and Authorization Operations

## Provisioning and invitations

Public signup is disabled in `supabase/config.toml` for the local configuration. In every hosted environment, also verify **Authentication → Providers → Email → Allow new users to sign up** is disabled; this hosted Auth setting is not a database migration and has not been applied from this repository.

Invitations and user creation must run through a trusted server/Edge Function or an operator-only Supabase admin workflow. The browser must never receive a service-role key or call `auth.admin.*`. The workflow is:

1. An authorized operator invokes the trusted admin pathway.
2. The pathway verifies MFA/session freshness and `users.manage` in the target company (or the private platform-admin registry for explicit cross-company administration).
3. It creates/invites the Auth identity. `on_auth_user_created` creates `public.profiles` in the same transaction.
4. It creates the company membership with server-derived `created_by`/`updated_by`.
5. It reports invite delivery separately from database provisioning. A failed Auth/profile transaction creates neither identity nor profile; a failed membership step is an explicit `INVITED_UNASSIGNED` operational error to retry, not a silently usable account.
6. P7 adds immutable audit events to this trusted pathway before production use.

Until that trusted endpoint is implemented, provisioning is an operator task using protected Supabase administration plus reviewed SQL for the membership. It is not a browser feature.

## Authorization rules

- `auth.users` is the authentication identity; `profiles` contains no secrets.
- Both an `ACTIVE` profile and an `ACTIVE` membership in an `ACTIVE` company are required for company access.
- `SYSTEM_ADMIN` in a company membership grants only `company.manage` and `users.manage` for that company. It neither grants accounting operations nor creates a browser-wide RLS bypass.
- Cross-company platform administration uses `private.system_administrators` through a trusted server/service pathway. Browser roles have no schema/table privileges on it.
- Membership/role/status and permission mappings have no browser write grants or write policies.
- A duplicate active `(company_id, user_id)` membership is rejected by a partial unique index. Historical inactive memberships remain intact.
- Project Manager project assignments are deferred to P3 because no production project parent exists in P2. P3 must add an FK-backed project-access table and make project policies require the active membership plus assignment.

## Remote Development test matrix

Run only against a linked Development project with synthetic users and companies. Do not run against Production.

| Test | Expected result | Repository status |
|---|---|---|
| Admin invite/create | Admin API succeeds; public signup remains rejected | DEFERRED — no Development project linked |
| Profile creation | Auth insert atomically creates one profile | DEFERRED |
| Active membership | Member sees own membership and company | DEFERRED |
| Tenant isolation | Member cannot select another company | DEFERRED |
| Self elevation | Membership INSERT/UPDATE/DELETE is denied | DEFERRED |
| Inactive membership | `is_company_member` and `has_permission` become false | DEFERRED |
| Inactive profile | All company helpers become false | DEFERRED |
| Certificate permission | True only for active `ACCOUNTING_ADMIN` membership | DEFERRED |
| Anonymous access | No profile/company/membership/permission data and no helper execution | DEFERRED |

For the permission test, explicitly prove `ACCOUNTANT` is false for `certificate.approve_post`. Test duplicate active membership rejection and inactive-company denial as additional defense-in-depth cases.

## Frontend boundary

P2 does not add a login shell. There is no verified remote backend, and gating the current localStorage accounting demo behind Supabase Auth would misleadingly associate browser-local demo books with a production company. The current adapter and locale persistence remain unchanged. Frontend Auth/session/login/logout/invite completion and profile-locale synchronization should be introduced with the async Supabase application boundary in P6 (or earlier once a Development backend and clear hybrid-mode UX exist).
