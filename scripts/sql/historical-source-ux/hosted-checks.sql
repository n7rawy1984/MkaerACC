-- Development only. New synthetic identities and Companies; every effect rolls back.
begin;
create temporary table source_ux_results(label text);
create function pg_temp.ok(label text, passed boolean) returns void language plpgsql as $$begin if passed is distinct from true then raise exception 'FAIL %',label;end if;insert into pg_temp.source_ux_results values(label);end $$;
create function pg_temp.check_sql(label text,statement text,expected_state text) returns void language plpgsql as $$declare actual text;begin begin execute statement;exception when others then get stacked diagnostics actual=returned_sqlstate;end;if actual is distinct from expected_state then raise exception 'FAIL %: expected %, actual %',label,expected_state,actual;end if;insert into pg_temp.source_ux_results values(label);end $$;
grant select,insert on source_ux_results to authenticated,anon;
create temporary table real_before as select
 (select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.historical_source_records s) sources,
 (select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.journal_entries s) journals,
 (select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.journal_lines s) lines,
 (select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.expenses s) expenses,
 (select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.payroll_postings s) payroll;
insert into auth.users(id,email,raw_user_meta_data) values
 ('96000000-0000-4000-8000-000000000001','source-ux-admin@example.invalid','{"display_name":"Synthetic source admin"}'),
 ('96000000-0000-4000-8000-000000000002','source-ux-viewer@example.invalid','{"display_name":"Synthetic source viewer"}');
insert into public.companies(id,code,name) values
 ('96000000-0000-4000-8000-0000000000a1','SOURCE-UX-A','Synthetic source A'),
 ('96000000-0000-4000-8000-0000000000a2','SOURCE-UX-B','Synthetic source B');
insert into public.company_memberships(company_id,user_id,role) values
 ('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-000000000001','ACCOUNTING_ADMIN'),
 ('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-000000000002','MANAGEMENT_VIEWER');
insert into public.accounts(id,company_id,code,name,account_type,status,requires_party,system_key) values
 ('96000000-0000-4000-8000-000000000011','96000000-0000-4000-8000-0000000000a1','CASH-UX','Synthetic cash','ASSET','ACTIVE',false,null),
 ('96000000-0000-4000-8000-000000000012','96000000-0000-4000-8000-0000000000a1','COST-UX','Synthetic cost','EXPENSE','ACTIVE',false,'COMPANY_EXPENSE');
insert into public.expense_categories(id,company_id,code,name,created_by,updated_by) values('96000000-0000-4000-8000-000000000021','96000000-0000-4000-8000-0000000000a1','UX','Synthetic expense','96000000-0000-4000-8000-000000000001','96000000-0000-4000-8000-000000000001');
select set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select public.create_treasury_master('96000000-0000-4000-8000-0000000000a1','{"code":"CASH-UX","name":"Synthetic cash","type":"CASH","gl_account_id":"96000000-0000-4000-8000-000000000011"}');
reset role;
insert into public.historical_source_records(id,company_id,source_file,source_hash,source_reference,record_type,source_month,source_date,description,outflow_minor,payroll_net_minor,raw_source,classification,created_by,cash_treasury_id) values
 ('96000000-0000-4000-8000-000000000031','96000000-0000-4000-8000-0000000000a1','synthetic.xlsx',repeat('a',64),'UX-G','GENERAL','2026-09','2026-09-20','Synthetic cash expense',10000,null,'{"original":"preserved"}','{"nature":"EXPENSE"}','96000000-0000-4000-8000-000000000001',(select id from public.treasury_accounts where company_id='96000000-0000-4000-8000-0000000000a1' and code='CASH-UX')),
 ('96000000-0000-4000-8000-000000000032','96000000-0000-4000-8000-0000000000a1','synthetic.xlsx',repeat('a',64),'UX-P','PAYROLL','2026-09',null,'Synthetic employee',null,250000,'{"Monthly Salary":"2500","Days Worked":"30"}','{}','96000000-0000-4000-8000-000000000001',null),
 ('96000000-0000-4000-8000-000000000033','96000000-0000-4000-8000-0000000000a2','synthetic.xlsx',repeat('a',64),'UX-F','GENERAL','2026-09',null,'Foreign source',10000,null,'{}','{}','96000000-0000-4000-8000-000000000001',null);
create temporary table stale_source as select company_id,id,updated_at from public.historical_source_records where id='96000000-0000-4000-8000-000000000031';grant select on stale_source to authenticated;
set local role authenticated;
select pg_temp.ok('admin sees only Company A sources',(select count(*)=2 from public.historical_source_records));
select public.complete_historical_source(company_id,id,updated_at,'{"amount_minor":"12550","description":"Synthetic cash expense","date":"2026-09-20","nature":"EXPENSE"}','REVIEWED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000031';
select pg_temp.ok('exact correction, actor and original preservation',exists(select 1 from public.historical_source_records where id='96000000-0000-4000-8000-000000000031' and completion->>'amount_minor'='12550' and outflow_minor=10000 and raw_source='{"original":"preserved"}'::jsonb and updated_by=auth.uid()));
select pg_temp.check_sql('stale edit rejected',$$select public.complete_historical_source(company_id,id,updated_at,'{}','PENDING') from pg_temp.stale_source$$,'40001');
select pg_temp.check_sql('cross Company edit denied',$$select public.complete_historical_source('96000000-0000-4000-8000-0000000000a2','96000000-0000-4000-8000-000000000033',now(),'{}','PENDING')$$,'42501');
select pg_temp.check_sql('direct source write denied',$$update public.historical_source_records set description='forged'$$,'42501');
select pg_temp.check_sql('physical delete denied',$$delete from public.historical_source_records$$,'42501');
select pg_temp.check_sql('audit overwrite denied',$$update public.historical_source_audit set action='forged'$$,'42501');
select public.complete_historical_source(company_id,id,updated_at,completion||'{"reason":"Synthetic archive"}','CANCELLED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000031';
select pg_temp.ok('archive changes active total without changing original',(select count(*)=1 from public.historical_source_records where review_status='CANCELLED') and (select sum(outflow_minor)=10000 from public.historical_source_records));
select pg_temp.ok('cancel audit records previous exact amount',exists(select 1 from public.historical_source_audit where action='CANCEL' and before_state->'completion'->>'amount_minor'='12550'));
select public.complete_historical_source(company_id,id,updated_at,completion,'REVIEWED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000031';
select pg_temp.ok('restore preserves correction and audit',exists(select 1 from public.historical_source_records where completion->>'amount_minor'='12550' and review_status='REVIEWED') and exists(select 1 from public.historical_source_audit where action='RESTORE'));
select public.complete_historical_source(company_id,id,updated_at,'{"amount_minor":"260033","basic_salary":"2500.00","additions":"25.00","deductions":"50.00","working_days":"29.5","salary_month":"2026-10"}','PENDING') from public.historical_source_records where id='96000000-0000-4000-8000-000000000032';
select pg_temp.ok('Payroll corrections preserve source salary and attendance',exists(select 1 from public.historical_source_records where id='96000000-0000-4000-8000-000000000032' and payroll_net_minor=250000 and completion->>'amount_minor'='260033' and raw_source->>'Days Worked'='30'));
select pg_temp.check_sql('invalid salary month denied',$$select public.complete_historical_source(company_id,id,updated_at,'{"salary_month":"2026-13"}','PENDING') from public.historical_source_records where id='96000000-0000-4000-8000-000000000032'$$,'22023');
select pg_temp.check_sql('fractional minor amount denied',$$select public.complete_historical_source(company_id,id,updated_at,'{"amount_minor":"12.5"}','PENDING') from public.historical_source_records where id='96000000-0000-4000-8000-000000000032'$$,'22023');
select public.complete_historical_source(company_id,id,updated_at,completion||'{"reason":"Synthetic payroll archive"}','CANCELLED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000032';
select pg_temp.ok('Payroll archive excludes corrected active net',(select coalesce(sum((completion->>'amount_minor')::bigint) filter(where review_status<>'CANCELLED'),0)=0 and sum(payroll_net_minor)=250000 from public.historical_source_records where record_type='PAYROLL'));
reset role;
select set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000002',true);
set local role authenticated;
select pg_temp.ok('management reads own sources only',(select count(*)=2 from public.historical_source_records));
select pg_temp.ok('management reads own audit',exists(select 1 from public.historical_source_audit) and not exists(select 1 from public.historical_source_audit where company_id='96000000-0000-4000-8000-0000000000a2'));
select pg_temp.check_sql('management edit denied',$$select public.complete_historical_source(company_id,id,updated_at,'{}','PENDING') from public.historical_source_records limit 1$$,'42501');
select pg_temp.check_sql('management posting denied',$$select public.post_historical_expense('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-000000000031','{}')$$,'42501');
reset role;
select set_config('request.jwt.claim.sub','96000000-0000-4000-8000-000000000001',true);
set local role authenticated;
select * from public.post_historical_expense('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-000000000031',jsonb_build_object('target_treasury_account_id',(select cash_treasury_id from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'),'target_funding_mode','TREASURY','target_payment_method','CASH','target_expense_date','2026-09-20','target_expense_category_id','96000000-0000-4000-8000-000000000021','target_description','Synthetic cash expense','target_net_amount_minor','12550','target_vat_mode','ZERO','target_has_tax_invoice',false));
select * from public.post_historical_expense('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-000000000031',jsonb_build_object('target_treasury_account_id',(select cash_treasury_id from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'),'target_funding_mode','TREASURY','target_payment_method','CASH','target_expense_date','2026-09-20','target_expense_category_id','96000000-0000-4000-8000-000000000021','target_description','Synthetic cash expense','target_net_amount_minor','12550','target_vat_mode','ZERO','target_has_tax_invoice',false));
select pg_temp.ok('source replay creates exactly one Expense and journal',(select count(*)=1 from public.expenses where company_id='96000000-0000-4000-8000-0000000000a1') and (select count(*)=1 from public.journal_entries where company_id='96000000-0000-4000-8000-0000000000a1'));
select pg_temp.ok('source credits actual Treasury GL and debits Company cost',exists(select 1 from public.journal_lines where company_id='96000000-0000-4000-8000-0000000000a1' and account_id='96000000-0000-4000-8000-000000000011' and credit_minor=12550 and debit_minor=0) and exists(select 1 from public.journal_lines where company_id='96000000-0000-4000-8000-0000000000a1' and account_id='96000000-0000-4000-8000-000000000012' and debit_minor=12550 and credit_minor=0));
select pg_temp.check_sql('posted source edit denied',$$select public.complete_historical_source(company_id,id,updated_at,completion||'{"amount_minor":"1"}','REVIEWED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'$$,'23514');
select pg_temp.check_sql('posted source archive denied',$$select public.complete_historical_source(company_id,id,updated_at,completion||'{"reason":"blocked"}','CANCELLED') from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'$$,'23514');
select pg_temp.check_sql('journal direct edit denied',$$update public.journal_lines set debit_minor=1 where company_id='96000000-0000-4000-8000-0000000000a1'$$,'42501');
select * from public.reverse_expense('96000000-0000-4000-8000-0000000000a1',(select expense_id from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'),'2026-09-21','Synthetic correction', '96000000-0000-4000-8000-000000000041');
select * from public.reverse_expense('96000000-0000-4000-8000-0000000000a1',(select expense_id from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'),'2026-09-21','Synthetic correction', '96000000-0000-4000-8000-000000000041');
select pg_temp.ok('reversal replay creates one reversal',(select count(*)=1 from public.expenses where company_id='96000000-0000-4000-8000-0000000000a1' and status='REVERSED'));
select * from public.post_expense('96000000-0000-4000-8000-0000000000a1','2026-09-21',null,'96000000-0000-4000-8000-000000000021','Synthetic corrected replacement',12000,'ZERO',null,'TREASURY',(select cash_treasury_id from public.historical_source_records where id='96000000-0000-4000-8000-000000000031'),null,null,'CASH',false,null,'Replaces synthetic reversed Expense','96000000-0000-4000-8000-000000000042');
select pg_temp.ok('posted replacement uses existing command',(select count(*)=1 from public.expenses where company_id='96000000-0000-4000-8000-0000000000a1' and status='POSTED' and gross_amount_minor=12000));
reset role;
select pg_temp.ok('each original/reversal/replacement journal balances',not exists(select 1 from public.journal_lines where company_id='96000000-0000-4000-8000-0000000000a1' group by journal_entry_id having sum(debit_minor-credit_minor)<>0));
select pg_temp.ok('reversal does not rewrite original amount',exists(select 1 from public.expenses where company_id='96000000-0000-4000-8000-0000000000a1' and status='REVERSED' and gross_amount_minor=12550));
select pg_temp.ok('real source records unchanged',(select sources from real_before)=(select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.historical_source_records s where company_id not in('96000000-0000-4000-8000-0000000000a1','96000000-0000-4000-8000-0000000000a2')));
select pg_temp.ok('real accounting history unchanged',(select journals from real_before)=(select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.journal_entries s where company_id<>'96000000-0000-4000-8000-0000000000a1') and (select lines from real_before)=(select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.journal_lines s where company_id<>'96000000-0000-4000-8000-0000000000a1') and (select expenses from real_before)=(select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.expenses s where company_id<>'96000000-0000-4000-8000-0000000000a1') and (select payroll from real_before)=(select md5(coalesce(string_agg(to_jsonb(s)::text,',' order by id),'')) from public.payroll_postings s));
select count(*) as passed_checks from source_ux_results;
rollback;
