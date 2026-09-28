-- Dedicated synthetic company: immutable journals are retained, then company/membership deactivated.
begin;
do $$ declare c uuid:='95610000-0000-4000-8000-000000000001'; u uuid; e uuid:='95610000-0000-4000-8000-000000000002'; p uuid; v integer; r uuid;
begin
 select user_id into u from public.profiles where status='ACTIVE' order by user_id limit 1;
 if u is null then raise exception 'Existing synthetic actor required'; end if;
 insert into public.companies(id,code,name) values(c,'PAYROLL-STEP2-RACE','SYNTHETIC Payroll Step 2 concurrency only');
 insert into public.company_settings(company_id,tenant_slug) values(c,'payroll-step2-race');
 insert into public.company_memberships(company_id,user_id,role) values(c,u,'ACCOUNTING_ADMIN');
 insert into public.parties(id,company_id,type,name) values(e,c,'EMPLOYEE','SYNTHETIC concurrency employee');
 insert into public.accounts(id,company_id,code,name,account_type,system_key) values
 ('95610000-0000-4000-8000-000000000003',c,'COST','Payroll cost','EXPENSE','COMPANY_EXPENSE'),
 ('95610000-0000-4000-8000-000000000004',c,'PAYABLE','Salary payable','LIABILITY','SALARY_PAYABLE'),
 ('95610000-0000-4000-8000-000000000005',c,'BANK','Synthetic bank','ASSET',null);
 insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id) values('95610000-0000-4000-8000-000000000006',c,'BANK','SYNTHETIC bank','BANK','95610000-0000-4000-8000-000000000005');
 perform set_config('request.jwt.claim.sub',u::text,true);
 set local role authenticated;
 perform public.save_payroll_profile(c,e,0,'RACE','Monthly','Test','Office',null,10000,'BANK','ACTIVE');
 perform public.confirm_attendance_review(c,'2026-08-01',0);
 p:=public.refresh_payroll_draft(c,'2026-08-01',0);
 select id into r from public.payroll_draft_rows where period_id=p;
 perform public.prepare_payroll_accounting(c,p,1,jsonb_build_object(r::text,null),'{}');
 perform public.review_payroll_draft(c,p,2);
 reset role;
end $$;
commit;
