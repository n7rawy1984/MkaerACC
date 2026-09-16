-- Development only. Replace the empty UUID in an execution copy with a newly
-- provisioned synthetic Auth user p6c-s7-browser@example.test. Never add passwords.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s7-browser@example.test') then raise exception 'Exact synthetic Auth user required'; end if;
 if not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Active fixture profile required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260916120000') then raise exception 'Slice 7 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.companies where id in ('77200000-0000-4000-8000-0000000000a1','77200000-0000-4000-8000-0000000000a2') or lower(btrim(code)) in ('p6c-s7-browser-a','p6c-s7-browser-b'))
 or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s7-browser-a','p6c-s7-browser-b')) then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,legal_name,trn,address,notes) values
 ('77200000-0000-4000-8000-0000000000a1','P6C-S7-BROWSER-A','Slice 7 Alpha','Alpha Legal','001234567890123','عنوان عربي',null),
 ('77200000-0000-4000-8000-0000000000a2','P6C-S7-BROWSER-B','Slice 7 Beta','Beta Legal',null,null,null);
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values
 ('77200000-0000-4000-8000-0000000000a1','p6c-s7-browser-a','Slice 7 Alpha Brand','#123456'),
 ('77200000-0000-4000-8000-0000000000a2','p6c-s7-browser-b','Slice 7 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role) values
 ('77200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('77200000-0000-4000-8000-0000000000a2',actor,'SYSTEM_ADMIN');
end $$;
commit;
