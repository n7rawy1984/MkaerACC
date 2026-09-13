-- Disposable concurrency fixture ONLY; not a browser fixture or migration.
begin;
insert into auth.users(id,email,raw_user_meta_data) values ('75100000-0000-4000-8000-000000000001','p6c-s5-concurrency@example.test','{"display_name":"Slice 5 concurrency"}');
insert into public.companies(id,code,name) values ('75100000-0000-4000-8000-0000000000a1','P6C-S5-CONCURRENCY','Slice 5 disposable concurrency');
insert into public.company_memberships(company_id,user_id,role) values ('75100000-0000-4000-8000-0000000000a1','75100000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN');
insert into public.expense_categories(id,company_id,code,name,updated_at) values ('75100000-0000-4000-8000-0000000000f1','75100000-0000-4000-8000-0000000000a1','EDIT','Concurrent edit','2000-01-01');
commit;
