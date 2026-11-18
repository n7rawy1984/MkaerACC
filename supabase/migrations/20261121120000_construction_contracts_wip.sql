-- 103 / CR05. Additive customer-contract integration; no tenant seeds or financial backfill.
-- GL, AR and project costs remain authoritative. These are contract policy, evidence and links.
create table public.construction_contracts(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 project_id uuid not null,customer_id uuid not null,reference text not null,from_date date not null,through_date date not null,
 consideration_minor bigint not null check(consideration_minor between 1 and 9000000000000000),
 recognition text not null check(recognition in('OVERTIME_35A','OVERTIME_35B','OVERTIME_35C','POINT_IN_TIME')),
 measurement text not null check(measurement in('CERTIFIED_OUTPUT','CONTROL_TRANSFER')),
 obligation text not null,policy_evidence text not null,retention_basis text not null check(retention_basis in('UNCONDITIONAL','CONDITIONAL')),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,project_id),unique(company_id,reference),
 foreign key(company_id,project_id)references public.projects(company_id,id),foreign key(company_id,customer_id)references public.parties(company_id,id),
 check(through_date>=from_date),check((recognition='POINT_IN_TIME')=(measurement='CONTROL_TRANSFER')));
create table public.construction_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,contract_id uuid not null,kind text not null,reference text not null,date date not null,
 input jsonb not null,document_id uuid,request_id uuid not null,request_hash text not null,result jsonb not null,
 actor uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_id),unique(company_id,contract_id,kind,reference),
 foreign key(company_id,contract_id)references public.construction_contracts(company_id,id),
 foreign key(company_id,document_id)references public.commercial_documents(company_id,id));
create table public.construction_document_links(
 company_id uuid not null,contract_id uuid not null,document_id uuid not null,primary key(company_id,document_id),
 foreign key(company_id,contract_id)references public.construction_contracts(company_id,id),foreign key(company_id,document_id)references public.commercial_documents(company_id,id));
do $$declare t text;begin foreach t in array array['construction_contracts','construction_events','construction_document_links']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy construction_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'')or public.has_company_role(company_id,''ACCOUNTANT'')or public.has_company_role(company_id,''MANAGEMENT_VIEWER''))',t);
 execute format('create trigger immutable_construction before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
end loop;end$$;
-- Retain all earlier control types; add no implicit Company mappings.
create or replace function private.commercial_control_type(k text)returns text language sql immutable set search_path=''as $$select case
 when k in('AR','ASSET_COST','ACCUMULATED_DEPRECIATION','PREPAYMENT','CONTRACT_ASSET','CONSTRUCTION_WIP','CUSTOMER_RETENTION')then 'ASSET'
 when k in('CUSTOMER_ADVANCE','OUTPUT_VAT','ACCRUED_LIABILITY','CONTRACT_LIABILITY')then 'LIABILITY'
 when k in('REVENUE','DISPOSAL_GAIN')then 'REVENUE'when k in('COGS','DEPRECIATION_EXPENSE','DISPOSAL_LOSS','ACCRUAL_EXPENSE')then 'EXPENSE'when k='RETAINED_EARNINGS'then 'EQUITY'end$$;
create function public.configure_construction_accounting(cid uuid,request_id uuid,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;k text;a public.accounts;h text;old public.commercial_setup_events;begin
 actor:=private.operational_finance_actor(cid,'account.manage');if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin required'using errcode='42501';end if;
 if request_id is null or jsonb_typeof(input)is distinct from 'object'or input-array['controls','evidence']<>'{}'::jsonb or jsonb_typeof(input->'controls')is distinct from 'object'or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 then raise exception 'Typed controls and audited setup evidence required'using errcode='22023';end if;
 perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(jsonb_build_array(actor,input)::text,'sha256'),'hex');
 select *into old from public.commercial_setup_events where company_id=cid and commercial_setup_events.request_id=configure_construction_accounting.request_id;if old.id is not null then if old.request_hash<>h then raise exception 'Changed setup request'using errcode='22023';end if;return old.result;end if;
 for k in select jsonb_object_keys(input->'controls')loop
 if k not in('CONTRACT_ASSET','CONTRACT_LIABILITY','CONSTRUCTION_WIP','CUSTOMER_RETENTION')then raise exception 'Unsupported construction control'using errcode='22023';end if;
 select *into a from public.accounts where company_id=cid and id=(input->'controls'->>k)::uuid;
 if a.id is null or a.status<>'ACTIVE'or a.account_type::text is distinct from private.commercial_control_type(k)or a.requires_party<>(k<>'CONSTRUCTION_WIP')or exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=a.id)then raise exception 'Active typed same-Company control and correct Party dimension required'using errcode='23514';end if;
 if exists(select 1 from public.commercial_controls where company_id=cid and key=k and account_id<>a.id)then raise exception 'Existing control cannot be remapped'using errcode='23514';end if;
 if not exists(select 1 from public.commercial_controls where company_id=cid and key=k)and exists(select 1 from public.journal_lines where company_id=cid and account_id=a.id)then raise exception 'Use certified opening after mapping; no unexplained historical adoption'using errcode='23514';end if;
 insert into public.commercial_controls values(cid,k,a.id)on conflict(company_id,key)do nothing;end loop;
 insert into public.commercial_setup_events(company_id,request_id,request_hash,input,result,actor)values(cid,request_id,h,input,'{"configured":true}',actor);return '{"configured":true}';end$$;
create function private.construction_live(cid uuid,did uuid,cutoff date default 'infinity')returns boolean language sql stable set search_path=''as $$select not exists(select 1 from public.commercial_documents r where r.company_id=cid and r.input->>'construction_reverses_id'=did::text and r.date<=cutoff)$$;
create function private.construction_docs(cid uuid,contract uuid,cutoff date default 'infinity')returns setof public.commercial_documents language sql stable set search_path=''as $$select d.*from public.construction_document_links l join public.commercial_documents d on d.company_id=l.company_id and d.id=l.document_id where l.company_id=cid and l.contract_id=contract and d.date<=cutoff and private.construction_live(cid,d.id,cutoff)and not(d.input?'construction_reverses_id')$$;
create function private.construction_value(cid uuid,contract uuid,cutoff date default 'infinity')returns bigint language sql stable set search_path=''as $$select coalesce((select(e.input->>'new_value_minor')::bigint from public.construction_events e where e.company_id=cid and e.contract_id=contract and e.kind='VARIATION'and e.date<=cutoff order by e.created_at desc,e.id desc limit 1),(select consideration_minor from public.construction_contracts where company_id=cid and id=contract))$$;
create function private.construction_balance(cid uuid,contract uuid,cutoff date default 'infinity')returns jsonb language sql stable set search_path=''as $$
 with docs as materialized(select *from private.construction_docs(cid,contract,cutoff)),v as(select
 coalesce(sum(amount_minor)filter(where kind='CR_REVENUE'),0)rev,
 coalesce(sum((input->>'bill_net_minor')::bigint)filter(where kind='AR_INVOICE'and input->>'construction_action'in('BILL','RELEASE_RETENTION')),0)billed,
 coalesce(sum((input->>'retention_minor')::bigint)filter(where kind='AR_INVOICE'and input->>'construction_action'='BILL'),0)-coalesce(sum(amount_minor)filter(where input->>'construction_action'='RELEASE_RETENTION'),0)retention,
 coalesce(sum(amount_minor)filter(where kind in('CR_WIP_CAPITALIZE','CR_WIP_OPENING')),0)-coalesce(sum(amount_minor)filter(where kind in('CR_WIP_RELEASE','CR_WIP_IMPAIR')),0)wip,
 coalesce(sum(case when kind in('AR_RECEIPT','AR_ADVANCE')then amount_minor when kind='AR_REFUND'then -amount_minor else 0 end),0)collected,
 coalesce(sum(amount_minor)filter(where kind='AR_ADVANCE'),0)-coalesce(sum(amount_minor)filter(where kind in('AR_APPLY','AR_REFUND')),0)advance
 from docs)select jsonb_build_object('revenue',rev::text,'billed',billed::text,'net_position',(rev-billed)::text,'retention',retention::text,'wip',wip::text,'collected',collected::text,'advance',advance::text)from v$$;
-- Customer receipts/applications from existing AR screens acquire the same contract trace.
create function private.construction_link_customer()returns trigger language plpgsql security definer set search_path=''as $$declare c uuid;begin
 select contract_id into c from public.construction_document_links where company_id=new.company_id and document_id=new.parent_id;
 if c is null and new.kind='AR_ADVANCE'then select id into c from public.construction_contracts where company_id=new.company_id and project_id=new.project_id and customer_id=new.party_id;end if;
 if c is not null then insert into public.construction_document_links values(new.company_id,c,new.id)on conflict do nothing;end if;return new;end$$;
create trigger construction_customer_trace after insert on public.commercial_documents for each row execute function private.construction_link_customer();
alter function private.customer_plan(uuid,text,jsonb)rename to customer_plan_pre103;
create function private.customer_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql set search_path=''as $$declare c uuid;related uuid;ct public.construction_contracts;t public.treasury_accounts;begin
 select *into ct from public.construction_contracts where company_id=cid and project_id=nullif(v->>'project_id','')::uuid;
 if ct.id is not null then if kind in('AR_INVOICE','AR_CASH_SALE')then raise exception 'Use construction progress billing; invoice issuance must not automatically recognize revenue'using errcode='23514';end if;if kind='AR_ADVANCE'and(exists(select 1 from public.projects where company_id=cid and id=ct.project_id and status='CLOSED')or coalesce((select kind='CLOSE'from public.construction_events where company_id=cid and contract_id=ct.id and kind in('CLOSE','REOPEN')order by created_at desc,id desc limit 1),false))then raise exception 'Reopen closed contract/Project before new deposits; existing settlements remain supported'using errcode='23514';end if;if kind='AR_ADVANCE'and ct.customer_id is distinct from(v->>'party_id')::uuid then raise exception 'Contract Customer must match deposit'using errcode='23514';end if;end if;
 select contract_id into c from public.construction_document_links where company_id=cid and document_id=nullif(v->>'parent_id','')::uuid;
 if c is not null then
 if kind='AR_CREDIT'then raise exception 'Construction billing requires its controlled credit/reversal; do not reverse earned revenue blindly'using errcode='23514';end if;
 select *into ct from public.construction_contracts where company_id=cid and id=c;
 if kind='AR_APPLY'then select contract_id into related from public.construction_document_links where company_id=cid and document_id=(v->>'related_id')::uuid;if related is distinct from c then raise exception 'Advance must belong to the same construction contract'using errcode='23514';end if;end if;
 if nullif(v->>'treasury_id','')is not null then select *into t from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid;if t.id is null or(t.project_id is not null and t.project_id is distinct from ct.project_id)then raise exception 'Consistent contract Project Treasury required'using errcode='23514';end if;end if;
 end if;return private.customer_plan_pre103(cid,kind,v);end$$;
create function private.construction_plan(cid uuid,action text,v jsonb)returns jsonb language plpgsql set search_path=''as $$
#variable_conflict use_variable
declare c public.construction_contracts;e public.construction_events;orig public.commercial_documents;src public.journal_lines;je public.journal_entries;
 b jsonb;value bigint;n bigint;tax bigint;ret bigint;bill bigint;position bigint;leftover bigint;used numeric;lines jsonb:='[]';ca uuid;cl uuid;ar uuid;wip uuid;rev uuid;rr uuid;cogs uuid;vat uuid;bank uuid;p jsonb;closed boolean;latest date;
begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if jsonb_typeof(v)is distinct from 'object'or octet_length(v::text)>20000 or v-array['contract_id','project_id','customer_id','reference','date','from_date','through_date','consideration_minor','recognition','measurement','obligation','policy_evidence','retention_basis','evidence','new_value_minor','same_obligation','approved_modification','amount_minor','vat_minor','vat_rate_bps','tax_evidence','tax_confirmed','retention_minor','certificate_id','parent_id','related_id','treasury_id','due_date','recognition_confirmed','control_transferred','future_performance_confirmed','recoverable_confirmed','other_standard_excluded','source_line_id','expected_release_date','recovery_minor','conditions_met','id']<>'{}'::jsonb or coalesce(length(v->>'evidence'),0)not between 5 and 1000 or coalesce(length(v->>'reference'),0)not between 1 and 120 or coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'date')::date>current_date then raise exception 'Bounded construction business inputs, actual date/reference and evidence required'using errcode='22023';end if;
 perform private.opening_period(cid,(v->>'date')::date);
 if action='CONTRACT'then
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin policy approval required'using errcode='42501';end if;
 if not(private.company_commercial_readiness(cid)->>'ready')::boolean then raise exception 'Commercial readiness required'using errcode='42501';end if;
 if not exists(select 1 from public.projects where company_id=cid and id=(v->>'project_id')::uuid and status='ACTIVE')or not exists(select 1 from public.customer_accounts a join public.parties p on p.company_id=a.company_id and p.id=a.party_id where a.company_id=cid and a.party_id=(v->>'customer_id')::uuid and p.status='ACTIVE')then raise exception 'Active Company Project and existing Customer relationship required'using errcode='23514';end if;
 if coalesce(v->>'from_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or coalesce(v->>'through_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or coalesce(v->>'consideration_minor','')!~'^[0-9]{1,16}$'or(v->>'consideration_minor')::numeric not between 1 and 9000000000000000 or coalesce(v->>'recognition','')not in('OVERTIME_35A','OVERTIME_35B','OVERTIME_35C','POINT_IN_TIME')or coalesce(v->>'measurement','')not in('CERTIFIED_OUTPUT','CONTROL_TRANSFER')or((v->>'recognition'='POINT_IN_TIME')is distinct from(v->>'measurement'='CONTROL_TRANSFER'))or coalesce(v->>'retention_basis','')not in('UNCONDITIONAL','CONDITIONAL')or coalesce(length(v->>'obligation'),0)not between 5 and 2000 or coalesce(length(v->>'policy_evidence'),0)not between 10 and 2000 or(v->>'through_date')::date<(v->>'from_date')::date or(v->>'date')::date<(v->>'from_date')::date then raise exception 'Explicit supported recognition criterion/measurement, obligation, consideration, dates and retention policy required'using errcode='23514';end if;
 if exists(select 1 from public.commercial_documents where company_id=cid and project_id=(v->>'project_id')::uuid and kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE'))then raise exception 'Existing Project customer financial events require scoped opening/migration assessment; no silent contract adoption'using errcode='23514';end if;
 return v||jsonb_build_object('lines',lines,'company_id',cid);end if;
 select *into c from public.construction_contracts where company_id=cid and id=(v->>'contract_id')::uuid for update;if c.id is null then raise exception 'Same-Company construction contract required'using errcode='42501';end if;
 select coalesce((select kind='CLOSE'from public.construction_events where company_id=cid and contract_id=c.id and kind in('CLOSE','REOPEN')order by created_at desc,id desc limit 1),false)into closed;
 if closed and action not in('REOPEN','RECEIPT','APPLY','REFUND')then raise exception 'Contract closed; audited Accounting Admin reopen required'using errcode='23514';end if;
 select max(date)into latest from public.construction_events where company_id=cid and contract_id=c.id;
 if(v->>'date')::date<greatest(c.from_date,coalesce(latest,c.from_date),(select max(date)from private.construction_docs(cid,c.id)))then raise exception 'Chronological contract date required; no silent historical restatement'using errcode='23514';end if;
 b:=private.construction_balance(cid,c.id);value:=private.construction_value(cid,c.id);position:=(b->>'net_position')::bigint;
 n:=coalesce(nullif(v->>'amount_minor','')::bigint,0);tax:=coalesce(nullif(v->>'vat_minor','')::bigint,0);ret:=coalesce(nullif(v->>'retention_minor','')::bigint,0);
 ca:=private.commercial_account(cid,'CONTRACT_ASSET');cl:=private.commercial_account(cid,'CONTRACT_LIABILITY');ar:=private.commercial_account(cid,'AR');wip:=private.commercial_account(cid,'CONSTRUCTION_WIP');rev:=private.commercial_account(cid,'REVENUE');rr:=private.commercial_account(cid,'CUSTOMER_RETENTION');cogs:=private.commercial_account(cid,'COGS');
 if action in('VARIATION','CERTIFY','CAPITALIZE_WIP','REGISTER_WIP_OPENING','RELEASE_WIP','IMPAIR_WIP','REVIEW_WIP','REVERSE','CLOSE','REOPEN')and not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin approval required for policy, valuation or correction'using errcode='42501';end if;
 if action='VARIATION'then
 if v->>'same_obligation'is distinct from 'true'or v->>'approved_modification'is distinct from 'true'or coalesce(v->>'new_value_minor','')!~'^[0-9]{1,16}$'or(v->>'new_value_minor')::numeric not between greatest((b->>'revenue')::numeric,(b->>'billed')::numeric)and 9000000000000000 then raise exception 'Approved same-obligation consideration modification required; separate obligations require separate assessment'using errcode='23514';end if;
 elsif action='CERTIFY'then
 if n<1 or n>value or n<(b->>'revenue')::bigint or(c.recognition='POINT_IN_TIME'and(v->>'control_transferred'is distinct from 'true'or n<>value))then raise exception 'Supported cumulative certified output/control transfer required; no invented progress'using errcode='23514';end if;
 elsif action in('ADVANCE','RECEIPT','APPLY','REFUND')then
 if n<1 or tax<>0 then raise exception 'Positive actual receipt/allocation with no invented tax required'using errcode='23514';end if;
 if action='ADVANCE'and v->>'tax_confirmed'is distinct from 'true'then raise exception 'Evidence that no deposit tax entry is required; taxable advances need their supported tax-point workflow'using errcode='23514';end if;
 if action<>'ADVANCE'and not exists(select 1 from public.construction_document_links where company_id=cid and contract_id=c.id and document_id=(v->>'parent_id')::uuid)then raise exception 'Original document must belong to this contract'using errcode='23514';end if;
 if nullif(v->>'treasury_id','')is not null and not exists(select 1 from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid and(project_id is null or project_id=c.project_id))then raise exception 'Consistent Project Treasury required'using errcode='23514';end if;
 p:=jsonb_strip_nulls(jsonb_build_object('date',v->>'date','party_id',c.customer_id,'project_id',case when action='REFUND'then null else c.project_id end,'treasury_id',nullif(v->>'treasury_id',''),'parent_id',nullif(v->>'parent_id',''),'related_id',nullif(v->>'related_id',''),'amount_minor',n::text,'vat_minor','0','reference',v->>'reference','evidence',v->>'evidence'));
 lines:=(private.customer_plan(cid,'AR_'||case when action='APPLY'then 'APPLY'else action end,p))->'lines';
 return v||jsonb_build_object('company_id',cid,'delegated_input',p,'lines',lines);
 elsif action in('BILL','RELEASE_RETENTION')then
 if action='BILL'then
 if n<1 or n>value or ret<0 or ret>n or tax<0 or n::numeric+tax>9000000000000000 then raise exception 'Supported invoice net, retention and tax required'using errcode='23514';end if;
 select *into e from public.construction_events where company_id=cid and contract_id=c.id and id=(v->>'certificate_id')::uuid and kind='CERTIFY';
 if e.id is null or e.date>(v->>'date')::date or n+(select coalesce(sum((input->>'amount_minor')::numeric),0)from private.construction_docs(cid,c.id)where input->>'construction_action'='BILL')>(e.input->>'amount_minor')::bigint then raise exception 'Billing exceeds supported cumulative certificate; milestone evidence required'using errcode='23514';end if;
 if tax>0 and(coalesce(v->>'vat_rate_bps','')<>'500'or tax<>round(n::numeric*500/10000)or coalesce(length(v->>'tax_evidence'),0)<5)or tax=0 and v->>'tax_confirmed'is distinct from 'true'then raise exception 'Actual supported invoice VAT/tax treatment required'using errcode='23514';end if;
 bill:=n-case when c.retention_basis='CONDITIONAL'then ret else 0 end;
 if n+tax-ret<1 then raise exception 'Positive unconditional invoice receivable required'using errcode='23514';end if;
 lines:=jsonb_build_array(private.commercial_line(ar,n+tax-ret,false,c.customer_id,c.project_id));
 if ret>0 and c.retention_basis='UNCONDITIONAL'then lines:=lines||jsonb_build_array(private.commercial_line(rr,ret,false,c.customer_id,c.project_id));end if;
 else
 if n<1 or n>(b->>'retention')::bigint or v->>'conditions_met'is distinct from 'true'or tax<>0 then raise exception 'Supported retention release conditions and remaining balance required'using errcode='23514';end if;
 bill:=case when c.retention_basis='CONDITIONAL'then n else 0 end;ret:=0;
 lines:=jsonb_build_array(private.commercial_line(ar,n,false,c.customer_id,c.project_id));if c.retention_basis='UNCONDITIONAL'then lines:=lines||jsonb_build_array(private.commercial_line(rr,n,true,c.customer_id,c.project_id));end if;
 end if;
 if bill>0 then leftover:=least(greatest(position,0),bill);if leftover>0 then lines:=lines||jsonb_build_array(private.commercial_line(ca,leftover,true,c.customer_id,c.project_id));end if;if bill>leftover then lines:=lines||jsonb_build_array(private.commercial_line(cl,bill-leftover,true,c.customer_id,c.project_id));end if;end if;
 if tax>0 then vat:=private.commercial_account(cid,'OUTPUT_VAT');lines:=lines||jsonb_build_array(private.commercial_line(vat,tax,true,null,c.project_id));end if;
 return v||jsonb_build_object('company_id',cid,'lines',lines,'bill_net_minor',bill::text,'retention_minor',ret::text,'ar_amount_minor',(case when action='BILL'then n+tax-ret else n end)::text);
 elsif action='RECOGNIZE'then
 select *into e from public.construction_events where company_id=cid and contract_id=c.id and id=(v->>'certificate_id')::uuid and kind='CERTIFY';
 if e.id is null or e.date>(v->>'date')::date or n<1 or n+(b->>'revenue')::numeric>least(value,(e.input->>'amount_minor')::numeric)or(c.recognition='POINT_IN_TIME'and(e.input->>'control_transferred'is distinct from 'true'or n+(b->>'revenue')::numeric<>value))then raise exception 'Approved supported progress/control transfer and remaining consideration required'using errcode='23514';end if;
 leftover:=least(greatest(-position,0),n);if leftover>0 then lines:=jsonb_build_array(private.commercial_line(cl,leftover,false,c.customer_id,c.project_id));end if;
 if n>leftover then lines:=lines||jsonb_build_array(private.commercial_line(ca,n-leftover,false,c.customer_id,c.project_id));end if;lines:=lines||jsonb_build_array(private.commercial_line(rev,n,true,null,c.project_id));
 elsif action in('CAPITALIZE_WIP','REGISTER_WIP_OPENING')then
 if not public.has_permission(cid,'payroll.manage')then raise exception 'Full cost-source scope required'using errcode='42501';end if;
 select *into src from public.journal_lines where company_id=cid and id=(v->>'source_line_id')::uuid for share;select *into je from public.journal_entries where company_id=cid and id=src.journal_entry_id;
 if src.id is null or je.posting_date>(v->>'date')::date or je.reversal_of_journal_entry_id is not null or exists(select 1 from public.journal_entries where company_id=cid and reversal_of_journal_entry_id=je.id)or n<1 or n>src.debit_minor-src.credit_minor then raise exception 'Unreversed actual posted cost/opening line and bounded amount required'using errcode='23514';end if;
 select coalesce(sum(amount_minor),0)into used from public.commercial_documents d where d.company_id=cid and d.input->>'source_line_id'=src.id::text and d.kind in('CR_WIP_CAPITALIZE','CR_WIP_OPENING')and private.construction_live(cid,d.id);if used+n>src.debit_minor-src.credit_minor then raise exception 'Source cost/opening already allocated; no duplicate WIP'using errcode='23514';end if;
 if v->>'recoverable_confirmed'is distinct from 'true'or v->>'future_performance_confirmed'is distinct from 'true'or coalesce(v->>'expected_release_date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'or(v->>'expected_release_date')::date<(v->>'date')::date or(v->>'expected_release_date')::date>c.through_date then raise exception 'Recoverable future-performance resource, expected release date and evidence required; completed-work costs stay expensed'using errcode='23514';end if;
 if action='CAPITALIZE_WIP'then
 if exists(select 1 from public.project_cost_corrections p where p.company_id=cid and p.expense_id=je.source_id)or exists(select 1 from public.source_reclassification_events p where p.company_id=cid and p.state='POSTED'and(p.origin->>'id'=je.source_id::text or p.replacement->>'id'=je.source_id::text))then raise exception 'Corrected source requires specialized cost-line assessment; do not reuse original expense'using errcode='23514';end if;
 if exists(select 1 from public.inventory_events ie where ie.company_id=cid and ie.state='POSTED'and ie.snapshot->>'expense_id'=je.source_id::text and ie.snapshot->>'kind'in('RECEIPT','MATCH')and not exists(select 1 from public.inventory_events ir where ir.company_id=cid and ir.document_id=ie.document_id and ir.state='REVERSED'))then raise exception 'Expense already capitalized/matched in Inventory; no duplicate contract-cost asset'using errcode='23514';end if;
 if src.project_id is distinct from c.project_id or v->>'other_standard_excluded'is distinct from 'true'or je.source_type like 'CR_%'or not exists(select 1 from public.accounts where company_id=cid and id=src.account_id and account_type='EXPENSE')then raise exception 'Actual Project expense outside other asset standards required; never capitalize current performance automatically'using errcode='23514';end if;
 lines:=jsonb_build_array(private.commercial_line(wip,n,false,null,c.project_id),private.commercial_line(src.account_id,n,true,src.party_id,src.project_id)||jsonb_build_object('subcontract_id',src.subcontract_id));
 else
 if je.source_type<>'CERTIFIED_OPENING'or src.account_id<>wip or src.project_id is not null or src.party_id is not null then raise exception 'Properly certified unallocated opening WIP required; no new opening asset invented'using errcode='23514';end if;
 lines:=jsonb_build_array(private.commercial_line(wip,n,false,null,c.project_id),private.commercial_line(wip,n,true));end if;
 elsif action in('RELEASE_WIP','IMPAIR_WIP','REVIEW_WIP')then
 select *into orig from private.construction_docs(cid,c.id)where id=(v->>'parent_id')::uuid and kind in('CR_WIP_CAPITALIZE','CR_WIP_OPENING');
 select orig.amount_minor-coalesce(sum(amount_minor),0)into leftover from private.construction_docs(cid,c.id)where parent_id=orig.id and kind in('CR_WIP_RELEASE','CR_WIP_IMPAIR');
 if orig.id is null or orig.date>(v->>'date')::date then raise exception 'Original remaining contract-cost asset required'using errcode='23514';end if;
 if action='REVIEW_WIP'then if coalesce(v->>'recovery_minor','')!~'^[0-9]{1,16}$'or(v->>'recovery_minor')::numeric<leftover then raise exception 'Record supported impairment before certifying recoverability'using errcode='23514';end if;
 else if n<1 or n>leftover or(action='RELEASE_WIP'and v->>'recognition_confirmed'is distinct from 'true')then raise exception 'Actual transfer/impairment and remaining WIP required'using errcode='23514';end if;lines:=jsonb_build_array(private.commercial_line(cogs,n,false,null,c.project_id),private.commercial_line(wip,n,true,null,c.project_id));end if;
 elsif action='REVERSE'then
 select *into orig from private.construction_docs(cid,c.id)where id=(v->>'id')::uuid;
 if orig.id is null or orig.kind not in('CR_REVENUE','CR_WIP_CAPITALIZE','CR_WIP_OPENING','CR_WIP_RELEASE','CR_WIP_IMPAIR','AR_INVOICE')or orig.date>(v->>'date')::date then raise exception 'Live construction financial document required'using errcode='23514';end if;
 if orig.id is distinct from(select id from private.construction_docs(cid,c.id)where kind like 'CR_%'or kind='AR_INVOICE'order by created_at desc,id desc limit 1)then raise exception 'Reverse later construction recognition/billing/WIP dependencies first'using errcode='23514';end if;
 if exists(select 1 from public.commercial_documents where company_id=cid and parent_id=orig.id and private.construction_live(cid,id)and not(input?'construction_reverses_id'))then raise exception 'Dependent settlement/release prevents direct reversal'using errcode='23514';end if;
 select jsonb_agg(jsonb_build_object('account_id',l.account_id,'project_id',l.project_id,'party_id',l.party_id,'subcontract_id',l.subcontract_id,'treasury_account_id',l.treasury_account_id,'debit_minor',l.credit_minor::text,'credit_minor',l.debit_minor::text)order by l.line_number)into lines from public.journal_lines l where company_id=cid and journal_entry_id=orig.journal_id;
 elsif action='CLOSE'then
 if(b->>'revenue')::bigint<>value or(b->>'wip')::bigint<>0 or(b->>'retention')::bigint<>0 or(b->>'advance')::bigint<>0 or position<>0 or exists(select 1 from private.construction_docs(cid,c.id)d where d.kind='AR_INVOICE'and d.amount_minor<>(select coalesce(sum(x.ar_reduction_minor),0)from public.commercial_documents x where x.company_id=cid and x.parent_id=d.id))then raise exception 'Settle all AR, advances, retention, WIP and earned/billed balances before closeout'using errcode='23514';end if;
 if exists(select 1 from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=c.project_id and a.system_key in('SUBCONTRACTOR_ADVANCE','SUBCONTRACTOR_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE','SUPPLIER_PAYABLE','SALARY_PAYABLE')group by a.id,l.party_id,l.subcontract_id having sum(l.debit_minor-l.credit_minor)<>0)then raise exception 'Settle related Project contractor, Supplier and Payroll controls before closeout'using errcode='23514';end if;
 elsif action='REOPEN'then if not closed then raise exception 'Closed contract required'using errcode='23514';end if;
 else raise exception 'Supported construction event required'using errcode='22023';end if;
 return v||jsonb_build_object('company_id',cid,'lines',lines,'contract_value_minor',value::text);
end$$;
create function private.normalize_construction(v jsonb)returns jsonb language plpgsql immutable set search_path=''as $$declare k text;x text;begin
 if jsonb_typeof(v)is distinct from 'object'then raise exception 'Business input object required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
 if jsonb_typeof(v->k)not in('string','number','boolean','null')then raise exception 'Business scalars only; no caller journal lines'using errcode='22023';end if;
 if jsonb_typeof(v->k)='string'then v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end if;x:=nullif(v->>k,'');
 if x is not null then
 if k='id'or k like '%_id'then v:=jsonb_set(v,array[k],to_jsonb(x::uuid::text));
 elsif k like '%_minor'then if x!~'^[0-9]{1,16}$'then raise exception 'Exact nonnegative minor units required'using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb(x::bigint::text));
 elsif k in('date','from_date','through_date','due_date','expected_release_date')then if x!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Exact ISO calendar date required'using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb(x::date::text));end if;end if;end loop;return v;end$$;
create function public.preview_construction(cid uuid,action text,input jsonb)returns jsonb language sql security definer set search_path=''as $$select private.construction_plan(cid,action,private.normalize_construction(input))$$;
create function public.command_construction(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;old public.construction_events;h text;plan jsonb;result jsonb;c public.construction_contracts;doc uuid;j uuid;kind text;orig public.commercial_documents;event uuid:=gen_random_uuid();snapshot jsonb;req private.financial_command_requests;begin
 actor:=private.operational_finance_actor(cid,case when action='REVERSE'then 'accounting.reverse'else 'accounting.post'end);perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null then raise exception 'Request key required'using errcode='22023';end if;input:=private.normalize_construction(input);h:=encode(extensions.digest(jsonb_build_array(actor,action,input)::text,'sha256'),'hex');
 select *into old from public.construction_events where company_id=cid and construction_events.request_id=command_construction.request_id;
 if old.id is not null then if old.request_hash<>h then raise exception 'Changed construction retry intent'using errcode='22023';end if;return old.result||jsonb_build_object('replayed',true);end if;
 plan:=private.construction_plan(cid,action,input);
 if action='CONTRACT'then
 insert into public.construction_contracts(company_id,project_id,customer_id,reference,from_date,through_date,consideration_minor,recognition,measurement,obligation,policy_evidence,retention_basis,created_by)values(cid,(input->>'project_id')::uuid,(input->>'customer_id')::uuid,input->>'reference',(input->>'from_date')::date,(input->>'through_date')::date,(input->>'consideration_minor')::bigint,input->>'recognition',input->>'measurement',input->>'obligation',input->>'policy_evidence',input->>'retention_basis',actor)returning *into c;
 else select *into c from public.construction_contracts where company_id=cid and id=(input->>'contract_id')::uuid;end if;
 if action in('ADVANCE','RECEIPT','APPLY','REFUND')then
 result:=public.command_customer_accounting(cid,request_id,'AR_'||action,plan->'delegated_input');doc:=(result->>'id')::uuid;j:=(result->>'journal_id')::uuid;
 elsif jsonb_array_length(plan->'lines')>0 then
 req:=private.reserve_financial_command(cid,'CONSTRUCTION_'||action,request_id,h,actor);doc:=gen_random_uuid();
 kind:=case action when 'BILL'then 'AR_INVOICE'when 'RELEASE_RETENTION'then 'AR_INVOICE'when 'RECOGNIZE'then 'CR_REVENUE'when 'CAPITALIZE_WIP'then 'CR_WIP_CAPITALIZE'when 'REGISTER_WIP_OPENING'then 'CR_WIP_OPENING'when 'RELEASE_WIP'then 'CR_WIP_RELEASE'when 'IMPAIR_WIP'then 'CR_WIP_IMPAIR'else 'CR_REVERSAL'end;
 snapshot:=input||jsonb_build_object('construction_contract_id',c.id,'construction_action',action,'bill_net_minor',plan->>'bill_net_minor','retention_minor',coalesce(plan->>'retention_minor','0'),'due_date',coalesce(input->>'due_date',input->>'date'));
 if action='REVERSE'then
 select *into orig from public.commercial_documents where company_id=cid and id=(input->>'id')::uuid;
 j:=private.reverse_journal(orig.journal_id,(input->>'date')::date,input->>'evidence',actor);snapshot:=snapshot||jsonb_build_object('construction_reverses_id',orig.id,'construction_cost_sensitive',orig.kind like 'CR_WIP_%');input:=input||jsonb_build_object('construction_cost_sensitive',orig.kind like 'CR_WIP_%');if orig.kind='AR_INVOICE'then kind:='AR_CREDIT';end if;
 else j:=private.create_journal(cid,(input->>'date')::date,input->>'reference'||' '||(input->>'evidence'),kind,doc,'ORIGINAL',plan->'lines',actor);end if;
 insert into public.commercial_documents(id,company_id,kind,date,party_id,project_id,parent_id,reference,amount_minor,journal_id,ar_reduction_minor,input,request_id,request_hash,created_by)values(doc,cid,kind,(input->>'date')::date,c.customer_id,c.project_id,case when action='REVERSE'and orig.kind='AR_INVOICE'then orig.id else nullif(input->>'parent_id','')::uuid end,input->>'reference',case when action='REVERSE'then orig.amount_minor when action in('BILL','RELEASE_RETENTION')then(plan->>'ar_amount_minor')::bigint else(input->>'amount_minor')::bigint end,j,case when action='REVERSE'and orig.kind='AR_INVOICE'then orig.amount_minor else 0 end,snapshot,request_id,h,actor);
 perform private.complete_financial_command(req.id,j);
 end if;
 if doc is not null then insert into public.construction_document_links values(cid,c.id,doc)on conflict do nothing;end if;
 result:=jsonb_build_object('company_id',cid,'contract_id',c.id,'id',coalesce(doc,event),'journal_id',j,'action',action,'reference',input->>'reference');
 insert into public.construction_events(id,company_id,contract_id,kind,reference,date,input,document_id,request_id,request_hash,result,actor)values(event,cid,c.id,action,input->>'reference',(input->>'date')::date,input,doc,request_id,h,result,actor);return result;
end$$;
-- Prevent reversal/recovery of a source already reclassified to a future-performance asset.
create function private.guard_construction_cost_reversal()returns trigger language plpgsql security definer set search_path=''as $$declare jid uuid;begin
 if tg_table_name='journal_entries'then jid:=new.reversal_of_journal_entry_id;
 else if new.state<>'POSTED'then return new;end if;
 if new.snapshot->>'kind'in('RECEIPT','MATCH')and exists(select 1 from public.commercial_documents d join public.journal_lines l on l.company_id=d.company_id and l.id=(d.input->>'source_line_id')::uuid join public.expenses ex on ex.company_id=l.company_id and ex.posted_journal_entry_id=l.journal_entry_id where d.company_id=new.company_id and d.kind='CR_WIP_CAPITALIZE'and ex.id::text=new.snapshot->>'expense_id'and private.construction_live(d.company_id,d.id))then raise exception 'Expense already allocated to contract WIP; reverse dependent capitalization before Inventory recognition'using errcode='23514';end if;
 if new.snapshot->>'kind'<>'RETURN'then return new;end if;select journal_id into jid from public.inventory_events where company_id=new.company_id and document_id=(new.snapshot->>'origin_id')::uuid and state='POSTED';end if;
 if jid is not null and exists(select 1 from public.commercial_documents d join public.journal_lines l on l.company_id=d.company_id and l.id=(d.input->>'source_line_id')::uuid where d.company_id=new.company_id and d.kind='CR_WIP_CAPITALIZE'and l.journal_entry_id=jid and private.construction_live(d.company_id,d.id))then raise exception 'Reverse dependent WIP releases/capitalization before source correction or stock recovery'using errcode='23514';end if;return new;end$$;
create trigger construction_cost_reverse_guard before insert on public.journal_entries for each row when(new.reversal_of_journal_entry_id is not null)execute function private.guard_construction_cost_reversal();
create trigger construction_stock_recovery_guard before insert on public.inventory_events for each row execute function private.guard_construction_cost_reversal();
-- Full source cost scope includes Payroll. Do not leak individual labor-cost reclassifications.
create function public.construction_journal_visible(cid uuid,jid uuid)returns boolean language sql stable security definer set search_path=''as $$select public.is_company_member(cid)and(public.has_permission(cid,'payroll.manage')or not exists(select 1 from public.journal_entries where company_id=cid and id=jid and (source_type like 'CR_WIP_%'or reversal_of_journal_entry_id in(select id from public.journal_entries o where o.company_id=cid and o.source_type like 'CR_WIP_%'))))$$;
create policy construction_cost_journal_privacy on public.journal_entries as restrictive for select to authenticated using(public.construction_journal_visible(company_id,id));
create policy construction_cost_line_privacy on public.journal_lines as restrictive for select to authenticated using(public.construction_journal_visible(company_id,journal_entry_id));
create policy construction_cost_document_privacy on public.commercial_documents as restrictive for select to authenticated using((kind not like 'CR_WIP_%'and input->>'construction_cost_sensitive'is distinct from 'true')or public.has_permission(company_id,'payroll.manage'));
create policy construction_cost_event_privacy on public.construction_events as restrictive for select to authenticated using((kind not in('CAPITALIZE_WIP','REGISTER_WIP_OPENING','RELEASE_WIP','IMPAIR_WIP','REVIEW_WIP')and input->>'construction_cost_sensitive'is distinct from 'true')or public.has_permission(company_id,'payroll.manage'));
create function public.read_construction(cid uuid,contract uuid default null,as_of date default current_date)returns jsonb language plpgsql stable security definer set search_path=''as $$
#variable_conflict use_variable
declare c public.construction_contracts;b jsonb;full_cost boolean;cost numeric;wip_gl numeric;ca numeric;cl numeric;rev numeric;result jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Construction reader denied'using errcode='42501';end if;
 if as_of is null or as_of>current_date then raise exception 'Valid cutoff required'using errcode='22023';end if;full_cost:=public.has_permission(cid,'payroll.manage');
 if contract is null then return jsonb_build_object('company_id',cid,'today',current_date,'contracts',(select coalesce(jsonb_agg(to_jsonb(lc)),'[]')from public.construction_contracts lc where lc.company_id=cid),'controls',(select coalesce(jsonb_object_agg(key,account_id),'{}')from public.commercial_controls where company_id=cid),'full_cost_scope',full_cost);end if;
 select *into c from public.construction_contracts where company_id=cid and id=contract;if c.id is null then raise exception 'Company contract required'using errcode='42501';end if;
 b:=private.construction_balance(cid,c.id,as_of);
 select coalesce(sum(l.debit_minor-l.credit_minor)filter(where a.account_type='EXPENSE'),0),coalesce(sum(l.debit_minor-l.credit_minor)filter(where cc.key='CONSTRUCTION_WIP'),0),coalesce(sum(l.debit_minor-l.credit_minor)filter(where cc.key='CONTRACT_ASSET'),0),coalesce(sum(l.credit_minor-l.debit_minor)filter(where cc.key='CONTRACT_LIABILITY'),0),coalesce(sum(l.credit_minor-l.debit_minor)filter(where cc.key='REVENUE'),0)into cost,wip_gl,ca,cl,rev from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id left join public.commercial_controls cc on cc.company_id=l.company_id and cc.account_id=l.account_id where l.company_id=cid and l.project_id=c.project_id and j.posting_date<=as_of and j.source_type<>'ANNUAL_CLOSE'and not exists(select 1 from public.journal_entries original where original.company_id=cid and original.id=j.reversal_of_journal_entry_id and original.source_type='ANNUAL_CLOSE');
 result:=jsonb_build_object('company_id',cid,'today',current_date,'contract',to_jsonb(c),'as_of',as_of,'consideration_minor',private.construction_value(cid,c.id,as_of)::text,'balances',case when full_cost then b else b-'wip'end,'full_cost_scope',full_cost,'cost_minor',case when full_cost then cost::text end,'margin_minor',case when full_cost then((b->>'revenue')::numeric-cost)::text end,'wip_gl_minor',case when full_cost then wip_gl::text end,'contract_asset_minor',ca::text,'contract_liability_minor',cl::text,'revenue_gl_minor',rev::text,'subcontract_advance_minor',case when full_cost then(select coalesce(sum(l.debit_minor-l.credit_minor),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.project_id=c.project_id and a.system_key='SUBCONTRACTOR_ADVANCE'and j.posting_date<=as_of)end,'subcontract_retention_minor',case when full_cost then(select coalesce(sum(l.credit_minor-l.debit_minor),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.project_id=c.project_id and a.system_key='SUBCONTRACTOR_RETENTION_PAYABLE'and j.posting_date<=as_of)end,
 'events',(select coalesce(jsonb_agg(to_jsonb(e)order by created_at,id),'[]')from public.construction_events e where company_id=cid and contract_id=c.id and date<=as_of and(full_cost or(kind not in('CAPITALIZE_WIP','REGISTER_WIP_OPENING','RELEASE_WIP','IMPAIR_WIP','REVIEW_WIP')and input->>'construction_cost_sensitive'is distinct from 'true'))),
 'documents',(select coalesce(jsonb_agg(to_jsonb(d)||jsonb_build_object('amount_minor',amount_minor::text)),'[]')from private.construction_docs(cid,c.id,as_of)d where full_cost or(kind not like 'CR_WIP_%'and input->>'construction_cost_sensitive'is distinct from 'true')),
 'cost_sources',case when full_cost then(select coalesce(jsonb_agg(jsonb_build_object('id',l.id,'journal_id',j.id,'date',j.posting_date,'description',j.description,'amount_minor',(l.debit_minor-l.credit_minor)::text,'account',a.code,'source',j.source_type)),'[]')from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=c.project_id and a.account_type='EXPENSE'and l.debit_minor>l.credit_minor and j.posting_date<=as_of and j.source_type not like 'CR_%'and j.reversal_of_journal_entry_id is null and not exists(select 1 from public.journal_entries r where r.company_id=cid and r.reversal_of_journal_entry_id=j.id))else '[]'::jsonb end,
 'wip_overdue',case when full_cost then(select count(*)from private.construction_docs(cid,c.id,as_of)d where kind in('CR_WIP_CAPITALIZE','CR_WIP_OPENING')and(input->>'expected_release_date')::date<as_of and d.amount_minor>coalesce((select sum(s.amount_minor)from private.construction_docs(cid,c.id,as_of)s where s.parent_id=d.id and s.kind in('CR_WIP_RELEASE','CR_WIP_IMPAIR')),0))else null end);
 return result;
end$$;
revoke all on function private.construction_live(uuid,uuid,date),private.construction_docs(uuid,uuid,date),private.construction_value(uuid,uuid,date),private.construction_balance(uuid,uuid,date),private.construction_link_customer(),private.customer_plan_pre103(uuid,text,jsonb),private.customer_plan(uuid,text,jsonb),private.construction_plan(uuid,text,jsonb),private.normalize_construction(jsonb),private.guard_construction_cost_reversal(),public.configure_construction_accounting(uuid,uuid,jsonb),public.preview_construction(uuid,text,jsonb),public.command_construction(uuid,uuid,text,jsonb),public.read_construction(uuid,uuid,date),public.construction_journal_visible(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.configure_construction_accounting(uuid,uuid,jsonb),public.preview_construction(uuid,text,jsonb),public.command_construction(uuid,uuid,text,jsonb),public.read_construction(uuid,uuid,date),public.construction_journal_visible(uuid,uuid)to authenticated;
-- The existing general setup entry point must enforce the same new typed dimensions.
do $$declare def text;begin def:=pg_get_functiondef('public.configure_commercial_accounting(uuid,uuid,jsonb)'::regprocedure);
 if position('a.requires_party<>(k in(''AR'',''CUSTOMER_ADVANCE''))'in def)=0 then raise exception 'Unexpected canonical setup definition; stop rather than weaken controls';end if;
 def:=replace(def,'a.requires_party<>(k in(''AR'',''CUSTOMER_ADVANCE''))','a.requires_party<>(k in(''AR'',''CUSTOMER_ADVANCE'',''CONTRACT_ASSET'',''CONTRACT_LIABILITY'',''CUSTOMER_RETENTION''))');
 def:=replace(def,'if k in(''AR'',''CUSTOMER_ADVANCE'')and not exists','if k in(''AR'',''CUSTOMER_ADVANCE'',''CONTRACT_ASSET'',''CONTRACT_LIABILITY'',''CUSTOMER_RETENTION'',''CONSTRUCTION_WIP'')and not exists');execute def;end$$;
-- Existing receivables must remain collectible after administrative Project closure.
-- Only canonical settlement sources are added; recognition/cost entries still fail closed.
create or replace function private.guard_closed_project_journal()returns trigger language plpgsql set search_path=''as $$
declare s public.project_status;j public.journal_entries;a public.accounts;begin
 if new.project_id is null then return new;end if;
 select status into s from public.projects where company_id=new.company_id and id=new.project_id for share;
 if not found then raise exception 'Company Project unavailable'using errcode='23503';end if;
 if s<>'CLOSED'then return new;end if;
 select *into j from public.journal_entries where company_id=new.company_id and id=new.journal_entry_id;
 if j.source_type='JOURNAL_REVERSAL'and j.reversal_of_journal_entry_id is not null then return new;end if;
 select *into a from public.accounts where company_id=new.company_id and id=new.account_id;
 if j.source_type in('SUPPLIER_PAYMENT','SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_RELEASE','SUBCONTRACTOR_RETENTION_PAYMENT','CUSTODY_CASH_RETURN','SALARY_PAYMENT','AR_RECEIPT','AR_APPLY','AR_REFUND')and a.account_type<>'EXPENSE'then return new;end if;
 raise exception 'Closed Project cannot receive new recognition or cost allocation'using errcode='23514';
end$$;
