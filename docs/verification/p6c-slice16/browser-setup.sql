-- Development only. Replace only the empty UUID in an execution copy with the
-- disposable p6c-s16-browser@example.test Auth UUID. Never add a password.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s16-browser@example.test') or not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Exact active synthetic Auth identity required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260923120000') then raise exception 'Slice 16 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor) or exists(select 1 from public.companies where left(id::text,8)='86200000' or lower(btrim(code)) in ('p6c-s16-browser-a','p6c-s16-browser-b')) or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s16-browser-a','p6c-s16-browser-b')) then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,status) values ('86200000-0000-4000-8000-0000000000a1','P6C-S16-BROWSER-A','Slice 16 Alpha','ACTIVE'),('86200000-0000-4000-8000-0000000000a2','P6C-S16-BROWSER-B','Slice 16 Beta','ACTIVE');
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values ('86200000-0000-4000-8000-0000000000a1','p6c-s16-browser-a','Slice 16 Alpha Brand','#123456'),('86200000-0000-4000-8000-0000000000a2','p6c-s16-browser-b','Slice 16 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role,status) values ('86200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN','ACTIVE'),('86200000-0000-4000-8000-0000000000a2',actor,'ACCOUNTING_ADMIN','ACTIVE');
 insert into public.projects(id,company_id,code,name,status) values ('86200000-0000-4000-8000-0000000000c1','86200000-0000-4000-8000-0000000000a1','P1','Alpha Project','ACTIVE'),('86200000-0000-4000-8000-0000000000c2','86200000-0000-4000-8000-0000000000a2','P2','Beta Project','ACTIVE');
 insert into public.parties(id,company_id,code,name,type,status) values ('86200000-0000-4000-8000-0000000000b1','86200000-0000-4000-8000-0000000000a1','SC1','Alpha Subcontractor','SUBCONTRACTOR','ACTIVE'),('86200000-0000-4000-8000-0000000000b2','86200000-0000-4000-8000-0000000000a2','SC2','Beta Subcontractor','SUBCONTRACTOR','ACTIVE'),('86200000-0000-4000-8000-0000000000b3','86200000-0000-4000-8000-0000000000a1','SUP1','Supplier regression','SUPPLIER','ACTIVE');
 insert into public.subcontracts(id,company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,approved_variations_minor,retention_bps,start_date,expected_end_date,status,notes) values
 ('86200000-0000-4000-8000-0000000000d1','86200000-0000-4000-8000-0000000000a1','86200000-0000-4000-8000-0000000000c1','86200000-0000-4000-8000-0000000000b1','0001','Alpha active scope',12345,500,525,'2026-01-01','2026-12-31','ACTIVE','Alpha notes'),
 ('86200000-0000-4000-8000-0000000000d2','86200000-0000-4000-8000-0000000000a1','86200000-0000-4000-8000-0000000000c1','86200000-0000-4000-8000-0000000000b1','0002','Alpha closed scope',23456,0,0,null,null,'CLOSED',null),
 ('86200000-0000-4000-8000-0000000000d3','86200000-0000-4000-8000-0000000000a2','86200000-0000-4000-8000-0000000000c2','86200000-0000-4000-8000-0000000000b2','0003','Beta active scope',34567,0,0,null,null,'ACTIVE',null);
end $$; commit;
