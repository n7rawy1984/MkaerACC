-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
-- Provision p6c-slice6-user@example.test via trusted Auth first. Never store passwords.
-- Replace empty UUID below only in the operator's execution copy.
begin;
select set_config('makeracc.fixture_user','',true);
do $$ declare actor uuid; begin
 actor:=nullif(current_setting('makeracc.fixture_user',true),'')::uuid;
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260913123000') then raise exception 'Slice 6 migration required'; end if;
 if actor is null or not exists(select 1 from auth.users where id=actor and email='p6c-slice6-user@example.test')
 or not exists(select 1 from public.profiles where user_id=actor and status='ACTIVE') then raise exception 'Confirmed browser identity required'; end if;
 if exists(select 1 from public.company_memberships where user_id=actor)
 or exists(select 1 from public.project_assignments where user_id=actor) then raise exception 'Identity already used'; end if;
 insert into public.companies(id,code,name) values
 ('76200000-0000-4000-8000-0000000000a1','P6C-S6-BROWSER-A','P6C Slice 6 Alpha'),('76200000-0000-4000-8000-0000000000a2','P6C-S6-BROWSER-B','P6C Slice 6 Beta');
 insert into public.company_settings(company_id,tenant_slug,app_display_name,primary_color,accent_color) values
 ('76200000-0000-4000-8000-0000000000a1','p6c-s6-browser-alpha','Slice 6 Alpha','#1d4ed8','#0891b2'),
 ('76200000-0000-4000-8000-0000000000a2','p6c-s6-browser-beta','Slice 6 Beta','#7e22ce','#c2410c');
 insert into public.company_memberships(company_id,user_id,role) values
 ('76200000-0000-4000-8000-0000000000a1',actor,'ACCOUNTING_ADMIN'),('76200000-0000-4000-8000-0000000000a2',actor,'MANAGEMENT_VIEWER');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f1','76200000-0000-4000-8000-0000000000a1','SUPPLIER','SUP','مورد تجريبي','001234567890123','ACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f2','76200000-0000-4000-8000-0000000000a1','SUPPLIER','INACTIVE','Slice 6 SUPPLIER',NULL,'INACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f3','76200000-0000-4000-8000-0000000000a1','OWNER','OWNER','Slice 6 OWNER',NULL,'ACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f4','76200000-0000-4000-8000-0000000000a1','CUSTODIAN','CUSTODIAN','Slice 6 CUSTODIAN',NULL,'ACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f5','76200000-0000-4000-8000-0000000000a1','EMPLOYEE','EMPLOYEE','Slice 6 EMPLOYEE',NULL,'ACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f6','76200000-0000-4000-8000-0000000000a1','SUBCONTRACTOR','SUBCONTRACTOR','Slice 6 SUBCONTRACTOR',NULL,'ACTIVE');
 insert into public.parties(id,company_id,type,code,name,trn,status) values ('76200000-0000-4000-8000-0000000000f7','76200000-0000-4000-8000-0000000000a1','OTHER','OTHER','Slice 6 OTHER',NULL,'ACTIVE');
end $$;
commit;
