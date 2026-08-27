# P2 Auth and Authorization Operations

## Provisioning and invitations

Public signup is disabled in `supabase/config.toml` for the local configuration. On 2026-08-27 the linked `MakerACC-Development` hosted project was also verified with **Allow new users to sign up** and anonymous sign-ins disabled. Its Development Site URL is `https://maker-eosin.vercel.app`; allowed redirects are that URL plus `http://localhost:5173` and `http://127.0.0.1:5173`.

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

Executed successfully on 2026-08-27 against the linked Development project only, using nine synthetic `example.invalid` Auth identities and two synthetic companies. The initial privilege-diagnostic run created nine additional profile-only synthetic identities before tenant provisioning failed; their profiles were explicitly set `INACTIVE` after the correction, preserving Auth history without tenant access. No real company/accounting data, Staging, or Production environment was used.

| Test | Expected result | Repository status |
|---|---|---|
| Admin create and public-signup denial | Nine Admin API creates succeeded; public signup rejected HTTP 422 | PASS |
| Profile creation/defaults | 9/9 profiles matched Auth UUID, `ACTIVE` status and requested/default locale | PASS |
| Own-profile boundary | Each token read exactly its own profile; security-field update rejected HTTP 403 | PASS |
| Active membership | Company A member saw Company A | PASS |
| Tenant isolation / UUID guessing | Company A member received zero Company B rows | PASS |
| Self membership / role elevation | INSERT and role UPDATE rejected HTTP 403 | PASS |
| Duplicate active membership | Database rejected duplicate with HTTP 409 | PASS |
| Inactive membership | Company visibility removed and `is_company_member` returned false | PASS |
| Inactive profile | Company visibility removed and `is_active_user` returned false | PASS |
| Certificate permission | True only for active `ACCOUNTING_ADMIN`; false for all six other frozen roles | PASS |
| System Admin boundary | Saw only its member company, had configuration permission, no certificate permission | PASS |
| Anonymous access | Profile/company/membership/helper requests rejected HTTP 401 | PASS |

The deployed migration history is `20260826193204`, `20260827120000`, `20260828120000`, and `20260828123000`. A final linked dry-run reported the remote database up to date; database lint reported no schema errors. The last two migrations correct trusted `service_role` provisioning privileges and remove browser EXECUTE from the provider-created `rls_auto_enable()` event-trigger helper.

Security advisors retain expected warnings because the four authorization helpers are intentionally authenticated-callable `SECURITY DEFINER` functions with fixed empty search paths and `auth.uid()`-derived identity. Leaked-password protection is disabled in Development; it is recommended provider hardening, but was not a frozen P2 exit requirement.

## Frontend boundary

P2 does not add a login shell. Although the Development identity backend is now verified, gating the current localStorage accounting demo behind Supabase Auth would misleadingly associate browser-local demo books with a production company. The current adapter and locale persistence remain unchanged. Frontend Auth/session/login/logout/invite completion and profile-locale synchronization should be introduced with the async Supabase application boundary in P6 (or earlier only with a clearly designed hybrid-mode UX).
