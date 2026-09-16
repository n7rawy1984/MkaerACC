-- MakerACC-Development only. Exact disposable non-login fixture.
begin;
do $$ begin
 if not exists(select 1 from supabase_migrations.schema_migrations where version='20260916120000') then raise exception 'Slice 7 migration required'; end if;
 if exists(select 1 from auth.users where id='77100000-0000-4000-8000-000000000001' or email='p6c-s7-concurrency@example.test')
 or exists(select 1 from public.companies where id='77100000-0000-4000-8000-0000000000a1' or lower(btrim(code))='p6c-s7-concurrency')
 or exists(select 1 from public.company_settings where tenant_slug='p6c-s7-concurrency') then raise exception 'Fixture collision'; end if;
end $$;
insert into auth.users(id,email,raw_user_meta_data) values ('77100000-0000-4000-8000-000000000001','p6c-s7-concurrency@example.test','{"display_name":"Slice 7 non-login concurrency"}');
insert into public.companies(id,code,name,updated_at) values ('77100000-0000-4000-8000-0000000000a1','P6C-S7-CONCURRENCY','Slice 7 disposable concurrency','2000-01-01T00:00:00.123456Z');
insert into public.company_settings(company_id,tenant_slug) values ('77100000-0000-4000-8000-0000000000a1','p6c-s7-concurrency');
insert into public.company_memberships(company_id,user_id,role) values ('77100000-0000-4000-8000-0000000000a1','77100000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
commit;
