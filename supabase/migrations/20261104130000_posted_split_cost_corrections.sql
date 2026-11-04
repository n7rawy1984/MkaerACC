-- Cash-neutral correction of immutable originally allocated Expenses. No historical DML.
alter table public.project_cost_corrections add column original_allocation_plan jsonb,
 add constraint correction_original_allocation_shape check(original_allocation_plan is null or (jsonb_typeof(original_allocation_plan)='object' and allocation_plan is not null));

-- Validate original provenance and the complete journal, never an aggregate Project header.
create function private.valid_original_expense_split(e public.expenses) returns boolean
language plpgsql stable set search_path='' as $$
declare normalized jsonb;d jsonb;aid uuid;t public.treasury_accounts;begin
 if e.allocation_event_id is null or e.allocation_plan is null or e.project_id is not null then return false;end if;
 normalized:=private.shared_cost_plan(e.net_amount_minor,jsonb_set(e.allocation_plan-array['rounding','weight_scale'],'{destinations}',(select jsonb_agg(v-'amount_minor') from jsonb_array_elements(e.allocation_plan->'destinations') v)));
 if normalized is distinct from e.allocation_plan or not exists(select 1 from public.source_expense_allocation_events a where a.company_id=e.company_id and a.id=e.allocation_event_id and a.plan=e.allocation_plan and a.source_amount_minor=e.net_amount_minor and a.source_date=e.expense_date) then return false;end if;
 select * into t from public.treasury_accounts where company_id=e.company_id and id=e.treasury_account_id;
 if not exists(select 1 from public.journal_entries j where j.company_id=e.company_id and j.id=e.posted_journal_entry_id and j.source_type='EXPENSE' and j.source_id=e.id and j.posting_purpose='ORIGINAL' and j.reversal_of_journal_entry_id is null)
 or (select count(*) from public.journal_lines where company_id=e.company_id and journal_entry_id=e.posted_journal_entry_id)<>jsonb_array_length(normalized->'destinations')+1
 or not exists(select 1 from public.journal_lines l where l.company_id=e.company_id and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=t.gl_account_id and l.credit_minor=e.net_amount_minor and l.debit_minor=0 and l.treasury_account_id=t.id and l.project_id is null and l.party_id is null and l.subcontract_id is null) then return false;end if;
 for d in select value from jsonb_array_elements(normalized->'destinations') loop
  select id into aid from public.accounts where company_id=e.company_id and system_key=case when d->>'project_id' is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
  if aid is null or (select count(*) from public.journal_lines l where l.company_id=e.company_id and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=aid and l.debit_minor=(d->>'amount_minor')::bigint and l.credit_minor=0 and l.project_id is not distinct from (d->>'project_id')::uuid and l.treasury_account_id is null and l.party_id is null and l.subcontract_id is null)<>1 then return false;end if;
 end loop;
 return true;
 exception when invalid_parameter_value or invalid_text_representation or check_violation or numeric_value_out_of_range then return false;
end;$$;
revoke all on function private.valid_original_expense_split(public.expenses) from public,anon,authenticated,service_role;

-- Both plans are server-derived; numeric summation avoids intermediate BIGINT overflow.
create function private.split_cost_delta(original_plan jsonb,corrected_plan jsonb) returns jsonb
language sql immutable set search_path='' as $$
 with parts as (select v->>'project_id' project_id,-(v->>'amount_minor')::numeric amount from jsonb_array_elements(original_plan->'destinations') v
 union all select v->>'project_id',(v->>'amount_minor')::numeric from jsonb_array_elements(corrected_plan->'destinations') v),
 net as(select project_id,sum(amount)::bigint delta from parts group by project_id)
 select coalesce(jsonb_agg(jsonb_build_object('project_id',project_id,'delta_minor',delta::text) order by coalesce(project_id,'~') collate "C") filter(where delta<>0),'[]'::jsonb) from net;
$$;
revoke all on function private.split_cost_delta(jsonb,jsonb) from public,anon,authenticated,service_role;

create or replace function private.project_correction_check(cid uuid,rid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.expense_correction_reviews;e public.expenses;t public.treasury_accounts;today date:=(statement_timestamp() at time zone 'UTC')::date;m date:=date_trunc('month',today)::date;source_account uuid;destination_account uuid;why text;begin
 select * into r from public.expense_correction_reviews where company_id=cid and id=rid;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select * into e from public.expenses where company_id=cid and id=r.expense_id;
 if e.allocation_event_id is not null then why:='NONSTANDARD_SOURCE_JOURNAL';
 elsif r.kind<>'PROJECT' then why:='ALLOCATION_ONLY';
 elsif exists(select 1 from public.expense_correction_reviews next where next.previous_review_id=r.id) then why:='STALE_REVIEW';
 elsif e.status<>'POSTED' or e.updated_at<>r.expense_updated_at or e.project_id is distinct from r.original_project_id then why:='SOURCE_CHANGED';
 elsif e.expense_date<m or e.expense_date>today or r.requested_effective_date<>today then why:='CURRENT_PERIOD_TODAY_ONLY';
 elsif exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='CLOSED') then why:='PERIOD_CLOSED';
 elsif not exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='OPEN') then why:='PERIOD_NOT_OPEN';
 elsif (public.get_my_company_subscription(cid)->>'access') is distinct from 'FULL' then why:='COMMERCIAL_ACCESS_REQUIRED';
 elsif e.funding_mode<>'TREASURY' or e.payment_method<>'CASH' or e.supplier_id is not null or e.paid_by_party_id is not null or e.vat_amount_minor<>0 or e.gross_amount_minor<>e.net_amount_minor then why:='UNSUPPORTED_SOURCE';
 elsif r.proposed_project_id is not distinct from e.project_id then why:='UNCHANGED_ALLOCATION';
 elsif exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.expense_id=e.id and not exists(select 1 from public.project_cost_correction_reversals v where v.correction_id=c.id)) then why:='LIVE_CORRECTION';
 elsif exists(select 1 from public.supplier_payment_allocations a where a.company_id=cid and a.expense_id=e.id) or exists(select 1 from public.custody_settlement_items i where i.company_id=cid and i.expense_id=e.id) then why:='SETTLEMENT_DEPENDENCY';end if;
 select * into t from public.treasury_accounts where company_id=cid and id=e.treasury_account_id;
 if why is null and (t.id is null or t.type<>'CASH' or t.project_id is not null) then why:='BANK_OR_SCOPED_TREASURY';end if;
 if why is null and exists(select 1 from public.projects p where p.company_id=cid and p.id in (e.project_id,r.proposed_project_id) and p.status<>'ACTIVE') then why:='PROJECT_NOT_ACTIVE';end if;
 select id into source_account from public.accounts where company_id=cid and system_key=case when e.project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 select id into destination_account from public.accounts where company_id=cid and system_key=case when r.proposed_project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 if why is null and (source_account is null or destination_account is null) then why:='COST_MAPPING_UNAVAILABLE';end if;
 if why is null and (not exists(select 1 from public.journal_entries j where j.company_id=cid and j.id=e.posted_journal_entry_id and j.source_type='EXPENSE' and j.source_id=e.id and j.posting_purpose='ORIGINAL' and j.reversal_of_journal_entry_id is null)
 or (select count(*) from public.journal_lines where company_id=cid and journal_entry_id=e.posted_journal_entry_id)<>2
 or not exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=source_account and l.debit_minor=e.net_amount_minor and l.credit_minor=0 and l.project_id is not distinct from e.project_id and l.treasury_account_id is null and l.party_id is null and l.subcontract_id is null)
 or not exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=t.gl_account_id and l.credit_minor=e.net_amount_minor and l.debit_minor=0 and l.treasury_account_id=t.id and l.party_id is null and l.subcontract_id is null)) then why:='NONSTANDARD_SOURCE_JOURNAL';end if;
 return jsonb_build_object('eligible',why is null,'blocker',why,'review_id',r.id,'expense_id',e.id,'expense_reference',e.expense_reference,'original_project_id',e.project_id,'corrected_project_id',r.proposed_project_id,'amount_minor',e.net_amount_minor::text,'effective_date',today,'source_account_id',source_account,'destination_account_id',destination_account,'reason',r.reason,'requires_unreconciled_evidence',true);
end;$$;
create function private.split_cost_correction_check(cid uuid,rid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.expense_correction_reviews;e public.expenses;t public.treasury_accounts;today date:=(statement_timestamp() at time zone 'UTC')::date;m date:=date_trunc('month',today)::date;source_account uuid;destination_account uuid;why text;begin
 select * into r from public.expense_correction_reviews where company_id=cid and id=rid;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select * into e from public.expenses where company_id=cid and id=r.expense_id;
 if e.allocation_event_id is null or e.allocation_plan is null then why:='NONSTANDARD_SOURCE_JOURNAL';
 elsif r.kind<>'PROJECT' then why:='ALLOCATION_ONLY';
 elsif exists(select 1 from public.expense_correction_reviews next where next.previous_review_id=r.id) then why:='STALE_REVIEW';
 elsif e.status<>'POSTED' or e.updated_at<>r.expense_updated_at or e.project_id is distinct from r.original_project_id then why:='SOURCE_CHANGED';
 elsif e.expense_date<m or e.expense_date>today or r.requested_effective_date<>today then why:='CURRENT_PERIOD_TODAY_ONLY';
 elsif exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='CLOSED') then why:='PERIOD_CLOSED';
 elsif not exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='OPEN') then why:='PERIOD_NOT_OPEN';
 elsif (public.get_my_company_subscription(cid)->>'access') is distinct from 'FULL' then why:='COMMERCIAL_ACCESS_REQUIRED';
 elsif e.funding_mode<>'TREASURY' or e.payment_method<>'CASH' or e.supplier_id is not null or e.paid_by_party_id is not null or e.vat_amount_minor<>0 or e.gross_amount_minor<>e.net_amount_minor then why:='UNSUPPORTED_SOURCE';
 
 elsif exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.expense_id=e.id and not exists(select 1 from public.project_cost_correction_reversals v where v.correction_id=c.id)) then why:='LIVE_CORRECTION';
 elsif exists(select 1 from public.supplier_payment_allocations a where a.company_id=cid and a.expense_id=e.id) or exists(select 1 from public.custody_settlement_items i where i.company_id=cid and i.expense_id=e.id) then why:='SETTLEMENT_DEPENDENCY';end if;
 select * into t from public.treasury_accounts where company_id=cid and id=e.treasury_account_id;
 if why is null and (t.id is null or t.type<>'CASH' or t.project_id is not null) then why:='BANK_OR_SCOPED_TREASURY';end if;
 if why is null and exists(select 1 from public.projects p where p.company_id=cid and (p.id=r.proposed_project_id or p.id in (select (v->>'project_id')::uuid from jsonb_array_elements(e.allocation_plan->'destinations') v)) and p.status<>'ACTIVE') then why:='PROJECT_NOT_ACTIVE';end if;
 select id into source_account from public.accounts where company_id=cid and system_key=case when e.allocation_plan->'destinations'->0->>'project_id' is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 select id into destination_account from public.accounts where company_id=cid and system_key=case when r.proposed_project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 if why is null and (source_account is null or destination_account is null) then why:='COST_MAPPING_UNAVAILABLE';end if;
 if why is null and not private.valid_original_expense_split(e) then why:='NONSTANDARD_SOURCE_JOURNAL';end if;
 return jsonb_build_object('original_allocation_plan',e.allocation_plan,'allocation_event_id',e.allocation_event_id,'eligible',why is null,'blocker',why,'review_id',r.id,'expense_id',e.id,'expense_reference',e.expense_reference,'original_project_id',e.project_id,'corrected_project_id',r.proposed_project_id,'amount_minor',e.net_amount_minor::text,'effective_date',today,'source_account_id',source_account,'destination_account_id',destination_account,'reason',r.reason,'requires_unreconciled_evidence',true);
end;$$;
revoke all on function private.split_cost_correction_check(uuid,uuid) from public,anon,authenticated,service_role;
create or replace function public.get_project_correction_eligibility(target_company_id uuid,target_review_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin
 perform 1 from public.companies where id=target_company_id for share;perform private.correction_authority(target_company_id);
 if exists(select 1 from public.expense_correction_reviews r join public.expenses e on e.company_id=r.company_id and e.id=r.expense_id where r.company_id=target_company_id and r.id=target_review_id and e.allocation_event_id is not null) then return private.split_cost_correction_check(target_company_id,target_review_id);end if;
 return private.project_correction_check(target_company_id,target_review_id);
end;$$;
create or replace function public.record_expense_correction_review(target_company_id uuid,target_expense_id uuid,
 expected_updated_at timestamptz,expected_latest_review_id uuid,request_id uuid,kind text,
 proposed_project_id uuid,requested_effective_date date,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();e public.expenses;prior public.expense_correction_reviews;latest uuid;
 review_id uuid;digest text;evidence jsonb;normalized_reason text;
 trim_chars text:=E' \t\n\r\f'||chr(11)||chr(160)||chr(5760)||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279);
begin
 if actor is null then raise exception 'Denied' using errcode='42501';end if;
 perform 1 from public.companies where id=target_company_id for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=target_company_id and user_id=actor for share;
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then raise exception 'Review denied' using errcode='42501';end if;
 normalized_reason:=nullif(btrim(reason,trim_chars),'');
 if target_expense_id is null or expected_updated_at is null or request_id is null or kind is null or kind not in ('PROJECT','CLASSIFICATION','REVERSAL')
 or requested_effective_date is null or normalized_reason is null or length(normalized_reason)>500
 or (kind<>'PROJECT' and proposed_project_id is not null) then raise exception 'Invalid review' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'expense',target_expense_id,
 'expected_epoch',extract(epoch from expected_updated_at),'previous',expected_latest_review_id,'kind',kind,
 'project',proposed_project_id,'date',requested_effective_date,'reason',normalized_reason)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('expense-correction-review:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.expense_correction_reviews r where r.company_id=target_company_id and r.request_id=record_expense_correction_review.request_id;
 if found then
  if prior.input_hash<>digest or prior.actor_id<>actor then raise exception 'Request changed' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'expense_id',prior.expense_id,'request_id',prior.request_id,'status',prior.status);
 end if;
 if proposed_project_id is not null then
  perform 1 from public.projects p where p.company_id=target_company_id and p.id=proposed_project_id for share;
  if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 end if;
 select * into e from public.expenses where company_id=target_company_id and id=target_expense_id for update;
 if not found then raise exception 'Expense unavailable' using errcode='42501';end if;
 if e.updated_at<>expected_updated_at then raise exception 'Expense changed; refresh' using errcode='40001';end if;
 if e.status not in ('POSTED','REVERSED') or e.posted_journal_entry_id is null then raise exception 'Posted expense required' using errcode='23514';end if;
 if requested_effective_date<e.expense_date then raise exception 'Requested date precedes original' using errcode='22023';end if;
 if kind='PROJECT' and e.allocation_event_id is null and proposed_project_id is not distinct from e.project_id then raise exception 'Project unchanged' using errcode='22023';end if;
 select r.id into latest from public.expense_correction_reviews r where r.company_id=target_company_id and r.expense_id=target_expense_id
 and not exists(select 1 from public.expense_correction_reviews successor where successor.previous_review_id=r.id);
 if latest is distinct from expected_latest_review_id then raise exception 'Review changed; refresh' using errcode='40001';end if;
 evidence:=jsonb_build_object('original_allocation_plan',e.allocation_plan,'allocation_event_id',e.allocation_event_id,'expense_reference',e.expense_reference,'expense_status',e.status,'expense_date',e.expense_date,
  'funding_mode',e.funding_mode,'net_amount_minor',e.net_amount_minor::text,'gross_amount_minor',e.gross_amount_minor::text,
  'reversal_journal_entry_id',e.reversal_journal_entry_id,
  'live_supplier_payment_count',(select count(distinct p.id) from public.supplier_payment_allocations a join public.supplier_payments p on p.company_id=a.company_id and p.id=a.supplier_payment_id where a.company_id=target_company_id and a.expense_id=e.id and p.status='POSTED'),
  'live_custody_settlement_count',(select count(distinct s.id) from public.custody_settlement_items i join public.custody_settlements s on s.company_id=i.company_id and s.id=i.settlement_id where i.company_id=target_company_id and i.expense_id=e.id and s.status='FINALIZED'),
  'period_control','NOT_IMPLEMENTED','reconciliation_status','UNVERIFIED','financial_execution','NOT_AUTHORIZED_BY_REVIEW',
  'policy_decision',case kind when 'PROJECT' then 'DIMENSION_CORRECTION_METHOD_AND_DEPENDENCIES' when 'CLASSIFICATION' then 'CLASSIFICATION_SUBSTANCE_AND_CORRECTION_METHOD' else 'REVERSAL_DEPENDENCIES_AND_EFFECTIVE_PERIOD' end);
 insert into public.expense_correction_reviews(company_id,expense_id,request_id,previous_review_id,actor_id,kind,reason,
  requested_effective_date,original_project_id,proposed_project_id,original_journal_entry_id,expense_updated_at,input_hash,snapshot)
 values(target_company_id,target_expense_id,request_id,latest,actor,kind,normalized_reason,requested_effective_date,e.project_id,
  proposed_project_id,e.posted_journal_entry_id,e.updated_at,digest,evidence) returning id into review_id;
 return jsonb_build_object('id',review_id,'company_id',target_company_id,'expense_id',target_expense_id,'request_id',request_id,'status','REVIEW_REQUIRED');
end;$$;
create function public.execute_posted_split_cost_correction(target_company_id uuid,target_review_id uuid,request_id uuid,plan jsonb,basis_approved boolean,unreconciled_confirmed boolean,evidence_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.expense_correction_reviews;e public.expenses;c public.project_cost_corrections;effect jsonb;allocation jsonb;d jsonb;digest text;cid uuid:=gen_random_uuid();jid uuid;lines jsonb:='[]';aid uuid;pid uuid;today date:=(statement_timestamp() at time zone 'UTC')::date;ev text:=private.correction_text(evidence_reference);begin
 perform 1 from public.companies where id=target_company_id for share;actor:=private.correction_authority(target_company_id);
 if request_id is null or target_review_id is null or basis_approved is distinct from true or unreconciled_confirmed is distinct from true or ev is null or length(ev)>500 then raise exception 'Approved basis and unreconciled evidence required' using errcode='22023';end if;
 select * into r from public.expense_correction_reviews where company_id=target_company_id and id=target_review_id;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select * into e from public.expenses where company_id=target_company_id and id=r.expense_id;
 allocation:=private.shared_cost_plan(e.net_amount_minor,plan);
 digest:=encode(extensions.digest(jsonb_build_object('command','POSTED_SPLIT_V1','actor',actor,'company',target_company_id,'review',target_review_id,'plan',allocation,'basis_approved',true,'unreconciled',true,'evidence',ev)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('project-cost-correction:'||target_company_id::text||':'||request_id::text,0));
 select * into c from public.project_cost_corrections x where x.company_id=target_company_id and x.request_id=execute_posted_split_cost_correction.request_id;
 if found then if c.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return (to_jsonb(c)-'input_hash')||jsonb_build_object('amount_minor',c.amount_minor::text);end if;
 -- The reviewed destination is the anchor; the confirmed plan is the full allocation.
 if not exists(select 1 from jsonb_array_elements(allocation->'destinations') v where (v->>'project_id')::uuid is not distinct from r.proposed_project_id) then raise exception 'Reviewed destination must be included' using errcode='23514';end if;
 for pid in select distinct p from (select (v->>'project_id')::uuid p from jsonb_array_elements(allocation->'destinations') v union select (v->>'project_id')::uuid from jsonb_array_elements(e.allocation_plan->'destinations') v union select r.original_project_id union select r.proposed_project_id) x where p is not null order by p loop
  perform 1 from public.projects where company_id=target_company_id and id=pid and status='ACTIVE' for share;
  if not found then raise exception 'Active Company Project required' using errcode='42501';end if;
 end loop;
 select * into e from public.expenses where company_id=target_company_id and id=r.expense_id for update;
 if exists(select 1 from public.project_cost_corrections x where x.review_id=r.id) then raise exception 'Review already executed' using errcode='23514';end if;
 effect:=private.split_cost_correction_check(target_company_id,target_review_id);
 if not(effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 perform 1 from public.treasury_accounts where company_id=target_company_id and id=e.treasury_account_id for share;
 perform 1 from public.accounts where company_id=target_company_id and (system_key in ('PROJECT_COST','COMPANY_EXPENSE') or id=(effect->>'source_account_id')::uuid) order by id for share;
 effect:=private.split_cost_correction_check(target_company_id,target_review_id);
 if not(effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 for d in select value from jsonb_array_elements(private.split_cost_delta(e.allocation_plan,allocation)) loop
  select id into aid from public.accounts where company_id=target_company_id and system_key=case when d->>'project_id' is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and status='ACTIVE' and account_type='EXPENSE';
  if aid is null then raise exception 'Cost mapping unavailable' using errcode='23514';end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',aid,'debit_minor',greatest((d->>'delta_minor')::bigint,0)::text,'credit_minor',greatest(-(d->>'delta_minor')::bigint,0)::text,'project_id',d->>'project_id','memo',r.reason));
 end loop;
 if jsonb_array_length(lines)=0 then raise exception 'Allocation unchanged' using errcode='23514';end if;
 jid:=private.create_journal(target_company_id,today,'Split cost correction: '||e.expense_reference,'PROJECT_COST_CORRECTION',cid,'POST',lines,actor);
 insert into public.project_cost_corrections(id,company_id,expense_id,review_id,correction_reference,request_id,actor_id,correction_date,month,original_project_id,corrected_project_id,source_account_id,destination_account_id,amount_minor,original_journal_entry_id,journal_entry_id,reason,evidence_reference,unreconciled_attested,input_hash,allocation_plan,original_allocation_plan)
 values(cid,target_company_id,e.id,r.id,private.allocate_reference(target_company_id,'PCC',extract(year from today)::integer),request_id,actor,today,date_trunc('month',today)::date,e.project_id,r.proposed_project_id,(effect->>'source_account_id')::uuid,(effect->>'destination_account_id')::uuid,e.net_amount_minor,e.posted_journal_entry_id,jid,r.reason,ev,true,digest,allocation,e.allocation_plan);
 return (select (to_jsonb(x)-'input_hash')||jsonb_build_object('amount_minor',x.amount_minor::text) from public.project_cost_corrections x where id=cid);
end;$$;
revoke all on function public.execute_posted_split_cost_correction(uuid,uuid,uuid,jsonb,boolean,boolean,text) from public,anon,authenticated,service_role;
grant execute on function public.execute_posted_split_cost_correction(uuid,uuid,uuid,jsonb,boolean,boolean,text) to authenticated;
