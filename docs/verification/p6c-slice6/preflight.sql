-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
begin transaction read only;
select version from supabase_migrations.schema_migrations order by version;
select column_name, data_type, udt_name, is_nullable, column_default
from information_schema.columns where table_schema='public' and table_name='parties' order by ordinal_position;
select polname, polpermissive, polcmd, pg_get_expr(polqual,polrelid) as using_expression,
 pg_get_expr(polwithcheck,polrelid) as check_expression
from pg_policy where polrelid='public.parties'::regclass;
select attname, has_column_privilege('authenticated','public.parties',attname,'INSERT') as can_insert,
 has_column_privilege('authenticated','public.parties',attname,'UPDATE') as can_update
from pg_attribute where attrelid='public.parties'::regclass and attnum>0 and not attisdropped;
select r.rolname, has_table_privilege(r.oid,'public.parties','SELECT') as can_select,
 has_table_privilege(r.oid,'public.parties','INSERT') as broad_insert,
 has_table_privilege(r.oid,'public.parties','UPDATE') as broad_update,
 has_table_privilege(r.oid,'public.parties','DELETE') as can_delete,
 has_table_privilege(r.oid,'public.parties','TRUNCATE') as can_truncate
from pg_roles r where rolname in ('authenticated','anon','service_role');
select relrowsecurity,relforcerowsecurity from pg_class where oid='public.parties'::regclass;
select tgname, pg_get_triggerdef(t.oid), p.prosecdef,p.proconfig,p.proacl,pg_get_functiondef(p.oid)
from pg_trigger t join pg_proc p on p.oid=t.tgfoid where tgrelid='public.parties'::regclass and not tgisinternal;
select pg_get_functiondef('public.set_updated_at()'::regprocedure);
select conname,conrelid::regclass,pg_get_constraintdef(oid) from pg_constraint
where conrelid='public.parties'::regclass or confrelid='public.parties'::regclass;
select indexdef from pg_indexes where schemaname='public' and tablename='parties';
select role,permission_key from public.role_permissions where permission_key='party.manage' order by role;
select count(*) as companies,(select count(*) from public.company_settings) as settings,
 count(*) filter(where not exists(select 1 from public.company_settings s where s.company_id=c.id)) as missing_settings
from public.companies c;
rollback;
