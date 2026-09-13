-- Only the disposable concurrency fixture. Never use for browser acceptance cleanup.
begin;
do $$ declare n integer; begin
 if not exists(select 1 from auth.users where id='75100000-0000-4000-8000-000000000001' and email='p6c-s5-concurrency@example.test')
 or not exists(select 1 from public.companies where id='75100000-0000-4000-8000-0000000000a1' and code='P6C-S5-CONCURRENCY' and name='Slice 5 disposable concurrency') then raise exception 'Fixture identity mismatch'; end if;
 if (select count(*) from public.expense_categories where company_id='75100000-0000-4000-8000-0000000000a1' and lower(btrim(code))='race')<>1
 or (select count(*) from public.expense_categories where company_id='75100000-0000-4000-8000-0000000000a1')<>2
 or not exists(select 1 from public.expense_categories where id='75100000-0000-4000-8000-0000000000f1' and name in ('Editor 1','Editor 2') and updated_at>'2000-01-01'::timestamptz) then raise exception 'Concurrent results mismatch'; end if;
 if exists(select 1 from public.company_memberships where user_id='75100000-0000-4000-8000-000000000001' and company_id<>'75100000-0000-4000-8000-0000000000a1') then raise exception 'Unexpected membership'; end if;
 delete from public.expense_categories where company_id='75100000-0000-4000-8000-0000000000a1' and (id='75100000-0000-4000-8000-0000000000f1' or lower(btrim(code))='race');
 get diagnostics n=row_count; if n<>2 then raise exception 'Category count mismatch'; end if;
 delete from public.company_memberships where company_id='75100000-0000-4000-8000-0000000000a1' and user_id='75100000-0000-4000-8000-000000000001';
 get diagnostics n=row_count; if n<>1 then raise exception 'Membership count mismatch'; end if;
 delete from public.companies where id='75100000-0000-4000-8000-0000000000a1' and code='P6C-S5-CONCURRENCY';
 delete from public.profiles where user_id='75100000-0000-4000-8000-000000000001';
 delete from auth.users where id='75100000-0000-4000-8000-000000000001' and email='p6c-s5-concurrency@example.test';
end $$;
select 'concurrent create uniqueness and conditional update verified; disposable fixture removed' as result;
commit;
