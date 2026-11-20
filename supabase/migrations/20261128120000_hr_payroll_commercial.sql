--110: confidential WPS preparation and bounded Article51 gratuity lifecycle.
-- No backfill, account creation, employee edits or hosted financial activity.
create table public.hr_commercial_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id)on delete restrict,
 document_id uuid not null,kind text not null check(kind in('EMPLOYER','EMPLOYEE','WPS','GRATUITY_SETUP','GRATUITY')),
 version integer not null check(version>0),state text not null,payload jsonb not null,
 actor uuid not null references auth.users(id),reason text not null check(length(btrim(reason))between 1 and 1000),
 request_id uuid not null,request_hash text not null,at timestamptz not null default clock_timestamp(),
 unique(company_id,kind,document_id,version),unique(company_id,request_id));
create index hr_commercial_latest on public.hr_commercial_events(company_id,kind,document_id,version desc);
alter table public.hr_commercial_events enable row level security;
grant select on public.hr_commercial_events to authenticated;
revoke insert,update,delete on public.hr_commercial_events from anon,authenticated,service_role;
create policy hr_commercial_read on public.hr_commercial_events for select to authenticated using(public.has_permission(company_id,'payroll.manage'));
create trigger hr_commercial_immutable before update or delete on public.hr_commercial_events for each row execute function private.financial_evidence_immutable();

create function private.hr_commercial_latest(cid uuid,k text,d uuid default null)returns public.hr_commercial_events
language sql stable set search_path=''as $$select e from public.hr_commercial_events e where company_id=cid and kind=k and(d is null or document_id=d)order by version desc,at desc limit 1$$;

-- Explicit, reviewed scope: foreign full-time monthly-paid workers, traditional scheme only.
-- Actual/365 service-day convention is disclosed product policy; final amount rounds once to fils.
create function private.hr_gratuity(cid uuid,v jsonb)returns jsonb language plpgsql stable set search_path=''as $$
declare t public.hr_term_events;first_day date;last_day date;days integer;unpaid integer;basic bigint;n numeric;anniversary date;
begin
 if v->>'scheme'is distinct from'FOREIGN_FULL_TIME_TRADITIONAL'or v->>'basis'is distinct from'ACTUAL_365'or v->>'no_prior_provision'is distinct from'true'then raise exception 'HR_SCOPE: verified full-time foreign traditional scheme and no prior provision required'using errcode='23514';end if;
 last_day:=(v->>'last_day')::date;select *into t from private.hr_term(cid,(v->>'employee_id')::uuid,last_day);
 if t.id is null or t.employed_from is null or last_day is null or last_day<t.employed_from or last_day>(current_timestamp at time zone'Asia/Dubai')::date then raise exception 'HR_TERMS: verified employment dates required'using errcode='23514';end if;
 if not exists(select 1 from public.parties where company_id=cid and id=t.employee_id and private.party_has_person_role(cid,id,'EMPLOYEE'))then raise exception 'HR_EMPLOYEE'using errcode='23514';end if;
 if t.employed_until is distinct from last_day then raise exception 'HR_TERMS: last employed date must match dated employment terms'using errcode='23514';end if;
 if coalesce(v->>'unpaid_days','')!~'^[0-9]+$'then raise exception 'HR_DAYS: verified unpaid service days required'using errcode='23514';end if;
 first_day:=t.employed_from;unpaid:=(v->>'unpaid_days')::integer;days:=last_day-first_day+1-unpaid;basic:=t.basic_minor;
 if days<0 or basic<=0 then raise exception 'HR_DAYS: invalid service/basic wage'using errcode='23514';end if;
 anniversary:=(first_day+interval'1 year')::date;
 if last_day+1-unpaid<anniversary then n:=0;else n:=round(basic::numeric*(least(days,1825)*21+greatest(days-1825,0)*30)/(365*30));end if;
 n:=least(n,(basic::numeric+coalesce((select sum((x->>'amount_minor')::numeric)from jsonb_array_elements(t.allowances)x),0))*24);
 return jsonb_build_object('employee_id',t.employee_id,'term_id',t.id,'employed_from',first_day,'last_day',last_day,'service_days',days,'unpaid_days',unpaid,'basic_minor',basic::text,'amount_minor',n::bigint::text,'scheme',v->>'scheme','basis','ACTUAL_365','no_prior_provision',true,'due_on',last_day+14);
end$$;

create function private.hr_wps_packet(cid uuid,payroll uuid)returns jsonb language plpgsql stable set search_path=''as $$
declare employer public.hr_commercial_events;p public.payroll_postings;e record;profile public.hr_commercial_events;rows jsonb:='[]';issues jsonb:='[]';total numeric:=0;unpaid numeric;paid numeric;recovery numeric;
begin
 employer:=private.hr_commercial_latest(cid,'EMPLOYER',cid);
 select *into p from public.payroll_postings where company_id=cid and id=payroll;
 if p.id is null or not exists(select 1 from private.live_payroll_periods where company_id=cid and payroll_id=p.id)then raise exception 'WPS_PAYROLL: active posted payroll required'using errcode='23514';end if;
 if employer.id is null then issues:=issues||jsonb_build_array('EMPLOYER_SETUP');end if;
 for e in select x.*,a.name employee_name from public.payroll_entitlements x join public.parties a on a.company_id=x.company_id and a.id=x.employee_id where x.company_id=cid and x.payroll_id=p.id order by x.employee_id loop
  profile:=private.hr_commercial_latest(cid,'EMPLOYEE',e.employee_id);unpaid:=private.payroll_unpaid(e.id);total:=total+unpaid;
  select coalesce(sum(x.amount_minor),0)into paid from public.salary_payments x where x.company_id=cid and x.entitlement_id=e.id and not exists(select 1 from public.salary_payment_reversals y where y.company_id=cid and y.payment_id=x.id);
  recovery:=e.amount_minor-paid-unpaid;
  if profile.id is null then issues:=issues||jsonb_build_array('EMPLOYEE_SETUP:'||e.employee_id::text);end if;
  rows:=rows||jsonb_build_array(jsonb_build_object('employee_id',e.employee_id,'employee_name',e.employee_name,'entitlement_id',e.id,'earned_minor',e.amount_minor::text,'recovery_minor',recovery::bigint::text,'paid_minor',paid::bigint::text,'entitlement_minor',(e.amount_minor-recovery)::bigint::text,'outstanding_minor',unpaid::bigint::text,'recipient',profile.payload,'profile_version',profile.version));
 end loop;
 if total<=0 then issues:=issues||jsonb_build_array('NO_OUTSTANDING_SALARY');end if;
 return jsonb_build_object('payroll_id',p.id,'month',p.month,'employer',employer.payload,'employer_version',employer.version,'rows',rows,'total_minor',total::bigint::text,'issues',issues,'bank_file_supported',false,'scope','PREPARATION_ONLY_AGENT_SPECIFICATION_NOT_VERIFIED');
end$$;

create function public.preview_hr_gratuity(cid uuid,input jsonb)returns jsonb language plpgsql stable security definer set search_path=''as $$
begin perform private.hr_read_actor(cid);return private.hr_gratuity(cid,input);end$$;

create function public.command_hr_commercial(cid uuid,request_id uuid,action text,input jsonb)returns jsonb
language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare actor uuid;h text;old public.hr_commercial_events;e public.hr_commercial_events;cfg public.hr_commercial_events;
 d uuid;k text;s text;v jsonb;prior integer;emp uuid;amount bigint;j uuid;dt date;acct public.accounts;t public.treasury_accounts;cash numeric;paid numeric;r jsonb;
begin
 actor:=private.operational_finance_actor(cid,'payroll.manage');perform private.attendance_company_lock(cid);
 if request_id is null or jsonb_typeof(input)is distinct from'object'or octet_length(input::text)>20000 or action is null or action not in('EMPLOYER','EMPLOYEE','WPS_PREPARE','WPS_STATUS','GRATUITY_SETUP','GRATUITY_SAVE','GRATUITY_APPROVE','GRATUITY_POST','GRATUITY_PAY','GRATUITY_REVERSE_PAYMENT','GRATUITY_REVERSE')then raise exception 'HR_INPUT'using errcode='22023';end if;
 if coalesce(length(btrim(input->>'reason')),0)not between 1 and 1000 then raise exception 'HR_EVIDENCE: approval/correction reference required'using errcode='23514';end if;
 input:=input||jsonb_build_object('reason',btrim(input->>'reason'));
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into old from public.hr_commercial_events x where x.company_id=cid and x.request_id=command_hr_commercial.request_id;
 if found then if old.request_hash<>h then raise exception 'HR_CHANGED_REQUEST'using errcode='22023';end if;return jsonb_build_object('id',old.document_id,'version',old.version,'state',old.state,'payload',old.payload);end if;
 if action not in('WPS_PREPARE','GRATUITY_SAVE')and not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'HR_ADMIN_REQUIRED'using errcode='42501';end if;
 k:=case when action like'WPS_%'then'WPS'when action like'GRATUITY_%'and action<>'GRATUITY_SETUP'then'GRATUITY'else action end;
 d:=case when action in('EMPLOYER','GRATUITY_SETUP')then cid when action='EMPLOYEE'then(input->>'employee_id')::uuid when action='WPS_PREPARE'then(input->>'payroll_id')::uuid else(input->>'id')::uuid end;
 if d is null then raise exception 'HR_DOCUMENT_ID'using errcode='22023';end if;
 e:=private.hr_commercial_latest(cid,k,d);prior:=coalesce(e.version,0);
 if coalesce((input->>'version')::integer,0)<>prior then raise exception 'HR_STALE: refresh changed record'using errcode='40001';end if;
 if action='EMPLOYER'then
  if nullif(btrim(input->>'employer_identifier'),'')is null or nullif(btrim(input->>'agent_name'),'')is null or nullif(btrim(input->>'agent_identifier'),'')is null then raise exception 'WPS_SETUP: employer and contracted payment agent identifiers required'using errcode='23514';end if;
  v:=jsonb_build_object('employer_identifier',btrim(input->>'employer_identifier'),'agent_name',btrim(input->>'agent_name'),'agent_identifier',btrim(input->>'agent_identifier'));s:='CONFIGURED';
 elsif action='EMPLOYEE'then
  if not exists(select 1 from public.parties where company_id=cid and id=d and private.party_has_person_role(cid,id,'EMPLOYEE'))then raise exception 'HR_EMPLOYEE'using errcode='23514';end if;
  if nullif(btrim(input->>'person_identifier'),'')is null or nullif(btrim(input->>'routing_identifier'),'')is null or nullif(btrim(input->>'recipient_account'),'')is null or coalesce(input->>'account_kind','')not in('IBAN','SALARY_CARD')then raise exception 'WPS_EMPLOYEE: identifiers and recipient account required'using errcode='23514';end if;
  if input->>'account_kind'='IBAN'and upper(replace(input->>'recipient_account',' ',''))!~'^AE[0-9]{21}$'then raise exception 'WPS_IBAN: UAE IBAN must have 23 characters'using errcode='23514';end if;
  if input->>'account_kind'='IBAN'and mod((substring(upper(replace(input->>'recipient_account',' ',''))from 5)||'1014'||substring(replace(input->>'recipient_account',' ','')from 3 for 2))::numeric,97)<>1 then raise exception 'WPS_IBAN_CHECKSUM'using errcode='23514';end if;
  if exists(select 1 from(select distinct on(document_id)*from public.hr_commercial_events where company_id=cid and kind='EMPLOYEE'order by document_id,version desc)x where x.document_id<>d and x.payload->>'person_identifier'=btrim(input->>'person_identifier'))then raise exception 'WPS_DUPLICATE_EMPLOYEE_IDENTIFIER'using errcode='23505';end if;
  v:=jsonb_build_object('employee_id',d,'person_identifier',btrim(input->>'person_identifier'),'routing_identifier',btrim(input->>'routing_identifier'),'recipient_account',upper(replace(input->>'recipient_account',' ','')),'account_kind',input->>'account_kind');s:='CONFIGURED';
 elsif action='WPS_PREPARE'then
  if e.state in('SUBMITTED','ACCEPTED')then raise exception 'WPS_ALREADY_SENT: resolve existing agent submission first'using errcode='23514';end if;
  v:=private.hr_wps_packet(cid,d);s:='PREPARED';
 elsif action='WPS_STATUS'then
  s:=input->>'state';
  if not((e.state='PREPARED'and s='SUBMITTED')or(e.state='SUBMITTED'and s in('ACCEPTED','REJECTED')))then raise exception 'WPS_TRANSITION'using errcode='23514';end if;
  if s='SUBMITTED'and(e.payload is distinct from private.hr_wps_packet(cid,d)or jsonb_array_length(e.payload->'issues')<>0)then raise exception 'WPS_STALE: resolve preparation issues and refresh balances before recording external submission'using errcode='23514';end if;
  if nullif(btrim(input->>'external_reference'),'')is null then raise exception 'WPS_AGENT_REFERENCE_REQUIRED'using errcode='23514';end if;
  v:=e.payload||jsonb_build_object('external_reference',btrim(input->>'external_reference'),'external_status',s);
 elsif action='GRATUITY_SETUP'then
  if not public.has_permission(cid,'account.manage')then raise exception 'HR_ACCOUNT_SETUP_DENIED'using errcode='42501';end if;
  v:=jsonb_build_object('expense_account_id',(input->>'expense_account_id')::uuid,'payable_account_id',(input->>'payable_account_id')::uuid);
  for acct in select *from public.accounts where company_id=cid and id in((v->>'expense_account_id')::uuid,(v->>'payable_account_id')::uuid)for share loop
   if acct.status<>'ACTIVE'or acct.system_key is not null or exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=acct.id)or acct.account_type::text<>(case when acct.id=(v->>'expense_account_id')::uuid then'EXPENSE'else'LIABILITY'end) or(acct.id=(v->>'payable_account_id')::uuid and not acct.requires_party)then raise exception 'HR_SETUP: dedicated active expense and Party-required liability accounts required'using errcode='23514';end if;
  end loop;
  if(select count(*)from public.accounts where company_id=cid and id in((v->>'expense_account_id')::uuid,(v->>'payable_account_id')::uuid))<>2 then raise exception 'HR_SETUP_ACCOUNTS'using errcode='23514';end if;s:='CONFIGURED';
 elsif action='GRATUITY_SAVE'then
  if e.state in('POSTED','PAID','PART_PAID')then raise exception 'HR_IMMUTABLE: reverse accounting or create a separate corrected draft'using errcode='23514';end if;
  v:=private.hr_gratuity(cid,input);s:='DRAFT';
 elsif action='GRATUITY_APPROVE'then
  if e.state<>'DRAFT'or e.payload is distinct from private.hr_gratuity(cid,e.payload)then raise exception 'HR_STALE_TERMS'using errcode='23514';end if;
  cfg:=private.hr_commercial_latest(cid,'GRATUITY_SETUP',cid);if cfg.id is null then raise exception 'HR_SETUP_REQUIRED'using errcode='23514';end if;
  v:=e.payload||cfg.payload;s:='APPROVED';
 else
  perform private.serialize_operational_finance(cid,'OPERATIONS');
  if not public.has_permission(cid,case when action in('GRATUITY_REVERSE_PAYMENT','GRATUITY_REVERSE')then'payroll.reverse'when action='GRATUITY_PAY'then'payroll.pay'else'payroll.post'end)then raise exception 'HR_POSTING_DENIED'using errcode='42501';end if;
  dt:=(input->>'date')::date;
  if dt is null or dt>(current_timestamp at time zone'Asia/Dubai')::date then raise exception 'HR_POSTING_DATE'using errcode='23514';end if;
  v:=e.payload;emp:=(v->>'employee_id')::uuid;amount:=(v->>'amount_minor')::bigint;
  if action<>'GRATUITY_POST'and e.state in('POSTED','PART_PAID','PAID')and (select coalesce(sum(credit_minor-debit_minor),0)from public.journal_lines where company_id=cid and account_id=(v->>'payable_account_id')::uuid and party_id=emp)<>(v->>'amount_minor')::bigint-(v->>'paid_minor')::bigint then raise exception 'HR_CONTROL_RECONCILIATION: gratuity subledger differs from control GL'using errcode='23514';end if;
  if action='GRATUITY_POST'then
   if e.state is distinct from'APPROVED'or dt<(v->>'last_day')::date or amount<=0 or (v-'expense_account_id'-'payable_account_id')is distinct from private.hr_gratuity(cid,v)then raise exception 'HR_REVIEW: approved current gratuity and valid date required'using errcode='23514';end if;
   if exists(select 1 from(select distinct on(document_id)*from public.hr_commercial_events where company_id=cid and kind='GRATUITY'order by document_id,version desc)x where x.document_id<>d and x.payload->>'employee_id'=emp::text and x.payload->>'employed_from'=v->>'employed_from'and x.state in('POSTED','PART_PAID','PAID'))then raise exception 'HR_DUPLICATE_SERVICE'using errcode='23505';end if;
   if exists(select 1 from public.accounts where company_id=cid and id in((v->>'expense_account_id')::uuid,(v->>'payable_account_id')::uuid)and(status<>'ACTIVE'or account_type::text<>case when id=(v->>'expense_account_id')::uuid then'EXPENSE'else'LIABILITY'end))then raise exception 'HR_ACCOUNTS_CHANGED'using errcode='23514';end if;
   if(select coalesce(sum(credit_minor-debit_minor),0)from public.journal_lines where company_id=cid and account_id=(v->>'payable_account_id')::uuid and party_id=emp)<>0 then raise exception 'HR_PRIOR_PROVISION: reconcile existing gratuity liability before new recognition'using errcode='23514';end if;
   j:=private.create_journal(cid,dt,'End-of-service gratuity','HR_GRATUITY',d,'POST',jsonb_build_array(jsonb_build_object('account_id',v->>'expense_account_id','party_id',emp,'debit_minor',amount::text,'credit_minor','0'),jsonb_build_object('account_id',v->>'payable_account_id','party_id',emp,'debit_minor','0','credit_minor',amount::text)),actor);
   v:=v||jsonb_build_object('journal_id',j,'posting_date',dt,'paid_minor','0','payments','[]'::jsonb);s:='POSTED';
  elsif action='GRATUITY_PAY'then
   if e.state not in('POSTED','PART_PAID')or dt<(v->>'posting_date')::date or coalesce(input->>'amount_minor','')!~'^[1-9][0-9]*$'then raise exception 'HR_PAYMENT'using errcode='23514';end if;
   amount:=(input->>'amount_minor')::bigint;
   if exists(select 1 from jsonb_array_elements(v->'payments')x where x->>'reversed'='false'and x->>'reference'=btrim(input->>'reason'))then raise exception 'HR_DUPLICATE_PAYMENT_REFERENCE'using errcode='23505';end if;
   if amount>(v->>'amount_minor')::bigint-(v->>'paid_minor')::bigint then raise exception 'HR_OVERPAYMENT'using errcode='23514';end if;
   select *into t from public.treasury_accounts where company_id=cid and id=(input->>'treasury_id')::uuid and status='ACTIVE'and project_id is null for share;
   if t.id is null or not exists(select 1 from public.accounts where company_id=cid and id=t.gl_account_id and status='ACTIVE'and account_type='ASSET')then raise exception 'HR_COMPANY_TREASURY_REQUIRED'using errcode='23514';end if;
   select coalesce(sum(l.debit_minor-l.credit_minor),0)into cash from public.journal_lines l join public.journal_entries x on x.company_id=l.company_id and x.id=l.journal_entry_id where l.company_id=cid and l.account_id=t.gl_account_id and x.posting_date<=dt;
   if cash<amount then raise exception 'HR_INSUFFICIENT_FUNDS'using errcode='23514';end if;
   j:=private.create_journal(cid,dt,'Gratuity payment','HR_GRATUITY_PAYMENT',request_id,'POST',jsonb_build_array(jsonb_build_object('account_id',v->>'payable_account_id','party_id',emp,'debit_minor',amount::text,'credit_minor','0'),jsonb_build_object('account_id',t.gl_account_id,'treasury_account_id',t.id,'party_id',emp,'debit_minor','0','credit_minor',amount::text)),actor);
   paid:=(v->>'paid_minor')::bigint+amount;v:=v||jsonb_build_object('paid_minor',paid::bigint::text,'payments',(v->'payments')||jsonb_build_array(jsonb_build_object('journal_id',j,'date',dt,'amount_minor',amount::text,'reference',input->>'reason','treasury_id',t.id,'reversed',false)));s:=case when paid=(v->>'amount_minor')::bigint then'PAID'else'PART_PAID'end;
  elsif action='GRATUITY_REVERSE_PAYMENT'then
   select x into r from jsonb_array_elements(v->'payments')x where x->>'journal_id'=input->>'payment_journal_id'and x->>'reversed'='false';
   if e.state not in('POSTED','PART_PAID','PAID')or r is null or dt<(r->>'date')::date then raise exception 'HR_PAYMENT_REVERSAL'using errcode='23514';end if;
   j:=private.reverse_journal((r->>'journal_id')::uuid,dt,input->>'reason',actor);
   paid:=(v->>'paid_minor')::bigint-(r->>'amount_minor')::bigint;
   v:=v||jsonb_build_object('paid_minor',paid::bigint::text,'payments',(select jsonb_agg(case when x->>'journal_id'=r->>'journal_id'then x||jsonb_build_object('reversed',true,'reversal_journal_id',j)else x end)from jsonb_array_elements(v->'payments')x));s:=case when paid=0 then'POSTED'else'PART_PAID'end;
  else
   if e.state not in('POSTED','PART_PAID','PAID')or(v->>'paid_minor')::bigint<>0 or dt<(v->>'posting_date')::date then raise exception 'HR_REVERSE_PAYMENTS_FIRST'using errcode='23514';end if;
   j:=private.reverse_journal((v->>'journal_id')::uuid,dt,input->>'reason',actor);v:=v||jsonb_build_object('reversal_journal_id',j);s:='REVERSED';
  end if;
 end if;
 insert into public.hr_commercial_events(company_id,document_id,kind,version,state,payload,actor,reason,request_id,request_hash)values(cid,d,k,prior+1,s,v,actor,btrim(input->>'reason'),request_id,h);
 return jsonb_build_object('id',d,'version',prior+1,'state',s,'payload',v);
end$$;

create function public.read_hr_commercial(cid uuid,m date)returns jsonb language plpgsql stable security definer set search_path=''as $$
begin
 perform private.hr_read_actor(cid);
 if m is null or extract(day from m)<>1 then raise exception 'HR_MONTH'using errcode='22023';end if;
 return jsonb_build_object('company_id',cid,'month',m,'events',(select coalesce(jsonb_agg(to_jsonb(x)order by at),'[]')from public.hr_commercial_events x where company_id=cid),'payrolls',(select coalesce(jsonb_agg(private.hr_wps_packet(cid,p.id)),'[]')from public.payroll_postings p join private.live_payroll_periods l on l.company_id=p.company_id and l.payroll_id=p.id where p.company_id=cid and p.month=m),'employees',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name),'[]')from public.parties where company_id=cid and private.party_has_person_role(cid,id,'EMPLOYEE')),'accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'code',code,'name',name,'type',account_type,'party',requires_party)order by code),'[]')from public.accounts where company_id=cid and status='ACTIVE'and system_key is null and account_type in('EXPENSE','LIABILITY')and not exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=accounts.id)),'treasuries',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',name)order by name),'[]')from public.treasury_accounts where company_id=cid and status='ACTIVE'and project_id is null));
end$$;

-- Extend the existing confidential journal boundary, including reversals.
do $$begin execute replace(pg_get_functiondef('public.payroll_journal_visible(uuid,uuid)'::regprocedure),'public.payroll_journal_visible(', 'private.hr_commercial_previous_journal_visible(');end$$;
create or replace function public.payroll_journal_visible(target_company_id uuid,target_journal_id uuid)returns boolean language sql stable security definer set search_path=''as $$
 select private.hr_commercial_previous_journal_visible(target_company_id,target_journal_id)and(public.has_permission(target_company_id,'payroll.manage')or not exists(select 1 from public.journal_entries j left join public.journal_entries o on o.company_id=j.company_id and o.id=j.reversal_of_journal_entry_id where j.company_id=target_company_id and j.id=target_journal_id and(j.source_type in('HR_GRATUITY','HR_GRATUITY_PAYMENT')or o.source_type in('HR_GRATUITY','HR_GRATUITY_PAYMENT'))))$$;
revoke all on function private.hr_commercial_latest(uuid,text,uuid),private.hr_gratuity(uuid,jsonb),private.hr_wps_packet(uuid,uuid),private.hr_commercial_previous_journal_visible(uuid,uuid)from public,anon,authenticated,service_role;
revoke all on function public.preview_hr_gratuity(uuid,jsonb),public.command_hr_commercial(uuid,uuid,text,jsonb),public.read_hr_commercial(uuid,date),public.payroll_journal_visible(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.preview_hr_gratuity(uuid,jsonb),public.command_hr_commercial(uuid,uuid,text,jsonb),public.read_hr_commercial(uuid,date),public.payroll_journal_visible(uuid,uuid)to authenticated;
