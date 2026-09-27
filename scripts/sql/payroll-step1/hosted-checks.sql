-- Calculation-only Payroll Step 1. MakerACC-Development, synthetic fixtures, one rollback transaction.
begin;
create temp table payroll_checks(passed integer not null); insert into payroll_checks values(0); grant select,update on payroll_checks to authenticated;
create function pg_temp.payroll_check(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; update payroll_checks set passed=passed+1; end $$;
create function pg_temp.payroll_reject(q text,code text) returns void language plpgsql as $$
begin begin execute q; exception when others then if sqlstate=code then perform pg_temp.payroll_check(true,q);return;else raise;end if;end;raise exception 'Expected rejection: %',q;end $$;
do $$
#variable_conflict use_variable
declare f record; other_company uuid; other_employee uuid; other_project uuid; second_employee uuid:=gen_random_uuid(); non_employee uuid;
 profile_id uuid; profile_version integer; period_id uuid; row_id uuid; adjustment_id uuid:=gen_random_uuid(); deduction_id uuid:=gen_random_uuid(); calc record;
 period_version integer; doc jsonb; month date; expected_days integer; ar integer; baseline_journals bigint; test_role public.company_role; tbl text; n integer; days integer;
begin
 select c.id company_id,m.user_id,p.id project_id,e.id employee_id into f from public.companies c
 join public.company_memberships m on m.company_id=c.id and m.status='ACTIVE' join public.profiles u on u.user_id=m.user_id and u.status='ACTIVE'
 join public.projects p on p.company_id=c.id and p.status<>'CLOSED' join public.parties e on e.company_id=c.id and e.type='EMPLOYEE' and e.status='ACTIVE'
 where c.status='ACTIVE' order by c.id,m.user_id,p.id limit 1;
 if f.user_id is null then raise exception 'Synthetic fixture unavailable';end if;
 select company_id,id into other_company,other_employee from public.parties where company_id<>f.company_id and type='EMPLOYEE' limit 1;
 select id into other_project from public.projects where company_id=other_company limit 1;
 select id into non_employee from public.parties where company_id=f.company_id and type<>'EMPLOYEE' limit 1;
 insert into public.parties(id,company_id,type,name) values(second_employee,f.company_id,'EMPLOYEE','Payroll Step1 rollback fixture');
 select count(*) into baseline_journals from public.journal_entries;
 -- Real canonical calculation, independent expected results and large exact intermediates.
 foreach days in array array[28,29,30,31] loop
  select * into calc from private.calculate_payroll_draft(9000000000000000,days,0,0,0);
  perform pg_temp.payroll_check(calc.net_salary_minor=9000000000000000 and calc.absence_deduction_minor=0,'exact full salary zero absence '||days);
  select * into calc from private.calculate_payroll_draft(9000000000000000,days,2*days,0,0);
  perform pg_temp.payroll_check(calc.net_salary_minor=0 and calc.absence_deduction_minor=9000000000000000,'all days absent exact large multiplication '||days);
 end loop;
 select * into calc from private.calculate_payroll_draft(30,30,1,0,0);perform pg_temp.payroll_check(calc.absence_deduction_minor=1,'half-away-from-zero tie');
 select * into calc from private.calculate_payroll_draft(100,30,4,0,0);perform pg_temp.payroll_check(calc.absence_deduction_minor=7,'single rounding not rounded daily rate');
 select * into calc from private.calculate_payroll_draft(3100,31,3,50,20);perform pg_temp.payroll_check(calc.absence_deduction_minor=150 and calc.gross_salary_minor=2950 and calc.net_salary_minor=2980,'mixed absences and adjustments');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(100,30,61,0,0)','23514');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(100,30,-1,0,0)','23514');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(100,30,0,0,101)','23514');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(9000000000000000,30,0,1,0)','23514');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(100,30,0,9000000000000001,0)','23514');
 perform pg_temp.payroll_reject('select private.calculate_payroll_draft(100,30,0,0.5,0)','23514');
 perform set_config('request.jwt.claim.sub',f.user_id::text,true);
 update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';
 set local role authenticated;
 perform public.save_employee_site_assignment(f.company_id,f.employee_id,f.project_id,'2024-01-01',null);
 profile_id:=public.save_payroll_profile(f.company_id,f.employee_id,0,' PAY-001 ','Monthly','Worker','Site',f.project_id,100,'CASH','ACTIVE');
 perform pg_temp.payroll_check(profile_id is not null,'profile create');
 doc:=public.read_payroll_profiles(f.company_id);
 perform pg_temp.payroll_check(doc->'profiles'->0->>'monthly_salary_minor'='100' and jsonb_typeof(doc->'profiles'->0->'monthly_salary_minor')='string','profile exact text');
 perform pg_temp.payroll_check(doc->'profiles'->0->>'payroll_id'='PAY-001','profile normalization');
 perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,0,''pay-001'',''Monthly'',''Worker'',''Site'',null,100,''CASH'',''ACTIVE'')',f.company_id,second_employee),'23505');
 perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,0,''PAY-X'',''Monthly'',''Worker'',''Site'',null,100,''CASH'',''ACTIVE'')',f.company_id,other_employee),'23514');
 perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,0,''PAY-X'',''Monthly'',''Worker'',''Site'',null,100,''CASH'',''ACTIVE'')',f.company_id,non_employee),'23514');
 perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,1,''PAY-001'',''Monthly'',''Worker'',''Site'',%L,100,''CASH'',''ACTIVE'')',f.company_id,f.employee_id,other_project),'23503');
 perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,0,''PAY-001'',''Monthly'',''Worker'',''Site'',null,100,''CASH'',''ACTIVE'')',f.company_id,f.employee_id),'40001');
 -- Month lengths and leap year through actual period refresh, not a browser calculation.
 foreach month in array array['2026-02-01'::date,'2024-02-01'::date,'2026-04-01'::date,'2026-01-01'::date] loop
  perform pg_temp.payroll_reject(format('select public.refresh_payroll_draft(%L,%L,0)',f.company_id,month),'23514');
  perform public.confirm_attendance_review(f.company_id,month,0);
  period_id:=public.refresh_payroll_draft(f.company_id,month,0);
  doc:=public.read_payroll_draft(f.company_id,month);
  expected_days:=case month when '2026-02-01' then 28 when '2024-02-01' then 29 when '2026-04-01' then 30 else 31 end;
  perform pg_temp.payroll_check((doc->'period'->>'calendar_days')::integer=expected_days,'month calendar '||month);
  perform pg_temp.payroll_check(doc->'rows'->0->>'net_salary_minor'='100' and not (doc->>'stale')::boolean,'zero absence stored full salary '||month);
 end loop;
 month:='2026-04-01';doc:=public.read_payroll_draft(f.company_id,month);period_id:=(doc->'period'->>'id')::uuid;row_id:=(doc->'rows'->0->>'id')::uuid;
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,month,'HALF_DAY',null,0);
 doc:=public.read_payroll_draft(f.company_id,month);
 perform pg_temp.payroll_check((doc->>'stale')::boolean and not(doc->>'attendance_review_valid')::boolean,'attendance invalidates payroll');
 perform pg_temp.payroll_reject(format('select public.refresh_payroll_draft(%L,%L,1)',f.company_id,month),'23514');
 reset role;select revision into ar from public.attendance_periods where company_id=f.company_id and attendance_periods.month=month;
 set local role authenticated;perform public.confirm_attendance_review(f.company_id,month,ar);
 perform public.refresh_payroll_draft(f.company_id,month,1);doc:=public.read_payroll_draft(f.company_id,month);
 perform pg_temp.payroll_check(doc->'rows'->0->>'absence_half_units'='1' and doc->'rows'->0->>'absence_deduction_minor'='2','half day on actual draft');
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,month+1,'FULL_DAY',null,0);
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,month+2,'HALF_DAY',null,0);
 reset role;select revision into ar from public.attendance_periods where company_id=f.company_id and attendance_periods.month=month;
 set local role authenticated;perform public.confirm_attendance_review(f.company_id,month,ar);perform public.refresh_payroll_draft(f.company_id,month,2);
 doc:=public.read_payroll_draft(f.company_id,month);
 perform pg_temp.payroll_check(doc->'rows'->0->>'absence_half_units'='4' and doc->'rows'->0->>'absence_deduction_minor'='7' and doc->'rows'->0->>'gross_salary_minor'='93','multiple absences round once actual draft');
 -- Accountant can manage/review; adjustment edits never change calculated rows until explicit refresh.
 reset role;update public.company_memberships set role='ACCOUNTANT' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';set local role authenticated;
 perform public.save_payroll_draft_adjustment(f.company_id,row_id,adjustment_id,0,'ADDITION',10,'Bonus',false,null);
 perform public.save_payroll_draft_adjustment(f.company_id,row_id,deduction_id,0,'DEDUCTION',3,'Other deduction',false,null);
 doc:=public.read_payroll_draft(f.company_id,month);period_version:=(doc->'period'->>'version')::integer;
 perform pg_temp.payroll_check((doc->>'stale')::boolean and doc->'rows'->0->>'net_salary_minor'='93','adjustments preserve stale calculated values');
 perform pg_temp.payroll_check(jsonb_typeof(doc->'adjustments'->0->'amount_minor')='string','adjustment exact text');
 perform pg_temp.payroll_reject(format('select public.review_payroll_draft(%L,%L,%s)',f.company_id,period_id,period_version),'40001');
 perform pg_temp.payroll_reject(format('select public.refresh_payroll_draft(%L,%L,3)',f.company_id,month),'40001');
 perform public.refresh_payroll_draft(f.company_id,month,period_version);doc:=public.read_payroll_draft(f.company_id,month);
 perform pg_temp.payroll_check(doc->'rows'->0->>'net_salary_minor'='100' and doc->'rows'->0->>'additions_minor'='10' and doc->'rows'->0->>'deductions_minor'='3','adjustments exact calculation');
 perform public.review_payroll_draft(f.company_id,period_id,(doc->'period'->>'version')::integer);
 perform pg_temp.payroll_check((public.read_payroll_draft(f.company_id,month)->>'review_valid')::boolean,'draft review current');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,0,''DEDUCTION'',101,''negative'',false,null)',f.company_id,row_id,gen_random_uuid()),'23514');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,0,''ADDITION'',9000000000000000,''overflow'',false,null)',f.company_id,row_id,gen_random_uuid()),'23514');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,0,''ADDITION'',1,''duplicate'',false,null)',f.company_id,row_id,adjustment_id),'40001');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,1,''ADDITION'',11,''edit'',false,null)',f.company_id,row_id,adjustment_id),'23514');
 perform public.save_payroll_draft_adjustment(f.company_id,row_id,adjustment_id,1,'ADDITION',11,'Corrected bonus',false,'Correction');
 perform public.save_payroll_draft_adjustment(f.company_id,row_id,deduction_id,1,'DEDUCTION',3,'Other deduction',true,'Void incorrect deduction');
 doc:=public.read_payroll_draft(f.company_id,month);perform public.refresh_payroll_draft(f.company_id,month,(doc->'period'->>'version')::integer);
 doc:=public.read_payroll_draft(f.company_id,month);perform pg_temp.payroll_check(doc->'rows'->0->>'net_salary_minor'='104','edit and void calculation');
 -- Profile changes invalidate without rewriting saved draft; refresh remains explicit.
 perform public.save_payroll_profile(f.company_id,f.employee_id,1,'PAY-001','Monthly','Worker','Site',null,200,'CASH','ACTIVE');
 doc:=public.read_payroll_draft(f.company_id,month);perform pg_temp.payroll_check((doc->>'stale')::boolean and doc->'rows'->0->>'monthly_salary_minor'='100','profile edit stales snapshot');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,0,''ADDITION'',1,''stale'',false,null)',f.company_id,row_id,gen_random_uuid()),'40001');
 perform public.refresh_payroll_draft(f.company_id,month,(doc->'period'->>'version')::integer);
 doc:=public.read_payroll_draft(f.company_id,month);perform pg_temp.payroll_check(doc->'rows'->0->>'monthly_salary_minor'='200','explicit profile refresh');
 perform public.save_payroll_profile(f.company_id,f.employee_id,2,'PAY-001','Monthly','Worker','Site',null,200,'CASH','INACTIVE');
 doc:=public.read_payroll_draft(f.company_id,month);
 perform pg_temp.payroll_reject(format('select public.refresh_payroll_draft(%L,%L,%s)',f.company_id,month,(doc->'period'->>'version')::integer),'23514');
 perform public.save_payroll_draft_adjustment(f.company_id,row_id,adjustment_id,2,'ADDITION',11,'Corrected bonus',true,'Employee excluded');
 doc:=public.read_payroll_draft(f.company_id,month);perform public.refresh_payroll_draft(f.company_id,month,(doc->'period'->>'version')::integer);
 perform pg_temp.payroll_check(not(public.read_payroll_draft(f.company_id,month)->'rows'->0->>'included')::boolean,'inactive profile excluded, history retained');
 perform public.save_payroll_profile(f.company_id,f.employee_id,3,'PAY-001','Monthly','Worker','Site',null,9000000000000000,'CASH','ACTIVE');
 doc:=public.read_payroll_draft(f.company_id,'2026-01-01');perform public.refresh_payroll_draft(f.company_id,'2026-01-01',(doc->'period'->>'version')::integer);
 doc:=public.read_payroll_draft(f.company_id,'2026-01-01');perform pg_temp.payroll_check(doc->'rows'->0->>'net_salary_minor'='9000000000000000' and jsonb_typeof(doc->'rows'->0->'net_salary_minor')='string','maximum money exact JSON string');
 perform pg_temp.payroll_reject(format('delete from public.payroll_profiles where id=%L',profile_id),'42501');
 perform pg_temp.payroll_reject(format('update public.payroll_draft_rows set net_salary_minor=1 where id=%L',row_id),'42501');
 perform pg_temp.payroll_reject(format('select public.read_payroll_profiles(%L)',other_company),'42501');
 perform pg_temp.payroll_reject(format('select public.read_payroll_draft(%L,%L)',other_company,month),'42501');
 perform pg_temp.payroll_reject(format('select public.save_payroll_draft_adjustment(%L,%L,%L,0,''ADDITION'',1,''foreign'',false,null)',other_company,row_id,gen_random_uuid()),'42501');
 reset role;
 foreach test_role in array enum_range(null::public.company_role) loop
  update public.company_memberships set role=test_role where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';set local role authenticated;
  if test_role in ('ACCOUNTING_ADMIN','ACCOUNTANT') then
   perform pg_temp.payroll_check(jsonb_array_length(public.read_payroll_profiles(f.company_id)->'profiles')=1,'profile role '||test_role);
  else
   perform pg_temp.payroll_reject(format('select public.read_payroll_profiles(%L)',f.company_id),'42501');
   perform pg_temp.payroll_reject(format('select public.read_payroll_draft(%L,%L)',f.company_id,month),'42501');
   perform pg_temp.payroll_reject(format('select public.refresh_payroll_draft(%L,%L,0)',f.company_id,month),'42501');
   perform pg_temp.payroll_reject(format('select public.save_payroll_profile(%L,%L,4,''PAY-001'',''Monthly'',''Worker'',''Site'',null,1,''CASH'',''ACTIVE'')',f.company_id,f.employee_id),'42501');
   foreach tbl in array array['payroll_profiles','payroll_draft_periods','payroll_draft_rows','payroll_draft_adjustments','payroll_draft_audit'] loop
    execute format('select count(*) from public.%I',tbl) into n;perform pg_temp.payroll_check(n=0,'no salary rows: '||test_role||' '||tbl);
   end loop;
  end if;reset role;
 end loop;
 update public.company_memberships set role='ACCOUNTANT',status='INACTIVE' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';set local role authenticated;
 perform pg_temp.payroll_reject(format('select public.read_payroll_profiles(%L)',f.company_id),'42501');reset role;
 update public.company_memberships set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id;
 update public.profiles set status='INACTIVE' where user_id=f.user_id;set local role authenticated;
 perform pg_temp.payroll_reject(format('select public.read_payroll_draft(%L,%L)',f.company_id,month),'42501');reset role;
 update public.profiles set status='ACTIVE' where user_id=f.user_id;
 perform pg_temp.payroll_check((select count(*) from public.payroll_draft_audit where entity='payroll_draft_adjustments' and entity_id=adjustment_id)=3,'adjustment immutable audit');
 perform pg_temp.payroll_check((select count(*) from public.journal_entries)=baseline_journals,'no accounting effect');
 perform pg_temp.payroll_check(not exists(select 1 from public.attendance_periods where company_id=f.company_id and locked_at is not null),'Payroll draft never locks attendance');
 perform pg_temp.payroll_check(not has_function_privilege('authenticated','private.calculate_payroll_draft(bigint,integer,integer,numeric,numeric)','EXECUTE'),'private calculation helper');
 perform pg_temp.payroll_reject(format('delete from public.payroll_draft_adjustments where id=%L',adjustment_id),'23514');
 perform pg_temp.payroll_reject(format('update public.payroll_draft_audit set entity=''bad'' where entity_id=%L',adjustment_id),'23514');
end $$;
select passed,'Payroll Step 1 rollback checks PASS' result from payroll_checks;
rollback;
