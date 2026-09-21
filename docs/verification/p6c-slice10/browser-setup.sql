-- Development only. Replace the empty UUID in an execution copy with a newly
-- provisioned synthetic Auth user p6c-s10-browser@example.test. Never add passwords.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s10-browser@example.test') then raise exception 'Exact synthetic Auth user required'; end if;
 if not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Active fixture profile required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260921120000') then raise exception 'Slice 10 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.companies where id in ('80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000a2') or lower(btrim(code)) in ('p6c-s10-browser-a','p6c-s10-browser-b'))
 or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s10-browser-a','p6c-s10-browser-b')) or exists(select 1 from public.treasury_accounts where id in ('80200000-0000-4000-8000-0000000000b1','80200000-0000-4000-8000-0000000000b2','80200000-0000-4000-8000-0000000000b3'))
 or exists(select 1 from public.accounts where id in ('80200000-0000-4000-8000-0000000000d1','80200000-0000-4000-8000-0000000000d2','80200000-0000-4000-8000-0000000000d3'))
 or exists(select 1 from public.projects where id='80200000-0000-4000-8000-0000000000c1')
 or exists(select 1 from public.project_assignments where user_id=actor or id='80200000-0000-4000-8000-0000000000e1') then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,legal_name,trn,address,notes) values
 ('80200000-0000-4000-8000-0000000000a1','P6C-S10-BROWSER-A','Slice 10 Alpha','Alpha Legal','001234567890123','عنوان عربي',null),
 ('80200000-0000-4000-8000-0000000000a2','P6C-S10-BROWSER-B','Slice 10 Beta','Beta Legal',null,null,null);
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values
 ('80200000-0000-4000-8000-0000000000a1','p6c-s10-browser-a','Slice 10 Alpha Brand','#123456'),
 ('80200000-0000-4000-8000-0000000000a2','p6c-s10-browser-b','Slice 10 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role) values
 ('80200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('80200000-0000-4000-8000-0000000000a2',actor,'ACCOUNTING_ADMIN');
 insert into public.accounts(id,company_id,code,name,account_type) values
 ('80200000-0000-4000-8000-0000000000d1','80200000-0000-4000-8000-0000000000a1','GL1','Alpha Bank GL','ASSET'),
 ('80200000-0000-4000-8000-0000000000d2','80200000-0000-4000-8000-0000000000a1','GL2','Alpha Cash GL','ASSET'),
 ('80200000-0000-4000-8000-0000000000d3','80200000-0000-4000-8000-0000000000a2','GL3','Beta GL','ASSET');
 insert into public.projects(id,company_id,code,name) values ('80200000-0000-4000-8000-0000000000c1','80200000-0000-4000-8000-0000000000a1','P1','Alpha Project');
 insert into public.project_assignments(id,company_id,project_id,user_id) values ('80200000-0000-4000-8000-0000000000e1','80200000-0000-4000-8000-0000000000a1','80200000-0000-4000-8000-0000000000c1',actor);
 insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id,project_id,status,bank_name,account_reference,notes) values
 ('80200000-0000-4000-8000-0000000000b1','80200000-0000-4000-8000-0000000000a1','0001','بنك Alpha','BANK','80200000-0000-4000-8000-0000000000d1',null,'INACTIVE','Bank Alpha','000123','Keep notes'),
 ('80200000-0000-4000-8000-0000000000b2','80200000-0000-4000-8000-0000000000a1','0002','Project Cash','CASH','80200000-0000-4000-8000-0000000000d2','80200000-0000-4000-8000-0000000000c1','ACTIVE',null,null,null),
 ('80200000-0000-4000-8000-0000000000b3','80200000-0000-4000-8000-0000000000a2','0003','Beta Treasury','CASH','80200000-0000-4000-8000-0000000000d3',null,'ACTIVE',null,null,null);
end $$;
commit;
