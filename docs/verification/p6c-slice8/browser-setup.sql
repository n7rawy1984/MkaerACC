-- Development only. Replace the empty UUID in an execution copy with a newly
-- provisioned synthetic Auth user p6c-s8-browser@example.test. Never add passwords.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid:=nullif(current_setting('makeracc.fixture_user'),'')::uuid; begin
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-s8-browser@example.test') then raise exception 'Exact synthetic Auth user required'; end if;
 if not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Active fixture profile required'; end if;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260916140000') then raise exception 'Slice 8 migration required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.companies where id in ('78200000-0000-4000-8000-0000000000a1','78200000-0000-4000-8000-0000000000a2') or lower(btrim(code)) in ('p6c-s8-browser-a','p6c-s8-browser-b'))
 or exists(select 1 from public.company_settings where tenant_slug in ('p6c-s8-browser-a','p6c-s8-browser-b')) or exists(select 1 from public.projects where id in ('78200000-0000-4000-8000-0000000000b1','78200000-0000-4000-8000-0000000000b2','78200000-0000-4000-8000-0000000000b3'))
 or exists(select 1 from public.project_assignments where id='78200000-0000-4000-8000-0000000000c1' or user_id=actor) then raise exception 'Fixture collision'; end if;
 insert into public.companies(id,code,name,legal_name,trn,address,notes) values
 ('78200000-0000-4000-8000-0000000000a1','P6C-S8-BROWSER-A','Slice 8 Alpha','Alpha Legal','001234567890123','عنوان عربي',null),
 ('78200000-0000-4000-8000-0000000000a2','P6C-S8-BROWSER-B','Slice 8 Beta','Beta Legal',null,null,null);
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color) values
 ('78200000-0000-4000-8000-0000000000a1','p6c-s8-browser-a','Slice 8 Alpha Brand','#123456'),
 ('78200000-0000-4000-8000-0000000000a2','p6c-s8-browser-b','Slice 8 Beta Brand','#654321');
 insert into public.company_memberships(company_id,user_id,role) values
 ('78200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('78200000-0000-4000-8000-0000000000a2',actor,'ACCOUNTING_ADMIN');
 insert into public.projects(id,company_id,code,name,client_name,location,contract_number,notes,status) values
 ('78200000-0000-4000-8000-0000000000b1','78200000-0000-4000-8000-0000000000a1','P1','مشروع Alpha','Client Alpha',null,'000123',null,'ACTIVE'),
 ('78200000-0000-4000-8000-0000000000b2','78200000-0000-4000-8000-0000000000a1','P2','Closed Alpha',null,'Site Alpha',null,'Historical project description','CLOSED'),
 ('78200000-0000-4000-8000-0000000000b3','78200000-0000-4000-8000-0000000000a2','P3','Beta Project',null,null,null,null,'PLANNING');
 insert into public.project_assignments(id,company_id,project_id,user_id) values ('78200000-0000-4000-8000-0000000000c1','78200000-0000-4000-8000-0000000000a1','78200000-0000-4000-8000-0000000000b1',actor);
end $$;
commit;
