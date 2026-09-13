-- Read-only final catalog and fixture verification; Development only.
begin transaction read only;
select a.attname as column_name,
 has_column_privilege('authenticated','public.expense_categories',a.attname,'INSERT') as can_insert,
 has_column_privilege('authenticated','public.expense_categories',a.attname,'UPDATE') as can_update
from pg_attribute a where attrelid='public.expense_categories'::regclass and attnum>0 and not attisdropped order by attnum;
select pg_get_triggerdef(oid) as trigger_definition from pg_trigger where tgrelid='public.expense_categories'::regclass and not tgisinternal;
select pg_get_functiondef('public.set_updated_at()'::regprocedure) as unchanged_shared_timestamp_function;
select column_name,column_default from information_schema.columns where table_schema='public' and table_name='expense_categories' and column_name in ('id','status');
select policyname,cmd,qual,with_check from pg_policies where schemaname='public' and tablename='expense_categories';
select
 (select count(*) from public.companies where id in ('75000000-0000-4000-8000-0000000000a1','75000000-0000-4000-8000-0000000000a2','75100000-0000-4000-8000-0000000000a1','75200000-0000-4000-8000-0000000000a1','75200000-0000-4000-8000-0000000000a2')) as slice5_companies,
 (select count(*) from public.expense_categories where company_id in ('75000000-0000-4000-8000-0000000000a1','75000000-0000-4000-8000-0000000000a2','75100000-0000-4000-8000-0000000000a1','75200000-0000-4000-8000-0000000000a1','75200000-0000-4000-8000-0000000000a2')) as slice5_categories,
 (select count(*) from auth.users where id in ('75000000-0000-4000-8000-000000000001','75100000-0000-4000-8000-000000000001','75300000-0000-4000-8000-000000000001') or email='p6c-slice5-user@example.test') as slice5_auth,
 (select count(*) from public.companies) as companies,
 (select count(*) from public.company_settings) as settings,
 (select count(*) from public.companies c left join public.company_settings s on c.id=s.company_id where s.company_id is null) as missing_settings,
 (select count(*) from public.company_settings s left join public.companies c on c.id=s.company_id where c.id is null) as orphan_settings;
rollback;
