-- 92: read-only dashboard projections. No backfill, financial writes or permission changes.
-- INVOKER functions retain all canonical table RLS, including confidential payroll.
create function public.dashboard_verified_date(value text) returns date
language plpgsql immutable strict security invoker set search_path='' as $$
declare d date;begin
 if value !~ '^[0-9]{4}-(0[1-9]|1[0-2])-[0-9]{2}$' then return null;end if;
 d:=value::date;if to_char(d,'YYYY-MM-DD')<>value then return null;end if;return d;
 exception when datetime_field_overflow or invalid_datetime_format then return null;
end$$;
revoke all on function public.dashboard_verified_date(text) from public,anon,service_role;
grant execute on function public.dashboard_verified_date(text) to authenticated;

create function public.read_dashboard_sources(cid uuid,reporting_month text,project uuid default null,company_only boolean default false,include_unknown boolean default false)
returns table(id uuid,company_id uuid,reference text,activity_date date,report_month text,status text,event_type text,project_id uuid,description text,possible_duplicate boolean,journal_id text,document_id text)
language plpgsql stable security invoker set search_path='' as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Dashboard access denied'using errcode='42501';end if;
 if public.dashboard_verified_date(reporting_month||'-01')is null then raise exception 'Valid reporting month required'using errcode='22023';end if;
 return query
 select s.id,s.company_id,s.source_reference::text,d.dt,
 period.report_month,
 case when link.item->'correction' is not null and link.item->'correction'<>'null'::jsonb then case when (link.item->'correction'->>'reversed')::boolean then 'NEEDS_REVIEW'else 'POSTED'end
 when coalesce((link.item->>'reversed')::boolean,false)or x.status='REVERSED'then 'NEEDS_REVIEW'
 when pe.id is not null and exists(select 1 from public.payroll_reversals pr where pr.company_id=cid and pr.payroll_id=pe.payroll_id)then 'NEEDS_REVIEW'
 when link.item->'event'->>'state'='POSTED'or x.status='POSTED'or pe.id is not null then 'POSTED'
 when link.item->'event'->>'state' in('DRAFT','REVIEWED','APPROVED')then 'DRAFT'
 when s.review_status='REVIEWED'then 'CLASSIFIED_UNPOSTED'
 when coalesce(nullif(s.completion->>'nature',''),s.classification->>'nature','')not in('','NEEDS_REVIEW')then 'CLASSIFIED_UNPOSTED'
 else 'UNCLASSIFIED'end::text,
 coalesce(case when s.record_type='PAYROLL' then 'PAYROLL'end,case coalesce(link.item->'correction'->'receipt'->>'kind',link.item->>'kind') when 'CONTRACT_ADVANCE'then 'SUBCONTRACTOR_ADVANCE'when 'CONTRACT_PAYMENT'then 'SUBCONTRACTOR_PAYMENT'when 'EMPLOYEE_ADVANCE'then 'HR_EMPLOYEE_ADVANCE'when 'EXPENSE'then 'EXPENSE'end,case when s.expense_id is not null then 'EXPENSE'end,nullif(s.completion->>'nature',''),s.classification->>'nature',s.record_type)::text,s.assigned_project_id,s.description::text,
 coalesce(s.classification->'potential_duplicate'='true'::jsonb,false)or s.classification?'duplicate_group'or s.raw_source?'existing_match_candidates_unverified',
 coalesce(link.item->'correction'->'receipt'->>'journal',link.item->'event'->'receipt'->>'journal',x.posted_journal_entry_id::text,pp.journal_id::text),
 coalesce(link.item->'correction'->'receipt'->>'id',link.item->'event'->'receipt'->>'id',link.item->>'draft_id',s.expense_id::text,pe.id::text)
 from public.historical_source_records s
 cross join lateral(select public.dashboard_verified_date(case when s.completion?'date'then s.completion->>'date'else s.source_date::text end)dt)d
 cross join lateral(select case when s.record_type='PAYROLL' then to_char(public.dashboard_verified_date(coalesce(s.completion->>'salary_month',s.source_month)||'-01'),'YYYY-MM') else to_char(d.dt,'YYYY-MM')end report_month)period
 left join public.expenses x on x.company_id=cid and x.id=s.expense_id
 left join public.payroll_entitlements pe on pe.company_id=cid and pe.id=s.payroll_entitlement_id
 left join public.payroll_postings pp on pp.company_id=cid and pp.id=pe.payroll_id
 left join lateral(select item from jsonb_array_elements(public.read_source_document_links(cid,array[s.id]))item limit 1)link on s.record_type='GENERAL'
 where s.company_id=cid and s.review_status<>'CANCELLED'
 and(period.report_month=reporting_month or include_unknown and period.report_month is null)
 and(case when company_only then s.assigned_project_id is null when project is not null then s.assigned_project_id=project else true end);
end$$;
revoke all on function public.read_dashboard_sources(uuid,text,uuid,boolean,boolean)from public,anon,service_role;
grant execute on function public.read_dashboard_sources(uuid,text,uuid,boolean,boolean)to authenticated;

create function public.read_accounting_dashboard(cid uuid,selected_month date,comparison integer default 6,project uuid default null,company_only boolean default false)
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
 'custodyOther',coalesce(sum(l.net)filter(where system_key='CUSTODY_ADVANCE'and typ not in('CUSTODY_ADVANCE','PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','EXPENSE','SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYMENT','HR_EMPLOYEE_ADVANCE','CUSTODY_CASH_RETURN')),0)::text,
 'operating',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is null and typ<>'PAYROLL'),0)::text,
 'projectCost',coalesce(sum(l.net)filter(where account_type='EXPENSE'and project_id is not null),0)::text,
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
revoke all on function public.read_accounting_dashboard(uuid,date,integer,uuid,boolean)from public,anon,service_role;
grant execute on function public.read_accounting_dashboard(uuid,date,integer,uuid,boolean)to authenticated;

create function public.read_dashboard_transactions(cid uuid,month date,domain text default 'JOURNALS',page integer default 0,page_size integer default 25,search text default '',status_filter text default 'ALL',type_filter text default '',project uuid default null,company_only boolean default false,sort_order text default 'DESC',unknown_dates boolean default false)
returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare r jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Dashboard access denied'using errcode='42501';end if;
 if month is null or extract(day from month)<>1 or domain not in('JOURNALS','SOURCES')or page<0 or page>100000 or page_size not in(10,25,50)or length(search)>100 or length(type_filter)>80 or sort_order not in('ASC','DESC')or status_filter not in('ALL','POSTED','DRAFT','CLASSIFIED_UNPOSTED','UNCLASSIFIED','NEEDS_REVIEW','POSSIBLE_DUPLICATE')or project is not null and(company_only or not exists(select 1 from public.projects where company_id=cid and id=project))then raise exception 'Invalid transaction filters'using errcode='22023';end if;
 with source_rows as materialized(select * from public.read_dashboard_sources(cid,to_char(month,'YYYY-MM'),project,company_only,unknown_dates)where domain='SOURCES'),
 items as(
 select s.id,s.company_id,s.reference,s.activity_date date,s.status,s.event_type,s.project_id,s.description,s.journal_id,s.document_id,s.possible_duplicate from source_rows s where(case when unknown_dates then s.report_month is null else s.report_month=to_char(month,'YYYY-MM')end)
 union all
 select e.id,e.company_id,e.journal_reference,e.posting_date,'POSTED',e.source_type,null::uuid,e.description,e.id::text,e.source_id::text,false from public.journal_entries e where domain='JOURNALS'and not unknown_dates and e.company_id=cid and e.posting_date>=month and e.posting_date<month+interval '1 month'
 and(project is null and not company_only or exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=e.id and(case when company_only then l.project_id is null else l.project_id=project end)))
 ),matching as materialized(select * from items i where i.company_id=cid
 and(domain='JOURNALS'or case when company_only then i.project_id is null when project is not null then i.project_id=project else true end)
 and(status_filter='ALL'or status_filter='NEEDS_REVIEW'and i.status<>'POSTED'or status_filter='POSSIBLE_DUPLICATE'and i.possible_duplicate or i.status=status_filter)
 and(type_filter=''or i.event_type=type_filter)
 and(search=''or strpos(lower(coalesce(i.reference,'')||' '||coalesce(i.description,'')||' '||i.id::text||' '||coalesce(i.document_id,'')||' '||coalesce(i.journal_id,'')),lower(search))>0)),
 paged as(select * from matching order by case when sort_order='ASC'then date end asc nulls last,case when sort_order='DESC'then date end desc nulls last,id limit page_size offset page::bigint*page_size)
 select jsonb_build_object('company',cid,'total',(select count(*)from matching),'page',page,'pageSize',page_size,'rows',coalesce((select jsonb_agg(to_jsonb(paged))from paged),'[]'::jsonb))into r;return r;
end$$;
revoke all on function public.read_dashboard_transactions(uuid,date,text,integer,integer,text,text,text,uuid,boolean,text,boolean)from public,anon,service_role;
grant execute on function public.read_dashboard_transactions(uuid,date,text,integer,integer,text,text,text,uuid,boolean,text,boolean)to authenticated;
