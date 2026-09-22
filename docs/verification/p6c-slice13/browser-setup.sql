-- Development only. Replace the empty UUID in an execution copy with a newly
-- provisioned synthetic Auth user p6c-s13-browser@example.test. Never add passwords.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s13-browser@example.test') then raise exception 'Exact synthetic Auth user required'; end if;
 if not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Active fixture profile required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260922130000') then raise exception 'Slice 13 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.companies where id in ('83200000-0000-4000-8000-0000000000a1','83200000-0000-4000-8000-0000000000a2') or lower(btrim(code)) in ('p6c-s13-browser-a','p6c-s13-browser-b'))
 or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s13-browser-a','p6c-s13-browser-b')) or exists(select 1 from public.parties where id::text like '83200000-0000-4000-8000-0000000000b_')
 or exists(select 1 from public.project_assignments where user_id=actor) then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,legal_name,trn,address,notes) values
 ('83200000-0000-4000-8000-0000000000a1','P6C-S13-BROWSER-A','Slice 13 Alpha','Alpha Legal','001234567890123','عنوان عربي',null),
 ('83200000-0000-4000-8000-0000000000a2','P6C-S13-BROWSER-B','Slice 13 Beta','Beta Legal',null,null,null);
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values
 ('83200000-0000-4000-8000-0000000000a1','p6c-s13-browser-a','Slice 13 Alpha Brand','#123456'),
 ('83200000-0000-4000-8000-0000000000a2','p6c-s13-browser-b','Slice 13 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role) values
 ('83200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('83200000-0000-4000-8000-0000000000a2',actor,'ACCOUNTING_ADMIN');
 insert into public.parties(id,company_id,code,name,type,status,trn,contact_person,notes) values
 ('83200000-0000-4000-8000-0000000000b1','83200000-0000-4000-8000-0000000000a1','0001','أمين عهدة Alpha','CUSTODIAN','INACTIVE','001234567890123','جهة اتصال','Keep notes'),
 ('83200000-0000-4000-8000-0000000000b2','83200000-0000-4000-8000-0000000000a1','0002','Active Custodian','CUSTODIAN','ACTIVE',null,null,null),
 ('83200000-0000-4000-8000-0000000000b3','83200000-0000-4000-8000-0000000000a2','0003','Beta Custodian','CUSTODIAN','ACTIVE',null,null,null),
 ('83200000-0000-4000-8000-0000000000b4','83200000-0000-4000-8000-0000000000a1','0004','Supplier regression','SUPPLIER','ACTIVE',null,null,null),
 ('83200000-0000-4000-8000-0000000000b5','83200000-0000-4000-8000-0000000000a1','0005','Other regression','OTHER','ACTIVE',null,null,null),
 ('83200000-0000-4000-8000-0000000000b6','83200000-0000-4000-8000-0000000000a1','0006','Employee regression','EMPLOYEE','ACTIVE',null,null,null);
end $$;
commit;
