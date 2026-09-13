begin;
set local role authenticated;
select set_config('request.jwt.claim.sub','75100000-0000-4000-8000-000000000001',true);
insert into public.expense_categories(company_id,code,name) values ('75100000-0000-4000-8000-0000000000a1', ' RACE ', 'Concurrent create') returning id,code;
select pg_sleep(4);
commit;
