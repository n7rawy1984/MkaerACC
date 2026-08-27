-- P5A corrective migration: remove provider default TRUNCATE/TRIGGER/REFERENCES
-- privileges from immutable journal tables, then restore read-only access.

revoke all on table public.journal_entries, public.journal_lines from service_role;
grant select on table public.journal_entries, public.journal_lines to service_role;
