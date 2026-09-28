begin;
do $$ declare c uuid:='95610000-0000-4000-8000-000000000001'; x record; p uuid;
begin
 perform set_config('request.jwt.claim.sub',(select user_id::text from public.company_memberships where company_id=c and status='ACTIVE'),true);
 set local role authenticated;
 for x in select s.id from public.salary_payments s where s.company_id=c and not exists(select 1 from public.salary_payment_reversals v where v.payment_id=s.id) loop
  perform public.reverse_salary_payment(c,x.id,'2026-09-02','Close synthetic test payment',gen_random_uuid());
 end loop;
 for x in select s.id from public.payroll_postings s where s.company_id=c and not exists(select 1 from public.payroll_reversals v where v.payroll_id=s.id) loop
  perform public.reverse_payroll(c,x.id,'2026-09-02','Close synthetic test payroll',gen_random_uuid());
 end loop;
 reset role;
 if (select count(*) from public.payroll_postings where company_id=c)<>1 or (select count(*) from public.payroll_reversals where company_id=c)<>1 then raise exception 'Unexpected posting count'; end if;
 if exists(select 1 from private.live_payroll_periods where company_id=c) then raise exception 'Live synthetic payroll'; end if;
 if exists(select 1 from public.journal_lines where company_id=c group by account_id,party_id,project_id,treasury_account_id having sum(debit_minor::numeric-credit_minor::numeric)<>0) then raise exception 'Synthetic net accounting not zero'; end if;
 update public.company_memberships set status='INACTIVE' where company_id=c;
 update public.companies set status='INACTIVE' where id=c;
end $$;
commit;
select 'Concurrency fixture closed: no live payroll, net zero by dimension, Company and membership inactive; immutable synthetic history retained' result;
