-- Development-only rollback verification. No durable fixtures or schema changes.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260921120000') then raise exception 'Slice 10 migration required'; end if;
end $$;
create temporary table slice10_results(label text, passed boolean);
grant select,insert on pg_temp.slice10_results to authenticated,anon,service_role;
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null)
returns void language plpgsql as $$
declare actual_rows integer; actual_state text;
begin
 begin execute statement; get diagnostics actual_rows=row_count;
 exception when others then get stacked diagnostics actual_state=returned_sqlstate; end;
 if actual_state is distinct from expected_state or (expected_rows is not null and actual_rows is distinct from expected_rows) then
  raise exception 'FAIL %: state %, rows % (expected %, %)',label,actual_state,actual_rows,expected_state,expected_rows;
 end if;
 insert into pg_temp.slice10_results values(label,true);
end $$;
create function pg_temp.assert_true(label text, passed boolean) returns void language plpgsql as $$
begin if passed is distinct from true then raise exception 'FAIL %',label; end if;
 insert into pg_temp.slice10_results values(label,true); end $$;

-- Reuse an existing synthetic actor; never create/delete an Auth user.
do $$ begin
 if not exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id where u.id='7cf0bfff-6938-4beb-a0ff-0ed726867304' and u.email='maker-p2v-accountant_a-1787848792973-68f666@example.invalid' and p.status='ACTIVE') then raise exception 'Existing synthetic actor unavailable'; end if;
end $$;
insert into public.companies(id,code,name) values ('80000000-0000-4000-8000-0000000000a1','P6C-S10-ROLLBACK-A','S10 rollback A'),('80000000-0000-4000-8000-0000000000a2','P6C-S10-ROLLBACK-B','S10 rollback B');
insert into public.company_memberships(company_id,user_id,role) values ('80000000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN');
insert into public.accounts(id,company_id,code,name,account_type) values
 ('80000000-0000-4000-8000-0000000000d1','80000000-0000-4000-8000-0000000000a1','GL1','GL1','ASSET'),
 ('80000000-0000-4000-8000-0000000000d2','80000000-0000-4000-8000-0000000000a1','GL2','GL2','ASSET'),
 ('80000000-0000-4000-8000-0000000000d3','80000000-0000-4000-8000-0000000000a2','GL3','GL3','ASSET'),
 ('80000000-0000-4000-8000-0000000000d4','80000000-0000-4000-8000-0000000000a1','GL4','GL4','ASSET');
insert into public.projects(id,company_id,code,name) values ('80000000-0000-4000-8000-0000000000c1','80000000-0000-4000-8000-0000000000a1','P1','Assigned project');
insert into public.project_assignments(company_id,project_id,user_id) values ('80000000-0000-4000-8000-0000000000a1','80000000-0000-4000-8000-0000000000c1','7cf0bfff-6938-4beb-a0ff-0ed726867304');
insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id,project_id,status,bank_name,account_reference,notes,created_at,updated_at,created_by) values
 ('80000000-0000-4000-8000-0000000000b1','80000000-0000-4000-8000-0000000000a1','0001','Original','BANK','80000000-0000-4000-8000-0000000000d1',null,'INACTIVE','Bank','000123','Notes','2000-01-01','2099-01-01','7cf0bfff-6938-4beb-a0ff-0ed726867304'),
 ('80000000-0000-4000-8000-0000000000b2','80000000-0000-4000-8000-0000000000a1','0002','Project cash','CASH','80000000-0000-4000-8000-0000000000d2','80000000-0000-4000-8000-0000000000c1','ACTIVE',null,null,null,'2000-01-01','2000-01-01',null),
 ('80000000-0000-4000-8000-0000000000b3','80000000-0000-4000-8000-0000000000a2','0003','Beta','BANK','80000000-0000-4000-8000-0000000000d3',null,'ACTIVE',null,null,null,'2000-01-01','2000-01-01',null);
select pg_temp.assert_true('forced RLS',(select relrowsecurity and relforcerowsecurity from pg_class where oid='public.treasury_accounts'::regclass));
select pg_temp.assert_true('fixed invoker search_path',(select not prosecdef and proconfig=array['search_path=""'] from pg_proc where oid='public.prepare_treasury_display_name_update()'::regprocedure));
select pg_temp.assert_true('update RLS retained',(select qual=with_check and qual like '%treasury.manage%' from pg_policies where schemaname='public' and tablename='treasury_accounts' and policyname='treasury_update_admin'));
select pg_temp.assert_true('only local timestamp replaced',(select count(*)=2 from pg_trigger where tgrelid='public.treasury_accounts'::regclass and not tgisinternal));
select pg_temp.assert_true('no broad writes',not has_table_privilege('authenticated','public.treasury_accounts','INSERT,UPDATE,DELETE,TRUNCATE'));
do $$ declare c record; begin
 for c in select attname from pg_attribute where attrelid='public.treasury_accounts'::regclass and attnum>0 and not attisdropped loop
 perform pg_temp.assert_true(c.attname||' update grant',has_column_privilege('authenticated','public.treasury_accounts',c.attname,'UPDATE')=(c.attname=any(array['name'])));
 perform pg_temp.assert_true(c.attname||' insert denied',not has_column_privilege('authenticated','public.treasury_accounts',c.attname,'INSERT'));
 end loop;
end $$;
select pg_temp.assert_true('authenticated no trigger execute',not has_function_privilege('authenticated','public.prepare_treasury_display_name_update()','EXECUTE'));
select pg_temp.assert_true('anon no trigger execute',not has_function_privilege('anon','public.prepare_treasury_display_name_update()','EXECUTE'));
select pg_temp.assert_true('service_role no trigger execute',not has_function_privilege('service_role','public.prepare_treasury_display_name_update()','EXECUTE'));
select set_config('request.jwt.claim.sub','7cf0bfff-6938-4beb-a0ff-0ed726867304',true);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('ACCOUNTING_ADMIN inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('ACCOUNTING_ADMIN other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTING_ADMIN other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROJECT_MANAGER' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROJECT_MANAGER inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROJECT_MANAGER other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PM assigned Treasury visible',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b2'$q$,null,1);
select pg_temp.check_sql('PM company Treasury hidden',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PM GL hidden',$q$select id from public.accounts where id='80000000-0000-4000-8000-0000000000d2'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTANT' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('ACCOUNTANT inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('ACCOUNTANT other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='PROCUREMENT' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('PROCUREMENT inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('PROCUREMENT other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='DATA_ENTRY' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('DATA_ENTRY inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('DATA_ENTRY other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='MANAGEMENT_VIEWER' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('MANAGEMENT_VIEWER inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('MANAGEMENT_VIEWER other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='SYSTEM_ADMIN' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('SYSTEM_ADMIN inactive name',$q$update public.treasury_accounts set name=chr(65279)||'  حساب  Mixed ' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN project cash',$q$update public.treasury_accounts set name='test' where id='80000000-0000-4000-8000-0000000000b2'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN other tenant',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
select pg_temp.check_sql('SYSTEM_ADMIN other tenant read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b3'$q$,null,0);
reset role; update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('protected id',$q$update public.treasury_accounts set id=id where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected company_id',$q$update public.treasury_accounts set company_id=company_id where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected project_id',$q$update public.treasury_accounts set project_id=project_id where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected code',$q$update public.treasury_accounts set code=code where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected type',$q$update public.treasury_accounts set type=type where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected gl_account_id',$q$update public.treasury_accounts set gl_account_id=gl_account_id where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected status',$q$update public.treasury_accounts set status=status where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected bank_name',$q$update public.treasury_accounts set bank_name=bank_name where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected account_reference',$q$update public.treasury_accounts set account_reference=account_reference where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected notes',$q$update public.treasury_accounts set notes=notes where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_at',$q$update public.treasury_accounts set created_at=created_at where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected created_by',$q$update public.treasury_accounts set created_by=created_by where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_at',$q$update public.treasury_accounts set updated_at=updated_at where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('protected updated_by',$q$update public.treasury_accounts set updated_by=updated_by where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('insert denied',$q$insert into public.treasury_accounts(company_id,code,name,type,gl_account_id) values ('80000000-0000-4000-8000-0000000000a1','NO','Denied','CASH','80000000-0000-4000-8000-0000000000d4')$q$,'42501');
select pg_temp.check_sql('delete denied',$q$delete from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('truncate denied',$q$truncate public.treasury_accounts$q$,'42501');

select pg_temp.check_sql('empty name',$q$update public.treasury_accounts set name=chr(65279)||' ' where id='80000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('long name',$q$update public.treasury_accounts set name=repeat('名',201) where id='80000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('null name',$q$update public.treasury_accounts set name=null where id='80000000-0000-4000-8000-0000000000b1'$q$,'23502');
do $$ declare c public.treasury_accounts; token timestamptz; begin
 select * into strict c from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1';
 perform pg_temp.assert_true('normalized name',c.name='حساب  Mixed');
 perform pg_temp.assert_true('actor/creation',c.updated_by=auth.uid() and c.created_by=auth.uid() and c.created_at='2000-01-01'::timestamptz);
 perform pg_temp.assert_true('configuration unchanged',c.status='INACTIVE' and c.code='0001' and c.type='BANK' and c.gl_account_id='80000000-0000-4000-8000-0000000000d1' and c.project_id is null and c.bank_name='Bank' and c.account_reference='000123' and c.notes='Notes');
 perform pg_temp.assert_true('Project scope retained',(select project_id='80000000-0000-4000-8000-0000000000c1' from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b2'));
 token:=c.updated_at;
 update public.treasury_accounts set name=name where id=c.id and updated_at=token returning * into c;
 perform pg_temp.assert_true('future no-op monotonic',c.updated_at>token and c.updated_at>'2099-01-01'::timestamptz);
 perform pg_temp.check_sql('stale token',format('update public.treasury_accounts set name=''stale'' where id=%L and updated_at=%L',c.id,token),null,0);
 update public.treasury_accounts set name=repeat('😀',200) where id=c.id returning * into c;
 perform pg_temp.assert_true('Unicode bounds',length(c.name)=200);
end $$;
reset role; update public.profiles set status='INACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive profiles write',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive profiles read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.profiles set status='ACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.company_memberships set status='INACTIVE' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive company_memberships write',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive company_memberships read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.company_memberships set status='ACTIVE' where company_id='80000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
reset role; update public.companies set status='INACTIVE' where id='80000000-0000-4000-8000-0000000000a1'; set local role authenticated;
select pg_temp.check_sql('inactive companies write',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
select pg_temp.check_sql('inactive companies read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,null,0);
reset role; update public.companies set status='ACTIVE' where id='80000000-0000-4000-8000-0000000000a1';

set local role anon;
select pg_temp.check_sql('anon update',$q$update public.treasury_accounts set name='denied' where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
select pg_temp.check_sql('anon read',$q$select id from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'$q$,'42501');
reset role; set local role service_role;
update public.treasury_accounts set updated_by=null,name=' trusted ' where id='80000000-0000-4000-8000-0000000000b1';
select pg_temp.assert_true('trusted actor retained',(select updated_by is null and name='trusted' from public.treasury_accounts where id='80000000-0000-4000-8000-0000000000b1'));
select pg_temp.check_sql('creation time immutable',$q$update public.treasury_accounts set created_at='2001-01-01' where id='80000000-0000-4000-8000-0000000000b1'$q$,'23514');
select pg_temp.check_sql('creation actor immutable',$q$update public.treasury_accounts set created_by=null where id='80000000-0000-4000-8000-0000000000b1'$q$,'23514');
insert into public.treasury_accounts(company_id,code,name,type,gl_account_id,created_at,updated_at) values ('80000000-0000-4000-8000-0000000000a1','TRUSTED','Trusted','CASH','80000000-0000-4000-8000-0000000000d4','1999-01-01','1999-01-02');
select pg_temp.assert_true('trusted provisioning retained',(select created_at='1999-01-01'::timestamptz and updated_at='1999-01-02'::timestamptz from public.treasury_accounts where company_id='80000000-0000-4000-8000-0000000000a1' and code='TRUSTED'));
reset role;
select count(*) as passed,count(*) filter(where not passed) as failed from slice10_results;
rollback;
