-- Read-only Development verification. No fixtures or financial command execution.
begin read only;
select jsonb_build_object(
 'columns',(select jsonb_agg(jsonb_build_object('name',attname,'type',format_type(atttypid,atttypmod))) from pg_attribute where attrelid='public.expenses'::regclass and attnum>0 and not attisdropped),
 'rls',(select jsonb_build_object('enabled',relrowsecurity,'forced',relforcerowsecurity) from pg_class where oid='public.expenses'::regclass),
 'policies',(select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname='public' and tablename='expenses'),
 'grants',(select jsonb_agg(jsonb_build_object('role',r,'select',has_table_privilege(r,'public.expenses','SELECT'),'write',has_table_privilege(r,'public.expenses','INSERT,UPDATE,DELETE,TRUNCATE'))) from unnest(array['anon','authenticated','service_role']) r),
 'precision',(select bool_and(jsonb_typeof(to_jsonb(net_amount_minor::text))='string' and jsonb_typeof(to_jsonb(vat_amount_minor::text))='string' and jsonb_typeof(to_jsonb(gross_amount_minor::text))='string') from public.expenses),
 'counts',(select jsonb_object_agg(status,n) from (select status,count(*) n from public.expenses group by status) s),
 'companies',(select count(*) from public.companies),'settings',(select count(*) from public.company_settings),
 'missing',(select count(*) from public.companies c left join public.company_settings s on s.company_id=c.id where s.company_id is null),
 'orphan',(select count(*) from public.company_settings s left join public.companies c on c.id=s.company_id where c.id is null)
) contract;
commit;
