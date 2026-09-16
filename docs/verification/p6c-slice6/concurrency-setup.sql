-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
-- Requires confirmed Development target and applied Slice 6 migration.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260913123000') then raise exception 'Slice 6 migration required'; end if;
 if exists(select 1 from auth.users where id='76100000-0000-4000-8000-000000000001' or email='p6c-s6-concurrency@example.test')
 or exists(select 1 from public.companies where id='76100000-0000-4000-8000-0000000000a1' or lower(btrim(code))='p6c-s6-concurrency')
 or exists(select 1 from public.parties where id='76100000-0000-4000-8000-0000000000f1') then raise exception 'Fixture collision'; end if;
end $$;
insert into auth.users(id,email,raw_user_meta_data) values ('76100000-0000-4000-8000-000000000001','p6c-s6-concurrency@example.test','{"display_name":"Slice 6 non-login concurrency"}');
insert into public.companies(id,code,name) values ('76100000-0000-4000-8000-0000000000a1','P6C-S6-CONCURRENCY','Slice 6 disposable concurrency');
insert into public.company_settings(company_id,tenant_slug) values ('76100000-0000-4000-8000-0000000000a1','p6c-s6-concurrency');
insert into public.company_memberships(company_id,user_id,role) values ('76100000-0000-4000-8000-0000000000a1','76100000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
insert into public.parties(id,company_id,type,code,name,updated_at) values ('76100000-0000-4000-8000-0000000000f1','76100000-0000-4000-8000-0000000000a1','SUPPLIER','EDIT','Concurrent edit','2000-01-01T00:00:00Z');
commit;
