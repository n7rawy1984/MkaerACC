-- MakerACC-Development only. Rollback-only Slice 16 database contract.
begin;
select set_config('request.jwt.claim.sub','7cf0bfff-6938-4beb-a0ff-0ed726867304',true);
create temporary table slice16_results(label text primary key, passed boolean not null);
create function pg_temp.assert_true(label text, condition boolean) returns void language plpgsql as $$ begin if condition is not true then raise exception 'FAILED: %',label; end if; insert into slice16_results values(label,true); end $$;
create function pg_temp.check_sql(label text, statement text, expected_state text default null, expected_rows integer default null) returns void language plpgsql as $$
declare actual integer; begin
 begin execute statement; get diagnostics actual=row_count; if expected_state is not null then raise exception 'FAILED: % expected SQLSTATE %',label,expected_state; end if;
 exception when others then if expected_state is null or sqlstate<>expected_state then raise; end if; actual:=null; end;
 if expected_rows is not null and actual is distinct from expected_rows then raise exception 'FAILED: % rows %, expected %',label,actual,expected_rows; end if;
 insert into slice16_results values(label,true);
end $$;
grant select,insert on pg_temp.slice16_results to authenticated;
select pg_temp.assert_true('forced RLS',(select relrowsecurity and relforcerowsecurity from pg_class where oid='public.subcontracts'::regclass));
select pg_temp.assert_true('exact update grants',not has_table_privilege('authenticated','public.subcontracts','INSERT,UPDATE,DELETE,TRUNCATE') and (select array_agg(attname::text order by attname) from pg_attribute where attrelid='public.subcontracts'::regclass and attnum>0 and not attisdropped and has_column_privilege('authenticated','public.subcontracts',attname,'UPDATE'))=array['expected_end_date','notes','scope_of_work','start_date']);
select pg_temp.assert_true('exact write roles',(select array_agg(role order by role) from public.role_permissions where permission_key='subcontract.manage')=array['ACCOUNTING_ADMIN'::public.company_role,'PROCUREMENT'::public.company_role]);
do $$ begin
 if not exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id where u.id='7cf0bfff-6938-4beb-a0ff-0ed726867304' and p.status='ACTIVE') then raise exception 'Existing synthetic actor unavailable'; end if;
 if exists(select 1 from public.companies where id in ('86000000-0000-4000-8000-0000000000a1','86000000-0000-4000-8000-0000000000a2')) then raise exception 'Fixture collision'; end if;
end $$;
insert into public.companies(id,code,name,status) values
 ('86000000-0000-4000-8000-0000000000a1','P6C-S16-A','Slice 16 Alpha','ACTIVE'),
 ('86000000-0000-4000-8000-0000000000a2','P6C-S16-B','Slice 16 Beta','ACTIVE');
insert into public.company_settings(company_id,tenant_slug) values
 ('86000000-0000-4000-8000-0000000000a1','p6c-s16-a'),('86000000-0000-4000-8000-0000000000a2','p6c-s16-b');
insert into public.company_memberships(company_id,user_id,role,status) values
 ('86000000-0000-4000-8000-0000000000a1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACCOUNTING_ADMIN','ACTIVE'),
 ('86000000-0000-4000-8000-0000000000a2','7cf0bfff-6938-4beb-a0ff-0ed726867304','MANAGEMENT_VIEWER','ACTIVE');
insert into public.projects(id,company_id,code,name,status) values
 ('86000000-0000-4000-8000-0000000000c1','86000000-0000-4000-8000-0000000000a1','P1','Alpha Project','ACTIVE'),
 ('86000000-0000-4000-8000-0000000000c2','86000000-0000-4000-8000-0000000000a2','P2','Beta Project','ACTIVE');
insert into public.parties(id,company_id,code,name,type,status) values
 ('86000000-0000-4000-8000-0000000000b1','86000000-0000-4000-8000-0000000000a1','SC1','Alpha Subcontractor','SUBCONTRACTOR','ACTIVE'),
 ('86000000-0000-4000-8000-0000000000b2','86000000-0000-4000-8000-0000000000a2','SC2','Beta Subcontractor','SUBCONTRACTOR','ACTIVE');
insert into public.subcontracts(id,company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,approved_variations_minor,retention_bps,start_date,expected_end_date,status,notes,created_by,updated_at) values
 ('86000000-0000-4000-8000-0000000000d1','86000000-0000-4000-8000-0000000000a1','86000000-0000-4000-8000-0000000000c1','86000000-0000-4000-8000-0000000000b1','0001','Active work',9007199254740993,17,525,'2026-01-01','2026-02-01','ACTIVE','Original','7cf0bfff-6938-4beb-a0ff-0ed726867304','2000-01-01T00:00:00.123456Z'),
 ('86000000-0000-4000-8000-0000000000d2','86000000-0000-4000-8000-0000000000a1','86000000-0000-4000-8000-0000000000c1','86000000-0000-4000-8000-0000000000b1','0002','Completed work',2,0,0,null,null,'COMPLETED',null,null,'2000-01-01T00:00:00.123456Z'),
 ('86000000-0000-4000-8000-0000000000d3','86000000-0000-4000-8000-0000000000a1','86000000-0000-4000-8000-0000000000c1','86000000-0000-4000-8000-0000000000b1','0003','Closed work',3,0,0,null,null,'CLOSED',null,null,'2000-01-01T00:00:00.123456Z'),
 ('86000000-0000-4000-8000-0000000000d4','86000000-0000-4000-8000-0000000000a2','86000000-0000-4000-8000-0000000000c2','86000000-0000-4000-8000-0000000000b2','0004','Beta work',4,0,0,null,null,'ACTIVE',null,null,'2000-01-01T00:00:00.123456Z');
insert into public.project_assignments(company_id,project_id,user_id,status) values ('86000000-0000-4000-8000-0000000000a1','86000000-0000-4000-8000-0000000000c1','7cf0bfff-6938-4beb-a0ff-0ed726867304','ACTIVE');
create temporary table historical_row as select to_jsonb(s) row from public.subcontracts s where id='86000000-0000-4000-8000-0000000000d1';
create temporary table historical_counts as select
 (select count(*) from public.subcontractor_advances) advances,(select count(*) from public.subcontractor_certificates) certificates,
 (select count(*) from public.subcontractor_payments) payments,(select count(*) from public.subcontractor_retention_releases) releases,
 (select count(*) from public.subcontractor_retention_payments) retention_payments,(select count(*) from public.journal_entries) journals,(select count(*) from public.journal_lines) lines;
grant select on pg_temp.historical_row,pg_temp.historical_counts to authenticated;

set local role authenticated;
select pg_temp.check_sql('admin ACTIVE',$q$update public.subcontracts set scope_of_work=chr(65279)||'  نطاق  Mixed  ',start_date=null,expected_end_date='2027-03-04',notes=E'  A\n  B  ' where id='86000000-0000-4000-8000-0000000000d1'$q$,null,1);
select pg_temp.check_sql('admin COMPLETED',$q$update public.subcontracts set notes='completed edit' where id='86000000-0000-4000-8000-0000000000d2'$q$,null,1);
select pg_temp.check_sql('admin CLOSED',$q$update public.subcontracts set notes='closed edit' where id='86000000-0000-4000-8000-0000000000d3'$q$,null,1);
select pg_temp.check_sql('cross tenant',$q$update public.subcontracts set notes='denied' where id='86000000-0000-4000-8000-0000000000d4'$q$,null,0);
reset role;
update public.company_memberships set role='PROCUREMENT' where company_id='86000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('procurement edit',$q$update public.subcontracts set notes='procurement' where id='86000000-0000-4000-8000-0000000000d1'$q$,null,1);
reset role;
do $$ declare r public.company_role; affected integer; visible integer; expected_read integer; begin
 foreach r in array array['ACCOUNTANT','MANAGEMENT_VIEWER','PROJECT_MANAGER','DATA_ENTRY','SYSTEM_ADMIN']::public.company_role[] loop
  update public.company_memberships set role=r where company_id='86000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
  perform set_config('role','authenticated',true);
  execute $q$update public.subcontracts set notes='denied' where id='86000000-0000-4000-8000-0000000000d1'$q$;
  get diagnostics affected=row_count;
  select count(*) into visible from public.subcontracts where company_id='86000000-0000-4000-8000-0000000000a1';
  expected_read:=case when r in ('ACCOUNTANT','MANAGEMENT_VIEWER','PROJECT_MANAGER') then 3 else 0 end;
  perform set_config('role','postgres',true);
  perform pg_temp.assert_true(r||' write denied',affected=0);
  perform pg_temp.assert_true(r||' exact read',visible=expected_read);
 end loop;
end $$;
update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id='86000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('protected contract_number',$q$update public.subcontracts set contract_number='9999' where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected value',$q$update public.subcontracts set original_contract_value_minor=0 where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected variations',$q$update public.subcontracts set approved_variations_minor=0 where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected retention',$q$update public.subcontracts set retention_bps=0 where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected status',$q$update public.subcontracts set status='CLOSED' where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected project',$q$update public.subcontracts set project_id=project_id where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected subcontractor',$q$update public.subcontracts set subcontractor_id=subcontractor_id where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected company',$q$update public.subcontracts set company_id=company_id where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected created_by',$q$update public.subcontracts set created_by=created_by where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected created_at',$q$update public.subcontracts set created_at=created_at where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected updated_by',$q$update public.subcontracts set updated_by=updated_by where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('protected updated_at',$q$update public.subcontracts set updated_at=updated_at where id='86000000-0000-4000-8000-0000000000d1'$q$,'42501');
select pg_temp.check_sql('blank scope',$q$update public.subcontracts set scope_of_work=chr(65279)||chr(160) where id='86000000-0000-4000-8000-0000000000d1'$q$,'23514');
reset role;
select pg_temp.assert_true('normalized and unchanged',(select scope_of_work='نطاق  Mixed' and start_date is null and expected_end_date='2027-03-04' and notes='procurement' and updated_by='7cf0bfff-6938-4beb-a0ff-0ed726867304' and contract_number='0001' and original_contract_value_minor=9007199254740993 and approved_variations_minor=17 and retention_bps=525 and status='ACTIVE' and project_id='86000000-0000-4000-8000-0000000000c1' and subcontractor_id='86000000-0000-4000-8000-0000000000b1' and created_by='7cf0bfff-6938-4beb-a0ff-0ed726867304' from public.subcontracts where id='86000000-0000-4000-8000-0000000000d1'));
create temporary table old_token as select updated_at from public.subcontracts where id='86000000-0000-4000-8000-0000000000d1'; grant select on pg_temp.old_token to authenticated; set local role authenticated;
select pg_temp.check_sql('exact token',$q$update public.subcontracts set notes=null,start_date='2026-12-31',expected_end_date=null where id='86000000-0000-4000-8000-0000000000d1' and updated_at=(select updated_at from pg_temp.old_token)$q$,null,1);
select pg_temp.check_sql('stale token',$q$update public.subcontracts set notes='stale' where id='86000000-0000-4000-8000-0000000000d1' and updated_at=(select updated_at from pg_temp.old_token)$q$,null,0);
reset role;
select pg_temp.assert_true('nullable clear and token',(select notes is null and start_date='2026-12-31' and expected_end_date is null and updated_at>(select updated_at from pg_temp.old_token) from public.subcontracts where id='86000000-0000-4000-8000-0000000000d1'));
update public.company_memberships set status='INACTIVE' where company_id='86000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive membership',$q$update public.subcontracts set notes='denied' where id='86000000-0000-4000-8000-0000000000d1'$q$,null,0); reset role; update public.company_memberships set status='ACTIVE' where company_id='86000000-0000-4000-8000-0000000000a1' and user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
update public.profiles set status='INACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304'; set local role authenticated;
select pg_temp.check_sql('inactive profile',$q$update public.subcontracts set notes='denied' where id='86000000-0000-4000-8000-0000000000d1'$q$,null,0); reset role; update public.profiles set status='ACTIVE' where user_id='7cf0bfff-6938-4beb-a0ff-0ed726867304';
update public.companies set status='INACTIVE' where id='86000000-0000-4000-8000-0000000000a1'; set local role authenticated;
select pg_temp.check_sql('inactive company',$q$update public.subcontracts set notes='denied' where id='86000000-0000-4000-8000-0000000000d1'$q$,null,0); reset role; update public.companies set status='ACTIVE' where id='86000000-0000-4000-8000-0000000000a1';
set local role service_role; update public.subcontracts set notes=' trusted ',updated_by=null where id='86000000-0000-4000-8000-0000000000d1'; reset role;
select pg_temp.assert_true('trusted metadata and actor',(select notes='trusted' and updated_by is null from public.subcontracts where id='86000000-0000-4000-8000-0000000000d1'));
select pg_temp.assert_true('financial counts unchanged',(select (select count(*) from public.subcontractor_advances)=advances and (select count(*) from public.subcontractor_certificates)=certificates and (select count(*) from public.subcontractor_payments)=payments and (select count(*) from public.subcontractor_retention_releases)=releases and (select count(*) from public.subcontractor_retention_payments)=retention_payments and (select count(*) from public.journal_entries)=journals and (select count(*) from public.journal_lines)=lines from pg_temp.historical_counts));
select pg_temp.assert_true('historical protected fields unchanged',(select (row->>'contract_number')=s.contract_number and (row->>'original_contract_value_minor')::bigint=s.original_contract_value_minor and (row->>'approved_variations_minor')::bigint=s.approved_variations_minor and (row->>'retention_bps')::integer=s.retention_bps and (row->>'project_id')::uuid=s.project_id and (row->>'subcontractor_id')::uuid=s.subcontractor_id and (row->>'status')=s.status::text and (row->>'created_at')::timestamptz=s.created_at and (row->>'created_by')::uuid=s.created_by from pg_temp.historical_row h join public.subcontracts s on s.id='86000000-0000-4000-8000-0000000000d1'));
select count(*) passed,bool_and(passed) all_passed from slice16_results;
rollback;
