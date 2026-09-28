-- Forward correction: disambiguate draft-row aliases from PL/pgSQL loop records.
create or replace function public.prepare_payroll_accounting(target_company_id uuid,target_period_id uuid,target_version integer,target_allocations jsonb,target_classifications jsonb)
returns void language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare p public.payroll_draft_periods; r record; a jsonb; category text;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id for update;
 if not found or target_version is distinct from p.version then raise exception 'Draft changed; reload' using errcode='40001'; end if;
 if p.source_hash<>md5(private.payroll_draft_source(target_company_id,p.month)::text) or p.adjustments_revision<>p.calculated_adjustments_revision then
  raise exception 'Refresh current draft first' using errcode='40001'; end if;
 if jsonb_typeof(target_allocations) is distinct from 'object' or jsonb_typeof(target_classifications) is distinct from 'object' then raise exception 'Explicit allocation/classification required' using errcode='23514'; end if;
 if (select count(*) from jsonb_object_keys(target_allocations))<>(select count(*) from public.payroll_draft_rows where period_id=p.id and included) then raise exception 'Allocate every included employee exactly once' using errcode='23514'; end if;
 for r in select * from public.payroll_draft_rows where period_id=p.id and included loop
  a:=target_allocations->r.id::text;
  if a is null or (a<>'null'::jsonb and (jsonb_typeof(a)<>'string' or not exists(select 1 from public.projects where company_id=target_company_id and id=(a#>>'{}')::uuid and status<>'CLOSED'))) then
   raise exception 'Explicit Company overhead or eligible same-Company Project required' using errcode='23514'; end if;
 end loop;
 if (select count(*) from jsonb_object_keys(target_classifications))<>(select count(*) from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id where r.period_id=p.id and not a.voided) then raise exception 'Classify every live adjustment' using errcode='23514'; end if;
 for r in select a.* from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id where r.period_id=p.id and not a.voided loop
  category:=target_classifications->>r.id::text;
  if category is distinct from (case r.kind when 'ADDITION' then 'EARNED_SALARY_ADDITION' else 'CURRENT_SALARY_REDUCTION' end) then
   raise exception 'Unsupported adjustment accounting category' using errcode='23514'; end if;
 end loop;
 update public.payroll_draft_periods set version=version+1,reviewed_version=null,reviewed_by=null,reviewed_at=null where id=p.id;
 insert into public.payroll_draft_accounting(company_id,period_id,version,allocations,classifications,created_by)
 values(target_company_id,p.id,p.version+1,target_allocations,target_classifications,auth.uid());
end $$;
create or replace function public.post_payroll(target_company_id uuid,target_period_id uuid,target_version integer,target_idempotency_key uuid)
returns uuid language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
declare p public.payroll_draft_periods; plan public.payroll_draft_accounting; req private.financial_command_requests; r record;
 result_id uuid:=gen_random_uuid(); j uuid; payable uuid; cost uuid; project uuid; lines jsonb:='[]'::jsonb; snap jsonb; previous uuid;
begin
 if not public.has_permission(target_company_id,'payroll.post') then raise exception 'Payroll POST denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 req:=private.payroll_reserve(target_company_id,'POST_PAYROLL',target_idempotency_key,jsonb_build_object('period',target_period_id,'version',target_version));
 if req.status='COMPLETED' then return (select id from public.payroll_postings where company_id=target_company_id and journal_id=req.resulting_journal_entry_id); end if;
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id for update;
 if not found or target_version is distinct from p.version or p.reviewed_version is distinct from p.version then raise exception 'Fresh reviewed draft required' using errcode='40001'; end if;
 if (p.month+interval '1 month')::date>(current_timestamp at time zone 'Asia/Dubai')::date then raise exception 'Payroll month must be complete' using errcode='23514'; end if;
 -- Stabilize employee metadata/status while validating the exact reviewed source.
 perform 1 from public.parties e join public.payroll_profiles f on f.company_id=e.company_id and f.employee_id=e.id where f.company_id=target_company_id order by e.id for share of e;
 snap:=public.read_payroll_draft(target_company_id,p.month);
 if (snap->>'stale')::boolean or not (snap->>'review_valid')::boolean then raise exception 'Draft stale; refresh and review' using errcode='40001'; end if;
 select * into plan from public.payroll_draft_accounting where company_id=target_company_id and period_id=p.id and version=p.version;
 if not found then raise exception 'Explicit allocation and adjustment classification required' using errcode='23514'; end if;
 select id into payable from public.accounts where company_id=target_company_id and system_key='SALARY_PAYABLE' and account_type='LIABILITY' and status='ACTIVE' for share;
 if payable is null then raise exception 'Active SALARY_PAYABLE LIABILITY mapping required' using errcode='23514'; end if;
 for r in select * from public.payroll_draft_rows where period_id=p.id and included order by employee_id loop
  project:=(plan.allocations->>r.id::text)::uuid;
  if project is not null then
   perform 1 from public.projects where company_id=target_company_id and id=project and status<>'CLOSED' for share;
   if not found then raise exception 'Allocated Project unavailable' using errcode='23514'; end if;
  end if;
  select id into cost from public.accounts where company_id=target_company_id and system_key=case when project is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE' for share;
  if cost is null then raise exception 'Active cost EXPENSE mapping required' using errcode='23514'; end if;
  if r.net_salary_minor>0 then lines:=lines||jsonb_build_array(
   jsonb_build_object('account_id',cost,'debit_minor',r.net_salary_minor::text,'credit_minor','0','project_id',project,'party_id',r.employee_id),
   jsonb_build_object('account_id',payable,'debit_minor','0','credit_minor',r.net_salary_minor::text,'project_id',project,'party_id',r.employee_id)); end if;
 end loop;
 if jsonb_array_length(lines)=0 then raise exception 'All-zero payroll cannot post' using errcode='23514'; end if;
 perform private.lock_attendance_month(target_company_id,p.month,p.attendance_revision);
 j:=private.create_journal(target_company_id,(p.month+interval '1 month - 1 day')::date,'Payroll recognition','PAYROLL',result_id,'POST',lines,auth.uid());
 select x.id into previous from public.payroll_postings x join public.payroll_reversals v on v.payroll_id=x.id where x.company_id=target_company_id and x.month=p.month order by x.created_at desc,x.id desc limit 1;
 insert into public.payroll_postings(id,company_id,period_id,month,posting_date,draft_version,snapshot,journal_id,replaces_id,created_by)
 values(result_id,target_company_id,p.id,p.month,(p.month+interval '1 month - 1 day')::date,p.version,snap||jsonb_build_object('accounting',to_jsonb(plan)),j,previous,auth.uid());
 insert into public.payroll_entitlements(company_id,payroll_id,employee_id,project_id,cost_account_id,payable_account_id,amount_minor)
 select target_company_id,result_id,r.employee_id,(plan.allocations->>r.id::text)::uuid,a.id,payable,r.net_salary_minor
 from public.payroll_draft_rows r join public.accounts a on a.company_id=r.company_id and a.system_key=case when plan.allocations->>r.id::text is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end
 where r.period_id=p.id and r.included;
 insert into private.live_payroll_periods values(target_company_id,p.month,result_id);
 perform private.complete_financial_command(req.id,j); return result_id;
end $$;
