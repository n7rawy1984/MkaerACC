-- Development-only rollback verification. No durable fixtures or schema changes.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260916140000') then raise exception 'Slice 8 migration required'; end if;
end $$;
create temporary table slice8_results(label text, passed boolean);
grant select,insert on pg_temp.slice8_results to authenticated,anon,service_role;
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
 begin execute statement; get diagnostics actual_rows=row_count;
 exception when others then get stacked diagnostics actual_state=returned_sqlstate; end;
 if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
  raise exception 'FAIL %: state %, rows % (expected %, %)',label,actual_state,actual_rows,expected_state,expected_rows;
 end if;
 insert into pg_temp.slice8_results values(label,true);
end $$;
create function pg_temp.assert_true(label text, passed boolean) returns void language plpgsql as $$
begin if passed is distinct from true then raise exception 'FAIL %',label; end if;
 insert into pg_temp.slice8_results values(label,true); end $$;

-- Reuse an existing synthetic actor; never create/delete an Auth user.
do $$ begin
 if not exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id where u.id='7cf0bfff-6938-4beb-a0ff-0ed726867304' and u.email='maker-p2v-accountant_a-1787848792973-68f666@example.invalid' and p.status='ACTIVE') then raise exception 'Existing synthetic actor unavailable'; end if;
end $$;
insert into public.companies(id,code,name) values ('78000000-0000-4000-8000-0000000000a1','P6C-S8-ROLLBACK-A','S8 rollback A'),('78000000-0000-4000-8000-0000000000a2','P6C-S8-ROLLBACK-B','S8 rollback B');
insert into public.company_memberships(company_id,user_id,role) values ('78000000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN');
insert into public.projects(id,company_id,code,name,status,original_contract_value_minor,budget_minor,created_at,updated_at,created_by) values
 ('78000000-0000-4000-8000-0000000000b1','78000000-0000-4000-8000-0000000000a1','P1','Original','CLOSED',9007199254740993,9007199254740993,'2000-01-01','2099-01-01','7cf0bfff-6938-4beb-a0ff-0ed726867304'),
 ('78000000-0000-4000-8000-0000000000b2','78000000-0000-4000-8000-0000000000a1','P2','Unassigned','ACTIVE',null,null,'2000-01-01','2000-01-01',null),
 ('78000000-0000-4000-8000-0000000000b3','78000000-0000-4000-8000-0000000000a2','P3','Other tenant','PLANNING',null,null,'2000-01-01','2000-01-01',null);
insert into public.project_assignments(company_id,project_id,user_id) values ('78000000-0000-4000-8000-0000000000a1','78000000-0000-4000-8000-0000000000b1','7cf0bfff-6938-4beb-a0ff-0ed726867304');
select pg_temp.assert_true('forced RLS',(select relrowsecurity and relforcerowsecurity from pg_class where oid='public.projects'::regclass));
select pg_temp.assert_true('fixed invoker search_path',(select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.prepare_project_metadata_update()'::regprocedure));
select pg_temp.assert_true('update RLS retained',(select qual=with_check and qual like '%ACCOUNTING_ADMIN%' and qual like '%PROJECT_MANAGER%' and qual like '%has_active_project_assignment%' from pg_policies where schemaname='public' and tablename='projects' and policyname='projects_update_authorized'));
select pg_temp.assert_true('only local timestamp replaced',(select count(*)=2 from pg_trigger where tgrelid='public.projects'::regclass and not tgisinternal));
select pg_temp.assert_true('no broad writes',not has_table_privilege('authenticated','public.projects','INSERT,UPDATE,DELETE,TRUNCATE'));
do $$ declare c record; begin
 for c in select attname from pg_attribute where attrelid='public.projects'::regclass and attnum>0 and not attisdropped loop
 perform pg_temp.assert_true(c.attname||' update grant',has_column_privilege('authenticated','public.projects',c.attname,'UPDATE')=(c.attname=any(array['name','client_name','location','contract_number','notes'])));
 perform pg_temp.assert_true(c.attname||' insert denied',not has_column_privilege('authenticated','public.projects',c.attname,'INSERT'));
 end loop;
end $$;
select pg_temp.assert_true('authenticated no trigger execute',not has_function_privilege('authenticated','public.prepare_project_metadata_update()','EXECUTE'));
select pg_temp.assert_true('anon no trigger execute',not has_function_privilege('anon','public.prepare_project_metadata_update()','EXECUTE'));
select pg_temp.assert_true('service_role no trigger execute',not has_function_privilege('service_role','public.prepare_project_metadata_update()','EXECUTE'));
select set_config('request.jwt.claim.sub','7cf0bfff-6938-4beb-a0ff-0ed726867304',true);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('ACCOUNTING_ADMIN assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROJECT_MANAGER' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('PROJECT_MANAGER unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTANT' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROCUREMENT' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROCUREMENT assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='DATA_ENTRY' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='MANAGEMENT_VIEWER' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='SYSTEM_ADMIN' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN assigned metadata',$q$update public.projects set name='  مشروع  Mixed ',client_name=' ',location=' Site ',contract_number=' 0001 ',notes=E' A\n  B ' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN unassigned',$q$update public.projects set notes='test' where id='78000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN other tenant',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN other tenant read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('protected id',$q$update public.projects set id=id where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected company_id',$q$update public.projects set company_id=company_id where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected code',$q$update public.projects set code=code where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected status',$q$update public.projects set status=status where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected original_contract_value_minor',$q$update public.projects set original_contract_value_minor=original_contract_value_minor where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected budget_minor',$q$update public.projects set budget_minor=budget_minor where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected start_date',$q$update public.projects set start_date=start_date where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected expected_completion_date',$q$update public.projects set expected_completion_date=expected_completion_date where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_by',$q$update public.projects set created_by=created_by where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_by',$q$update public.projects set updated_by=updated_by where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_at',$q$update public.projects set created_at=created_at where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_at',$q$update public.projects set updated_at=updated_at where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('insert denied',$q$insert into public.projects(company_id,code,name) values ('78000000-0000-4000-8000-0000000000a1','NO','Denied')$q$,'42501');
select pg_temp.check_sql('delete denied',$q$delete from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('truncate denied',$q$truncate public.projects$q$,'42501');

select pg_temp.check_sql('empty name',$q$update public.projects set name=chr(65279)||' ' where id='78000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('long name',$q$update public.projects set name=repeat('名',201) where id='78000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('null name',$q$update public.projects set name=null where id='78000000-0000-4000-8000-0000000000b1'$q$,'23502');
do $$ declare c public.projects; token timestamptz; begin
 select * into strict c from public.projects where id='78000000-0000-4000-8000-0000000000b1';
 perform pg_temp.assert_true('normalized metadata',c.name='مشروع  Mixed' and c.client_name is null and c.location='Site' and c.contract_number='0001' and c.notes=E'A\n  B');
 perform pg_temp.assert_true('actor/creation',c.updated_by=auth.uid() and c.created_by=auth.uid() and c.created_at='2000-01-01'::timestamptz);
 perform pg_temp.assert_true('financial/status unchanged',c.status='CLOSED' and c.original_contract_value_minor=9007199254740993 and c.budget_minor=9007199254740993 and c.code='P1');
 token:=c.updated_at;
 update public.projects set notes=notes where id=c.id and updated_at=token returning * into c;
 perform pg_temp.assert_true('future no-op monotonic',c.updated_at>token and c.updated_at>'2099-01-01'::timestamptz);
 perform pg_temp.check_sql('stale token',format('update public.projects set notes=''stale'' where id=%L and updated_at=%L',c.id,token),null,0);
 update public.projects set name=repeat('😀',200),client_name=chr(65279)||chr(8195),location='',contract_number=chr(160),notes=repeat('名',10001) where id=c.id returning * into c;
 perform pg_temp.assert_true('Unicode and optional bounds',length(c.name)=200 and c.client_name is null and c.location is null and c.contract_number is null and length(c.notes)=10001);
end $$;
reset role;
update public.company_memberships set role='PROJECT_MANAGER' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
update public.project_assignments set status='INACTIVE' where company_id='78000000-0000-4000-8000-0000000000a1' and project_id='78000000-0000-4000-8000-0000000000b1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
set local role authenticated;
select pg_temp.check_sql('revoked assignment write',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('revoked assignment read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role;
update public.project_assignments set status='ACTIVE' where company_id='78000000-0000-4000-8000-0000000000a1' and project_id='78000000-0000-4000-8000-0000000000b1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.profiles set status='INACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive profiles write',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive profiles read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.profiles set status='ACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.company_memberships set status='INACTIVE' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive company_memberships write',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive company_memberships read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.company_memberships set status='ACTIVE' where company_id='78000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.companies set status='INACTIVE' where id='78000000-0000-4000-8000-0000000000a1'; set local role authenticated;
select pg_temp.check_sql('inactive companies write',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive companies read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.companies set status='ACTIVE' where id='78000000-0000-4000-8000-0000000000a1';

set local role anon;
select pg_temp.check_sql('anon update',$q$update public.projects set notes='denied' where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('anon read',$q$select id from public.projects where id='78000000-0000-4000-8000-0000000000b1'$q$,'42501');
reset role; set local role service_role;
update public.projects set updated_by=null,notes=' trusted ' where id='78000000-0000-4000-8000-0000000000b1';
select pg_temp.assert_true('trusted actor retained',(select updated_by is null and notes='trusted' from public.projects where id='78000000-0000-4000-8000-0000000000b1'));
select pg_temp.check_sql('creation time immutable',$q$update public.projects set created_at='2001-01-01' where id='78000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('creation actor immutable',$q$update public.projects set created_by=null where id='78000000-0000-4000-8000-0000000000b1'$q$,'23514');
insert into public.projects(company_id,code,name,created_at,updated_at) values ('78000000-0000-4000-8000-0000000000a1','TRUSTED','Trusted','1999-01-01','1999-01-02');
select pg_temp.assert_true('trusted provisioning retained',(select created_at='1999-01-01'::timestamptz and updated_at='1999-01-02'::timestamptz from public.projects where company_id='78000000-0000-4000-8000-0000000000a1' and code='TRUSTED'));
reset role;
select count(*) as passed,count(*) filter(where not passed) as failed from slice8_results;
rollback;
