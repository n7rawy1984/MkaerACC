-- 80: durable incomplete expense capture. Financial truth remains in canonical commands.
create table public.expense_draft_events (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 draft_id uuid not null, version integer not null check(version>0), request_id uuid not null,
 request_hash text not null, state text not null check(state in ('DRAFT','REVIEWED','CANCELLED','POSTED')),
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'), preview jsonb, receipt jsonb,
 reason text not null check(length(reason) between 1 and 2000),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,draft_id,version),unique(company_id,request_id),
 check((state='POSTED')=(receipt is not null))
);
alter table public.expense_draft_events enable row level security;
alter table public.expense_draft_events force row level security;
revoke all on public.expense_draft_events from public,anon,authenticated,service_role;
grant select on public.expense_draft_events to authenticated;
create policy financial_read on public.expense_draft_events for select to authenticated using (
 public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER')
);
create trigger expense_drafts_immutable before update or delete on public.expense_draft_events for each row execute function private.financial_evidence_immutable();

-- Incomplete raw amounts are source text, never posted money. Exact conversion only at review.
create function private.expense_draft_amount(raw text) returns bigint language plpgsql immutable set search_path='' as $$
declare n numeric;
begin
 if coalesce(btrim(raw),'') !~ '^[0-9]+(\.[0-9]{1,2})?$' or length(raw)>20 then raise exception 'Enter a positive AED amount with at most two decimals' using errcode='22023';end if;
 n:=btrim(raw)::numeric*100;
 if n not between 1 and 9000000000000000 then raise exception 'Amount outside supported range' using errcode='22023';end if;
 return n::bigint;
end;$$;
create function private.validate_expense_draft(cid uuid,v jsonb) returns jsonb language plpgsql set search_path='' as $$
declare d date;pid uuid;cat uuid;tid uuid;person uuid;supplier uuid;net bigint;vat bigint:=0;mode text;funding text;nature text;
begin
 d:=nullif(v->>'date','')::date;pid:=nullif(v->>'project_id','')::uuid;cat:=nullif(v->>'category_id','')::uuid;
 tid:=nullif(v->>'treasury_id','')::uuid;person:=nullif(v->>'paid_by_id','')::uuid;supplier:=nullif(v->>'supplier_id','')::uuid;
 if d is null or coalesce(v->>'period_month','')<>to_char(d,'YYYY-MM') then raise exception 'Date and matching accounting month required' using errcode='23514';end if;
 perform private.opening_period(cid,d);
 if coalesce(length(btrim(v->>'description')),0) not between 1 and 1000 or coalesce(length(btrim(v->>'supporting_reference')),0) not between 1 and 1500 or coalesce(length(btrim(v->>'source_reference')),0) not between 1 and 200 then raise exception 'Description, original source and supporting evidence required before review' using errcode='23514';end if;
 nature:=v->>'nature';
 if nature is distinct from (case when pid is null then 'OPERATING_EXPENSE' else 'PROJECT_COST' end) then raise exception 'Only original operating or Project costs may use expense posting; assets, contract events, transfers and Partner withdrawals require their own workflow' using errcode='23514';end if;
 if v->>'original_cost_not_posted' is distinct from 'true' then raise exception 'Confirm this cost has not already been recognized, including contract certifications' using errcode='23514';end if;
 if pid is not null then
  perform 1 from public.projects where company_id=cid and id=pid and status='ACTIVE' for share;
  if not found then raise exception 'Active same-Company Project required' using errcode='23503';end if;
 end if;
 perform 1 from public.expense_categories where company_id=cid and id=cat and status='ACTIVE' for share;
 if not found then raise exception 'Active expense category required' using errcode='23503';end if;
 if supplier is not null then
  perform 1 from public.parties where company_id=cid and id=supplier and type='SUPPLIER' and status='ACTIVE' for share;
  if not found then raise exception 'Active same-Company Supplier required' using errcode='23503';end if;
 end if;
 net:=private.expense_draft_amount(v->>'net_aed');mode:=v->>'vat_mode';
 if mode='AUTO_5' then vat:=round(net::numeric*5/100)::bigint;
 elsif mode='MANUAL' then vat:=private.expense_draft_amount(v->>'vat_aed');if vat>net then raise exception 'VAT exceeds net amount' using errcode='23514';end if;
 elsif mode is distinct from 'ZERO' then raise exception 'Select VAT treatment' using errcode='23514';end if;
 if net::numeric+vat>9000000000000000 then raise exception 'Gross exceeds supported amount' using errcode='22003';end if;
 if mode<>'ZERO' and (v->>'has_invoice' is distinct from 'true' or coalesce(length(btrim(v->>'invoice_number')),0) not between 1 and 100) then raise exception 'Recoverable VAT requires tax invoice evidence' using errcode='23514';end if;
 if (v->>'has_invoice'='true') is distinct from (coalesce(length(btrim(v->>'invoice_number')),0)>0) then raise exception 'Invoice flag and invoice number must agree' using errcode='23514';end if;
 funding:=v->>'funding_mode';
 if funding='TREASURY' then
  perform 1 from public.treasury_accounts where company_id=cid and id=tid and status='ACTIVE' and (project_id is null or project_id=pid) for share;
  if not found or person is not null then raise exception 'Actual scoped Treasury required; no personal payer' using errcode='23503';end if;
 elsif funding in ('CUSTODIAN','PERSONAL') then
  perform 1 from public.parties where company_id=cid and id=person and status='ACTIVE' and (private.party_has_person_role(cid,id,'CUSTODIAN') or funding='PERSONAL' and private.party_has_person_role(cid,id,'EMPLOYEE')) for share;
  if not found or tid is not null then raise exception 'Eligible active payer required; personal funds are not Treasury' using errcode='23503';end if;
  if funding='PERSONAL' and not exists(select 1 from public.operational_liability_configuration where company_id=cid and classification='REIMBURSEMENT_PAYABLE') then raise exception 'Configure reimbursement liability before posting personal expenses; draft remains saved' using errcode='23514';end if;
 elsif funding='SUPPLIER_CREDIT' then
  if supplier is null or tid is not null or person is not null then raise exception 'Unpaid Supplier credit requires Supplier and no cash source' using errcode='23514';end if;
 else raise exception 'Select payment source' using errcode='23514';end if;
 return jsonb_build_object('net_minor',net::text,'vat_minor',vat::text,'gross_minor',(net+vat)::text);
end;$$;
revoke all on function private.expense_draft_amount(text),private.validate_expense_draft(uuid,jsonb) from public,anon,authenticated,service_role;

create function public.command_expense_draft(cid uuid,draft uuid,expected_version integer,request_id uuid,action text,input jsonb,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid; prev public.expense_draft_events; replay public.expense_draft_events; r public.expense_draft_events;
 v jsonb;h text;k text;summary jsonb;result jsonb; e jsonb;x record;new_state text; eid uuid;
begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if draft is null or expected_version is null or expected_version<0 or request_id is null or action is null or action not in ('SAVE','REVIEW','CANCEL','POST') or input is null or jsonb_typeof(input)<>'object' or coalesce(length(btrim(reason)),0) not between 1 and 2000 then raise exception 'Draft command inputs required' using errcode='22023';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('draft',draft,'version',expected_version,'action',action,'input',input,'reason',btrim(reason),'actor',actor)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into replay from public.expense_draft_events t where t.company_id=cid and t.request_id=request_id;
 if found then
  if replay.request_hash<>h then raise exception 'Request key reused with changed intent' using errcode='22023';end if;
  return to_jsonb(replay);
 end if;
 select * into prev from public.expense_draft_events t where t.company_id=cid and t.draft_id=draft order by t.version desc limit 1;
 if coalesce(prev.version,0)<>expected_version then raise exception 'Draft changed; reload latest version' using errcode='40001';end if;
 if prev.state in ('POSTED','CANCELLED') then raise exception 'Final draft cannot be changed; use canonical reversal for posted financial documents' using errcode='23514';end if;
 if action='SAVE' then
  v:=input;
  if pg_column_size(v)>24000 then raise exception 'Draft too large' using errcode='22023';end if;
  for k in select jsonb_object_keys(v) loop
   if k<>all(array['date','period_month','description','project_id','category_id','supplier_id','funding_mode','treasury_id','paid_by_id','has_invoice','invoice_number','supporting_reference','source_reference','notes','nature','net_aed','vat_mode','vat_aed','original_cost_not_posted']) or jsonb_typeof(v->k) not in ('string','boolean','null') or length(v->>k)>2000 then raise exception 'Unsupported draft input' using errcode='22023';end if;
  end loop;
  new_state:='DRAFT';
 else
  if prev.id is null or input<>'{}'::jsonb then raise exception 'Save the draft first; actions accept no replacement financial inputs' using errcode='23514';end if;
  v:=prev.snapshot;new_state:=case action when 'CANCEL' then 'CANCELLED' when 'REVIEW' then 'REVIEWED' else 'POSTED' end;
  if action in ('REVIEW','POST') then summary:=private.validate_expense_draft(cid,v);end if;
  if action='POST' then
   if prev.state<>'REVIEWED' then raise exception 'Review the current draft version before posting' using errcode='23514';end if;
   -- Reuse canonical original evidence uniqueness across expense drafts, including no-invoice sources.
   perform pg_advisory_xact_lock(hashtextextended('expense-source:'||cid::text||':'||lower(btrim(v->>'source_reference')),0));
   if exists(select 1 from public.expense_draft_events t where t.company_id=cid and t.state='POSTED' and lower(btrim(t.snapshot->>'source_reference'))=lower(btrim(v->>'source_reference'))) then raise exception 'Original expense source already posted; inspect existing document' using errcode='23505';end if;
   if v->>'funding_mode'='PERSONAL' then
    e:=public.submit_financial_operation_evidence(cid,request_id,jsonb_build_object('kind','PERSONAL_EXPENSE','event_date',v->>'date','counterparty_id',v->>'paid_by_id','project_id',nullif(v->>'project_id',''),'amount_minor',summary->>'gross_minor','classification','PERSONAL_FUNDS','destination','PERSONAL_FUNDS','source_reference',v->>'source_reference','description',v->>'description','supporting_reference',v->>'supporting_reference'));
    eid:=(e->>'id')::uuid;
    perform public.review_financial_operation_evidence(cid,request_id,eid,'REVIEWED',reason);
    result:=public.post_reviewed_financial_operation(cid,request_id,eid,jsonb_build_object('net_minor',summary->>'net_minor','vat_mode',v->>'vat_mode','manual_vat_minor',case when v->>'vat_mode'='MANUAL' then summary->>'vat_minor' end,'expense_category_id',v->>'category_id','supplier_id',nullif(v->>'supplier_id',''),'invoice_number',nullif(btrim(v->>'invoice_number'),''),'has_tax_invoice',coalesce((v->>'has_invoice')::boolean,false),'original_cost_not_posted',true,'cost_classification',v->>'nature','approval_reference',reason));
   else
    select * into x from public.post_expense(cid,(v->>'date')::date,nullif(v->>'project_id','')::uuid,(v->>'category_id')::uuid,btrim(v->>'description'),(summary->>'net_minor')::bigint,(v->>'vat_mode')::public.expense_vat_mode,case when v->>'vat_mode'='MANUAL' then (summary->>'vat_minor')::bigint end,(v->>'funding_mode')::public.expense_funding_mode,nullif(v->>'treasury_id','')::uuid,nullif(v->>'paid_by_id','')::uuid,nullif(v->>'supplier_id','')::uuid,case when v->>'funding_mode'='TREASURY' and exists(select 1 from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid and type='BANK') then 'BANK'::public.payment_method else 'CASH'::public.payment_method end,coalesce((v->>'has_invoice')::boolean,false),nullif(btrim(v->>'invoice_number'),''),left(concat_ws(E'\n',v->>'source_reference',v->>'supporting_reference',v->>'notes'),2000),request_id);
    result:=jsonb_build_object('id',x.expense_id,'reference',x.expense_reference,'journal',x.journal_entry_id,'replayed',x.replayed);
   end if;
  end if;
 end if;
 insert into public.expense_draft_events(company_id,draft_id,version,request_id,request_hash,state,snapshot,preview,receipt,reason,created_by)
 values(cid,draft,expected_version+1,request_id,h,new_state,v,summary,result,btrim(reason),actor) returning * into r;
 return to_jsonb(r);
end;$$;
revoke all on function public.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) from public,anon,authenticated,service_role;
grant execute on function public.command_expense_draft(uuid,uuid,integer,uuid,text,jsonb,text) to authenticated;
comment on table public.expense_draft_events is 'Append-only unposted source versions and canonical posting receipts. Saving and reviewing never posts; editing invalidates review. Asset/contract/transfer sources remain unposted.';
