begin read only;
select jsonb_build_object(
 'columns',(select jsonb_agg(jsonb_build_object('name',column_name,'type',data_type,'nullable',is_nullable)) from information_schema.columns where table_schema='public' and table_name='accounts'),
 'rls',(select jsonb_build_object('enabled',relrowsecurity,'forced',relforcerowsecurity) from pg_class where oid='public.accounts'::regclass),
 'policies',(select jsonb_agg(to_jsonb(p)) from pg_policies p where schemaname='public' and tablename='accounts'),
 'grants',(select jsonb_agg(to_jsonb(p)) from information_schema.role_table_grants p where table_schema='public' and table_name='accounts'),
 'column_grants',(select jsonb_agg(to_jsonb(p)) from information_schema.column_privileges p where table_schema='public' and table_name='accounts' and grantee='authenticated'),
 'triggers',(select jsonb_agg(pg_get_triggerdef(oid)) from pg_trigger where tgrelid='public.accounts'::regclass and not tgisinternal),
 'indexes',(select jsonb_agg(indexdef) from pg_indexes where schemaname='public' and tablename='accounts'),
 'constraints',(select jsonb_agg(pg_get_constraintdef(oid)) from pg_constraint where conrelid='public.accounts'::regclass),
 'permissions',(select jsonb_agg(to_jsonb(p)) from public.role_permissions p where permission_key='account.manage'),
 'settings_integrity',(select jsonb_build_object('companies',(select count(*) from public.companies),'settings',(select count(*) from public.company_settings),'missing',(select count(*) from public.companies c left join public.company_settings s on s.company_id=c.id where s.company_id is null),'orphan',(select count(*) from public.company_settings s left join public.companies c on c.id=s.company_id where c.id is null)))
) as preflight;
commit;
