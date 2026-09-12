begin read only;
do $verify$
declare r record; n bigint;
begin
  for r in select n.nspname as schema_name,c.relname as table_name from pg_class c
    join pg_namespace n on n.oid=c.relnamespace
    where n.nspname in ('public','private') and c.relkind='r'
      and exists (select 1 from pg_attribute x where x.attrelid=c.oid and x.attname='company_id' and not x.attisdropped)
      and not (n.nspname='public' and c.relname in ('company_settings','company_memberships','projects','project_assignments','parties','expense_categories'))
  loop
    execute format('select count(*) from %I.%I where company_id in ($1,$2)',r.schema_name,r.table_name) into n using '72000000-0000-4000-8000-0000000000a1'::uuid,'72000000-0000-4000-8000-0000000000a2'::uuid;
    if n <> 0 then raise exception 'Unexpected non-fixture rows in %.%',r.schema_name,r.table_name; end if;
  end loop;
end;
$verify$;
select jsonb_build_object(
 'orphan_fixture_rows',(select count(*) from (select x.company_id from public.company_settings x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.company_memberships x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.projects x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.project_assignments x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.parties x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.expense_categories x left join public.companies c on c.id=x.company_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and c.id is null union all select x.company_id from public.project_assignments x left join public.projects p on p.company_id=x.company_id and p.id=x.project_id left join public.profiles u on u.user_id=x.user_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and (p.id is null or u.user_id is null) union all select x.company_id from public.company_memberships x left join public.profiles p on p.user_id=x.user_id where x.company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2') and p.user_id is null) orphan_rows),
 'profile',(select count(*) from public.profiles where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and email_snapshot='p6c-slice2-user@example.test'),
 'companies',(select count(*) from public.companies where id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')),
 'memberships',(select count(*) from public.company_memberships where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')),
 'settings',(select count(*) from public.company_settings where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')),
 'alpha_projects',(select count(*) from public.projects where company_id='72000000-0000-4000-8000-0000000000a1'),
 'beta_projects',(select count(*) from public.projects where company_id='72000000-0000-4000-8000-0000000000a2'),
 'assignments',(select count(*) from public.project_assignments where company_id in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')),
 'alpha_parties',(select count(*) from public.parties where company_id='72000000-0000-4000-8000-0000000000a1'),
 'beta_parties',(select count(*) from public.parties where company_id='72000000-0000-4000-8000-0000000000a2'),
 'alpha_categories',(select count(*) from public.expense_categories where company_id='72000000-0000-4000-8000-0000000000a1'),
 'beta_categories',(select count(*) from public.expense_categories where company_id='72000000-0000-4000-8000-0000000000a2'),
 'unrelated_user_memberships',(select count(*) from public.company_memberships where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and company_id not in ('72000000-0000-4000-8000-0000000000a1','72000000-0000-4000-8000-0000000000a2')),
 'unrelated_user_assignments',(select count(*) from public.project_assignments where user_id='74e36291-172a-44e7-95be-f6c1283c315b' and (company_id<>'72000000-0000-4000-8000-0000000000a1' or project_id<>'72000000-0000-4000-8000-0000000000c1')),
 'global_companies',(select count(*) from public.companies),
 'global_settings',(select count(*) from public.company_settings),
 'missing_or_orphan_settings',(select count(*) from public.companies c full join public.company_settings s on s.company_id=c.id where c.id is null or s.company_id is null),
 'financial_and_other_out_of_scope_company_rows',0,
 'party_details',(select jsonb_agg(jsonb_build_object('id',id,'type',type,'code',code,'status',status,'trn',trn,'contact_person',contact_person) order by id) from public.parties where company_id='72000000-0000-4000-8000-0000000000a1'),
 'category_details',(select jsonb_agg(jsonb_build_object('id',id,'code',code,'status',status,'description',description) order by id) from public.expense_categories where company_id='72000000-0000-4000-8000-0000000000a1'),
 'leading_zero_trn',(select trn from public.parties where id='72000000-0000-4000-8000-0000000000e4'),
 'initial_roles',(select jsonb_agg(jsonb_build_object('company_id',company_id,'role',role,'status',status)) from public.company_memberships where user_id='74e36291-172a-44e7-95be-f6c1283c315b')
) as fixture_counts;
rollback;
