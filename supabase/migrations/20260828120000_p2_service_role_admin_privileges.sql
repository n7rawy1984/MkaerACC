-- P2V corrective migration: allow the trusted service-role administration
-- pathway designed in P2 to provision tenant identity records.
--
-- The original P2 migration intentionally denied all browser writes, but the
-- new-project Data API defaults also left service_role without table grants.
-- RLS bypass alone does not supply SQL privileges, so trusted provisioning
-- received permission denied. These grants remain server-only; service_role
-- credentials are never exposed to browser code.

grant select, insert, update on table public.profiles to service_role;
grant select, insert, update on table public.companies to service_role;
grant select, insert, update on table public.company_memberships to service_role;
grant select on table public.permissions to service_role;
grant select on table public.role_permissions to service_role;

grant usage on schema private to service_role;
grant select, insert, update on table private.system_administrators to service_role;

revoke delete on table public.profiles from service_role;
revoke delete on table public.companies from service_role;
revoke delete on table public.company_memberships from service_role;
revoke insert, update, delete on table public.permissions from service_role;
revoke insert, update, delete on table public.role_permissions from service_role;
revoke delete on table private.system_administrators from service_role;

comment on table private.system_administrators is
  'Trusted service-only platform administrator registry. Browser roles have no schema access; deletion is withheld to preserve history.';
