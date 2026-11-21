--111: bank-specific audited SIF exports and source-conserving employee final settlement.
-- Additive, no backfill, master/config changes or financial invocation during migration.
create table public.hr_completion_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),document_id uuid not null,
 kind text not null check(kind in('SIF','SETUP','SETTLEMENT')),version integer not null,state text not null,payload jsonb not null,
 actor uuid not null references auth.users(id),reason text not null,request_id uuid not null,request_hash text not null,at timestamptz not null default clock_timestamp(),
 unique(company_id,kind,document_id,version),unique(company_id,request_id));
create table private.hr_settlement_claims(company_id uuid not null,settlement_id uuid not null,kind text not null,source_id uuid not null,amount_minor bigint not null check(amount_minor>=0),account_id uuid not null,employee_id uuid not null,
 primary key(company_id,settlement_id,kind,source_id),foreign key(company_id)references public.companies(id));
revoke all on private.hr_settlement_claims from public,anon,authenticated,service_role;
alter table public.hr_completion_events enable row level security;
grant select on public.hr_completion_events to authenticated;
revoke insert,update,delete on public.hr_completion_events from anon,authenticated,service_role;
create policy hr_completion_read on public.hr_completion_events for select to authenticated using(public.has_permission(company_id,'payroll.manage'));
create trigger hr_completion_immutable before update or delete on public.hr_completion_events for each row execute function private.financial_evidence_immutable();
create trigger hr_claims_immutable before update or delete on private.hr_settlement_claims for each row execute function private.financial_evidence_immutable();
create function private.hr_completion_latest(c uuid,k text,d uuid)returns public.hr_completion_events language sql stable set search_path=''as $$select e from public.hr_completion_events e where company_id=c and kind=k and document_id=d order by version desc limit 1$$;
create function private.hr_settlement_live(c uuid,d uuid)returns boolean language sql stable set search_path=''as $$select coalesce((private.hr_completion_latest(c,'SETTLEMENT',d)).state in('POSTED','PART_PAID','PAID'),false)$$;

-- Display and settle transferred salary in one authoritative place; no second salary expense.
do $$begin execute replace(pg_get_functiondef('private.payroll_unpaid(uuid)'::regprocedure),'private.payroll_unpaid(', 'private.hr_pre_final_payroll_unpaid(');execute replace(pg_get_functiondef('private.hr_recovery_balance(uuid,uuid)'::regprocedure),'private.hr_recovery_balance(', 'private.hr_pre_final_recovery_balance(');end$$;
create or replace function private.payroll_unpaid(e uuid)returns numeric language sql stable set search_path=''as $$select private.hr_pre_final_payroll_unpaid(e)-coalesce((select sum(amount_minor)from private.hr_settlement_claims x where kind='SALARY'and source_id=e and private.hr_settlement_live(company_id,settlement_id)),0)$$;
create or replace function private.hr_recovery_balance(cid uuid,aid uuid)returns bigint language sql stable set search_path=''as $$select(private.hr_pre_final_recovery_balance(cid,aid)-coalesce((select sum(amount_minor)from private.hr_settlement_claims where company_id=cid and kind='ADVANCE'and source_id=aid and private.hr_settlement_live(cid,settlement_id)),0))::bigint$$;

create function private.hr_sif(cid uuid,payroll uuid,v jsonb,stamp timestamptz)returns jsonb language plpgsql stable set search_path=''as $$
declare packet jsonb;employer text;bank text;row jsonb;r jsonb;recipient jsonb;seen text[]:='{}';person text;route text;account text;fixed bigint;variable bigint;components jsonb;n numeric;total numeric:=0;lines text[]:='{}';start_date date;end_date date;unpaid integer;ts text;reference text;
begin
 if v->>'profile'is distinct from'DIB_V1_1_SAMPLE_13_14'or v->>'agent_confirmed'is distinct from'true'then raise exception 'SIF_PROFILE: confirm applicability of DIB v1.1 example profile with your agent'using errcode='23514';end if;
 packet:=private.hr_wps_packet(cid,payroll);if jsonb_array_length(packet->'issues')<>0 then raise exception 'SIF_SETUP: complete existing WPS preparation first'using errcode='23514';end if;
 employer:=packet->'employer'->>'employer_identifier';bank:=v->>'employer_bank_routing';reference:=coalesce(v->>'reference','');
 if employer!~'^[0-9]{1,13}$'or bank!~'^[0-9]{9}$'or reference!~'^[A-Za-z0-9 ._-]{0,35}$'then raise exception 'SIF_EMPLOYER: numeric employer ID up to13 digits, nine-digit employer bank routing and ASCII reference required'using errcode='23514';end if;
 if jsonb_typeof(v->'rows')is distinct from'array'or jsonb_array_length(v->'rows')<>jsonb_array_length(packet->'rows')then raise exception 'SIF_ROWS: classify every payroll employee once'using errcode='23514';end if;
 for row in select x from jsonb_array_elements(packet->'rows')x loop
  select x into r from jsonb_array_elements(v->'rows')x where x->>'employee_id'=row->>'employee_id';
  if r is null or row->>'employee_id'=any(seen)or(select count(*)from jsonb_array_elements(v->'rows')x where x->>'employee_id'=row->>'employee_id')<>1 then raise exception 'SIF_DUPLICATE_OR_MISSING_ROW'using errcode='23514';end if;seen:=array_append(seen,row->>'employee_id');
  if row->>'paid_minor'<>'0'or exists(select 1 from private.hr_settlement_claims where company_id=cid and source_id=(row->>'entitlement_id')::uuid and kind='SALARY'and private.hr_settlement_live(cid,settlement_id))then raise exception 'SIF_PART_PAID: paid or settlement-transferred payroll cannot be exported again'using errcode='23514';end if;
  recipient:=row->'recipient';person:=recipient->>'person_identifier';route:=recipient->>'routing_identifier';account:=recipient->>'recipient_account';
  if person!~'^[0-9]{1,14}$'or route!~'^[0-9]{9}$'or account!~'^[A-Z0-9]{1,23}$'then raise exception 'SIF_RECIPIENT: verify person identifier, routing and recipient account'using errcode='23514';end if;
  if left(account,2)='AE'and(length(account)<>23 or mod((substring(account from 5)||'1014'||substring(account from 3 for 2))::numeric,97)<>1)then raise exception 'SIF_IBAN'using errcode='23514';end if;
  if coalesce(r->>'fixed_minor','')!~'^[0-9]+$'or jsonb_typeof(r->'variable_minor')is distinct from'array'or jsonb_array_length(r->'variable_minor')<>7 or exists(select 1 from jsonb_array_elements_text(r->'variable_minor')x where x!~'^[0-9]+$')then raise exception 'SIF_SPLIT: fixed net plus seven verified nonnegative variable components required'using errcode='23514';end if;
  fixed:=(r->>'fixed_minor')::bigint;select sum(x::numeric)into n from jsonb_array_elements_text(r->'variable_minor')x;variable:=n::bigint;
  if fixed::numeric+variable<>(row->>'outstanding_minor')::numeric then raise exception 'SIF_TOTAL: fixed plus variable must equal canonical net payable after recovery'using errcode='23514';end if;
  start_date:=(r->>'start_date')::date;end_date:=(r->>'end_date')::date;unpaid:=(r->>'unpaid_days')::integer;
  if start_date is null or end_date is null or start_date<'2010-10-01'or end_date<=start_date or date_trunc('month',start_date)::date<>(packet->>'month')::date or date_trunc('month',end_date)::date<>(packet->>'month')::date or unpaid is null or unpaid<0 or unpaid>end_date-start_date+1 then raise exception 'SIF_PERIOD: verified dates in payroll month and unpaid days required'using errcode='23514';end if;
  if length(private.hr_sif_money(fixed))>15 or length(private.hr_sif_money(variable))>15 then raise exception 'SIF_AMOUNT_RANGE'using errcode='23514';end if;
  lines:=array_append(lines,array_to_string(array['EDR',lpad(person,14,'0'),route,account,start_date::text,end_date::text,(end_date-start_date+1)::text,private.hr_sif_money(fixed),private.hr_sif_money(variable),unpaid::text],','));
  if variable>0 then select jsonb_agg(private.hr_sif_money(x::bigint)order by ord)into components from jsonb_array_elements_text(r->'variable_minor')with ordinality q(x,ord);lines:=array_append(lines,'EVP,'||lpad(person,14,'0')||','||route||','||(select string_agg(x,','order by ord)from jsonb_array_elements_text(components)with ordinality q(x,ord)));end if;
  total:=total+fixed+variable;
 end loop;
 if total<=0 or length(private.hr_sif_money(total::bigint))>15 then raise exception 'SIF_TOTAL_RANGE'using errcode='23514';end if;
 ts:=to_char(stamp at time zone'Asia/Dubai','YYYY-MM-DD HH24MI YYMMDDHH24MISS');
 if(select count(distinct lpad(x->'recipient'->>'person_identifier',14,'0'))from jsonb_array_elements(packet->'rows')x)<>cardinality(seen)then raise exception 'SIF_DUPLICATE_PERSON'using errcode='23514';end if;
 lines:=array_append(lines,array_to_string(array['SCR',lpad(employer,13,'0'),bank,left(ts,10),substring(ts from 12 for 4),to_char((packet->>'month')::date,'MMYYYY'),cardinality(seen)::text,private.hr_sif_money(total::bigint),'AED',reference],','));
 return jsonb_build_object('profile',v->>'profile','filename',lpad(employer,13,'0')||substring(ts from 17)||'.SIF','content',array_to_string(lines,E'\r\n')||E'\r\n','total_minor',total::bigint::text,'employee_count',cardinality(seen),'packet',packet,'classification',v->'rows','employer_bank_routing',bank,'agent_confirmation',v->>'reason','created_at',stamp);
end$$;
create function private.hr_sif_money(n bigint)returns text language sql immutable set search_path=''as $$select(n/100)::text||'.'||lpad((n%100)::text,2,'0')$$;
create function private.hr_employee_control(c uuid,a uuid,e uuid)returns bigint language sql stable set search_path=''as $$select coalesce(sum(credit_minor-debit_minor),0)::bigint from public.journal_lines where company_id=c and account_id=a and party_id=e$$;
-- Extend the existing calculation helper with an optional employee scope; all
-- normal payroll calls retain the exact original computation through a wrapper.
do $$declare definition text;begin definition:=pg_get_functiondef('private.hr_payroll_rows(uuid,date)'::regprocedure);definition:=replace(definition,'private.hr_payroll_rows(cid uuid, m date)','private.hr_scoped_payroll_rows(cid uuid, m date, target_employee uuid)');definition:=replace(definition,'days jsonb:=private.hr_days(cid,m);','days jsonb:=(select coalesce(jsonb_agg(x),''[]''::jsonb)from jsonb_array_elements(private.hr_days(cid,m))x where target_employee is null or x->>''employee_id''=target_employee::text);');if definition not like '%target_employee uuid%'or definition not like '%target_employee is null%'then raise exception 'Canonical payroll dependency signature changed';end if;execute definition;end$$;
create or replace function private.hr_payroll_rows(cid uuid,m date)returns jsonb language sql stable set search_path=''as $$select private.hr_scoped_payroll_rows(cid,m,null)$$;
create function private.hr_final_preview(cid uuid,v jsonb)returns jsonb language plpgsql stable set search_path=''as $$
declare t public.hr_term_events;cfg public.hr_completion_events;g jsonb;e record;x record;claims jsonb:='[]';salary numeric:=0;reimbursement numeric:=0;advances numeric:=0;gross numeric;gratuity bigint;prior bigint;already_paid bigint:=0;leave_pay bigint;notice_pay bigint;deduction bigint;leave_days integer;notice_days integer;wage numeric;last_day date;emp uuid;final_month date;final_payroll boolean:=false;new_salary jsonb;minimum_date date;replacement public.hr_completion_events;
begin
 emp:=(v->>'employee_id')::uuid;last_day:=(v->>'last_day')::date;final_month:=date_trunc('month',last_day)::date;
 if nullif(v->>'replacement_id','')is not null then replacement:=private.hr_completion_latest(cid,'SETTLEMENT',(v->>'replacement_id')::uuid);if replacement.state is distinct from'REVERSED'or replacement.payload->>'employee_id'<>emp::text then raise exception 'FINAL_REPLACEMENT: reference a reversed settlement for this employee'using errcode='23514';end if;end if;
 cfg:=private.hr_completion_latest(cid,'SETUP',cid);if cfg.id is null then raise exception 'FINAL_SETUP: Accounting Admin must map dedicated controls'using errcode='23514';end if;
 for x in select key,value from jsonb_each_text(cfg.payload)loop
  if not exists(select 1 from public.accounts where company_id=cid and id=x.value::uuid and status='ACTIVE'and system_key is null)then raise exception 'FINAL_ACCOUNT_CHANGED: refresh approved active controls'using errcode='23514';end if;
 end loop;
 if v->>'review_complete'is distinct from'true'or v->>'scheme'is distinct from'FOREIGN_FULL_TIME_TRADITIONAL'then raise exception 'FINAL_SCOPE: verified traditional foreign full-time category and complete entitlement review required'using errcode='23514';end if;
 g:=private.hr_gratuity(cid,v||jsonb_build_object('no_prior_provision',true,'basis','ACTUAL_365'));select *into t from private.hr_term(cid,emp,last_day);
 if exists(select 1 from public.hr_completion_events h where h.company_id=cid and h.kind='SETTLEMENT'and h.payload->>'employee_id'=emp::text and h.payload->>'employed_from'=t.employed_from::text and private.hr_settlement_live(cid,h.document_id))then raise exception 'FINAL_DUPLICATE: this service spell already has a posted final settlement'using errcode='23505';end if;
 for e in select n.*,p.month from public.payroll_entitlements n join public.payroll_postings p on p.company_id=n.company_id and p.id=n.payroll_id join private.live_payroll_periods l on l.company_id=p.company_id and l.payroll_id=p.id where n.company_id=cid and n.employee_id=emp order by p.month loop
  if e.month>final_month then raise exception 'FINAL_FUTURE_PAYROLL: reconcile payroll after termination first'using errcode='23514';end if;
  if e.month=final_month then final_payroll:=true;end if;
  salary:=salary+private.payroll_unpaid(e.id);claims:=claims||jsonb_build_array(jsonb_build_object('kind','SALARY','source_id',e.id,'account_id',e.payable_account_id,'amount_minor',private.payroll_unpaid(e.id)::bigint::text));
 end loop;
 if not final_payroll then
  if private.hr_policy(cid,final_month)is null then raise exception 'FINAL_MONTH: approved explicit-attendance payroll policy required'using errcode='23514';end if;
  if exists(select 1 from public.payroll_draft_rows r join public.payroll_draft_periods p on p.company_id=r.company_id and p.id=r.period_id where r.company_id=cid and r.employee_id=emp and p.month=final_month)then raise exception 'FINAL_DRAFT: resolve the existing final-month payroll draft before recognizing salary in settlement'using errcode='23514';end if;
  new_salary:=private.hr_scoped_payroll_rows(cid,final_month,emp)->0;if new_salary is null then raise exception 'FINAL_ATTENDANCE: reviewed complete employee attendance required through termination'using errcode='23514';end if;salary:=salary+(new_salary->>'earned_minor')::bigint;
 end if;
 -- Reimbursements must already be approved and accrued to their canonical liability.
 for e in select p.*from public.operational_liability_postings p where p.company_id=cid and p.kind='PERSONAL_EXPENSE_RECOGNITION'and p.counterparty_id=emp and not exists(select 1 from public.operational_liability_reversals r where r.company_id=cid and r.posting_id=p.id)loop
  gross:=e.amount_minor-coalesce((select sum(q.amount_minor)from public.operational_liability_postings q where q.company_id=cid and q.parent_posting_id=e.id and q.kind='PERSONAL_REIMBURSEMENT'and not exists(select 1 from public.operational_liability_reversals r where r.company_id=cid and r.posting_id=q.id)),0);
  reimbursement:=reimbursement+gross;claims:=claims||jsonb_build_array(jsonb_build_object('kind','REIMBURSEMENT','source_id',e.id,'account_id',e.account_id,'amount_minor',gross::bigint::text));
 end loop;
 for e in select a.*from public.hr_advance_postings a where a.company_id=cid and a.employee_id=emp and not exists(select 1 from public.hr_financial_reversals r where r.company_id=cid and r.kind='ADVANCE'and r.source_id=a.id)loop
  gross:=private.hr_recovery_balance(cid,e.id);advances:=advances+gross;claims:=claims||jsonb_build_array(jsonb_build_object('kind','ADVANCE','source_id',e.id,'account_id',e.account_id,'amount_minor',gross::bigint::text));
 end loop;
 if advances>0 and nullif(btrim(v->>'advance_authorization'),'')is null then raise exception 'FINAL_ADVANCE_AUTHORITY: documented lawful offset required; otherwise settle advances separately'using errcode='23514';end if;
 if coalesce(v->>'leave_days_hundredths','')!~'^[0-9]+$'or coalesce(v->>'notice_days','')!~'^[0-9]+$'or coalesce(v->>'deduction_minor','')!~'^[0-9]+$'then raise exception 'FINAL_FACTS: verified leave balance, notice days and deduction amount required'using errcode='23514';end if;
 leave_days:=(v->>'leave_days_hundredths')::integer;notice_days:=(v->>'notice_days')::integer;deduction:=(v->>'deduction_minor')::bigint;
 if deduction>0 and exists(select 1 from public.journal_lines where company_id=cid and account_id=nullif(cfg.payload->>'deduction_receivable','')::uuid and party_id=emp and(project_id is not null or subcontract_id is not null or treasury_account_id is not null))then raise exception 'FINAL_DEDUCTION_DIMENSIONS: reconcile this dimensional receivable through its original workflow'using errcode='23514';end if;
 if leave_days>365000 or notice_days>90 then raise exception 'FINAL_DAYS_RANGE'using errcode='23514';end if;
 if leave_days>0 and nullif(btrim(v->>'leave_evidence'),'')is null then raise exception 'FINAL_LEAVE: approved accrued unused leave balance evidence required'using errcode='23514';end if;
 if notice_days>0 and(v->>'notice_treatment'is distinct from'EMPLOYER_OWES_UNSERVED'or nullif(btrim(v->>'notice_evidence'),'')is null)then raise exception 'FINAL_NOTICE: verify employer liability for unserved notice; served notice belongs in payroll'using errcode='23514';end if;
 wage:=t.basic_minor+coalesce((select sum((a->>'amount_minor')::numeric)from jsonb_array_elements(t.allowances)a),0);
 leave_pay:=round(t.basic_minor::numeric*leave_days/3000)::bigint;notice_pay:=round(wage*notice_days/30)::bigint;
 -- Known previous gratuity payments reduce the lifetime entitlement, not the provision twice.
 for x in select distinct on(document_id)*from public.hr_commercial_events where company_id=cid and kind='GRATUITY'and payload->>'employee_id'=emp::text and payload->>'employed_from'=t.employed_from::text order by document_id,version desc loop
  if x.state in('POSTED','PART_PAID','PAID')then already_paid:=already_paid+(x.payload->>'paid_minor')::bigint;end if;
 end loop;
 if coalesce(v->>'verified_prior_gratuity_paid_minor','')!~'^[0-9]+$'then raise exception 'FINAL_PRIOR_PAYMENTS: verify any earlier externally accrued/paid gratuity; enter0 explicitly when none'using errcode='23514';end if;
 if(v->>'verified_prior_gratuity_paid_minor')::bigint>0 and nullif(btrim(v->>'prior_payment_evidence'),'')is null then raise exception 'FINAL_PRIOR_EVIDENCE: identify other historical payments separately from already linked gratuity payments'using errcode='23514';end if;
 already_paid:=already_paid+(v->>'verified_prior_gratuity_paid_minor')::bigint;
 gratuity:=(g->>'amount_minor')::bigint-already_paid;prior:=private.hr_employee_control(cid,(cfg.payload->>'gratuity_payable')::uuid,emp);
 if gratuity<0 or prior<0 or prior>gratuity then raise exception 'FINAL_PROVISION: existing gratuity payments/provision exceed supported entitlement; reconcile before settlement'using errcode='23514';end if;
 if prior>0 then claims:=claims||jsonb_build_array(jsonb_build_object('kind','GRATUITY','source_id',(cfg.payload->>'gratuity_payable')::uuid,'account_id',cfg.payload->>'gratuity_payable','amount_minor',prior::text));end if;
 if deduction>0 then
  if nullif(btrim(v->>'deduction_evidence'),'')is null or nullif(cfg.payload->>'deduction_receivable','')is null or -private.hr_employee_control(cid,(cfg.payload->>'deduction_receivable')::uuid,emp)<deduction then raise exception 'FINAL_DEDUCTION: documented lawful amount and existing dedicated employee receivable required'using errcode='23514';end if;
  claims:=claims||jsonb_build_array(jsonb_build_object('kind','DEDUCTION','source_id',(cfg.payload->>'deduction_receivable')::uuid,'account_id',cfg.payload->>'deduction_receivable','amount_minor',deduction::text));
 end if;
 gross:=salary+reimbursement+gratuity+leave_pay+notice_pay-advances-deduction;
 if gross<0 or gross>9000000000000000 then raise exception 'FINAL_NET: negative settlement requires separate employee receivable treatment'using errcode='23514';end if;
 -- Claim totals must reconcile by employee/control before any reclassification.
 for x in select z->>'account_id'a,sum((z->>'amount_minor')::bigint)amount,bool_and(z->>'kind'in('ADVANCE','DEDUCTION'))asset from jsonb_array_elements(claims)z group by z->>'account_id'loop
  if (exists(select 1 from jsonb_array_elements(claims)z where z->>'account_id'=x.a and z->>'kind'='DEDUCTION')and -private.hr_employee_control(cid,x.a::uuid,emp)<x.amount)or(not exists(select 1 from jsonb_array_elements(claims)z where z->>'account_id'=x.a and z->>'kind'='DEDUCTION')and abs(private.hr_employee_control(cid,x.a::uuid,emp))<>x.amount)then raise exception 'FINAL_CONTROL: reconcile source subledger and employee GL control before settlement'using errcode='23514';end if;
 end loop;
 if private.hr_employee_control(cid,(cfg.payload->>'settlement_payable')::uuid,emp)<>0 then raise exception 'FINAL_CONTROL: existing final-settlement balance needs reconciliation'using errcode='23514';end if;
 select greatest(last_day,max(j.posting_date))into minimum_date from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.party_id=emp and l.account_id in(select(z->>'account_id')::uuid from jsonb_array_elements(claims)z);
 return jsonb_build_object('minimum_posting_date',minimum_date,'employee_id',emp,'employed_from',t.employed_from,'last_day',last_day,'term_id',t.id,'setup',cfg.payload,'claims',claims,'salary_minor',salary::bigint::text,'new_salary_basis',new_salary,'reimbursement_minor',reimbursement::bigint::text,'gratuity_total_minor',g->>'amount_minor','gratuity_paid_minor',already_paid::text,'gratuity_remaining_minor',gratuity::text,'gratuity_provision_minor',prior::text,'gratuity_new_expense_minor',(gratuity-prior)::text,'leave_minor',leave_pay::text,'notice_minor',notice_pay::text,'advance_minor',advances::bigint::text,'deduction_minor',deduction::text,'net_minor',gross::bigint::text,'facts',v,'paid_minor','0');
end$$;
create function public.preview_hr_completion(cid uuid,kind text,input jsonb)returns jsonb language plpgsql stable security definer set search_path=''as $$begin perform private.hr_read_actor(cid);if kind='SIF'then return private.hr_sif(cid,(input->>'payroll_id')::uuid,input,current_timestamp);elsif kind='SETTLEMENT'then return private.hr_final_preview(cid,input);else raise exception 'HR_COMPLETION_KIND'using errcode='22023';end if;end$$;
create function public.command_hr_completion(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_column
declare actor uuid;h text;old public.hr_completion_events;e public.hr_completion_events;cfg public.hr_completion_events;d uuid;k text;s text;v jsonb;x record;item jsonb;a public.accounts;t public.treasury_accounts;dt date;amount bigint;remaining bigint;j uuid;lines jsonb:='[]';emp uuid;balance numeric;fresh jsonb;wp public.hr_commercial_events;
begin
 actor:=private.operational_finance_actor(cid,'payroll.manage');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or action is null or action not in('SIF_EXPORT','SIF_DOWNLOAD','SETUP','SAVE','APPROVE','POST','PAY','REVERSE_PAYMENT','REVERSE')or jsonb_typeof(input)is distinct from'object'or octet_length(input::text)>200000 or coalesce(length(btrim(input->>'reason')),0)not between 1 and 1000 then raise exception 'HR_COMPLETION_INPUT: action, request and evidence required'using errcode='22023';end if;
 input:=input||jsonb_build_object('reason',btrim(input->>'reason'));h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into old from public.hr_completion_events x where x.company_id=cid and x.request_id=command_hr_completion.request_id;if found then if old.request_hash<>h then raise exception 'HR_CHANGED_REQUEST'using errcode='22023';end if;return jsonb_build_object('id',old.document_id,'version',old.version,'state',old.state,'payload',old.payload);end if;
 if action not in('SAVE','SIF_DOWNLOAD','PAY')and not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'HR_ADMIN_REQUIRED'using errcode='42501';end if;
 k:=case when action like'SIF_%'then'SIF'when action='SETUP'then'SETUP'else'SETTLEMENT'end;d:=case when k='SIF'then(input->>'payroll_id')::uuid when k='SETUP'then cid else(input->>'id')::uuid end;if d is null then raise exception 'HR_DOCUMENT_ID'using errcode='22023';end if;
 e:=private.hr_completion_latest(cid,k,d);if coalesce(e.version,0)<>coalesce((input->>'version')::integer,0)then raise exception 'HR_STALE: refresh the latest document'using errcode='40001';end if;
 if action='SIF_EXPORT'then
  if e.id is not null then raise exception 'SIF_ALREADY_EXPORTED: download the saved file; do not generate another payment request'using errcode='23505';end if;
  wp:=private.hr_commercial_latest(cid,'WPS',d);if wp.state is distinct from'PREPARED'or wp.payload is distinct from private.hr_wps_packet(cid,d)then raise exception 'SIF_PREPARATION: save a current WPS preparation snapshot first'using errcode='23514';end if;
  v:=private.hr_sif(cid,d,input,clock_timestamp());v:=v||jsonb_build_object('sha256',encode(extensions.digest(convert_to(v->>'content','UTF8'),'sha256'),'hex'));if exists(select 1 from public.hr_completion_events q where q.company_id=cid and q.kind='SIF'and q.payload->>'filename'=v->>'filename')then raise exception 'SIF_FILENAME_COLLISION: wait one second and retry the reviewed generation'using errcode='23505';end if;s:='EXPORTED';
 elsif action='SIF_DOWNLOAD'then
  if e.id is null then raise exception 'SIF_MISSING'using errcode='23514';end if;if e.payload->'packet'is distinct from private.hr_wps_packet(cid,d)then raise exception 'SIF_STALE: payroll, payment or recipient changed; do not resubmit the saved instruction'using errcode='23514';end if;v:=e.payload;s:='DOWNLOADED';
 elsif action='SETUP'then
  if not public.has_permission(cid,'account.manage')then raise exception 'HR_ACCOUNT_SETUP_DENIED'using errcode='42501';end if;v:='{}';
  for x in select *from(values('gratuity_expense','EXPENSE'),('gratuity_payable','LIABILITY'),('leave_expense','EXPENSE'),('notice_expense','EXPENSE'),('settlement_payable','LIABILITY'),('deduction_receivable','ASSET'))q(key,type)loop
   if x.key='deduction_receivable'and nullif(input->>x.key,'')is null then continue;end if;
   select *into a from public.accounts where company_id=cid and id=(input->>x.key)::uuid and status='ACTIVE'for share;
   if a.id is null or a.account_type::text<>x.type or a.system_key is not null or(x.type<>'EXPENSE'and not a.requires_party)or exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=a.id)then raise exception 'FINAL_ACCOUNT: dedicated active same-Company expense/Party control required for %',x.key using errcode='23514';end if;
   v:=v||jsonb_build_object(x.key,a.id);
  end loop;
  if nullif(v->>'deduction_receivable','')is not null and exists(select 1 from public.hr_payroll_setup_events where company_id=cid and advance_account_id=(v->>'deduction_receivable')::uuid)then raise exception 'FINAL_DEDUCTION_CONTROL: employee advance recovery uses its own source, not a second deduction mapping'using errcode='23514';end if;
  if v->>'gratuity_payable'=v->>'settlement_payable'then raise exception 'FINAL_DISTINCT_CONTROLS'using errcode='23514';end if;s:='CONFIGURED';
 elsif action='SAVE'then
  if e.state in('POSTED','PART_PAID','PAID','REVERSED')then raise exception 'FINAL_IMMUTABLE: use a new replacement draft linked to the reversed settlement'using errcode='23514';end if;
  v:=private.hr_final_preview(cid,input-'id'-'version');s:='DRAFT';
 elsif action='APPROVE'then
  if e.state is distinct from'DRAFT'then raise exception 'FINAL_REVIEW'using errcode='23514';end if;
  fresh:=private.hr_final_preview(cid,e.payload->'facts');if fresh is distinct from e.payload then raise exception 'FINAL_STALE: recalculate changed sources/terms/setup'using errcode='40001';end if;v:=e.payload;s:='APPROVED';
 else
  if not public.has_permission(cid,case when action in('REVERSE','REVERSE_PAYMENT')then'payroll.reverse'when action='PAY'then'payroll.pay'else'payroll.post'end)then raise exception 'FINAL_POSTING_DENIED'using errcode='42501';end if;
  dt:=(input->>'date')::date;v:=e.payload;emp:=(v->>'employee_id')::uuid;cfg.payload:=v->'setup';
  if dt is null or dt>(current_timestamp at time zone'Asia/Dubai')::date then raise exception 'FINAL_DATE'using errcode='23514';end if;
  if action='POST'then
   if dt<(v->>'minimum_posting_date')::date then raise exception 'FINAL_CUTOFF: date must be on or after linked source journals (%)',v->>'minimum_posting_date'using errcode='23514';end if;
   if e.state is distinct from'APPROVED'or private.hr_final_preview(cid,v->'facts')is distinct from v then raise exception 'FINAL_STALE: approved current sources required'using errcode='40001';end if;
   -- Clear each existing control in its actual GL dimensions, including any
   -- opposite-signed analytic buckets left by separately posted recoveries.
   for x in select distinct z->>'account_id'account from jsonb_array_elements(v->'claims')z where z->>'kind'<>'DEDUCTION'loop
    for item in select jsonb_build_object('project_id',l.project_id,'subcontract_id',l.subcontract_id,'treasury_account_id',l.treasury_account_id,'amount',sum(l.credit_minor-l.debit_minor)::text)from public.journal_lines l where l.company_id=cid and l.account_id=x.account::uuid and l.party_id=emp group by l.project_id,l.subcontract_id,l.treasury_account_id having sum(l.credit_minor-l.debit_minor)<>0 loop
     amount:=(item->>'amount')::bigint;lines:=lines||jsonb_build_array(item-'amount'||jsonb_build_object('account_id',x.account,'party_id',emp,'debit_minor',greatest(amount,0)::text,'credit_minor',greatest(-amount,0)::text));
    end loop;
   end loop;
   for item in select z from jsonb_array_elements(v->'claims')z where z->>'kind'='DEDUCTION'and(z->>'amount_minor')::bigint>0 loop
    lines:=lines||jsonb_build_array(jsonb_build_object('account_id',item->>'account_id','party_id',emp,'debit_minor','0','credit_minor',item->>'amount_minor'));
   end loop;
   if v->'new_salary_basis'is not null and v->'new_salary_basis'<>'null'::jsonb then
    for item in select z from jsonb_array_elements(private.hr_cost_parts((v->'new_salary_basis'->>'earned_minor')::bigint,v->'new_salary_basis'->'weights',null))z loop
     select id into a.id from public.accounts where company_id=cid and status='ACTIVE'and system_key=(case when nullif(item->>'project_id','')is null then'COMPANY_EXPENSE'else'PROJECT_COST'end)::public.system_account_key;
     if a.id is null then raise exception 'FINAL_SALARY_MAPPING'using errcode='23514';end if;
     lines:=lines||jsonb_build_array(jsonb_build_object('account_id',a.id,'party_id',emp,'project_id',nullif(item->>'project_id',''),'debit_minor',item->>'amount_minor','credit_minor','0'));
    end loop;
   end if;
   for x in select *from(values('gratuity_new_expense_minor','gratuity_expense'),('leave_minor','leave_expense'),('notice_minor','notice_expense'))q(amount,key)loop
    amount:=(v->>x.amount)::bigint;if amount>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cfg.payload->>x.key,'party_id',emp,'debit_minor',amount::text,'credit_minor','0'));end if;
   end loop;
   amount:=(v->>'net_minor')::bigint;if amount>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cfg.payload->>'settlement_payable','party_id',emp,'debit_minor','0','credit_minor',amount::text));end if;
   if jsonb_array_length(lines)>0 then j:=private.create_journal(cid,dt,'Employee final settlement','HR_FINAL_SETTLEMENT',d,'POST',lines,actor);end if;
   for item in select z from jsonb_array_elements(v->'claims')z loop insert into private.hr_settlement_claims values(cid,d,item->>'kind',(item->>'source_id')::uuid,(item->>'amount_minor')::bigint,(item->>'account_id')::uuid,emp);end loop;
   v:=v||jsonb_build_object('journal_id',j,'posting_date',dt,'payments','[]'::jsonb);s:=case when amount=0 then'PAID'else'POSTED'end;
  elsif action='PAY'then
   if e.state not in('POSTED','PART_PAID')or dt<(v->>'posting_date')::date or coalesce(input->>'amount_minor','')!~'^[1-9][0-9]*$'then raise exception 'FINAL_PAYMENT'using errcode='23514';end if;
   amount:=(input->>'amount_minor')::bigint;remaining:=(v->>'net_minor')::bigint-(v->>'paid_minor')::bigint;
   if amount>remaining or private.hr_employee_control(cid,(cfg.payload->>'settlement_payable')::uuid,emp)<>remaining then raise exception 'FINAL_CONTROL: unpaid settlement must reconcile to GL; no overpayment'using errcode='23514';end if;
   if exists(select 1 from jsonb_array_elements(v->'payments')z where z->>'reversed'='false'and z->>'reference'=input->>'reason')then raise exception 'FINAL_DUPLICATE_PAYMENT_REFERENCE'using errcode='23505';end if;
   select *into t from public.treasury_accounts where company_id=cid and id=(input->>'treasury_id')::uuid and status='ACTIVE'and project_id is null for share;if t.id is null or not exists(select 1 from public.accounts where company_id=cid and id=t.gl_account_id and status='ACTIVE'and account_type='ASSET')then raise exception 'FINAL_TREASURY'using errcode='23514';end if;
   select coalesce(sum(l.debit_minor-l.credit_minor),0)into balance from public.journal_lines l join public.journal_entries q on q.company_id=l.company_id and q.id=l.journal_entry_id where l.company_id=cid and l.account_id=t.gl_account_id and q.posting_date<=dt;
   if balance<amount then raise exception 'FINAL_INSUFFICIENT_FUNDS: recorded Treasury balance at payment date is insufficient'using errcode='23514';end if;
   j:=private.create_journal(cid,dt,'Final settlement payment','HR_FINAL_PAYMENT',request_id,'POST',jsonb_build_array(jsonb_build_object('account_id',cfg.payload->>'settlement_payable','party_id',emp,'debit_minor',amount::text,'credit_minor','0'),jsonb_build_object('account_id',t.gl_account_id,'party_id',emp,'treasury_account_id',t.id,'debit_minor','0','credit_minor',amount::text)),actor);
   v:=v||jsonb_build_object('paid_minor',((v->>'paid_minor')::bigint+amount)::text,'payments',(v->'payments')||jsonb_build_array(jsonb_build_object('journal_id',j,'amount_minor',amount::text,'date',dt,'reference',input->>'reason','treasury_id',t.id,'reversed',false)));s:=case when amount=remaining then'PAID'else'PART_PAID'end;
  elsif action='REVERSE_PAYMENT'then
   select z into item from jsonb_array_elements(v->'payments')z where z->>'journal_id'=input->>'payment_journal_id'and z->>'reversed'='false';
   if e.state not in('POSTED','PART_PAID','PAID')or item is null or dt<(item->>'date')::date then raise exception 'FINAL_PAYMENT_REVERSAL'using errcode='23514';end if;
   j:=private.reverse_journal((item->>'journal_id')::uuid,dt,input->>'reason',actor);v:=v||jsonb_build_object('paid_minor',((v->>'paid_minor')::bigint-(item->>'amount_minor')::bigint)::text,'payments',(select jsonb_agg(case when z->>'journal_id'=item->>'journal_id'then z||jsonb_build_object('reversed',true,'reversal_journal_id',j)else z end)from jsonb_array_elements(v->'payments')z));s:=case when v->>'paid_minor'='0'then'POSTED'else'PART_PAID'end;
  else
   if e.state not in('POSTED','PART_PAID','PAID')or v->>'paid_minor'<>'0'or dt<(v->>'posting_date')::date then raise exception 'FINAL_REVERSE_PAYMENTS_FIRST'using errcode='23514';end if;
   if nullif(v->>'journal_id','')is not null then j:=private.reverse_journal((v->>'journal_id')::uuid,dt,input->>'reason',actor);end if;v:=v||jsonb_build_object('reversal_journal_id',j);s:='REVERSED';
  end if;
 end if;
 insert into public.hr_completion_events(company_id,document_id,kind,version,state,payload,actor,reason,request_id,request_hash)values(cid,d,k,coalesce(e.version,0)+1,s,v,actor,input->>'reason',request_id,h);
 return jsonb_build_object('id',d,'version',coalesce(e.version,0)+1,'state',s,'payload',v);
end$$;

-- Prevent undoing source effects behind a live, immutable settlement.
create function private.hr_final_source_guard()returns trigger language plpgsql security definer set search_path=''as $$
declare sid uuid;k text;begin
 if tg_table_name='payroll_reversals'then
  if exists(select 1 from private.hr_settlement_claims x join public.payroll_entitlements n on n.company_id=x.company_id and n.id=x.source_id where x.company_id=new.company_id and x.kind='SALARY'and n.payroll_id=new.payroll_id and private.hr_settlement_live(x.company_id,x.settlement_id))then raise exception 'FINAL_DEPENDENCY: reverse final settlement first'using errcode='23514';end if;
 elsif tg_table_name='salary_payment_reversals'then
  if exists(select 1 from private.hr_settlement_claims x join public.salary_payments p on p.company_id=x.company_id and p.entitlement_id=x.source_id where x.company_id=new.company_id and x.kind='SALARY'and p.id=new.payment_id and private.hr_settlement_live(x.company_id,x.settlement_id))then raise exception 'FINAL_DEPENDENCY: reverse final settlement first'using errcode='23514';end if;
 elsif tg_table_name='payroll_entitlements'then
  if exists(select 1 from public.hr_completion_events x join public.payroll_postings p on p.company_id=x.company_id and p.id=new.payroll_id where x.company_id=new.company_id and x.kind='SETTLEMENT'and x.payload->>'employee_id'=new.employee_id::text and date_trunc('month',(x.payload->>'last_day')::date)::date=p.month and private.hr_settlement_live(x.company_id,x.document_id))then raise exception 'FINAL_SALARY_ALREADY_RECOGNIZED: reverse final settlement first'using errcode='23514';end if;
 elsif tg_table_name='hr_financial_reversals'then sid:=case when new.kind='RECOVERY'then(select advance_id from public.hr_recovery_postings where company_id=new.company_id and id=new.source_id)else new.source_id end;k:='ADVANCE';
 elsif tg_table_name='operational_liability_reversals'then select case when kind='PERSONAL_REIMBURSEMENT'then parent_posting_id else id end into sid from public.operational_liability_postings where company_id=new.company_id and id=new.posting_id;k:='REIMBURSEMENT';
 elsif tg_table_name='operational_liability_postings'then if new.kind='PERSONAL_REIMBURSEMENT'then sid:=new.parent_posting_id;k:='REIMBURSEMENT';end if;
 end if;
 if sid is not null and exists(select 1 from private.hr_settlement_claims x where x.company_id=new.company_id and x.kind=k and x.source_id=sid and private.hr_settlement_live(x.company_id,x.settlement_id))then raise exception 'FINAL_DEPENDENCY: source transferred to final settlement; reverse it first'using errcode='23514';end if;return new;
end$$;
create trigger hr_final_entitlement_dependency before insert on public.payroll_entitlements for each row execute function private.hr_final_source_guard();
create trigger hr_final_payroll_dependency before insert on public.payroll_reversals for each row execute function private.hr_final_source_guard();
create trigger hr_final_salary_dependency before insert on public.salary_payment_reversals for each row execute function private.hr_final_source_guard();
create trigger hr_final_advance_dependency before insert on public.hr_financial_reversals for each row execute function private.hr_final_source_guard();
create trigger hr_final_reimbursement_dependency before insert on public.operational_liability_reversals for each row execute function private.hr_final_source_guard();
create trigger hr_final_reimbursement_payment before insert on public.operational_liability_postings for each row execute function private.hr_final_source_guard();

create function public.read_hr_completion(cid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$begin perform private.hr_read_actor(cid);return jsonb_build_object('company_id',cid,'events',(select coalesce(jsonb_agg(to_jsonb(e)order by at),'[]')from public.hr_completion_events e where company_id=cid),'accounts',(select coalesce(jsonb_agg(jsonb_build_object('id',id,'name',code||' · '||name,'type',account_type,'party',requires_party)order by code),'[]')from public.accounts a where company_id=cid and status='ACTIVE'and system_key is null and not exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=a.id)));end$$;
do $$begin execute replace(pg_get_functiondef('public.payroll_journal_visible(uuid,uuid)'::regprocedure),'public.payroll_journal_visible(', 'private.hr_pre_final_journal_visible(');end$$;
create or replace function public.payroll_journal_visible(target_company_id uuid,target_journal_id uuid)returns boolean language sql stable security definer set search_path=''as $$select private.hr_pre_final_journal_visible(target_company_id,target_journal_id)and(public.has_permission(target_company_id,'payroll.manage')or not exists(select 1 from public.journal_entries j left join public.journal_entries o on o.id=j.reversal_of_journal_entry_id and o.company_id=j.company_id where j.company_id=target_company_id and j.id=target_journal_id and(j.source_type in('HR_FINAL_SETTLEMENT','HR_FINAL_PAYMENT')or o.source_type in('HR_FINAL_SETTLEMENT','HR_FINAL_PAYMENT'))))$$;
do $$declare p record;begin for p in select oid::regprocedure sig from pg_proc where pronamespace='private'::regnamespace and proname in('hr_scoped_payroll_rows','hr_completion_latest','hr_settlement_live','hr_pre_final_payroll_unpaid','hr_pre_final_recovery_balance','hr_sif','hr_sif_money','hr_employee_control','hr_final_preview','hr_final_source_guard','hr_pre_final_journal_visible')loop execute format('revoke all on function %s from public,anon,authenticated,service_role',p.sig);end loop;end$$;
revoke all on function public.preview_hr_completion(uuid,text,jsonb),public.command_hr_completion(uuid,uuid,text,jsonb),public.read_hr_completion(uuid),public.payroll_journal_visible(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.preview_hr_completion(uuid,text,jsonb),public.command_hr_completion(uuid,uuid,text,jsonb),public.read_hr_completion(uuid),public.payroll_journal_visible(uuid,uuid)to authenticated;
