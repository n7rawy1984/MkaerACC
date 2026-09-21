-- Development only. Replace the empty UUID in an execution copy with a newly
-- provisioned synthetic Auth user p6c-s9-browser@example.test. Never add passwords.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s9-browser@example.test') then raise exception 'Exact synthetic Auth user required'; end if;
 if not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Active fixture profile required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260917120000') then raise exception 'Slice 9 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.companies where id in ('79200000-0000-4000-8000-0000000000a1','79200000-0000-4000-8000-0000000000a2') or lower(btrim(code)) in ('p6c-s9-browser-a','p6c-s9-browser-b'))
 or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s9-browser-a','p6c-s9-browser-b')) or exists(select 1 from public.accounts where id in ('79200000-0000-4000-8000-0000000000b1','79200000-0000-4000-8000-0000000000b2','79200000-0000-4000-8000-0000000000b3'))
 or exists(select 1 from public.project_assignments where user_id=actor) then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,legal_name,trn,address,notes) values
 ('79200000-0000-4000-8000-0000000000a1','P6C-S9-BROWSER-A','Slice 9 Alpha','Alpha Legal','001234567890123','عنوان عربي',null),
 ('79200000-0000-4000-8000-0000000000a2','P6C-S9-BROWSER-B','Slice 9 Beta','Beta Legal',null,null,null);
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values
 ('79200000-0000-4000-8000-0000000000a1','p6c-s9-browser-a','Slice 9 Alpha Brand','#123456'),
 ('79200000-0000-4000-8000-0000000000a2','p6c-s9-browser-b','Slice 9 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role) values
 ('79200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('79200000-0000-4000-8000-0000000000a2',actor,'ACCOUNTING_ADMIN');
 insert into public.accounts(id,company_id,code,name,account_type,status,system_key,parent_account_id) values
 ('79200000-0000-4000-8000-0000000000b1','79200000-0000-4000-8000-0000000000a1','0001','حساب Alpha','ASSET','ACTIVE',null,null),
 ('79200000-0000-4000-8000-0000000000b2','79200000-0000-4000-8000-0000000000a1','0002','Inactive system Alpha','ASSET','INACTIVE','INPUT_VAT','79200000-0000-4000-8000-0000000000b1'),
 ('79200000-0000-4000-8000-0000000000b3','79200000-0000-4000-8000-0000000000a2','0003','Beta Account','ASSET','ACTIVE',null,null);
end $$;
commit;
