-- 81: Company-approved explicit HR mode. Legacy snapshots and financial history are retained.
create policy historical_payroll_confidential on public.historical_source_records as restrictive for select to authenticated
 using(record_type<>'PAYROLL' or public.has_permission(company_id,'payroll.manage'));
create policy historical_payroll_audit_confidential on public.historical_source_audit as restrictive for select to authenticated
 using(exists(select 1 from public.historical_source_records s where s.company_id=historical_source_audit.company_id and s.id=historical_source_audit.source_id));

create table public.hr_policy_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),version integer not null,
 effective_month date not null check(extract(day from effective_month)=1),timezone text not null check(timezone='Asia/Dubai'),
 method text not null check(method='SCHEDULED_MINUTES'),approval text not null check(length(btrim(approval)) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,version),unique(company_id,id)
);
create table public.hr_term_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),employee_id uuid not null,
 version integer not null,effective_on date not null,employed_from date not null,employed_until date,
 basic_minor bigint not null check(basic_minor between 0 and 9000000000000000),allowances jsonb not null,
 weekdays integer[] not null check(cardinality(weekdays) between 1 and 7),start_minute integer not null check(start_minute between 0 and 1439),
 end_minute integer not null,break_minutes integer not null check(break_minutes>=0),project_id uuid,
 status text not null check(status in ('ACTIVE','ENDED')),evidence text not null check(length(btrim(evidence)) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,employee_id,version),foreign key(company_id,employee_id) references public.parties(company_id,id),foreign key(company_id,project_id) references public.projects(company_id,id),
 check(employed_until is null or employed_until>=employed_from),check(end_minute>start_minute and end_minute<=start_minute+1440 and break_minutes<end_minute-start_minute)
);
create table public.hr_calendar_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),day date not null,version integer not null,
 expected_minutes integer not null check(expected_minutes between 0 and 1440),kind text not null check(kind in ('WORK','REST','HOLIDAY')),
 evidence text not null check(length(btrim(evidence)) between 1 and 1000),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,day,version)
);
create table public.hr_attendance_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),employee_id uuid not null,day date not null,version integer not null,
 status text not null check(status in ('PRESENT','ABSENT','PAID_LEAVE','UNPAID_LEAVE','PARTIAL','REST','HOLIDAY')),
 project_id uuid,start_minute integer,end_minute integer,break_minutes integer not null,worked_minutes integer not null,paid_leave_minutes integer not null,
 overtime_minutes integer not null,overtime_earned_minor bigint not null check(overtime_earned_minor between 0 and 9000000000000000),
 expected_minutes integer not null,term_id uuid not null,reason text not null check(length(btrim(reason)) between 1 and 1000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,employee_id,day,version),unique(company_id,id),
 foreign key(company_id,employee_id) references public.parties(company_id,id),foreign key(company_id,project_id) references public.projects(company_id,id),foreign key(company_id,term_id) references public.hr_term_events(company_id,id),
 check(expected_minutes between 0 and 1440 and worked_minutes between 0 and 1440 and break_minutes between 0 and 1440 and paid_leave_minutes between 0 and 1440 and overtime_minutes between 0 and 1440)
);
create table public.hr_payroll_setup_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),version integer not null,advance_account_id uuid,
 evidence text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,version),
 foreign key(company_id,advance_account_id) references public.accounts(company_id,id)
);
create table public.hr_advance_postings (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),employee_id uuid not null,
 account_id uuid not null,treasury_id uuid not null,amount_minor bigint not null check(amount_minor between 1 and 9000000000000000),
 monthly_limit_minor bigint not null check(monthly_limit_minor between 1 and amount_minor),posting_date date not null,evidence text not null,
 journal_id uuid not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,id),
 foreign key(company_id,employee_id) references public.parties(company_id,id),foreign key(company_id,account_id) references public.accounts(company_id,id),foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id),foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.hr_recovery_plans (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),month date not null,advance_id uuid not null,version integer not null,
 amount_minor bigint not null check(amount_minor between 0 and 9000000000000000),evidence text not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,month,advance_id,version),foreign key(company_id,advance_id) references public.hr_advance_postings(company_id,id)
);
create table public.hr_recovery_postings (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,advance_id uuid not null,payroll_id uuid not null,amount_minor bigint not null check(amount_minor>0),journal_id uuid not null,
 unique(company_id,id),unique(company_id,payroll_id,advance_id),foreign key(company_id,advance_id) references public.hr_advance_postings(company_id,id),foreign key(company_id,payroll_id) references public.payroll_postings(company_id,id),foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.hr_financial_reversals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),source_id uuid not null,kind text not null check(kind in ('ADVANCE','RECOVERY')),journal_id uuid not null,reason text not null,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),unique(company_id,kind,source_id),foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table private.hr_command_receipts(company_id uuid not null,request_id uuid not null,hash text not null,result jsonb not null,primary key(company_id,request_id));
revoke all on private.hr_command_receipts from public,anon,authenticated,service_role;
do $$declare t text;begin foreach t in array array['hr_policy_events','hr_term_events','hr_calendar_events','hr_attendance_events','hr_payroll_setup_events','hr_advance_postings','hr_recovery_plans','hr_recovery_postings','hr_financial_reversals'] loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy payroll_only on public.%I for select to authenticated using(public.has_permission(company_id,''payroll.manage''))',t);
 execute format('create trigger immutable_hr before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
end loop;end;$$;
create function private.hr_policy(cid uuid,m date) returns public.hr_policy_events language sql stable set search_path='' as $$select p from public.hr_policy_events p where p.company_id=cid and p.effective_month<=m order by version desc limit 1$$;
create function private.hr_term(cid uuid,emp uuid,d date) returns public.hr_term_events language sql stable set search_path='' as $$select t from public.hr_term_events t where company_id=cid and employee_id=emp and effective_on<=d order by effective_on desc,version desc limit 1$$;
create function private.hr_expected(cid uuid,t public.hr_term_events,d date) returns integer language sql stable set search_path='' as $$
 select coalesce((select expected_minutes from public.hr_calendar_events where company_id=cid and day=d order by version desc limit 1),case when extract(isodow from d)::integer=any(t.weekdays) then t.end_minute-t.start_minute-t.break_minutes else 0 end)
$$;
create function private.hr_touch(cid uuid,m date) returns void language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.attendance_periods where company_id=cid and month=m and locked_at is not null) then raise exception 'Payroll-locked month; reverse dependent payroll before correction' using errcode='23514';end if;
 insert into public.attendance_periods(company_id,month) values(cid,m) on conflict do nothing;
 update public.attendance_periods set revision=revision+1,reviewed_revision=null,reviewed_by=null,reviewed_at=null where company_id=cid and month=m;
end;$$;
-- Expected calendar/facts expose no salary to Foreman. Staff receives terms through a separate payroll-only read.
create function private.hr_days(cid uuid,m date) returns jsonb language plpgsql stable set search_path='' as $$
declare e record;d date;t public.hr_term_events;v public.hr_attendance_events;out jsonb:='[]';ex integer;
begin
 for e in select distinct employee_id from public.hr_term_events where company_id=cid loop
  for d in select generate_series(m,m+interval '1 month - 1 day',interval '1 day')::date loop
   t:=private.hr_term(cid,e.employee_id,d);
   if t.id is null or t.status<>'ACTIVE' or d<t.employed_from or d>coalesce(t.employed_until,'infinity'::date) then continue;end if;
   ex:=private.hr_expected(cid,t,d);
   select * into v from public.hr_attendance_events where company_id=cid and employee_id=e.employee_id and day=d order by version desc limit 1;
   out:=out||jsonb_build_array(jsonb_build_object('employee_id',e.employee_id,'employee_name',(select name from public.parties where company_id=cid and id=e.employee_id),'day',d,'expected_minutes',ex,'schedule_start',t.start_minute,'schedule_end',t.end_minute,'schedule_break',t.break_minutes,'term_id',t.id,'project_id',case when v.id is null then t.project_id else v.project_id end,'status',coalesce(v.status,'UNRECORDED'),'version',coalesce(v.version,0),'worked_minutes',v.worked_minutes,'paid_leave_minutes',v.paid_leave_minutes,'unpaid_minutes',case when v.id is null then null else greatest(ex-least(v.worked_minutes,ex)-v.paid_leave_minutes,0) end,'overtime_minutes',v.overtime_minutes,'overtime_earned_minor',v.overtime_earned_minor::text,'start_minute',v.start_minute,'end_minute',v.end_minute,'break_minutes',v.break_minutes,'reason',v.reason,'stale',v.id is not null and (v.term_id<>t.id or v.expected_minutes<>ex)));
  end loop;
 end loop;return out;
end;$$;
create function private.hr_open_terms(cid uuid,d date) returns void language plpgsql set search_path='' as $$begin
 if exists(select 1 from public.attendance_periods where company_id=cid and month>=date_trunc('month',d)::date and locked_at is not null) then raise exception 'Term/calendar change would alter locked payroll history; choose a later effective date' using errcode='23514';end if;
 update public.attendance_periods set revision=revision+1,reviewed_revision=null,reviewed_by=null,reviewed_at=null where company_id=cid and month>=date_trunc('month',d)::date;
end;$$;
create function public.command_hr(cid uuid,request_id uuid,action text,input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;r jsonb;old private.hr_command_receipts;emp uuid;d date;m date;v integer;policy public.hr_policy_events;t public.hr_term_events;latest public.hr_term_events;
 aid uuid;k text;item jsonb;total numeric:=0;week integer[];st integer;en integer;br integer;worked integer;paid integer;ex integer;ot integer;otpay bigint;attendance_status text;pid uuid;rid uuid;account public.accounts;setup public.hr_payroll_setup_events;
 loan public.hr_advance_postings;amount bigint;limit_amount bigint;j uuid;req private.financial_command_requests;balance numeric;prior integer;
begin
 actor:=private.operational_finance_actor(cid,'payroll.manage');perform private.attendance_company_lock(cid);
 if request_id is null or input is null or jsonb_typeof(input)<>'object' or octet_length(input::text)>40000 or action is null or action not in ('POLICY','TERMS','CALENDAR','ATTENDANCE','REVIEW','SETUP','ADVANCE','REVERSE_ADVANCE','RECOVERY') then raise exception 'Invalid HR command' using errcode='22023';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select * into old from private.hr_command_receipts where company_id=cid and hr_command_receipts.request_id=command_hr.request_id;
 if found then if old.hash<>h then raise exception 'Changed HR request' using errcode='22023';end if;return old.result;end if;
 if action='SETUP' and not public.has_permission(cid,'account.manage') then raise exception 'Account configuration denied' using errcode='42501';end if;
 if action in ('POLICY','TERMS','CALENDAR','SETUP','ADVANCE','REVERSE_ADVANCE','RECOVERY') and not public.has_company_role(cid,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin approval required' using errcode='42501';end if;
 if coalesce(length(btrim(input->>'evidence')),0) not between 1 and 1000 then raise exception 'Approval/correction evidence required' using errcode='23514';end if;
 v:=coalesce((input->>'version')::integer,0);
 if action='POLICY' then
  m:=(input->>'effective_month')::date;
  if m is null or extract(day from m)<>1 or input->>'method' is distinct from 'SCHEDULED_MINUTES' or input->>'timezone' is distinct from 'Asia/Dubai' or input->>'approved' is distinct from 'true' then raise exception 'Explicitly approve scheduled-minute salary basis and Dubai calendar policy' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_policy_events where company_id=cid;if prior<>v then raise exception 'Policy version changed' using errcode='40001';end if;
  if exists(select 1 from public.payroll_draft_periods where company_id=cid and month>=m) or exists(select 1 from public.attendance_periods where company_id=cid and month>=m and (reviewed_revision is not null or locked_at is not null)) or exists(select 1 from public.attendance_exceptions where company_id=cid and absence_date>=m) then raise exception 'Cutover cannot reinterpret existing payroll/reviewed Lite periods or exceptions' using errcode='23514';end if;
  insert into public.hr_policy_events(company_id,version,effective_month,timezone,method,approval,created_by) values(cid,v+1,m,'Asia/Dubai','SCHEDULED_MINUTES',input->>'evidence',actor) returning id into rid;
 elsif action='TERMS' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'effective_on')::date;
  if not exists(select 1 from public.parties where company_id=cid and id=emp and private.party_has_person_role(cid,id,'EMPLOYEE')) then raise exception 'Company Employee required' using errcode='23503';end if;
  select * into latest from public.hr_term_events where company_id=cid and employee_id=emp order by version desc limit 1;
  if coalesce(latest.version,0)<>v then raise exception 'Employment version changed' using errcode='40001';end if;
  if d is null or (latest.id is not null and d<=latest.effective_on) then raise exception 'Amendment must be later than previous effective terms' using errcode='23514';end if;
  if (input->>'status'='ENDED' and nullif(input->>'employed_until','')::date is distinct from d-1) or (input->>'status'='ACTIVE' and nullif(input->>'employed_until','')::date<d) then raise exception 'Ended terms must take effect the day after last employment; active terms cannot start after employment ends' using errcode='23514';end if;
  perform private.hr_open_terms(cid,d);
  if private.hr_policy(cid,date_trunc('month',d)::date) is null then raise exception 'Approve HR policy before employment terms' using errcode='23514';end if;
  if coalesce(input->>'basic_minor','')!~'^[0-9]+$' or jsonb_typeof(input->'allowances')<>'array' then raise exception 'Exact salary and allowance components required' using errcode='22023';end if;
  if exists(select 1 from jsonb_array_elements(input->'allowances') x where upper(btrim(x->>'name'))='BASIC') or (select count(*) from jsonb_array_elements(input->'allowances'))<>(select count(distinct lower(btrim(x->>'name'))) from jsonb_array_elements(input->'allowances') x) then raise exception 'Unique allowance names; BASIC is reserved' using errcode='23514';end if;
  total:=(input->>'basic_minor')::bigint;
  for item in select jsonb_array_elements(input->'allowances') loop
   if coalesce(length(btrim(item->>'name')),0) not between 1 and 100 or coalesce(item->>'amount_minor','')!~'^[0-9]+$' then raise exception 'Named exact allowance required' using errcode='23514';end if;
   total:=total+(item->>'amount_minor')::bigint;
  end loop;
  if total not between 1 and 9000000000000000 then raise exception 'Salary outside range' using errcode='23514';end if;
  select array_agg(x::integer) into week from jsonb_array_elements_text(input->'weekdays') x;
  if cardinality(week)<> (select count(distinct x) from unnest(week) x) or exists(select 1 from unnest(week) x where x not between 1 and 7) then raise exception 'Unique ISO weekdays required' using errcode='23514';end if;
  pid:=nullif(input->>'project_id','')::uuid;if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED') then raise exception 'Eligible Company Project required' using errcode='23503';end if;
  insert into public.hr_term_events(company_id,employee_id,version,effective_on,employed_from,employed_until,basic_minor,allowances,weekdays,start_minute,end_minute,break_minutes,project_id,status,evidence,created_by)
  values(cid,emp,v+1,d,(input->>'employed_from')::date,nullif(input->>'employed_until','')::date,(input->>'basic_minor')::bigint,input->'allowances',week,(input->>'start_minute')::integer,(input->>'end_minute')::integer,(input->>'break_minutes')::integer,pid,input->>'status',input->>'evidence',actor) returning id into rid;
 elsif action='CALENDAR' then
  d:=(input->>'day')::date;perform private.hr_open_terms(cid,d);
  select coalesce(max(version),0) into prior from public.hr_calendar_events where company_id=cid and day=d;if prior<>v then raise exception 'Calendar changed' using errcode='40001';end if;
  if (input->>'kind' in ('REST','HOLIDAY') and (input->>'expected_minutes')::integer<>0) or (input->>'kind'='WORK' and (input->>'expected_minutes')::integer<=0) then raise exception 'Calendar kind and expected minutes disagree' using errcode='23514';end if;
  insert into public.hr_calendar_events(company_id,day,version,expected_minutes,kind,evidence,created_by) values(cid,d,v+1,(input->>'expected_minutes')::integer,input->>'kind',input->>'evidence',actor) returning id into rid;
 elsif action='ATTENDANCE' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'day')::date;m:=date_trunc('month',d)::date;
  if d is null or d>(clock_timestamp() at time zone 'Asia/Dubai')::date or private.hr_policy(cid,m) is null then raise exception 'Eligible nonfuture explicit attendance date required' using errcode='23514';end if;
  if not public.has_permission(cid,'attendance.record') then raise exception 'Attendance record permission required' using errcode='42501';end if;
  t:=private.hr_term(cid,emp,d);if t.id is null or t.status<>'ACTIVE' or d<t.employed_from or d>coalesce(t.employed_until,'infinity'::date) then raise exception 'Effective active employment required' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_attendance_events where company_id=cid and employee_id=emp and day=d;if prior<>v then raise exception 'Attendance changed; reload' using errcode='40001';end if;
  ex:=private.hr_expected(cid,t,d);st:=nullif(input->>'start_minute','')::integer;en:=nullif(input->>'end_minute','')::integer;br:=coalesce((input->>'break_minutes')::integer,0);paid:=coalesce((input->>'paid_leave_minutes')::integer,0);attendance_status:=input->>'status';pid:=nullif(input->>'project_id','')::uuid;
  if (st is null)<>(en is null) or br<0 or (st is not null and (st not between 0 and 1439 or en<=st or en>st+1440 or br>=en-st)) then raise exception 'Valid worked interval / overnight end / breaks required' using errcode='23514';end if;
  worked:=case when st is null then 0 else en-st-br end;ot:=greatest(worked-ex,0);otpay:=coalesce((input->>'overtime_earned_minor')::bigint,0);
  if paid<0 or least(worked,ex)+paid>ex or (ot=0 and otpay<>0) or (ot>0 and coalesce(length(btrim(input->>'overtime_approval')),0)=0) then raise exception 'Leave overlap or unapproved overtime; documented earned amount required' using errcode='23514';end if;
  if (attendance_status='PRESENT' and (worked<ex or paid<>0 or (ex=0 and worked=0))) or (attendance_status in ('ABSENT','UNPAID_LEAVE') and (worked<>0 or paid<>0 or ex=0)) or (attendance_status='PAID_LEAVE' and (worked<>0 or paid<>ex or ex=0)) or (attendance_status in ('REST','HOLIDAY') and (ex<>0 or worked<>0 or paid<>0)) or (attendance_status='PARTIAL' and (ex=0 or least(worked,ex)+paid>=ex and worked=ex)) then raise exception 'Attendance status conflicts with recorded/expected/leave minutes' using errcode='23514';end if;
  if pid is not null and not exists(select 1 from public.projects where company_id=cid and id=pid and status<>'CLOSED') then raise exception 'Eligible Company site required' using errcode='23503';end if;
  if st is not null and exists(select 1 from (select distinct on(day) * from public.hr_attendance_events where company_id=cid and employee_id=emp and day between d-1 and d+1 and day<>d order by day,version desc) prior_day where prior_day.start_minute is not null and d+make_interval(mins=>st)<prior_day.day+make_interval(mins=>prior_day.end_minute) and prior_day.day+make_interval(mins=>prior_day.start_minute)<d+make_interval(mins=>en)) then raise exception 'Actual shifts overlap across attendance dates' using errcode='23514';end if;
  perform private.hr_touch(cid,m);
  insert into public.hr_attendance_events(company_id,employee_id,day,version,status,project_id,start_minute,end_minute,break_minutes,worked_minutes,paid_leave_minutes,overtime_minutes,overtime_earned_minor,expected_minutes,term_id,reason,created_by)
  values(cid,emp,d,v+1,attendance_status,pid,st,en,br,worked,paid,ot,otpay,ex,t.id,(input->>'evidence')||coalesce(' / '||(input->>'overtime_approval'),''),actor) returning id into rid;
 elsif action='REVIEW' then
  m:=(input->>'month')::date;if extract(day from m)<>1 or private.hr_policy(cid,m) is null then raise exception 'Explicit month required' using errcode='23514';end if;
  perform private.hr_touch(cid,m);
  if exists(select 1 from jsonb_array_elements(private.hr_days(cid,m)) x where x->>'status'='UNRECORDED' or (x->>'stale')::boolean) or jsonb_array_length(private.hr_days(cid,m))=0 then raise exception 'Resolve all unrecorded/stale employment days before review' using errcode='23514';end if;
  select revision into prior from public.attendance_periods where company_id=cid and month=m;
  if prior<>v+1 then raise exception 'Review revision changed' using errcode='40001';end if;
  update public.attendance_periods set reviewed_revision=revision,reviewed_by=actor,reviewed_at=clock_timestamp() where company_id=cid and month=m;
  rid:=request_id;
 elsif action='SETUP' then
  select coalesce(max(version),0) into prior from public.hr_payroll_setup_events where company_id=cid;if prior<>v then raise exception 'Setup changed' using errcode='40001';end if;
  for k in select unnest(array['SALARY_PAYABLE','PROJECT_COST','COMPANY_EXPENSE']) loop
   if input->>k='NEW' then
    if exists(select 1 from public.accounts where company_id=cid and system_key=k::public.system_account_key) then raise exception 'Reuse the existing keyed account' using errcode='23514';end if;
    insert into public.accounts(company_id,code,name,account_type,requires_party) values(cid,btrim(input->>(k||'_code')),btrim(input->>(k||'_name')),case when k='SALARY_PAYABLE' then 'LIABILITY'::public.account_type else 'EXPENSE'::public.account_type end,k='SALARY_PAYABLE') returning id into aid;
   else aid:=nullif(input->>k,'')::uuid;end if;
   select * into account from public.accounts where company_id=cid and id=aid and status='ACTIVE' for update;
   if not found or account.account_type::text<>(case when k='SALARY_PAYABLE' then 'LIABILITY' else 'EXPENSE' end) or (account.system_key is not null and account.system_key::text<>k) then raise exception 'Approved active Company account/type required for %',k using errcode='23514';end if;
   if exists(select 1 from public.accounts where company_id=cid and system_key=k::public.system_account_key and id<>aid) then raise exception 'Existing keyed account must be reused; no remapping' using errcode='23514';end if;
   -- Existing used accounts cannot be repurposed by setup.
   if account.system_key is null and exists(select 1 from public.journal_lines where company_id=cid and account_id=aid) then raise exception 'Used unkeyed account requires separately reviewed adoption; choose unused approved account' using errcode='23514';end if;
   update public.accounts set system_key=k::public.system_account_key where company_id=cid and id=aid and system_key is null;
  end loop;
  if input->>'advance_account_id'='NEW' then
   insert into public.accounts(company_id,code,name,account_type,requires_party) values(cid,btrim(input->>'advance_code'),btrim(input->>'advance_name'),'ASSET',true) returning id into aid;
  else aid:=nullif(input->>'advance_account_id','')::uuid;end if;
  if aid is not null and not exists(select 1 from public.accounts where company_id=cid and id=aid and status='ACTIVE' and account_type='ASSET' and requires_party and system_key is null and not exists(select 1 from public.treasury_accounts where company_id=cid and gl_account_id=aid)) then raise exception 'Dedicated employee receivable ASSET requiring Party required' using errcode='23514';end if;
  if aid is not null and exists(select 1 from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=cid and l.account_id=aid and j.source_type not in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY') and not exists(select 1 from public.journal_entries original where original.id=j.reversal_of_journal_entry_id and original.company_id=cid and original.source_type in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY'))) then raise exception 'Used non-HR account cannot become the dedicated employee receivable' using errcode='23514';end if;
  insert into public.hr_payroll_setup_events(company_id,version,advance_account_id,evidence,created_by) values(cid,v+1,aid,input->>'evidence',actor) returning id into rid;
 elsif action='ADVANCE' then
  emp:=(input->>'employee_id')::uuid;d:=(input->>'date')::date;amount:=(input->>'amount_minor')::bigint;limit_amount:=(input->>'monthly_limit_minor')::bigint;aid:=(input->>'treasury_id')::uuid;perform private.opening_period(cid,d);
  if not exists(select 1 from public.parties where company_id=cid and id=emp and status='ACTIVE' and private.party_has_person_role(cid,id,'EMPLOYEE')) then raise exception 'Active Company employee required' using errcode='23503';end if;
  select * into setup from public.hr_payroll_setup_events where company_id=cid order by version desc limit 1;
  if setup.advance_account_id is null then raise exception 'Approve employee advance mapping before funding' using errcode='23514';end if;
  select * into account from public.accounts where company_id=cid and id=setup.advance_account_id and status='ACTIVE' for share;if not found then raise exception 'Advance account inactive' using errcode='23514';end if;
  if amount not between 1 and 9000000000000000 or limit_amount not between 1 and amount then raise exception 'Approved amount and recovery limit required' using errcode='23514';end if;
  select gl_account_id into pid from public.treasury_accounts where company_id=cid and id=aid and status='ACTIVE' and project_id is null for share;if not found then raise exception 'Active general Treasury required' using errcode='23514';end if;
  rid:=gen_random_uuid();j:=private.create_journal(cid,d,'Approved employee advance','HR_EMPLOYEE_ADVANCE',rid,'POST',jsonb_build_array(jsonb_build_object('account_id',account.id,'party_id',emp,'debit_minor',amount::text,'credit_minor','0'),jsonb_build_object('account_id',pid,'treasury_account_id',aid,'debit_minor','0','credit_minor',amount::text)),actor);
  insert into public.hr_advance_postings(id,company_id,employee_id,account_id,treasury_id,amount_minor,monthly_limit_minor,posting_date,evidence,journal_id,created_by) values(rid,cid,emp,account.id,aid,amount,limit_amount,d,input->>'evidence',j,actor);
 elsif action='REVERSE_ADVANCE' then
  select * into loan from public.hr_advance_postings where company_id=cid and id=(input->>'advance_id')::uuid for update;
  if not found or exists(select 1 from public.hr_financial_reversals where company_id=cid and kind='ADVANCE' and source_id=loan.id) then raise exception 'Live Company advance required' using errcode='23514';end if;
  if exists(select 1 from public.hr_recovery_postings x where company_id=cid and advance_id=loan.id and not exists(select 1 from public.hr_financial_reversals y where y.company_id=cid and y.kind='RECOVERY' and y.source_id=x.id)) then raise exception 'Reverse dependent payroll recovery first' using errcode='23514';end if;
  d:=(input->>'date')::date;perform private.opening_period(cid,d);if d<loan.posting_date then raise exception 'Reversal before advance denied' using errcode='23514';end if;
  j:=private.reverse_journal(loan.journal_id,d,input->>'evidence',actor);insert into public.hr_financial_reversals(company_id,source_id,kind,journal_id,reason,created_by) values(cid,loan.id,'ADVANCE',j,input->>'evidence',actor) returning id into rid;
 elsif action='RECOVERY' then
  m:=(input->>'month')::date;if m is null or extract(day from m)<>1 or private.hr_policy(cid,m) is null then raise exception 'Explicit payroll month required' using errcode='23514';end if;perform private.hr_touch(cid,m);
  select * into loan from public.hr_advance_postings where company_id=cid and id=(input->>'advance_id')::uuid for update;
  if not found or m<date_trunc('month',loan.posting_date)::date or exists(select 1 from public.hr_financial_reversals where company_id=cid and source_id=loan.id and kind='ADVANCE') then raise exception 'Eligible advance required' using errcode='23514';end if;
  select coalesce(max(version),0) into prior from public.hr_recovery_plans where company_id=cid and month=m and advance_id=loan.id;if prior<>v then raise exception 'Recovery plan changed' using errcode='40001';end if;
  amount:=(input->>'amount_minor')::bigint;if amount<0 or amount>loan.monthly_limit_minor then raise exception 'Recovery exceeds explicitly approved monthly limit' using errcode='23514';end if;
  insert into public.hr_recovery_plans(company_id,month,advance_id,version,amount_minor,evidence,created_by) values(cid,m,loan.id,v+1,amount,input->>'evidence',actor) returning id into rid;
 end if;
 r:=jsonb_build_object('id',rid,'action',action);insert into private.hr_command_receipts values(cid,request_id,h,r);return r;
end;$$;

-- New mode extends the source hash; the old source remains identical before explicit cutover.
do $$declare n text;sig text;definition text;begin
 foreach n in array array['payroll_draft_source','refresh_payroll_draft','read_payroll_draft','post_payroll','reverse_payroll','payroll_unpaid','payroll_journal_visible','confirm_attendance_review'] loop
  select pg_get_functiondef(p.oid),pg_get_function_identity_arguments(p.oid) into definition,sig from pg_proc p join pg_namespace s on s.oid=p.pronamespace where p.proname=n and s.nspname=case when n in ('payroll_draft_source','payroll_unpaid') then 'private' else 'public' end;
  if definition is null then raise exception 'Missing canonical payroll dependency %',n;end if;
  definition:=regexp_replace(definition,'FUNCTION (public|private)\.'||n||'\(','FUNCTION private.hr_legacy_'||n||'(');
  execute definition;execute format('revoke all on function private.hr_legacy_%I(%s) from public,anon,authenticated,service_role',n,sig);
 end loop;
end;$$;
alter table public.payroll_draft_rows add column hr_basis jsonb;
do $$declare n text;begin
 select conname into n from pg_constraint where conrelid='public.payroll_draft_rows'::regclass and contype='c' and pg_get_constraintdef(oid) like '%round(%' and pg_get_constraintdef(oid) like '%absence_half_units%';
 if n is null then raise exception 'Missing canonical half-unit calculation constraint';end if;
 execute format('alter table public.payroll_draft_rows drop constraint %I',n);
end;$$;
alter table public.payroll_draft_rows add constraint payroll_calculation_basis check(
 (hr_basis is null and absence_deduction_minor=round(monthly_salary_minor::numeric*absence_half_units/(2*calendar_days))::bigint)
 or (hr_basis is not null and hr_basis->>'mode'='EXPLICIT_MINUTES' and absence_half_units=0
 and monthly_salary_minor=(hr_basis->>'nominal_minor')::bigint and gross_salary_minor=(hr_basis->>'earned_minor')::bigint)
);
create function private.hr_recovery_balance(cid uuid,aid uuid) returns bigint language sql stable set search_path='' as $$
 select a.amount_minor-coalesce((select sum(x.amount_minor) from public.hr_recovery_postings x where x.company_id=cid and x.advance_id=a.id and not exists(select 1 from public.hr_financial_reversals y where y.company_id=cid and y.kind='RECOVERY' and y.source_id=x.id)),0)::bigint
 from public.hr_advance_postings a where a.company_id=cid and a.id=aid and not exists(select 1 from public.hr_financial_reversals y where y.company_id=cid and y.kind='ADVANCE' and y.source_id=a.id)
$$;
create function private.hr_payroll_rows(cid uuid,m date) returns jsonb language plpgsql stable set search_path='' as $$
declare days jsonb:=private.hr_days(cid,m);e record;f public.payroll_profiles;t public.hr_term_events;day jsonb;item jsonb;comp jsonb;nominals jsonb;earnings jsonb;weights jsonb;key text;denom numeric;expected integer;payable integer;rate numeric;nominal bigint;earned bigint;ot bigint;minutes_worked integer;minutes_unpaid integer;minutes_expected integer;recov bigint;recovery jsonb;out jsonb:='[]';default_site uuid;site text;part numeric;
begin
 if jsonb_array_length(days)=0 or exists(select 1 from jsonb_array_elements(days) x where x->>'status'='UNRECORDED' or (x->>'stale')::boolean) then raise exception 'Complete and review explicit attendance before payroll calculation' using errcode='23514';end if;
 for e in select distinct x->>'employee_id' id from jsonb_array_elements(days) x loop
  select * into f from public.payroll_profiles where company_id=cid and employee_id=e.id::uuid and status='ACTIVE';
  if not found then raise exception 'Active Payroll profile required for every employed employee' using errcode='23514';end if;
  nominals:='{}';earnings:='{}';weights:='{}';ot:=0;minutes_worked:=0;minutes_unpaid:=0;minutes_expected:=0;
  for day in select x from jsonb_array_elements(days) x where x->>'employee_id'=e.id loop
   select * into t from public.hr_term_events where company_id=cid and id=(day->>'term_id')::uuid;
   select sum(private.hr_expected(cid,t,d::date)) into denom from generate_series(m,m+interval '1 month - 1 day',interval '1 day') d;
   if denom<=0 then raise exception 'No scheduled minutes in salary basis; approve a supported calendar' using errcode='23514';end if;
   expected:=(day->>'expected_minutes')::integer;payable:=least((day->>'worked_minutes')::integer,expected)+(day->>'paid_leave_minutes')::integer;
   comp:=jsonb_build_array(jsonb_build_object('name','BASIC','amount_minor',t.basic_minor::text))||t.allowances;
   site:=coalesce(day->>'project_id','COMPANY');part:=0;
   for item in select jsonb_array_elements(comp) loop
    key:=item->>'name';rate:=(item->>'amount_minor')::numeric;
    nominals:=jsonb_set(nominals,array[key],to_jsonb(coalesce((nominals->>key)::numeric,0)+rate*expected/denom),true);
    earnings:=jsonb_set(earnings,array[key],to_jsonb(coalesce((earnings->>key)::numeric,0)+rate*payable/denom),true);
    part:=part+rate*payable/denom;
   end loop;
   part:=part+(day->>'overtime_earned_minor')::bigint;ot:=ot+(day->>'overtime_earned_minor')::bigint;
   weights:=jsonb_set(weights,array[site],to_jsonb(coalesce((weights->>site)::numeric,0)+part),true);
   minutes_worked:=minutes_worked+(day->>'worked_minutes')::integer;minutes_unpaid:=minutes_unpaid+(day->>'unpaid_minutes')::integer;minutes_expected:=minutes_expected+expected;
  end loop;
  nominal:=ot;earned:=ot;comp:='[]';
  for key in select jsonb_object_keys(nominals) loop
   nominal:=nominal+round((nominals->>key)::numeric)::bigint;earned:=earned+round((earnings->>key)::numeric)::bigint;
   comp:=comp||jsonb_build_array(jsonb_build_object('name',key,'nominal_minor',round((nominals->>key)::numeric)::bigint::text,'earned_minor',round((earnings->>key)::numeric)::bigint::text));
  end loop;
  if nominal>9000000000000000 or earned>9000000000000000 then raise exception 'Compensation exceeds supported range' using errcode='22003';end if;
  select coalesce(sum(p.amount_minor),0)::bigint,coalesce(jsonb_agg(jsonb_build_object('advance_id',p.advance_id,'amount_minor',p.amount_minor::text,'evidence',p.evidence)),'[]') into recov,recovery
   from public.hr_recovery_plans p join public.hr_advance_postings a on a.company_id=p.company_id and a.id=p.advance_id
   where p.company_id=cid and p.month=m and a.employee_id=e.id::uuid and not exists(select 1 from public.hr_financial_reversals rv where rv.company_id=cid and rv.kind='ADVANCE' and rv.source_id=a.id) and p.version=(select max(version) from public.hr_recovery_plans z where z.company_id=p.company_id and z.month=p.month and z.advance_id=p.advance_id);
  for item in select jsonb_array_elements(recovery) loop
   null; -- Authoritative live receivable is revalidated atomically at posting.
  end loop;
  select case when count(*)=1 then nullif(min(k),'COMPANY')::uuid end into default_site from jsonb_each_text(weights) x(k,v) where v::numeric>0;
  out:=out||jsonb_build_array(jsonb_build_object('employee_id',e.id,'employee_name',(select name from public.parties where company_id=cid and id=e.id::uuid),'profile',to_jsonb(f)-'monthly_salary_minor','mode','EXPLICIT_MINUTES','nominal_minor',nominal::text,'earned_minor',earned::text,'components',comp,'overtime_minor',ot::text,'recovery_minor',recov::text,'recoveries',recovery,'worked_minutes',minutes_worked,'unpaid_minutes',minutes_unpaid,'expected_minutes',minutes_expected,'weights',weights,'default_project_id',default_site,'days',(select jsonb_agg(x) from jsonb_array_elements(days) x where x->>'employee_id'=e.id)));
 end loop;return out;
end;$$;
create or replace function private.payroll_draft_source(c uuid,m date) returns jsonb language plpgsql stable set search_path='' as $$
declare v jsonb:=private.hr_legacy_payroll_draft_source(c,m);begin
 if private.hr_policy(c,m) is not null then v:=v||jsonb_build_object('hr_policy',to_jsonb(private.hr_policy(c,m)),'hr_rows',private.hr_payroll_rows(c,m));end if;return v;
end;$$;
create or replace function public.refresh_payroll_draft(target_company_id uuid,target_month date,target_version integer) returns uuid language plpgsql security definer set search_path='' as $$
declare src jsonb;p public.payroll_draft_periods;v jsonb;f jsonb;a numeric;d numeric;net numeric;rid uuid;days integer;
begin
 perform private.operational_finance_actor(target_company_id,'payroll.manage');perform private.attendance_company_lock(target_company_id);
 if private.hr_policy(target_company_id,target_month) is null then return private.hr_legacy_refresh_payroll_draft(target_company_id,target_month,target_version);end if;
 if target_month is null or extract(day from target_month)<>1 or target_version is null then raise exception 'Valid month/version required' using errcode='23514';end if;
 src:=private.payroll_draft_source(target_company_id,target_month);perform private.require_payroll_review(src);
 select * into p from public.payroll_draft_periods where company_id=target_company_id and month=target_month for update;
 if coalesce(p.version,0)<>target_version then raise exception 'Draft changed' using errcode='40001';end if;
 days:=extract(day from target_month+interval '1 month - 1 day')::integer;
 if p.id is null then insert into public.payroll_draft_periods(company_id,month,calendar_days,source_hash,attendance_revision,created_by,refreshed_by) values(target_company_id,target_month,days,md5(src::text),(src->'attendance'->>'revision')::integer,auth.uid(),auth.uid()) returning * into p;end if;
 if exists(select 1 from public.payroll_draft_rows r join public.payroll_draft_adjustments x on x.row_id=r.id and not x.voided where r.period_id=p.id and not exists(select 1 from jsonb_array_elements(src->'hr_rows') h where h->>'employee_id'=r.employee_id::text)) then raise exception 'Void adjustments for excluded employees first' using errcode='23514';end if;
 update public.payroll_draft_rows set included=false where period_id=p.id;
 for v in select jsonb_array_elements(src->'hr_rows') loop
  f:=v->'profile';
  select coalesce(sum(x.amount_minor) filter(where x.kind='ADDITION'),0),coalesce(sum(x.amount_minor) filter(where x.kind='DEDUCTION'),0) into a,d from public.payroll_draft_adjustments x join public.payroll_draft_rows r on r.id=x.row_id where r.period_id=p.id and r.employee_id=(v->>'employee_id')::uuid and not x.voided;
  net:=(v->>'earned_minor')::bigint+a-d;if net<0 or net>9000000000000000 or net<(v->>'recovery_minor')::bigint then raise exception 'Negative pay or recovery exceeds earned entitlement' using errcode='23514';end if;
  v:=v||jsonb_build_object('cash_net_minor',(net-(v->>'recovery_minor')::bigint)::bigint::text);
  insert into public.payroll_draft_rows(company_id,period_id,employee_id,employee_name,payroll_id,payroll_type,profession,work_station,default_project_id,payment_type,monthly_salary_minor,calendar_days,absence_half_units,absence_deduction_minor,additions_minor,deductions_minor,gross_salary_minor,net_salary_minor,hr_basis)
   values(target_company_id,p.id,(v->>'employee_id')::uuid,v->>'employee_name',f->>'payroll_id','EXPLICIT_MINUTES',f->>'profession',f->>'work_station',(v->>'default_project_id')::uuid,f->>'payment_type',(v->>'nominal_minor')::bigint,days,0,(v->>'nominal_minor')::bigint-(v->>'earned_minor')::bigint,a::bigint,d::bigint,(v->>'earned_minor')::bigint,net::bigint,v)
  on conflict(company_id,period_id,employee_id) do update set included=true,employee_name=excluded.employee_name,payroll_id=excluded.payroll_id,payroll_type=excluded.payroll_type,profession=excluded.profession,work_station=excluded.work_station,default_project_id=excluded.default_project_id,payment_type=excluded.payment_type,monthly_salary_minor=excluded.monthly_salary_minor,calendar_days=excluded.calendar_days,absence_half_units=0,absence_deduction_minor=excluded.absence_deduction_minor,additions_minor=excluded.additions_minor,deductions_minor=excluded.deductions_minor,gross_salary_minor=excluded.gross_salary_minor,net_salary_minor=excluded.net_salary_minor,hr_basis=excluded.hr_basis;
 end loop;
 update public.payroll_draft_periods set version=case when target_version=0 then 1 else version+1 end,source_hash=md5(src::text),attendance_revision=(src->'attendance'->>'revision')::integer,calculated_adjustments_revision=adjustments_revision,reviewed_version=null,reviewed_by=null,reviewed_at=null,refreshed_by=auth.uid(),refreshed_at=clock_timestamp() where id=p.id;
 return p.id;
end;$$;
-- The legacy read preserves immutable posted rows; only attach existing new basis data to its rows.
create or replace function public.read_payroll_draft(target_company_id uuid,target_month date) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin return private.hr_legacy_read_payroll_draft(target_company_id,target_month);end;$$;
-- Legacy read's to_jsonb(row) already carries hr_basis; no mutable reconstruction of posted outputs.

create function private.hr_cost_parts(total bigint,weights jsonb,default_project uuid) returns jsonb language plpgsql immutable set search_path='' as $$
declare sum_weight numeric;out jsonb:='[]';r record;remainder bigint;begin
 select sum(v::numeric) into sum_weight from jsonb_each_text(weights) x(k,v) where v::numeric>0;
 if coalesce(sum_weight,0)=0 then return jsonb_build_array(jsonb_build_object('project_id',default_project,'amount_minor',total::text));end if;
 select total-sum(floor(total::numeric*v::numeric/sum_weight))::bigint into remainder from jsonb_each_text(weights) x(k,v) where v::numeric>0;
 for r in select k,floor(total::numeric*v::numeric/sum_weight)::bigint amount,row_number() over(order by (total::numeric*v::numeric/sum_weight-floor(total::numeric*v::numeric/sum_weight)) desc,k) rank from jsonb_each_text(weights) x(k,v) where v::numeric>0 loop
  out:=out||jsonb_build_array(jsonb_build_object('project_id',nullif(r.k,'COMPANY')::uuid,'amount_minor',(r.amount+case when r.rank<=remainder then 1 else 0 end)::text));
 end loop;return out;
end;$$;
create function private.hr_post_recoveries(cid uuid,payroll uuid) returns void language plpgsql set search_path='' as $$
declare p public.payroll_postings;r jsonb;x jsonb;loan public.hr_advance_postings;j uuid;rid uuid;payable uuid;net bigint;
begin
 select * into p from public.payroll_postings where company_id=cid and id=payroll;
 for r in select jsonb_array_elements(p.snapshot->'rows') loop
  if not coalesce((r->>'included')::boolean,false) or r->'hr_basis' is null or r->'hr_basis'='null' then continue;end if;
  payable:=(select payable_account_id from public.payroll_entitlements where company_id=cid and payroll_id=payroll and employee_id=(r->>'employee_id')::uuid);
  for x in select jsonb_array_elements(r->'hr_basis'->'recoveries') loop
   net:=(x->>'amount_minor')::bigint;if net=0 then continue;end if;
   if exists(select 1 from public.hr_recovery_postings where company_id=cid and payroll_id=payroll and advance_id=(x->>'advance_id')::uuid) then continue;end if;
   select * into loan from public.hr_advance_postings where company_id=cid and id=(x->>'advance_id')::uuid for update;
   if loan.employee_id<>(r->>'employee_id')::uuid or loan.posting_date>p.posting_date or coalesce(private.hr_recovery_balance(cid,loan.id),0)<net or net>loan.monthly_limit_minor then raise exception 'Approved recovery no longer eligible' using errcode='23514';end if;
   rid:=gen_random_uuid();j:=private.create_journal(cid,p.posting_date,'Approved payroll advance recovery','HR_PAYROLL_RECOVERY',rid,'POST',jsonb_build_array(jsonb_build_object('account_id',payable,'party_id',loan.employee_id,'debit_minor',net::text,'credit_minor','0'),jsonb_build_object('account_id',loan.account_id,'party_id',loan.employee_id,'debit_minor','0','credit_minor',net::text)),auth.uid());
   insert into public.hr_recovery_postings(id,company_id,advance_id,payroll_id,amount_minor,journal_id) values(rid,cid,loan.id,payroll,net,j);
  end loop;
 end loop;
end;$$;
-- Extend the canonical posting loop only; all approval, request, snapshot, lock,
-- entitlement and payment semantics remain the established implementation.
do $$declare body text;old text;new text;begin
 select prosrc into body from pg_proc p join pg_namespace n on n.oid=p.pronamespace where n.nspname='public' and p.proname='post_payroll';
 old:='if r.net_salary_minor>0 then lines:=lines||jsonb_build_array(';
 if position(old in body)=0 then raise exception 'Canonical posting loop changed';end if;
 body:=replace(body,'snap jsonb; previous uuid;','snap jsonb; previous uuid; hr_part jsonb; hr_account uuid; hr_project uuid;');
 new:=$code$if r.hr_basis is not null and r.net_salary_minor>0 then
   if plan.allocations->>r.id::text is distinct from r.default_project_id::text then raise exception 'Explicit attendance allocation must match reviewed source' using errcode='23514';end if;
   for hr_part in select jsonb_array_elements(private.hr_cost_parts(r.net_salary_minor,r.hr_basis->'weights',r.default_project_id)) loop
    hr_project:=(hr_part->>'project_id')::uuid;
    if hr_project is not null and not exists(select 1 from public.projects where company_id=target_company_id and id=hr_project and status<>'CLOSED') then raise exception 'Allocated Project unavailable' using errcode='23514';end if;
    select id into hr_account from public.accounts where company_id=target_company_id and system_key=(case when hr_project is null then 'COMPANY_EXPENSE' else 'PROJECT_COST' end)::public.system_account_key and status='ACTIVE' and account_type='EXPENSE';
    if hr_account is null then raise exception 'Project/company cost mapping missing' using errcode='23514';end if;
    if (hr_part->>'amount_minor')::bigint>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',hr_account,'debit_minor',hr_part->>'amount_minor','credit_minor','0','project_id',hr_project,'party_id',r.employee_id));end if;
   end loop;
   lines:=lines||jsonb_build_array(jsonb_build_object('account_id',payable,'debit_minor','0','credit_minor',r.net_salary_minor::text,'project_id',project,'party_id',r.employee_id));
  elsif r.net_salary_minor>0 then lines:=lines||jsonb_build_array($code$;
 body:=replace(body,old,new);
 execute 'create or replace function private.hr_post_core(target_company_id uuid,target_period_id uuid,target_version integer,target_idempotency_key uuid) returns uuid language plpgsql security definer set search_path='''' as '||quote_literal(body);
end;$$;
create or replace function public.post_payroll(target_company_id uuid,target_period_id uuid,target_version integer,target_idempotency_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid;d date;begin
 perform private.operational_finance_actor(target_company_id,'payroll.post');perform private.attendance_company_lock(target_company_id);
 select (month+interval '1 month - 1 day')::date into d from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id;
 perform private.opening_period(target_company_id,d);
 rid:=private.hr_post_core(target_company_id,target_period_id,target_version,target_idempotency_key);
 perform private.hr_post_recoveries(target_company_id,rid);return rid;
end;$$;
create or replace function private.payroll_unpaid(e uuid) returns numeric language sql stable set search_path='' as $$
 select private.hr_legacy_payroll_unpaid(e)-coalesce((select sum(x.amount_minor) from public.hr_recovery_postings x join public.hr_advance_postings a on a.company_id=x.company_id and a.id=x.advance_id join public.payroll_entitlements n on n.company_id=x.company_id and n.payroll_id=x.payroll_id and n.employee_id=a.employee_id where n.id=e and not exists(select 1 from public.hr_financial_reversals y where y.company_id=x.company_id and y.kind='RECOVERY' and y.source_id=x.id)),0)
$$;
create or replace function public.reverse_payroll(target_company_id uuid,target_payroll_id uuid,target_date date,target_reason text,target_idempotency_key uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare rid uuid;r public.hr_recovery_postings;j uuid;begin
 perform private.operational_finance_actor(target_company_id,'payroll.reverse');perform private.attendance_company_lock(target_company_id);perform private.opening_period(target_company_id,target_date);
 rid:=private.hr_legacy_reverse_payroll(target_company_id,target_payroll_id,target_date,target_reason,target_idempotency_key);
 for r in select * from public.hr_recovery_postings where company_id=target_company_id and payroll_id=target_payroll_id loop
  if not exists(select 1 from public.hr_financial_reversals where company_id=target_company_id and kind='RECOVERY' and source_id=r.id) then
   j:=private.reverse_journal(r.journal_id,target_date,target_reason,auth.uid());insert into public.hr_financial_reversals(company_id,source_id,kind,journal_id,reason,created_by) values(target_company_id,r.id,'RECOVERY',j,target_reason,auth.uid());
  end if;
 end loop;return rid;
end;$$;
create or replace function public.payroll_journal_visible(target_company_id uuid,target_journal_id uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.is_company_member(target_company_id) and (public.has_permission(target_company_id,'payroll.manage') or (private.hr_legacy_payroll_journal_visible(target_company_id,target_journal_id) and not exists(select 1 from public.journal_entries j left join public.journal_entries o on o.id=j.reversal_of_journal_entry_id where j.company_id=target_company_id and j.id=target_journal_id and (j.source_type in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY') or o.source_type in ('HR_EMPLOYEE_ADVANCE','HR_PAYROLL_RECOVERY')))))
$$;
-- Legacy absence commands cannot silently add half-day meaning to a new explicit month.
create function private.hr_guard_legacy_absence() returns trigger language plpgsql set search_path='' as $$begin
 if private.hr_policy(new.company_id,date_trunc('month',new.absence_date)::date) is not null then raise exception 'Use explicit attendance for this Company/month' using errcode='23514';end if;return new;
end;$$;
create trigger hr_explicit_absence_boundary before insert or update on public.attendance_exceptions for each row execute function private.hr_guard_legacy_absence();
create or replace function public.confirm_attendance_review(target_company_id uuid,target_month date,target_revision integer) returns void language plpgsql security definer set search_path='' as $$begin
 if private.hr_policy(target_company_id,target_month) is not null then raise exception 'Review explicit attendance completeness in HR workspace' using errcode='23514';end if;
 perform private.hr_legacy_confirm_attendance_review(target_company_id,target_month,target_revision);
end;$$;
-- Read projections validate the same actor/profile/tenant/permission boundary at
-- the statement snapshot. Row locks belong to write commands, not STABLE RPCs.
create function private.hr_read_actor(cid uuid) returns uuid language plpgsql stable set search_path='' as $$
declare actor uuid:=auth.uid();begin
 if actor is null then raise exception 'Financial access denied' using errcode='42501';end if;
 perform 1 from public.companies where id=cid and status='ACTIVE';
 if not found then raise exception 'Company unavailable' using errcode='42501';end if;
 perform 1 from public.profiles where user_id=actor and status='ACTIVE';
 if not found then raise exception 'Profile unavailable' using errcode='42501';end if;
 perform 1 from public.company_memberships where company_id=cid and user_id=actor and status='ACTIVE' and role in ('ACCOUNTING_ADMIN','ACCOUNTANT');
 if not found or not public.has_permission(cid,'payroll.manage') then raise exception 'Financial permission denied' using errcode='42501';end if;
 return actor;
end;$$;
create function public.read_hr_workspace(cid uuid,m date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare actor uuid;r jsonb;begin
 actor:=private.hr_read_actor(cid);if m is null or extract(day from m)<>1 then raise exception 'Month required' using errcode='23514';end if;
 return jsonb_build_object('company_id',cid,'month',m,'today',(clock_timestamp() at time zone 'Asia/Dubai')::date,'policy',to_jsonb(private.hr_policy(cid,m)),
 'policies',(select coalesce(jsonb_agg(to_jsonb(t) order by version desc),'[]') from public.hr_policy_events t where company_id=cid),
 'terms',(select coalesce(jsonb_agg((to_jsonb(t)-'basic_minor')||jsonb_build_object('basic_minor',basic_minor::text) order by employee_id,version desc),'[]') from public.hr_term_events t where company_id=cid),
 'calendar',(select coalesce(jsonb_agg(to_jsonb(t) order by day,version desc),'[]') from public.hr_calendar_events t where company_id=cid and day>=m and day<m+interval '1 month'),
 'period',(select to_jsonb(p) from public.attendance_periods p where company_id=cid and month=m),'days',private.hr_days(cid,m),
 'setup',(select to_jsonb(s) from public.hr_payroll_setup_events s where company_id=cid order by version desc limit 1),
 'mappings',(select jsonb_object_agg(k,(select jsonb_build_object('id',id,'code',code,'name',name,'valid',account_type::text=case when k='SALARY_PAYABLE' then 'LIABILITY' else 'EXPENSE' end and status='ACTIVE') from public.accounts where company_id=cid and system_key=k::public.system_account_key)) from unnest(array['SALARY_PAYABLE','PROJECT_COST','COMPANY_EXPENSE']) k),
 'advances',(select coalesce(jsonb_agg((to_jsonb(t)-array['amount_minor','monthly_limit_minor'])||jsonb_build_object('amount_minor',amount_minor::text,'monthly_limit_minor',monthly_limit_minor::text,'remaining_minor',private.hr_recovery_balance(cid,id)::text)),'[]') from public.hr_advance_postings t where company_id=cid),
 'recoveries',(select coalesce(jsonb_agg((to_jsonb(t)-'amount_minor')||jsonb_build_object('amount_minor',amount_minor::text)),'[]') from public.hr_recovery_plans t where company_id=cid and month=m));
end;$$;
-- Explicit grants: copied legacy implementations and all new helpers remain private.
do $$declare fn record;begin for fn in select proc.oid::regprocedure signature from pg_proc proc join pg_namespace n on n.oid=proc.pronamespace where n.nspname='private' and proc.proname like 'hr_%' loop execute format('revoke all on function %s from public,anon,authenticated,service_role',fn.signature);end loop;end;$$;
revoke all on function public.command_hr(uuid,uuid,text,jsonb),public.read_hr_workspace(uuid,date) from public,anon,authenticated,service_role;
grant execute on function public.command_hr(uuid,uuid,text,jsonb),public.read_hr_workspace(uuid,date) to authenticated;
create function public.bulk_hr_attendance(cid uuid,request_id uuid,entries jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;r private.hr_command_receipts;x jsonb;out jsonb:='[]';begin
 actor:=private.operational_finance_actor(cid,'attendance.record');perform private.attendance_company_lock(cid);
 if request_id is null or jsonb_typeof(entries)<>'array' or jsonb_array_length(entries) not between 1 and 100 then raise exception 'Select between 1 and 100 attendance cells' using errcode='23514';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'bulk',entries)::text,'UTF8'),'sha256'),'hex');
 select * into r from private.hr_command_receipts where company_id=cid and hr_command_receipts.request_id=bulk_hr_attendance.request_id;
 if found then if r.hash<>h then raise exception 'Changed bulk request' using errcode='22023';end if;return r.result;end if;
 for x in select jsonb_array_elements(entries) loop out:=out||jsonb_build_array(public.command_hr(cid,gen_random_uuid(),'ATTENDANCE',x));end loop;
 insert into private.hr_command_receipts values(cid,request_id,h,out);return out;
end;$$;
revoke all on function public.bulk_hr_attendance(uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.bulk_hr_attendance(uuid,uuid,jsonb) to authenticated;
