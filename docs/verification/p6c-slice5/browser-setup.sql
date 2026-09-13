-- EXECUTED 2026-09-13 for e6cac418-6739-4b66-a1ab-f7cd98bf89fc. Fixture is LIVE; do not rerun.
-- Retained operational Development fixture template, not a migration.
-- First provision p6c-slice5-user@example.test through trusted Supabase Auth.
-- In the SAME transaction, set makeracc.fixture_user to that confirmed UUID:
-- SELECT set_config('makeracc.fixture_user', '<confirmed Auth UUID>', true);
-- Replace the deliberate unset placeholder below before execution. Never add passwords.
begin;
select set_config('makeracc.fixture_user', '', true);
do $$ declare actor uuid; begin
 actor:=nullif(current_setting('makeracc.fixture_user',true),'')::uuid;
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-slice5-user@example.test')
   or not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Confirmed active browser fixture identity required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor) then raise exception 'Unexpected existing memberships'; end if;
 insert into public.companies(id,code,name) values
 ('75200000-0000-4000-8000-0000000000a1','P6C-S5-BROWSER-A','P6C Slice 5 Alpha'),
 ('75200000-0000-4000-8000-0000000000a2','P6C-S5-BROWSER-B','P6C Slice 5 Beta');
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color,accent_color) values
 ('75200000-0000-4000-8000-0000000000a1','p6c-s5-browser-alpha','Slice 5 Alpha','#1d4ed8','#0891b2'),
 ('75200000-0000-4000-8000-0000000000a2','p6c-s5-browser-beta','Slice 5 Beta','#7e22ce','#c2410c');
 insert into public.company_memberships(company_id,user_id,role) values
 ('75200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),
 ('75200000-0000-4000-8000-0000000000a2',actor,'MANAGEMENT_VIEWER');
 insert into public.projects(id,company_id,code,name,status) values
 ('75200000-0000-4000-8000-0000000000c1','75200000-0000-4000-8000-0000000000a1','ASSIGNMENT','Slice 5 assignment','ACTIVE');
 insert into public.project_assignments(company_id,project_id,user_id) values
 ('75200000-0000-4000-8000-0000000000a1','75200000-0000-4000-8000-0000000000c1',actor);
 insert into public.expense_categories(id,company_id,code,name,description,status) values
 ('75200000-0000-4000-8000-0000000000f1','75200000-0000-4000-8000-0000000000a1','MATERIALS','مواد البناء',null,'ACTIVE'),
 ('75200000-0000-4000-8000-0000000000f2','75200000-0000-4000-8000-0000000000a1','INACTIVE','Inactive reference','Synthetic browser category','INACTIVE');
end $$;
commit;
