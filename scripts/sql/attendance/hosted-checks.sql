-- MakerACC-Development ONLY. Existing synthetic identities; all fixtures and role changes roll back.
begin;
create temp table attendance_test_results(passed integer not null);
insert into attendance_test_results values(0);
grant select,update on attendance_test_results to authenticated;
create function pg_temp.check_attendance(ok boolean,label text) returns void language plpgsql as $$
begin if ok is distinct from true then raise exception 'FAIL: %',label; end if; update attendance_test_results set passed=passed+1; end $$;
create function pg_temp.attendance_denied(statement text,expected_code text) returns void language plpgsql as $$
begin
 begin execute statement; exception when others then
  if sqlstate=expected_code then perform pg_temp.check_attendance(true,statement); return; else raise; end if;
 end;
 raise exception 'Expected rejection: %',statement;
end $$;
do $$
declare f record; second_user uuid; other_project uuid; other_company uuid; other_employee uuid;
 a uuid; x uuid; day date:=((date_trunc('month',current_date)-interval '1 month')::date+5); mon date;
 result jsonb; revision integer; r public.company_role; table_name text; count_rows integer; baseline_journals bigint;
begin
 mon:=date_trunc('month',day)::date;
 select c.id company_id,m.user_id,p.id project_id,e.id employee_id into f
 from public.companies c join public.company_memberships m on m.company_id=c.id and m.status='ACTIVE'
 join public.profiles u on u.user_id=m.user_id and u.status='ACTIVE'
 join public.projects p on p.company_id=c.id and p.status<>'CLOSED'
 join public.parties e on e.company_id=c.id and e.type='EMPLOYEE' and e.status='ACTIVE'
 where c.status='ACTIVE' and (select count(*) from public.projects p2 where p2.company_id=c.id and p2.status<>'CLOSED')>=2
 order by c.id,m.user_id,p.id limit 1;
 if f.user_id is null then raise exception 'No synthetic attendance fixture'; end if;
 select m.user_id into second_user from public.company_memberships m join public.profiles p on p.user_id=m.user_id and p.status='ACTIVE'
 where m.company_id=f.company_id and m.status='ACTIVE' and m.user_id<>f.user_id limit 1;
 select id into other_project from public.projects where company_id=f.company_id and id<>f.project_id and status<>'CLOSED' limit 1;
 select company_id,id into other_company,other_employee from public.parties where company_id<>f.company_id and type='EMPLOYEE' limit 1;
 if second_user is null or other_company is null then raise exception 'Missing second actor/tenant'; end if;
 select count(*) into baseline_journals from public.journal_entries;
 perform set_config('request.jwt.claim.sub',f.user_id::text,true);
 update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';
 set local role authenticated;
 a:=public.save_employee_site_assignment(f.company_id,f.employee_id,f.project_id,mon,null);
 perform pg_temp.check_attendance(a is not null,'assignment created');
 perform pg_temp.attendance_denied(format('select public.save_employee_site_assignment(%L,%L,%L,%L,null)',f.company_id,f.employee_id,other_project,day),'23514');
 perform pg_temp.attendance_denied(format('select public.save_employee_site_assignment(%L,%L,%L,%L,null)',f.company_id,other_employee,f.project_id,day),'23514');
 reset role;
 update public.project_assignments set status='INACTIVE' where company_id=f.company_id and user_id in(f.user_id,second_user);
 insert into public.project_assignments(company_id,project_id,user_id,created_by) values(f.company_id,f.project_id,f.user_id,f.user_id),(f.company_id,f.project_id,second_user,f.user_id);
 update public.company_memberships set role='FOREMAN' where company_id=f.company_id and user_id in(f.user_id,second_user) and status='ACTIVE';
 set local role authenticated;
 result:=public.attendance_context(f.company_id);
 perform pg_temp.check_attendance(jsonb_array_length(result->'projects')=1 and jsonb_array_length(result->'employees')=0,'Foreman context is assigned project only');
 result:=public.attendance_day(f.company_id,f.project_id,day);
 perform pg_temp.check_attendance(jsonb_array_length(result->'rows')=1 and result->'rows'->0->'entry'='null'::jsonb,'eligible no exception means present');
 perform pg_temp.check_attendance(jsonb_array_length(public.attendance_day(f.company_id,f.project_id,mon-1)->'rows')=0,'effective date roster');
 perform pg_temp.attendance_denied(format('select public.attendance_day(%L,%L,%L)',f.company_id,other_project,day),'42501');
 perform pg_temp.attendance_denied(format('select public.attendance_context(%L)',other_company),'42501');
 perform pg_temp.attendance_denied(format('select public.attendance_month(%L,%L)',f.company_id,mon),'42501');
 perform pg_temp.attendance_denied(format('select public.save_employee_site_assignment(%L,%L,%L,%L,null)',f.company_id,f.employee_id,other_project,day),'42501');
 x:=public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,day,'HALF_DAY',' initial ',0);
 perform pg_temp.check_attendance(public.attendance_day(f.company_id,f.project_id,day)->'rows'->0->'entry'->>'kind'='HALF_DAY','half-day stored');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''FULL_DAY'',null,0)',f.company_id,f.project_id,f.employee_id,day),'40001');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''QUARTER_DAY'',null,0)',f.company_id,f.project_id,f.employee_id,day+1),'23514');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''HALF_DAY'',null,0)',f.company_id,f.project_id,f.employee_id,current_date+1),'23514');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''HALF_DAY'',null,0)',f.company_id,f.project_id,f.employee_id,mon-1),'23514');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''HALF_DAY'',null,0)',f.company_id,f.project_id,other_employee,day),'23514');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''FULL_DAY'',null,1)',f.company_id,f.project_id,f.employee_id,day),'23514');
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,day,'FULL_DAY',' corrected ',1,false,'full day correction');
 perform pg_temp.check_attendance(public.attendance_day(f.company_id,f.project_id,day)->'rows'->0->'entry'->>'kind'='FULL_DAY','full-day correction');
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,day,'FULL_DAY',null,2,true,'recorded in error');
 perform pg_temp.check_attendance((public.attendance_day(f.company_id,f.project_id,day)->'rows'->0->'entry'->>'voided')::boolean,'void preserved');
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,day,'HALF_DAY',null,3,false,'restore correct absence');
 perform pg_temp.attendance_denied(format('delete from public.attendance_exceptions where id=%L',x),'42501');
 perform pg_temp.attendance_denied(format('update public.attendance_exceptions set kind=''FULL_DAY'' where id=%L',x),'42501');
 perform pg_temp.attendance_denied(format('select private.lock_attendance_month(%L,%L,0)',f.company_id,mon),'42501');
 perform pg_temp.check_attendance(not public.has_permission(f.company_id,'accounting.view') and not public.has_permission(f.company_id,'accounting.post')
  and not public.has_permission(f.company_id,'accounting.reverse') and not public.has_permission(f.company_id,'treasury.view'),'no financial permissions');
 -- Real RLS reads, across existing nonempty financial tables. No financial mutations.
 foreach table_name in array array['parties','accounts','treasury_accounts','expenses','supplier_payments','supplier_payment_allocations',
 'journal_entries','journal_lines','subcontracts','subcontractor_advances','subcontractor_certificates','subcontractor_payments',
 'custody_advances','custody_settlements','custody_settlement_items','custody_cash_returns','subcontractor_certificate_deductions',
 'subcontractor_payment_allocations','subcontractor_retention_release_allocations','subcontractor_retention_payment_allocations','certificate_deduction_account_mappings',
 'subcontractor_retention_releases','subcontractor_retention_payments','attendance_exceptions','employee_site_assignments','attendance_periods','attendance_audit'] loop
  execute format('select count(*) from public.%I',table_name) into count_rows;
  perform pg_temp.check_attendance(count_rows=0,'Foreman raw data denied: '||table_name);
 end loop;
 perform pg_temp.attendance_denied(format('select public.reverse_expense(%L,%L,current_date,''denied'',gen_random_uuid())',f.company_id,x),'42501');
 reset role;
 -- Another authorized Foreman can see site records but cannot change the first recorder's entry.
 perform set_config('request.jwt.claim.sub',second_user::text,true); set local role authenticated;
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''FULL_DAY'',null,4,false,''other actor'')',f.company_id,f.project_id,f.employee_id,day),'42501');
 reset role; perform set_config('request.jwt.claim.sub',f.user_id::text,true);
 update public.project_assignments set status='INACTIVE' where company_id=f.company_id and user_id=f.user_id;
 set local role authenticated;
 perform pg_temp.attendance_denied(format('select public.attendance_day(%L,%L,%L)',f.company_id,f.project_id,day),'42501');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''FULL_DAY'',null,4,false,''revoked'')',f.company_id,f.project_id,f.employee_id,day),'42501');
 reset role;
 update public.project_assignments set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id and project_id=f.project_id;
 update public.profiles set status='INACTIVE' where user_id=f.user_id;
 set local role authenticated;
 perform pg_temp.attendance_denied(format('select public.attendance_context(%L)',f.company_id),'42501');
 reset role; update public.profiles set status='ACTIVE' where user_id=f.user_id;
 update public.company_memberships set status='INACTIVE' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';
 set local role authenticated;
 perform pg_temp.attendance_denied(format('select public.attendance_context(%L)',f.company_id),'42501');
 reset role; update public.company_memberships set status='ACTIVE' where company_id=f.company_id and user_id=f.user_id;
 -- Existing role matrix, monthly review and Admin correction of another actor's entry.
 foreach r in array enum_range(null::public.company_role) loop
  update public.company_memberships set role=r where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';
  set local role authenticated;
  if r in ('ACCOUNTANT','ACCOUNTING_ADMIN') then
   result:=public.attendance_month(f.company_id,mon);
   perform pg_temp.check_attendance(jsonb_array_length(result->'exceptions')=1,'review reader '||r);
  else perform pg_temp.attendance_denied(format('select public.attendance_month(%L,%L)',f.company_id,mon),'42501'); end if;
  if r not in ('ACCOUNTANT','ACCOUNTING_ADMIN','FOREMAN') then
   perform pg_temp.attendance_denied(format('select public.attendance_context(%L)',f.company_id),'42501'); end if;
  reset role;
 end loop;
 update public.company_memberships set role='ACCOUNTANT' where company_id=f.company_id and user_id=f.user_id and status='ACTIVE';
 set local role authenticated;
 revision:=(public.attendance_month(f.company_id,mon)->'period'->>'revision')::integer;
 perform public.confirm_attendance_review(f.company_id,mon,revision);
 perform pg_temp.check_attendance((public.attendance_month(f.company_id,mon)->'period'->>'reviewed_revision')::integer=revision,'review exact snapshot');
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''FULL_DAY'',null,4,false,''accountant denied'')',f.company_id,f.project_id,f.employee_id,day),'42501');
 reset role;
 update public.company_memberships set role='ACCOUNTING_ADMIN' where company_id=f.company_id and user_id=second_user and status='ACTIVE';
 perform set_config('request.jwt.claim.sub',second_user::text,true); set local role authenticated;
 perform public.save_attendance_exception(f.company_id,f.project_id,f.employee_id,day,'FULL_DAY',null,4,false,'Admin correction');
 result:=public.attendance_month(f.company_id,mon);
 perform pg_temp.check_attendance(result->'period'->>'reviewed_revision' is null,'correction invalidates review');
 perform pg_temp.check_attendance(result->'exceptions'->0->>'created_by'=f.user_id::text and result->'exceptions'->0->>'updated_by'=second_user::text,'server provenance retained');
 perform pg_temp.attendance_denied(format('select public.confirm_attendance_review(%L,%L,%s)',f.company_id,mon,revision),'40001');
 perform pg_temp.attendance_denied(format('select public.save_employee_site_assignment(%L,%L,%L,%L,%L,%L,1,''strands history'')',f.company_id,f.employee_id,f.project_id,mon,day-1,a),'23514');
 revision:=(result->'period'->>'revision')::integer;
 perform public.confirm_attendance_review(f.company_id,mon,revision);
 reset role;
 perform private.lock_attendance_month(f.company_id,mon,revision);
 set local role authenticated;
 perform pg_temp.attendance_denied(format('select public.save_attendance_exception(%L,%L,%L,%L,''HALF_DAY'',null,5,false,''locked'')',f.company_id,f.project_id,f.employee_id,day),'23514');
 perform pg_temp.attendance_denied(format('select public.save_employee_site_assignment(%L,%L,%L,%L,%L,%L,1,''locked interval'')',f.company_id,f.employee_id,f.project_id,mon,day+1,a),'23514');
 -- Ending after the locked month is safe, and a later non-overlapping transfer is allowed.
 perform public.save_employee_site_assignment(f.company_id,f.employee_id,f.project_id,mon,(mon+interval '1 month')::date-1,a,1,'future site transfer');
 perform public.save_employee_site_assignment(f.company_id,f.employee_id,other_project,(mon+interval '1 month')::date,null);
 reset role;
 perform pg_temp.check_attendance((select count(*) from public.attendance_exceptions where id=x)=1,'single employee/date document');
 perform pg_temp.check_attendance((select count(*) from public.attendance_audit where entity='attendance_exceptions' and entity_id=x::text)=5,'complete create/correct/void/restore audit');
 perform pg_temp.attendance_denied(format('delete from public.attendance_exceptions where id=%L',x),'23514');
 perform pg_temp.attendance_denied(format('update public.attendance_audit set entity=''changed'' where entity_id=%L',x::text),'23514');
 perform pg_temp.check_attendance((select count(*) from public.journal_entries)=baseline_journals,'zero accounting effect');
 perform pg_temp.check_attendance(not has_function_privilege('authenticated','private.lock_attendance_month(uuid,date,integer)','EXECUTE'),'private payroll integration only');
 perform pg_temp.check_attendance(not exists(select 1 from information_schema.columns cols where cols.table_schema='public' and cols.table_name in
 ('employee_site_assignments','attendance_exceptions','attendance_periods','attendance_audit') and column_name ilike '%salary%'),'no payroll data introduced');
end $$;
select passed, 'Attendance rollback-only checks PASS' as result from attendance_test_results;
rollback;
