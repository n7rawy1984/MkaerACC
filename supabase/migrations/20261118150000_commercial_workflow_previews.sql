-- 99: Read-only operational previews and scoped workspace metadata. No financial mutations.
create function public.preview_commercial_accounting(cid uuid,kind text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
declare plan jsonb;begin
 perform private.operational_finance_actor(cid,'accounting.post');
 if jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>16000 then raise exception 'Invalid preview'using errcode='22023';end if;
 input:=private.normalize_commercial_input(input);
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 if kind like 'AR_%'then plan:=private.customer_plan(cid,kind,input);else plan:=private.recognition_plan(cid,kind,input);end if;
 return jsonb_build_object('amount',plan->>'amount','lines',(select jsonb_agg(x||jsonb_build_object('code',a.code,'name',a.name))from jsonb_array_elements(plan->'lines')x join public.accounts a on a.company_id=cid and a.id=(x->>'account_id')::uuid));end;$$;
create function public.read_commercial_workspace(cid uuid)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Commercial workspace access denied'using errcode='42501';end if;
 return jsonb_build_object(
 'accounts',coalesce((select jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'type',account_type,'requires_party',requires_party,'active',status::text='ACTIVE')order by code)from public.accounts where company_id=cid),'[]'::jsonb),
 'parties',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'active',status::text='ACTIVE'))from public.parties where company_id=cid and type::text in('OTHER','SUPPLIER')),'[]'::jsonb),
 'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name))from public.projects where company_id=cid),'[]'::jsonb),
 'treasuries',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name,'account_id',gl_account_id))from public.treasury_accounts where company_id=cid and status::text='ACTIVE'),'[]'::jsonb),
 'controls',coalesce((select jsonb_object_agg(key,account_id)from public.commercial_controls where company_id=cid),'{}'::jsonb),
 'years',coalesce((select jsonb_agg(to_jsonb(y)||jsonb_build_object('state',coalesce(c.state,'OPEN'),'version',coalesce(c.version,0)))from public.accounting_fiscal_years y left join public.accounting_year_closures c on c.company_id=y.company_id and c.year_id=y.id where y.company_id=cid),'[]'::jsonb));end;$$;
revoke all on function public.preview_commercial_accounting(uuid,text,jsonb),public.read_commercial_workspace(uuid)from public,anon,authenticated,service_role;
grant execute on function public.preview_commercial_accounting(uuid,text,jsonb),public.read_commercial_workspace(uuid)to authenticated;

create function public.preview_annual_closing(cid uuid,year_id uuid)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare c public.accounting_year_closures;lines jsonb;begin
 perform private.operational_finance_actor(cid,'account.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or not public.has_permission(cid,'payroll.manage')then raise exception 'Accounting Admin full-ledger authority required'using errcode='42501';end if;
 select *into c from public.accounting_year_closures where company_id=cid and accounting_year_closures.year_id=preview_annual_closing.year_id;
 if c.state='FINAL'then
 select coalesce(jsonb_agg(private.commercial_line(l.account_id,l.debit_minor+l.credit_minor,l.debit_minor>0,l.party_id,l.project_id,l.treasury_account_id)||jsonb_build_object('subcontract_id',l.subcontract_id)order by l.line_number),'[]'::jsonb)into lines from public.journal_lines l where l.company_id=cid and l.journal_entry_id=c.journal_id;
 else lines:=private.annual_close_plan(cid,year_id);end if;
 return jsonb_build_object('action',case when c.state='FINAL'then 'REOPEN'else 'FINALIZE'end,'lines',coalesce((select jsonb_agg(x||jsonb_build_object('code',a.code,'name',a.name))from jsonb_array_elements(lines)x join public.accounts a on a.company_id=cid and a.id=(x->>'account_id')::uuid),'[]'::jsonb));end;$$;
revoke all on function public.preview_annual_closing(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.preview_annual_closing(uuid,uuid)to authenticated;

-- Annual transfers clear GL balances, not actual operating/Project costs.
create or replace function public.read_accounting_dashboard(cid uuid,selected_month date,comparison integer default 6,project uuid default null,company_only boolean default false)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;hr boolean;complete boolean;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Dashboard access denied'using errcode='42501';end if;
 if selected_month is null or extract(day from selected_month)<>1 or comparison not in(6,12)or selected_month<'0002-01-01'::date or selected_month>'9998-12-01'::date or project is not null and(company_only or not exists(select 1 from public.projects where company_id=cid and id=project))then raise exception 'Invalid dashboard scope'using errcode='22023';end if;
 hr:=public.has_permission(cid,'payroll.manage');
 select coalesce(bool_and(public.custody_reporting_complete(cid,p.id)),true)into complete from public.parties p where p.company_id=cid;
 with months as(select generate_series(selected_month-make_interval(months=>comparison-1),selected_month,'1 month')::date m),
 ledger as(
 select e.id,e.posting_date,coalesce(o.source_type,e.source_type)typ,a.system_key,a.account_type,l.project_id,
 l.debit_minor::numeric-l.credit_minor::numeric net,t.type treasury_type,t.id treasury_id, a.id account_id
 from public.journal_entries e join public.journal_lines l on l.company_id=cid and l.journal_entry_id=e.id
 join public.accounts a on a.company_id=cid and a.id=l.account_id
 left join public.journal_entries o on o.company_id=cid and o.id=e.reversal_of_journal_entry_id
 left join public.treasury_accounts t on t.company_id=cid and t.gl_account_id=a.id
 where e.company_id=cid and e.posting_date<selected_month+interval '1 month'
 and(case when company_only then l.project_id is null when project is not null then l.project_id=project else true end)
 ),rows as(select to_char(m.m,'YYYY-MM') as month,
 (select count(distinct id)from ledger where posting_date>=m.m and posting_date<m.m+interval '1 month')journals,
 coalesce((select sum(net)from ledger where system_key='CUSTODY_ADVANCE'and posting_date<m.m),0)::text "custodyOpening",
 coalesce((select sum(net)from ledger where system_key='CUSTODY_ADVANCE'and posting_date<m.m+interval '1 month'),0)::text "custodyClosing",
 coalesce((select sum(net)from ledger where treasury_id is not null and posting_date<m.m),0)::text "treasuryOpening",
 coalesce((select sum(net)from ledger where treasury_id is not null and posting_date<m.m+interval '1 month'),0)::text "treasuryClosing",
 jsonb_build_object(
 'treasuryIn',coalesce(sum(l.net)filter(where treasury_id is not null and net>=0),0)::text,
 'treasuryOut',coalesce(-sum(l.net)filter(where treasury_id is not null and net<0),0)::text,
 'cashChange',coalesce(sum(l.net)filter(where treasury_type in('CASH','PETTY_CASH','PROJECT_CASH_BOX')),0)::text,
 'bankChange',coalesce(sum(l.net)filter(where treasury_id is not null and treasury_type not in('CASH','PETTY_CASH','PROJECT_CASH_BOX')),0)::text,
 'custodyFunding',coalesce(sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ in('CUSTODY_ADVANCE','PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING')),0)::text,
 'custodyPayments',coalesce(-sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ in('EXPENSE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','HR_EMPLOYEE_ADVANCE')),0)::text,
 'custodyReturns',coalesce(-sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ='CUSTODY_CASH_RETURN'),0)::text,
 'custodyOther',coalesce(sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ not in('CUSTODY_ADVANCE','PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','EXPENSE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','HR_EMPLOYEE_ADVANCE','CUSTODY_CASH_RETURN','SUPPLIER_PAYMENT','SUPPLIER_ADVANCE')),0)::text,
 'operating',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is null and typ not in('PAYROLL','ANNUAL_CLOSE')),0)::text,
 'projectCost',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is not null and typ<>'ANNUAL_CLOSE'),0)::text,
 'contractAdvances',coalesce(sum(l.net)filter(where system_key='SUBCONTRACTOR_ADVANCE'),0)::text,
 'contractSettlements',coalesce(sum(l.net)filter(where system_key in('SUBCONTRACTOR_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE')and typ in('SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_PAYMENT')),0)::text,
 'employeeAdvances',case when hr then coalesce(sum(l.net)filter(where typ='HR_EMPLOYEE_ADVANCE'and account_type='ASSET'and system_key is distinct from 'CUSTODY_ADVANCE'and treasury_id is null),0)::text end,
 'payrollCost',case when hr then coalesce(sum(l.net)filter(where typ='PAYROLL'and account_type='EXPENSE'),0)::text end,
 'payrollPayments',case when hr then coalesce(sum(l.net)filter(where typ='SALARY_PAYMENT'and system_key='SALARY_PAYABLE'),0)::text end,
 'stockValue',coalesce(sum(l.net)filter(where l.account_id=(select inventory_account_id from public.inventory_configuration where company_id=cid)),0)::text
 )"values" from months m left join ledger l on l.posting_date>=m.m and l.posting_date<m.m+interval '1 month'group by m.m
 ),sources as materialized(select * from public.read_dashboard_sources(cid,to_char(selected_month,'YYYY-MM'),project,company_only,true)),counts as(
 select count(*)filter(where report_month=to_char(selected_month,'YYYY-MM'))total,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='POSTED')posted,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='DRAFT')draft,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='CLASSIFIED_UNPOSTED')classified,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status='UNCLASSIFIED')unclassified,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and status<>'POSTED')review,
 count(*)filter(where report_month=to_char(selected_month,'YYYY-MM')and possible_duplicate)duplicates,
 count(*)filter(where report_month is null)unknown
 from sources)
 select jsonb_build_object('company',cid,'month',to_char(selected_month,'YYYY-MM'),'rows',(select jsonb_agg(to_jsonb(rows)order by month)from rows),'counts',(select to_jsonb(counts)from counts),'payrollVisible',hr,'custodyComplete',complete,'captured',statement_timestamp())into result;
 -- Confidential incomplete Custody must never appear as a verified partial balance.
 if not complete then select jsonb_set(result,'{rows}',jsonb_agg((x-'custodyOpening'-'custodyClosing')||jsonb_build_object('custodyOpening',null,'custodyClosing',null,'values',(x->'values')||jsonb_build_object('custodyFunding',null,'custodyPayments',null,'custodyReturns',null,'custodyOther',null))))into result from jsonb_array_elements(result->'rows')x;end if;
 -- HR journal RLS can hide Treasury salary movements and Project payroll cost.
 -- Never turn that partial view into a claimed complete closing balance.
 if not hr then select jsonb_set(result,'{rows}',jsonb_agg(x||jsonb_build_object('treasuryOpening',null,'treasuryClosing',null,'values',(x->'values')||jsonb_build_object('treasuryIn',null,'treasuryOut',null,'cashChange',null,'bankChange',null,'projectCost',null))))into result from jsonb_array_elements(result->'rows')x;end if;
 return result;
end$$;
create or replace function private.project_lifecycle_dependencies(cid uuid,pid uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
 'pending_sources',(select count(*) from public.historical_source_records r left join public.source_expense_allocation_events a on a.company_id=r.company_id and a.id=r.expense_allocation_id
 where r.company_id=cid and r.review_status<>'CANCELLED' and r.record_type='GENERAL' and r.expense_id is null and not exists(select 1 from private.financial_command_requests q where q.company_id=cid and q.idempotency_key=r.id and q.command_type='POST_EXPENSE' and q.status='COMPLETED') and
 (r.assigned_project_id=pid or (r.allocation_scope is null and r.expense_allocation_id is null and r.completion->>'project_id'=pid::text) or exists(select 1 from jsonb_array_elements(coalesce(a.plan->'destinations','[]'::jsonb)) d where d->>'project_id'=pid::text))),
 'open_subcontracts',(select count(*) from public.subcontracts s where s.company_id=cid and s.project_id=pid and s.status<>'CLOSED'),
 'draft_certificates',(select count(*) from public.subcontractor_certificates c where c.company_id=cid and c.project_id=pid and c.status='DRAFT' and not exists(select 1 from public.subcontract_certificate_withdrawals w where w.company_id=cid and w.certificate_id=c.id)),
 'pending_corrections',(select count(*) from public.expense_correction_reviews r
 where r.company_id=cid and (r.original_project_id=pid or r.proposed_project_id=pid or exists(select 1 from public.expenses e, lateral jsonb_array_elements(coalesce(e.allocation_plan->'destinations','[]'::jsonb)) d where e.company_id=cid and e.id=r.expense_id and d->>'project_id'=pid::text))
 and not exists(select 1 from public.expense_correction_reviews n where n.company_id=cid and n.previous_review_id=r.id)
 and not exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.review_id=r.id)),
 'posted_split_expenses',(select count(*) from public.expenses e where e.company_id=cid and e.allocation_plan is not null and exists(select 1 from jsonb_array_elements(e.allocation_plan->'destinations') d where d->>'project_id'=pid::text)),
 'cost_debit_minor',(select coalesce(sum(l.debit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'and not exists(select 1 from public.journal_entries e left join public.journal_entries o on o.company_id=e.company_id and o.id=e.reversal_of_journal_entry_id where e.company_id=l.company_id and e.id=l.journal_entry_id and(e.source_type='ANNUAL_CLOSE'or o.source_type='ANNUAL_CLOSE'))),
 'cost_credit_minor',(select coalesce(sum(l.credit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'and not exists(select 1 from public.journal_entries e left join public.journal_entries o on o.company_id=e.company_id and o.id=e.reversal_of_journal_entry_id where e.company_id=l.company_id and e.id=l.journal_entry_id and(e.source_type='ANNUAL_CLOSE'or o.source_type='ANNUAL_CLOSE'))),
 -- Separate actual GL dimensions; never net assets, liabilities or contracts together.
 'obligations',coalesce((select jsonb_agg(to_jsonb(b) order by account_code,subcontract_id,party_id) from
 (select a.code account_code,a.name account_name,a.system_key::text category,l.subcontract_id,l.party_id,s.contract_number,
 sum(l.debit_minor::numeric-l.credit_minor::numeric)::text balance_minor
 from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id
 left join public.subcontracts s on s.company_id=l.company_id and s.id=l.subcontract_id
 where l.company_id=cid and l.project_id=pid and a.requires_party and a.account_type in ('ASSET','LIABILITY','EQUITY')
 group by a.id,a.code,a.name,a.system_key,l.subcontract_id,l.party_id,s.contract_number
 having sum(l.debit_minor::numeric-l.credit_minor::numeric)<>0) b),'[]'::jsonb),
 'coverage','PROJECT_JOURNAL_DIMENSIONS_ONLY','closure','POLICY_UNAVAILABLE');
$$;
