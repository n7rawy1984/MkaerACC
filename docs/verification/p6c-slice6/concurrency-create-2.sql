-- PREPARED / NOT EXECUTED. MakerACC-Development only; NOT a migration.
begin;
do $$ begin
 if not exists(select 1 from auth.users where id='76100000-0000-4000-8000-000000000001' and email='p6c-s6-concurrency@example.test')
 or not exists(select 1 from public.companies where id='76100000-0000-4000-8000-0000000000a1' and code='P6C-S6-CONCURRENCY') then raise exception 'Concurrency fixture missing'; end if;
end $$;
set local role authenticated;
select set_config('request.jwt.claim.sub','76100000-0000-4000-8000-000000000001',true);
insert into public.parties(company_id,code,name) values ('76100000-0000-4000-8000-0000000000a1', 'race', 'Concurrent create 2') returning id,code;
commit;
