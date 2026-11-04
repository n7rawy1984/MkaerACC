-- Private serialization versions contain no amounts or financial balances.
create table private.operational_finance_serialization(company_id uuid not null references public.companies(id),scope text not null check(scope in ('OPERATIONS','TREASURY') or scope like 'CUSTODY:%' or scope like 'INVOICE:%'),revision bigint not null,primary key(company_id,scope));
revoke all on private.operational_finance_serialization from public,anon,authenticated,service_role;
create function private.serialize_operational_finance(cid uuid,lock_scope text) returns void language plpgsql security definer set search_path='' as $$
begin
 if lock_scope not in ('OPERATIONS','TREASURY') and lock_scope!~'^CUSTODY:[0-9a-f-]{36}$' and lock_scope!~'^INVOICE:[0-9a-f]{64}$' then raise exception 'Invalid private serialization scope';end if;
 perform pg_advisory_xact_lock(hashtextextended('operational-serialization:'||cid::text||':'||lock_scope,0));
 insert into private.operational_finance_serialization values(cid,lock_scope,1) on conflict(company_id,scope) do update set revision=private.operational_finance_serialization.revision+1;
end;$$;
revoke all on function private.serialize_operational_finance(uuid,text) from public,anon,authenticated,service_role;
-- Configured capital/additional-capital/current/loan funding and separate reimbursement obligations.
-- No global OWNER_CURRENT type is assumed. Capital returns/distributions stay unposted.
create table public.operational_liability_configuration (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 classification text not null check(classification in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL','PARTNER_CURRENT','PARTNER_LOAN','REIMBURSEMENT_PAYABLE')),
 request_key uuid not null,request_hash text not null,account_id uuid not null,account_type public.account_type not null,allow_withdrawals boolean not null,
 previous_configuration_id uuid unique,approval_reference text not null check(length(approval_reference) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),foreign key(company_id,account_id) references public.accounts(company_id,id),
 foreign key(company_id,previous_configuration_id) references public.operational_liability_configuration(company_id,id),
 check((classification in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL') and account_type='EQUITY' and not allow_withdrawals) or (classification='PARTNER_CURRENT' and account_type in ('LIABILITY','EQUITY')) or (classification in ('PARTNER_LOAN','REIMBURSEMENT_PAYABLE') and account_type='LIABILITY' and allow_withdrawals))
);
create unique index operational_configuration_root on public.operational_liability_configuration(company_id,classification) where previous_configuration_id is null;
create table public.operational_liability_postings (
 id uuid primary key,company_id uuid not null references public.companies(id),
 evidence_id uuid not null,finance_reference text not null,
 kind text not null check(kind in ('PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','PARTNER_CURRENT_WITHDRAWAL','PERSONAL_EXPENSE_RECOGNITION','PARTNER_LOAN_REPAYMENT','PERSONAL_REIMBURSEMENT')),
 configuration_id uuid not null,classification text not null,parent_posting_id uuid,counterparty_id uuid not null,recipient_id uuid,
 treasury_account_id uuid,project_id uuid,posting_date date not null,
 amount_minor bigint not null check(amount_minor between 1 and 9000000000000000),
 net_minor bigint not null check(net_minor>=0),vat_minor bigint not null check(vat_minor>=0),
 expense_category_id uuid,supplier_id uuid,invoice_number text,
 account_id uuid not null,posted_journal_entry_id uuid not null,
 posting_evidence jsonb not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,evidence_id),unique(company_id,finance_reference),
 foreign key(company_id,configuration_id) references public.operational_liability_configuration(company_id,id),
 foreign key(company_id,evidence_id) references public.financial_operation_evidence(company_id,id),
 foreign key(company_id,parent_posting_id) references public.operational_liability_postings(company_id,id),
 foreign key(company_id,counterparty_id) references public.parties(company_id,id),
 foreign key(company_id,recipient_id) references public.parties(company_id,id),
 foreign key(company_id,treasury_account_id) references public.treasury_accounts(company_id,id),
 foreign key(company_id,project_id) references public.projects(company_id,id),
 foreign key(company_id,account_id) references public.accounts(company_id,id),
 foreign key(company_id,expense_category_id) references public.expense_categories(company_id,id),
 foreign key(company_id,supplier_id) references public.parties(company_id,id),
 foreign key(company_id,posted_journal_entry_id) references public.journal_entries(company_id,id),
 check((kind in ('PARTNER_LOAN_REPAYMENT','PERSONAL_REIMBURSEMENT'))=(parent_posting_id is not null)),
 check(kind<>'PERSONAL_EXPENSE_RECOGNITION' or net_minor+vat_minor=amount_minor)
);
create table public.operational_liability_reversals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,
 posting_id uuid not null,posting_date date not null,reason text not null check(length(reason) between 1 and 1000),
 reversal_journal_entry_id uuid not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,posting_id),
 foreign key(company_id,posting_id) references public.operational_liability_postings(company_id,id),
 foreign key(company_id,reversal_journal_entry_id) references public.journal_entries(company_id,id)
);
do $$declare t text;begin foreach t in array array['operational_liability_configuration','operational_liability_postings','operational_liability_reversals'] loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy operational_liability_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'') or public.has_company_role(company_id,''ACCOUNTANT'') or public.has_company_role(company_id,''MANAGEMENT_VIEWER''))',t);
 execute format('create trigger operational_liability_immutable before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
end loop;end;$$;
create function private.operational_finance_actor(cid uuid,permission text) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();begin
 if actor is null then raise exception 'Financial access denied' using errcode='42501';end if;
 perform 1 from public.companies where id=cid and status='ACTIVE' for share;
 if not found then raise exception 'Company unavailable' using errcode='42501';end if;
 perform 1 from public.profiles where user_id=actor and status='ACTIVE' for share;
 if not found then raise exception 'Profile unavailable' using errcode='42501';end if;
 perform 1 from public.company_memberships where company_id=cid and user_id=actor and status='ACTIVE' and role in ('ACCOUNTING_ADMIN','ACCOUNTANT') for share;
 if not found or not public.has_permission(cid,permission) then raise exception 'Financial permission denied' using errcode='42501';end if;
 return actor;
end;$$;
revoke all on function private.operational_finance_actor(uuid,text) from public,anon,authenticated,service_role;
create function public.configure_financial_operation_account(target_company_id uuid,target_request_key uuid,target_classification text,target_account_id uuid,target_allow_withdrawals boolean,target_approval_reference text,target_certified_existing boolean default false,target_account_code text default null,target_account_name text default null,target_account_type public.account_type default null)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.operational_liability_configuration;a public.accounts;hash text;begin
 actor:=private.operational_finance_actor(target_company_id,'account.manage');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or coalesce(length(btrim(target_approval_reference)),0) not between 1 and 1000 or target_classification is null or target_classification not in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL','PARTNER_CURRENT','PARTNER_LOAN','REIMBURSEMENT_PAYABLE') or target_allow_withdrawals is null then raise exception 'Approved classified account mapping required' using errcode='22023';end if;
 if target_request_key is null then raise exception 'Configuration request key required' using errcode='22023';end if;
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('class',target_classification,'account',target_account_id,'new_code',upper(btrim(target_account_code)),'new_name',btrim(target_account_name),'new_type',target_account_type,'withdrawals',target_allow_withdrawals,'approval',btrim(target_approval_reference),'certified',coalesce(target_certified_existing,false),'actor',actor)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into r from public.operational_liability_configuration where company_id=target_company_id and request_key=target_request_key;
 if found then
  if r.request_hash<>hash then raise exception 'Changed configuration intent' using errcode='22023';end if;
  return jsonb_build_object('configured',true,'id',r.id);
 end if;
 if target_account_id is null then
  if coalesce(length(btrim(target_account_code)),0) not between 1 and 50 or coalesce(length(btrim(target_account_name)),0) not between 1 and 200 or target_account_type is null or (target_classification in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL') and target_account_type<>'EQUITY') or (target_classification in ('PARTNER_LOAN','REIMBURSEMENT_PAYABLE') and target_account_type<>'LIABILITY') or (target_classification='PARTNER_CURRENT' and target_account_type not in ('LIABILITY','EQUITY')) then raise exception 'Explicit approved dedicated balance-sheet control details required' using errcode='22023';end if;
  if exists(select 1 from public.operational_liability_configuration where company_id=target_company_id and classification=target_classification) then raise exception 'Classification already configured; use its immutable account' using errcode='23514';end if;
  insert into public.accounts(company_id,code,name,account_type,requires_party,created_by,updated_by) values(target_company_id,upper(btrim(target_account_code)),btrim(target_account_name),target_account_type,true,actor,actor) returning * into a;
  target_account_id:=a.id;
 else
  if target_account_code is not null or target_account_name is not null or target_account_type is not null then raise exception 'Choose existing account or dedicated creation, not both' using errcode='22023';end if;
  select * into a from public.accounts where company_id=target_company_id and id=target_account_id for share;
 end if;
 if not found or a.status<>'ACTIVE' or not a.requires_party or (a.system_key is not null and not(target_classification='PARTNER_CURRENT' and a.system_key='OWNER_CURRENT')) then raise exception 'Approved dedicated Party balance-sheet account required' using errcode='23514';end if;
 if (target_classification in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL') and (a.account_type<>'EQUITY' or target_allow_withdrawals)) or (target_classification='PARTNER_CURRENT' and a.account_type not in ('LIABILITY','EQUITY')) or (target_classification in ('PARTNER_LOAN','REIMBURSEMENT_PAYABLE') and (a.account_type<>'LIABILITY' or not target_allow_withdrawals)) then raise exception 'Classification/account-type/withdrawal policy mismatch' using errcode='23514';end if;
 if exists(select 1 from public.operational_liability_configuration c where c.company_id=target_company_id and c.account_id=target_account_id and c.classification<>target_classification) then raise exception 'Financial categories require separate control accounts' using errcode='23514';end if;
 select * into r from public.operational_liability_configuration c where c.company_id=target_company_id and c.classification=target_classification order by c.created_at desc,c.id desc limit 1;
 if found then
  if r.account_id<>target_account_id or r.account_type<>a.account_type then raise exception 'Historical control mapping cannot change; reviewed reclassification required' using errcode='23514';end if;

 elsif exists(select 1 from public.journal_lines l where l.company_id=target_company_id and l.account_id=target_account_id) and not coalesce(target_certified_existing,false) then raise exception 'Existing balances require explicit certified-purpose/opening authorization; no silent reclassification' using errcode='23514';end if;
 insert into public.operational_liability_configuration(company_id,request_key,request_hash,classification,account_id,account_type,allow_withdrawals,previous_configuration_id,approval_reference,created_by) values(target_company_id,target_request_key,hash,target_classification,target_account_id,a.account_type,target_allow_withdrawals,r.id,btrim(target_approval_reference),actor) returning * into r;
 return jsonb_build_object('configured',true,'id',r.id);
end;$$;
-- Shared by every Treasury journal, including legacy custody/Expense/payment commands.
-- Receiving funds can repair a negative/incomplete legacy ledger; an outgoing
-- movement cannot manufacture further cash or an unconfigured overdraft.
create function private.guard_recorded_treasury_funds() returns trigger language plpgsql security definer set search_path='' as $$
declare treasury uuid;balance numeric;event_date date;custody boolean;begin
 select t.id into treasury from public.treasury_accounts t where t.company_id=new.company_id and t.gl_account_id=new.account_id;
 custody:=exists(select 1 from public.accounts a where a.company_id=new.company_id and a.id=new.account_id and a.system_key='CUSTODY_ADVANCE');
 if treasury is null and not custody then return new;end if;
 if custody then
  if new.party_id is null then raise exception 'Custody person required' using errcode='23514';end if;
  perform private.serialize_operational_finance(new.company_id,'CUSTODY:'||new.party_id::text);
 else perform private.serialize_operational_finance(new.company_id,'TREASURY');end if;
 if treasury is not null and new.treasury_account_id is distinct from treasury then raise exception 'Treasury GL dimension required' using errcode='23514';end if;
 if new.credit_minor>new.debit_minor then
  select posting_date into event_date from public.journal_entries where company_id=new.company_id and id=new.journal_entry_id;
  select min(running) into balance from (
   select d,sum(movement) over(order by d) running from (
    select d,sum(movement) movement from (
     select j.posting_date d,l.debit_minor::numeric-l.credit_minor::numeric movement from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=new.company_id and l.account_id=new.account_id and (not custody or l.party_id=new.party_id)
     union all select event_date,new.debit_minor::numeric-new.credit_minor::numeric
    ) raw group by d
   ) daily
  ) dated where d>=event_date;
  if balance<0 then raise exception 'Insufficient recorded Treasury funds; verify funding/opening evidence; no overdraft configured' using errcode='23514';end if;
 end if;
 return new;
end;$$;
revoke all on function private.guard_recorded_treasury_funds() from public,anon,authenticated,service_role;
create trigger recorded_treasury_funds before insert on public.journal_lines for each row execute function private.guard_recorded_treasury_funds();
create function public.post_reviewed_financial_operation(target_company_id uuid,target_request_key uuid,target_evidence_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;e public.financial_operation_evidence;cfg public.operational_liability_configuration;parent public.operational_liability_postings;request private.financial_command_requests;
 p public.operational_liability_postings;row_id uuid:=gen_random_uuid();ref text;journal uuid;kind text;control uuid;cost uuid;vat_account uuid;treasury public.treasury_accounts;lines jsonb;
 v jsonb:=business_input;k text;hash text;net bigint:=0;vat bigint:=0;mode text;category uuid;supplier uuid;invoice text;parent_id uuid;paid numeric;review_state text;
begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if target_request_key is null or target_evidence_id is null or v is null or jsonb_typeof(v)<>'object' then raise exception 'Reviewed business inputs required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop
  if k<>all(array['parent_posting_id','net_minor','vat_mode','manual_vat_minor','expense_category_id','supplier_id','invoice_number','original_cost_not_posted','has_tax_invoice','approved_classification','cost_classification','approval_reference']) then raise exception 'Unsupported financial input' using errcode='22023';end if;
 end loop;
 if coalesce(length(btrim(v->>'approval_reference')),0) not between 1 and 1000 then raise exception 'Accounting approval reference required' using errcode='22023';end if;
 v:=jsonb_build_object('parent_posting_id',nullif(v->>'parent_posting_id','')::uuid,'net_minor',case when v->>'net_minor' is null then null else ((v->>'net_minor')::bigint)::text end,'vat_mode',upper(btrim(v->>'vat_mode')),'manual_vat_minor',case when v->>'manual_vat_minor' is null then null else ((v->>'manual_vat_minor')::bigint)::text end,'expense_category_id',nullif(v->>'expense_category_id','')::uuid,'supplier_id',nullif(v->>'supplier_id','')::uuid,'invoice_number',nullif(btrim(v->>'invoice_number'),''),'original_cost_not_posted',coalesce((v->>'original_cost_not_posted')::boolean,false),'has_tax_invoice',coalesce((v->>'has_tax_invoice')::boolean,false),'approved_classification',v->>'approved_classification','cost_classification',v->>'cost_classification','approval_reference',btrim(v->>'approval_reference'));
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('evidence',target_evidence_id,'input',v,'actor',actor)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 request:=private.reserve_financial_command(target_company_id,'POST_OPERATIONAL_FINANCE',target_request_key,hash,actor);
 if request.status='COMPLETED' then
  select * into p from public.operational_liability_postings where company_id=target_company_id and posted_journal_entry_id=request.resulting_journal_entry_id;
  return jsonb_build_object('id',p.id,'reference',p.finance_reference,'journal',p.posted_journal_entry_id,'replayed',true);
 end if;
 select * into e from public.financial_operation_evidence where company_id=target_company_id and id=target_evidence_id for update;
 if not found then raise exception 'Company evidence unavailable' using errcode='23503';end if;
 if exists(select 1 from public.operational_liability_postings where company_id=target_company_id and evidence_id=e.id) then raise exception 'Evidence already recognized; use the original receipt' using errcode='23505';end if;
 select decision into review_state from public.financial_operation_evidence_reviews where company_id=target_company_id and evidence_id=e.id order by created_at desc,id desc limit 1;
 if review_state is distinct from 'REVIEWED' then raise exception 'Source evidence must be reviewed first' using errcode='23514';end if;
 
 if e.kind='PARTNER_FUNDING' then
  if v->>'approved_classification' is null or v->>'approved_classification' not in ('PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL','PARTNER_CURRENT','PARTNER_LOAN') then raise exception 'Select the actual approved funding classification; no default loan treatment' using errcode='23514';end if;
  if e.classification<>'UNCLASSIFIED' and (case e.classification when 'CAPITAL' then 'PARTNER_CAPITAL' when 'ADDITIONAL_CAPITAL' then 'PARTNER_ADDITIONAL_CAPITAL' when 'CURRENT_ACCOUNT' then 'PARTNER_CURRENT' else e.classification end)<>v->>'approved_classification' then raise exception 'Original evidence classification differs; review source before posting' using errcode='23514';end if;
  kind:=(v->>'approved_classification')||'_FUNDING';
 elsif e.kind='PERSONAL_EXPENSE' then kind:='PERSONAL_EXPENSE_RECOGNITION';
 elsif e.kind='PARTNER_WITHDRAWAL' and e.classification='LOAN_REPAYMENT' and v->>'approved_classification'='PARTNER_LOAN' then kind:='PARTNER_LOAN_REPAYMENT';
 elsif e.kind='PARTNER_WITHDRAWAL' and e.classification in ('CURRENT_ACCOUNT','DRAWING','UNCLASSIFIED') and v->>'approved_classification'='PARTNER_CURRENT' then kind:='PARTNER_CURRENT_WITHDRAWAL';
 elsif e.kind='PERSONAL_REIMBURSEMENT' then kind:='PERSONAL_REIMBURSEMENT';
 else raise exception 'Select a supported approved category; capital returns/distributions/counts require separate authorization contracts' using errcode='23514';end if;
 select * into cfg from public.operational_liability_configuration c where c.company_id=target_company_id and c.classification=(case when kind in ('PERSONAL_EXPENSE_RECOGNITION','PERSONAL_REIMBURSEMENT') then 'REIMBURSEMENT_PAYABLE' else v->>'approved_classification' end) order by c.created_at desc,c.id desc limit 1;
 if not found then raise exception 'Approved classified accounting configuration required' using errcode='23514';end if;
 control:=cfg.account_id;
 if kind='PARTNER_CURRENT_WITHDRAWAL' and not cfg.allow_withdrawals then raise exception 'Current-account withdrawal authorization required' using errcode='23514';end if;
 if kind in ('PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','PERSONAL_EXPENSE_RECOGNITION') and not (private.company_commercial_readiness(target_company_id)->>'ready')::boolean then raise exception 'Commercial readiness required for new recognition' using errcode='42501';end if;
 perform 1 from public.parties where company_id=target_company_id and id in (e.counterparty_id,e.recipient_id) order by id for update;
 if kind in ('PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING','PERSONAL_EXPENSE_RECOGNITION') then
  if not exists(select 1 from public.parties where company_id=target_company_id and id=e.counterparty_id and status='ACTIVE' and (case when e.kind='PARTNER_FUNDING' then type='OWNER' else type in ('EMPLOYEE','CUSTODIAN') or exists(select 1 from public.party_person_roles pr where pr.company_id=target_company_id and pr.party_id=e.counterparty_id and pr.role in ('EMPLOYEE','CUSTODIAN')) end)) then raise exception 'Active appropriate source Party required for new recognition' using errcode='23514';end if;
 end if;
 if e.destination='DIRECT_CUSTODY' and not exists(select 1 from public.parties where company_id=target_company_id and id=e.recipient_id and status='ACTIVE' and (type='CUSTODIAN' or exists(select 1 from public.party_person_roles pr where pr.company_id=target_company_id and pr.party_id=e.recipient_id and pr.role='CUSTODIAN'))) then raise exception 'Active authorized Custody recipient required' using errcode='23514';end if;
 if e.treasury_id is not null then
  select * into treasury from public.treasury_accounts where company_id=target_company_id and id=e.treasury_id and status='ACTIVE' for share;
  if not found then raise exception 'Active actual Treasury required' using errcode='23514';end if;
  if treasury.project_id is not null and treasury.project_id is distinct from e.project_id then raise exception 'Project Treasury scope mismatch' using errcode='23514';end if;
 end if;
 if kind in ('PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING') then
  if e.destination='DIRECT_CUSTODY' then
   select a.id into cost from public.accounts a where a.company_id=target_company_id and a.system_key='CUSTODY_ADVANCE' and a.account_type='ASSET' and a.requires_party and a.status='ACTIVE';
   if cost is null then raise exception 'Custody control mapping missing' using errcode='23514';end if;
   lines:=jsonb_build_array(jsonb_build_object('account_id',cost,'debit_minor',e.amount_minor,'credit_minor',0,'party_id',e.recipient_id,'project_id',e.project_id),jsonb_build_object('account_id',control,'debit_minor',0,'credit_minor',e.amount_minor,'party_id',e.counterparty_id));
  else
   lines:=jsonb_build_array(jsonb_build_object('account_id',treasury.gl_account_id,'debit_minor',e.amount_minor,'credit_minor',0,'treasury_account_id',treasury.id),jsonb_build_object('account_id',control,'debit_minor',0,'credit_minor',e.amount_minor,'party_id',e.counterparty_id));
  end if;
 elsif kind='PERSONAL_EXPENSE_RECOGNITION' then
  if v->>'cost_classification' is distinct from (case when e.project_id is null then 'OPERATING_EXPENSE' else 'PROJECT_COST' end) then raise exception 'Only supported operating/Project costs may be recognized; inventory/assets/settlements use separate workflows' using errcode='23514';end if;
  if v->>'original_cost_not_posted' is distinct from 'true' or coalesce(v->>'net_minor','')!~'^[0-9]+$' then raise exception 'Verified new cost recognition required; existing posted costs cannot be recognized twice' using errcode='23514';end if;
  net:=(v->>'net_minor')::bigint;mode:=v->>'vat_mode';category:=(v->>'expense_category_id')::uuid;supplier:=nullif(v->>'supplier_id','')::uuid;invoice:=nullif(btrim(v->>'invoice_number'),'');
  if net not between 1 and 9000000000000000 or mode is null or mode not in ('ZERO','AUTO_5','MANUAL') then raise exception 'Expense/VAT inputs required' using errcode='22023';end if;
  if mode='AUTO_5' then vat:=round(net::numeric*5/100)::bigint;elsif mode='MANUAL' then
   if coalesce(v->>'manual_vat_minor','')!~'^[0-9]+$' then raise exception 'Exact VAT required' using errcode='22023';end if;vat:=(v->>'manual_vat_minor')::bigint;
  end if;
  if vat<0 or net::numeric+vat::numeric<>e.amount_minor or (mode<>'ZERO' and (invoice is null or v->>'has_tax_invoice'<>'true')) or length(invoice)>100 then raise exception 'Gross/source/VAT evidence mismatch' using errcode='23514';end if;
  if not exists(select 1 from public.expense_categories where company_id=target_company_id and id=category and status='ACTIVE') then raise exception 'Actual expense category required' using errcode='23503';end if;
  if supplier is not null and not exists(select 1 from public.parties where company_id=target_company_id and id=supplier and type='SUPPLIER') then raise exception 'Company Supplier required' using errcode='23503';end if;
  if invoice is not null then
   perform private.serialize_operational_finance(target_company_id,'INVOICE:'||encode(extensions.digest(convert_to(coalesce(supplier::text,'NONE')||':'||lower(btrim(invoice)),'UTF8'),'sha256'),'hex'));
   if exists(select 1 from public.expenses x where x.company_id=target_company_id and lower(btrim(x.invoice_number))=lower(btrim(invoice)) and x.supplier_id is not distinct from supplier and (x.status<>'REVERSED' or exists(select 1 from public.journal_entries j where j.company_id=x.company_id and j.id=x.reversal_journal_entry_id and j.posting_date>e.event_date))) or exists(select 1 from public.operational_liability_postings x where x.company_id=target_company_id and lower(btrim(x.invoice_number))=lower(btrim(invoice)) and x.supplier_id is not distinct from supplier and not exists(select 1 from public.operational_liability_reversals r where r.company_id=x.company_id and r.posting_id=x.id and r.posting_date<=e.event_date)) then raise exception 'Invoice already recognized; reverse/correct original cost instead of reposting' using errcode='23505';end if;
  end if;
  select id into cost from public.accounts where company_id=target_company_id and system_key=(case when e.project_id is null then 'COMPANY_EXPENSE' else 'PROJECT_COST' end)::public.system_account_key and account_type='EXPENSE' and status='ACTIVE';
  if cost is null then raise exception 'Approved cost mapping required' using errcode='23514';end if;
  lines:=jsonb_build_array(jsonb_build_object('account_id',cost,'debit_minor',net,'credit_minor',0,'project_id',e.project_id),jsonb_build_object('account_id',control,'debit_minor',0,'credit_minor',e.amount_minor,'party_id',e.counterparty_id,'project_id',e.project_id));
  if vat>0 then
   select id into vat_account from public.accounts where company_id=target_company_id and system_key='INPUT_VAT' and status='ACTIVE';
   if vat_account is null then raise exception 'Input VAT mapping required' using errcode='23514';end if;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat_account,'debit_minor',vat,'credit_minor',0));
  end if;
 elsif kind='PARTNER_CURRENT_WITHDRAWAL' then
  with movements as(select j.posting_date d,sum(l.credit_minor::numeric-l.debit_minor::numeric) delta from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=target_company_id and l.account_id=control and l.party_id=e.counterparty_id group by j.posting_date union all select e.event_date,0), daily as(select d,sum(delta) delta from movements group by d), running as(select d,sum(delta) over(order by d) balance from daily) select min(balance) into paid from running where d>=e.event_date;
  if paid<e.amount_minor then raise exception 'Withdrawal exceeds recorded current-account credit; no partner overdraft/receivable authorized' using errcode='23514';end if;
  lines:=jsonb_build_array(jsonb_build_object('account_id',control,'debit_minor',e.amount_minor,'credit_minor',0,'party_id',e.counterparty_id),jsonb_build_object('account_id',treasury.gl_account_id,'debit_minor',0,'credit_minor',e.amount_minor,'treasury_account_id',treasury.id));
 else
  parent_id:=(v->>'parent_posting_id')::uuid;
  select * into parent from public.operational_liability_postings where company_id=target_company_id and id=parent_id for update;
  if not found or e.event_date<parent.posting_date or parent.counterparty_id<>e.counterparty_id or parent.kind is distinct from (case when kind='PARTNER_LOAN_REPAYMENT' then 'PARTNER_LOAN_FUNDING' else 'PERSONAL_EXPENSE_RECOGNITION' end) or exists(select 1 from public.operational_liability_reversals where company_id=target_company_id and posting_id=parent.id) then raise exception 'Active original liability required' using errcode='23514';end if;
  with changes as (
   select child.posting_date d,child.amount_minor::numeric delta from public.operational_liability_postings child where child.company_id=target_company_id and child.parent_posting_id=parent.id
   union all select r.posting_date,-child.amount_minor::numeric from public.operational_liability_postings child join public.operational_liability_reversals r on r.company_id=child.company_id and r.posting_id=child.id where child.company_id=target_company_id and child.parent_posting_id=parent.id
   union all select e.event_date,0
  ),daily as(select d,sum(delta) delta from changes group by d),running as(select d,sum(delta) over(order by d) paid_total from daily) select coalesce(max(paid_total),0) into paid from running where d>=e.event_date;
  if paid+e.amount_minor::numeric>parent.amount_minor then raise exception 'Payment exceeds remaining original liability' using errcode='23514';end if;
  control:=parent.account_id;
  lines:=jsonb_build_array(jsonb_build_object('account_id',control,'debit_minor',e.amount_minor,'credit_minor',0,'party_id',e.counterparty_id,'project_id',case when kind='PERSONAL_REIMBURSEMENT' then parent.project_id else null end),jsonb_build_object('account_id',treasury.gl_account_id,'debit_minor',0,'credit_minor',e.amount_minor,'treasury_account_id',treasury.id));
 end if;
 ref:=private.allocate_reference(target_company_id,'FIN',extract(year from e.event_date)::integer);
 journal:=private.create_journal(target_company_id,e.event_date,e.description,kind,row_id,'ORIGINAL',lines,actor,null);
 insert into public.operational_liability_postings(id,company_id,evidence_id,finance_reference,kind,configuration_id,classification,parent_posting_id,counterparty_id,recipient_id,treasury_account_id,project_id,posting_date,amount_minor,net_minor,vat_minor,expense_category_id,supplier_id,invoice_number,account_id,posted_journal_entry_id,posting_evidence,created_by)
 values(row_id,target_company_id,e.id,ref,kind,cfg.id,cfg.classification,parent_id,e.counterparty_id,e.recipient_id,e.treasury_id,e.project_id,e.event_date,e.amount_minor,net,vat,category,supplier,invoice,control,journal,v,actor);
 perform private.complete_financial_command(request.id,journal);
 return jsonb_build_object('id',row_id,'reference',ref,'journal',journal,'replayed',false);
end;$$;
create function public.reverse_operational_financial_posting(target_company_id uuid,target_request_key uuid,target_posting_id uuid,target_date date,target_reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;p public.operational_liability_postings;r private.financial_command_requests;hash text;journal uuid;remaining numeric;begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.reverse');
 if target_request_key is null or target_date is null or not isfinite(target_date) or extract(year from target_date) not between 1 and 9999 or coalesce(length(btrim(target_reason)),0) not between 1 and 1000 then raise exception 'Reason/date required' using errcode='22023';end if;
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('posting',target_posting_id,'date',target_date,'reason',btrim(target_reason))::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 r:=private.reserve_financial_command(target_company_id,'REVERSE_OPERATIONAL_FINANCE',target_request_key,hash,actor);
 if r.status='COMPLETED' then return jsonb_build_object('id',target_posting_id,'reference',(select finance_reference from public.operational_liability_postings where company_id=target_company_id and id=target_posting_id),'journal',r.resulting_journal_entry_id,'replayed',true);end if;
 select * into p from public.operational_liability_postings where company_id=target_company_id and id=target_posting_id for update;
 if not found or target_date<p.posting_date then raise exception 'Original posting/date unavailable' using errcode='23514';end if;
 if exists(select 1 from public.operational_liability_postings c where c.company_id=target_company_id and c.parent_posting_id=p.id and not exists(select 1 from public.operational_liability_reversals x where x.company_id=c.company_id and x.posting_id=c.id)) then raise exception 'Reverse dependent payments before original recognition' using errcode='23514';end if;
 if exists(select 1 from public.operational_liability_postings child join public.operational_liability_reversals reversal_proof on reversal_proof.company_id=child.company_id and reversal_proof.posting_id=child.id where child.company_id=target_company_id and child.parent_posting_id=p.id and reversal_proof.posting_date>target_date) then raise exception 'Original reversal cannot precede dependent payment reversals' using errcode='23514';end if;
 if p.kind='PARTNER_CURRENT_FUNDING' then
  with movements as(select j.posting_date d,sum(l.credit_minor::numeric-l.debit_minor::numeric) delta from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=target_company_id and l.account_id=p.account_id and l.party_id=p.counterparty_id group by j.posting_date union all select target_date,0),daily as(select d,sum(delta) delta from movements group by d),running as(select d,sum(delta) over(order by d) balance from daily) select min(balance) into remaining from running where d>=target_date;
  if remaining<p.amount_minor then raise exception 'Reverse dependent current-account withdrawals before funding' using errcode='23514';end if;
 end if;
 if p.kind in ('PARTNER_LOAN_FUNDING','PARTNER_CAPITAL_FUNDING','PARTNER_ADDITIONAL_CAPITAL_FUNDING','PARTNER_CURRENT_FUNDING') and p.recipient_id is not null and p.treasury_account_id is null then
  perform 1 from public.parties where company_id=target_company_id and id=p.recipient_id for update;
  remaining:=private.custody_balance_minor(target_company_id,p.recipient_id);
  if remaining<p.amount_minor then raise exception 'Custody funding already consumed; restore dependencies first' using errcode='23514';end if;
 end if;
 journal:=private.reverse_journal(p.posted_journal_entry_id,target_date,btrim(target_reason),actor);
 insert into public.operational_liability_reversals(company_id,posting_id,posting_date,reason,reversal_journal_entry_id,created_by) values(target_company_id,p.id,target_date,btrim(target_reason),journal,actor);
 perform private.complete_financial_command(r.id,journal);
 return jsonb_build_object('id',p.id,'reference',p.finance_reference,'journal',journal,'replayed',false);
end;$$;
revoke all on function public.configure_financial_operation_account(uuid,uuid,text,uuid,boolean,text,boolean,text,text,public.account_type),public.post_reviewed_financial_operation(uuid,uuid,uuid,jsonb),public.reverse_operational_financial_posting(uuid,uuid,uuid,date,text) from public,anon,authenticated,service_role;
grant execute on function public.configure_financial_operation_account(uuid,uuid,text,uuid,boolean,text,boolean,text,text,public.account_type),public.post_reviewed_financial_operation(uuid,uuid,uuid,jsonb),public.reverse_operational_financial_posting(uuid,uuid,uuid,date,text) to authenticated;
-- Safe source reader for existing Party/Custody/Project reporting.
create view public.operational_liability_documents with(security_invoker=true) as
 select p.*,e.source_reference,e.description,e.supporting_reference,case when exists(select 1 from public.operational_liability_reversals r where r.company_id=p.company_id and r.posting_id=p.id) then 'REVERSED' else 'POSTED' end as status
 from public.operational_liability_postings p join public.financial_operation_evidence e on e.company_id=p.company_id and e.id=p.evidence_id;
grant select on public.operational_liability_documents to authenticated;

-- Existing closed-Project liabilities remain settleable; new cost remains blocked.
create or replace function private.guard_closed_project_journal() returns trigger language plpgsql set search_path='' as $$
declare s public.project_status;j public.journal_entries;a public.accounts;begin
 if new.project_id is null then return new;end if;
 select status into s from public.projects where company_id=new.company_id and id=new.project_id for share;
 if not found then raise exception 'Company Project unavailable' using errcode='23503';end if;
 if s<>'CLOSED' then return new;end if;
 select * into j from public.journal_entries where company_id=new.company_id and id=new.journal_entry_id;
 if j.source_type='JOURNAL_REVERSAL' and j.reversal_of_journal_entry_id is not null then return new;end if;
 select * into a from public.accounts where company_id=new.company_id and id=new.account_id;
 if j.source_type in ('SUPPLIER_PAYMENT','SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_RELEASE','SUBCONTRACTOR_RETENTION_PAYMENT','CUSTODY_CASH_RETURN','SALARY_PAYMENT','PERSONAL_REIMBURSEMENT')
 and a.account_type<>'EXPENSE' then return new;end if;
 raise exception 'Closed Project cannot receive new recognition or cost allocation' using errcode='23514';
end;$$;

-- Existing Expense commands cannot recognize an active personal-funded invoice again.
create function private.guard_personal_invoice_recognition() returns trigger language plpgsql security definer set search_path='' as $$
begin
 if new.invoice_number is null or btrim(new.invoice_number)='' then return new;end if;
 perform private.serialize_operational_finance(new.company_id,'INVOICE:'||encode(extensions.digest(convert_to(coalesce(new.supplier_id::text,'NONE')||':'||lower(btrim(new.invoice_number)),'UTF8'),'sha256'),'hex'));
 if exists(select 1 from public.operational_liability_postings p where p.company_id=new.company_id and p.kind='PERSONAL_EXPENSE_RECOGNITION' and lower(btrim(p.invoice_number))=lower(btrim(new.invoice_number)) and p.supplier_id is not distinct from new.supplier_id and not exists(select 1 from public.operational_liability_reversals r where r.company_id=p.company_id and r.posting_id=p.id and r.posting_date<=new.expense_date)) then raise exception 'Personal-funded invoice already recognized; settle its payable without reposting cost' using errcode='23505';end if;
 return new;
end;$$;
revoke all on function private.guard_personal_invoice_recognition() from public,anon,authenticated,service_role;
create trigger personal_invoice_recognition before insert on public.expenses for each row execute function private.guard_personal_invoice_recognition();

create index operational_finance_parent on public.operational_liability_postings(company_id,parent_posting_id) where parent_posting_id is not null;
create index operational_finance_invoice on public.operational_liability_postings(company_id,supplier_id,lower(btrim(invoice_number))) where invoice_number is not null;
