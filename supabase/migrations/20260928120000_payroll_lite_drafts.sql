-- Payroll Lite Step 1: private calculation and DRAFT documents only. No accounting or attendance locks are posted.
insert into public.permissions(key,description) values ('payroll.manage','Manage private payroll profiles and calculation-only drafts');
insert into public.role_permissions(role,permission_key) values ('ACCOUNTING_ADMIN','payroll.manage'),('ACCOUNTANT','payroll.manage');

create table public.payroll_profiles (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 employee_id uuid not null, payroll_id text not null check(length(btrim(payroll_id)) between 1 and 80),
 payroll_type text not null check(length(btrim(payroll_type)) between 1 and 100),
 profession text not null check(length(btrim(profession)) between 1 and 200),
 work_station text not null check(length(btrim(work_station)) between 1 and 200), default_project_id uuid,
 monthly_salary_minor bigint not null check(monthly_salary_minor between 0 and 9000000000000000),
 payment_type text not null check(length(btrim(payment_type)) between 1 and 100), status public.account_status not null default 'ACTIVE',
 version integer not null default 1 check(version>0), created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_by uuid not null references auth.users(id) on delete restrict, updated_at timestamptz not null default now(),
 unique(company_id,employee_id), unique(company_id,id),
 foreign key(company_id,employee_id) references public.parties(company_id,id) on delete restrict,
 foreign key(company_id,default_project_id) references public.projects(company_id,id) on delete restrict
);
create unique index payroll_id_company_unique on public.payroll_profiles(company_id,lower(payroll_id));
create table public.payroll_draft_periods (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 month date not null check(extract(day from month)=1), calendar_days integer not null check(calendar_days between 28 and 31),
 state text not null default 'DRAFT' check(state='DRAFT'), version integer not null default 1 check(version>0),
 source_hash text not null, attendance_revision integer not null,
 adjustments_revision integer not null default 0 check(adjustments_revision>=0), calculated_adjustments_revision integer not null default 0,
 reviewed_version integer, reviewed_by uuid references auth.users(id) on delete restrict, reviewed_at timestamptz,
 created_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(),
 refreshed_by uuid not null references auth.users(id) on delete restrict, refreshed_at timestamptz not null default now(),
 unique(company_id,month), unique(company_id,id),
 check(calendar_days=extract(day from (month+interval '1 month - 1 day'))::integer)
);
create table public.payroll_draft_rows (
 id uuid primary key default gen_random_uuid(), company_id uuid not null, period_id uuid not null, employee_id uuid not null, included boolean not null default true,
 employee_name text not null, payroll_id text not null, payroll_type text not null, profession text not null, work_station text not null,
 default_project_id uuid, payment_type text not null, monthly_salary_minor bigint not null check(monthly_salary_minor between 0 and 9000000000000000),
 calendar_days integer not null check(calendar_days between 28 and 31), absence_half_units integer not null check(absence_half_units between 0 and 2*calendar_days),
 absence_deduction_minor bigint not null check(absence_deduction_minor between 0 and monthly_salary_minor),
 additions_minor bigint not null check(additions_minor between 0 and 9000000000000000), deductions_minor bigint not null check(deductions_minor between 0 and 9000000000000000),
 gross_salary_minor bigint not null check(gross_salary_minor between 0 and 9000000000000000),
 net_salary_minor bigint not null check(net_salary_minor between 0 and 9000000000000000),
 unique(company_id,period_id,employee_id), unique(company_id,id),
 foreign key(company_id,period_id) references public.payroll_draft_periods(company_id,id) on delete restrict,
 foreign key(company_id,employee_id) references public.payroll_profiles(company_id,employee_id) on delete restrict,
 foreign key(company_id,default_project_id) references public.projects(company_id,id) on delete restrict,
 check(gross_salary_minor=monthly_salary_minor-absence_deduction_minor),
 check(net_salary_minor::numeric=gross_salary_minor::numeric+additions_minor::numeric-deductions_minor::numeric),
 check(absence_deduction_minor=round(monthly_salary_minor::numeric*absence_half_units/(2*calendar_days))::bigint)
);
create table public.payroll_draft_adjustments (
 id uuid primary key, company_id uuid not null, row_id uuid not null,
 kind text not null check(kind in ('ADDITION','DEDUCTION')), amount_minor bigint not null check(amount_minor between 1 and 9000000000000000),
 reason text not null check(length(btrim(reason)) between 1 and 1000), voided boolean not null default false,
 version integer not null default 1 check(version>0), change_reason text check(length(btrim(change_reason)) between 1 and 1000),
 created_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(),
 updated_by uuid not null references auth.users(id) on delete restrict, updated_at timestamptz not null default now(),
 foreign key(company_id,row_id) references public.payroll_draft_rows(company_id,id) on delete restrict
);
create index payroll_adjustments_row on public.payroll_draft_adjustments(company_id,row_id);
create table public.payroll_draft_audit (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 entity text not null, entity_id uuid not null, actor_id uuid not null references auth.users(id) on delete restrict,
 occurred_at timestamptz not null default now(), before_row jsonb, after_row jsonb not null
);
create function private.payroll_draft_audit_change() returns trigger language plpgsql set search_path='' as $$
begin
 insert into public.payroll_draft_audit(company_id,entity,entity_id,actor_id,before_row,after_row)
 values(new.company_id,tg_table_name,new.id,auth.uid(),case when tg_op='UPDATE' then to_jsonb(old) else null end,to_jsonb(new));
 return new;
end $$;
create function private.payroll_draft_no_delete() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Payroll draft history cannot be deleted' using errcode='23514'; end $$;
create function private.payroll_profile_employee_guard() returns trigger language plpgsql set search_path='' as $$
begin
 if not exists(select 1 from public.parties where company_id=new.company_id and id=new.employee_id and type='EMPLOYEE') then
  raise exception 'Same-Company EMPLOYEE required' using errcode='23514'; end if;
 if tg_op='UPDATE' and (new.id,new.company_id,new.employee_id,new.created_by,new.created_at) is distinct from (old.id,old.company_id,old.employee_id,old.created_by,old.created_at) then
  raise exception 'Profile identity immutable' using errcode='23514'; end if;
 return new;
end $$;
create trigger payroll_profile_employee_guard before insert or update on public.payroll_profiles for each row execute function private.payroll_profile_employee_guard();

-- Exact, non-public calculation helper. Numeric intermediates prevent BIGINT multiplication/sum overflow.
create function private.calculate_payroll_draft(s bigint,d integer,u integer,a numeric,x numeric)
returns table(absence_deduction_minor bigint,gross_salary_minor bigint,net_salary_minor bigint) language plpgsql immutable set search_path='' as $$
declare deduction numeric; gross numeric; net numeric;
begin
 if s is null or d is null or u is null or a is null or x is null or s<0 or s>9000000000000000 or d not between 28 and 31 or u<0 or u>2*d
  or a<0 or x<0 or a<>trunc(a) or x<>trunc(x) or a>9000000000000000 or x>9000000000000000 then
  raise exception 'Payroll input outside exact supported bounds' using errcode='23514'; end if;
 deduction:=round(s::numeric*u/(2*d)); gross:=s::numeric-deduction; net:=gross+a-x;
 if net<0 or net>9000000000000000 then raise exception 'Negative net salary or payroll overflow' using errcode='23514'; end if;
 return query select deduction::bigint,gross::bigint,net::bigint;
end $$;

-- One coherent source snapshot. Profile versions/Party status/names + current reviewed attendance are hashed;
-- adjustments have their own period revision so several edits can be prepared before an explicit refresh.
create function private.payroll_draft_source(c uuid,m date) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object('attendance',(select to_jsonb(p) from public.attendance_periods p where company_id=c and month=m),
  'profiles',coalesce((select jsonb_agg((to_jsonb(p)-'monthly_salary_minor')||jsonb_build_object('monthly_salary_minor',p.monthly_salary_minor::text,
    'employee_name',e.name,'employee_status',e.status) order by p.employee_id)
    from public.payroll_profiles p join public.parties e on e.company_id=p.company_id and e.id=p.employee_id where p.company_id=c),'[]'::jsonb),
  'absences',coalesce((select jsonb_agg(jsonb_build_object('employee_id',employee_id,'units',units) order by employee_id) from
    (select employee_id,sum(case kind when 'HALF_DAY' then 1 else 2 end)::integer units from public.attendance_exceptions
     where company_id=c and absence_date>=m and absence_date<(m+interval '1 month')::date and not voided group by employee_id) q),'[]'::jsonb));
$$;
create function private.require_payroll_review(src jsonb) returns void language plpgsql immutable set search_path='' as $$
begin
 if src->'attendance' is null or src->'attendance'='null'::jsonb
  or src->'attendance'->>'reviewed_revision' is null
  or src->'attendance'->>'reviewed_revision' is distinct from src->'attendance'->>'revision' then
  raise exception 'Current monthly attendance review required' using errcode='23514'; end if;
end $$;

create function public.save_payroll_profile(target_company_id uuid,target_employee_id uuid,target_version integer,target_payroll_id text,
 target_payroll_type text,target_profession text,target_work_station text,target_project_id uuid,target_salary_minor bigint,target_payment_type text,target_status public.account_status)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.payroll_profiles; result_id uuid;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 if target_version is null or target_version<0 then raise exception 'Version required' using errcode='23514'; end if;
 perform private.attendance_company_lock(target_company_id);
 select * into p from public.payroll_profiles where company_id=target_company_id and employee_id=target_employee_id for update;
 if found then
  if p.version<>target_version then raise exception 'Profile changed; reload' using errcode='40001'; end if;
  update public.payroll_profiles set payroll_id=btrim(target_payroll_id),payroll_type=btrim(target_payroll_type),profession=btrim(target_profession),
   work_station=btrim(target_work_station),default_project_id=target_project_id,monthly_salary_minor=target_salary_minor,payment_type=btrim(target_payment_type),status=target_status,
   version=version+1,updated_by=auth.uid(),updated_at=clock_timestamp() where id=p.id returning id into result_id;
 else
  if target_version<>0 then raise exception 'Profile changed; reload' using errcode='40001'; end if;
  insert into public.payroll_profiles(company_id,employee_id,payroll_id,payroll_type,profession,work_station,default_project_id,monthly_salary_minor,payment_type,status,created_by,updated_by)
   values(target_company_id,target_employee_id,btrim(target_payroll_id),btrim(target_payroll_type),btrim(target_profession),btrim(target_work_station),target_project_id,target_salary_minor,btrim(target_payment_type),target_status,auth.uid(),auth.uid()) returning id into result_id;
 end if;
 return result_id;
end $$;

create function public.refresh_payroll_draft(target_company_id uuid,target_month date,target_version integer)
returns uuid language plpgsql security definer set search_path='' as $$
declare p public.payroll_draft_periods; src jsonb; profile jsonb; units integer; days integer; adds numeric; deducts numeric; calc record; existing_version integer;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 if target_month is null or extract(day from target_month)<>1 or target_version is null or target_version<0 then raise exception 'Month/version required' using errcode='23514'; end if;
 perform private.attendance_company_lock(target_company_id);
 src:=private.payroll_draft_source(target_company_id,target_month); perform private.require_payroll_review(src);
 days:=extract(day from target_month+interval '1 month - 1 day')::integer;
 select * into p from public.payroll_draft_periods where company_id=target_company_id and month=target_month for update;
 existing_version:=case when found then p.version else 0 end;
 if existing_version<>target_version then raise exception 'Draft changed; reload' using errcode='40001'; end if;
 if existing_version=0 then
  insert into public.payroll_draft_periods(company_id,month,calendar_days,source_hash,attendance_revision,created_by,refreshed_by)
   values(target_company_id,target_month,days,md5(src::text),(src->'attendance'->>'revision')::integer,auth.uid(),auth.uid()) returning * into p;
 end if;
 if exists(select 1 from public.payroll_draft_rows r join public.payroll_draft_adjustments a on a.row_id=r.id and a.company_id=r.company_id
  where r.period_id=p.id and not a.voided and not exists(select 1 from jsonb_array_elements(src->'profiles') v
   where (v->>'employee_id')::uuid=r.employee_id and v->>'status'='ACTIVE' and v->>'employee_status'='ACTIVE')) then
  raise exception 'Void adjustments for excluded employees before refresh' using errcode='23514'; end if;
 update public.payroll_draft_rows set included=false where period_id=p.id and included;
 for profile in select value from jsonb_array_elements(src->'profiles') where value->>'status'='ACTIVE' and value->>'employee_status'='ACTIVE' loop
  select coalesce((select (a->>'units')::integer from jsonb_array_elements(src->'absences') a where a->>'employee_id'=profile->>'employee_id'),0) into units;
  select coalesce(sum(a.amount_minor::numeric) filter(where a.kind='ADDITION'),0),coalesce(sum(a.amount_minor::numeric) filter(where a.kind='DEDUCTION'),0)
   into adds,deducts from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id and r.company_id=a.company_id
   where r.period_id=p.id and r.employee_id=(profile->>'employee_id')::uuid and not a.voided;
  select * into calc from private.calculate_payroll_draft((profile->>'monthly_salary_minor')::bigint,days,units,adds,deducts);
  insert into public.payroll_draft_rows(company_id,period_id,employee_id,employee_name,payroll_id,payroll_type,profession,work_station,default_project_id,payment_type,
   monthly_salary_minor,calendar_days,absence_half_units,absence_deduction_minor,additions_minor,deductions_minor,gross_salary_minor,net_salary_minor)
  values(target_company_id,p.id,(profile->>'employee_id')::uuid,profile->>'employee_name',profile->>'payroll_id',profile->>'payroll_type',profile->>'profession',profile->>'work_station',
   (profile->>'default_project_id')::uuid,profile->>'payment_type',(profile->>'monthly_salary_minor')::bigint,days,units,calc.absence_deduction_minor,adds::bigint,deducts::bigint,calc.gross_salary_minor,calc.net_salary_minor)
  on conflict(company_id,period_id,employee_id) do update set included=true,employee_name=excluded.employee_name,payroll_id=excluded.payroll_id,payroll_type=excluded.payroll_type,
   profession=excluded.profession,work_station=excluded.work_station,default_project_id=excluded.default_project_id,payment_type=excluded.payment_type,
   monthly_salary_minor=excluded.monthly_salary_minor,calendar_days=excluded.calendar_days,absence_half_units=excluded.absence_half_units,
   absence_deduction_minor=excluded.absence_deduction_minor,additions_minor=excluded.additions_minor,deductions_minor=excluded.deductions_minor,gross_salary_minor=excluded.gross_salary_minor,net_salary_minor=excluded.net_salary_minor;
 end loop;
 update public.payroll_draft_periods set version=case when existing_version=0 then 1 else version+1 end,source_hash=md5(src::text),attendance_revision=(src->'attendance'->>'revision')::integer,
  calculated_adjustments_revision=adjustments_revision,reviewed_version=null,reviewed_by=null,reviewed_at=null,refreshed_by=auth.uid(),refreshed_at=clock_timestamp() where id=p.id;
 return p.id;
end $$;

create function public.save_payroll_draft_adjustment(target_company_id uuid,target_row_id uuid,target_id uuid,target_version integer,
 target_kind text,target_amount_minor bigint,target_reason text,target_void boolean,target_change_reason text)
returns uuid language plpgsql security definer set search_path='' as $$
declare r public.payroll_draft_rows; p public.payroll_draft_periods; old public.payroll_draft_adjustments; src jsonb; adds numeric; deducts numeric;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 if target_id is null or target_version is null or target_version<0 or target_void is null or target_kind is null or target_kind not in ('ADDITION','DEDUCTION')
  or target_amount_minor is null or target_amount_minor<1 or target_amount_minor>9000000000000000 or nullif(btrim(target_reason),'') is null then
  raise exception 'Invalid adjustment' using errcode='23514'; end if;
 perform private.attendance_company_lock(target_company_id);
 select * into r from public.payroll_draft_rows where company_id=target_company_id and id=target_row_id for update;
 if not found then raise exception 'Payroll row unavailable' using errcode='42501'; end if;
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=r.period_id for update;
 if not target_void then
  src:=private.payroll_draft_source(target_company_id,p.month); perform private.require_payroll_review(src);
  if not r.included or p.source_hash<>md5(src::text) then raise exception 'Draft inputs changed; refresh before adjustments' using errcode='40001'; end if;
 end if;
 select * into old from public.payroll_draft_adjustments where id=target_id for update;
 if found then
  if old.company_id<>target_company_id or old.row_id<>target_row_id then raise exception 'Adjustment scope denied' using errcode='42501'; end if;
  if old.version<>target_version then raise exception 'Adjustment changed; reload' using errcode='40001'; end if;
  if nullif(btrim(target_change_reason),'') is null then raise exception 'Change reason required' using errcode='23514'; end if;
 else
  if target_version<>0 or target_void then raise exception 'Adjustment changed; reload' using errcode='40001'; end if;
 end if;
 select coalesce(sum(amount_minor::numeric) filter(where kind='ADDITION'),0),coalesce(sum(amount_minor::numeric) filter(where kind='DEDUCTION'),0)
 into adds,deducts from public.payroll_draft_adjustments where company_id=target_company_id and row_id=r.id and id<>target_id and not voided;
 if not target_void then if target_kind='ADDITION' then adds:=adds+target_amount_minor; else deducts:=deducts+target_amount_minor; end if; end if;
 perform private.calculate_payroll_draft(r.monthly_salary_minor,r.calendar_days,r.absence_half_units,adds,deducts);
 if old.id is null then
  insert into public.payroll_draft_adjustments(id,company_id,row_id,kind,amount_minor,reason,created_by,updated_by)
   values(target_id,target_company_id,r.id,target_kind,target_amount_minor,btrim(target_reason),auth.uid(),auth.uid());
 else
  update public.payroll_draft_adjustments set kind=target_kind,amount_minor=target_amount_minor,reason=btrim(target_reason),voided=target_void,
   version=version+1,change_reason=btrim(target_change_reason),updated_by=auth.uid(),updated_at=clock_timestamp() where id=target_id;
 end if;
 update public.payroll_draft_periods set version=version+1,adjustments_revision=adjustments_revision+1,reviewed_version=null,reviewed_by=null,reviewed_at=null where id=p.id;
 return target_id;
end $$;

create function public.review_payroll_draft(target_company_id uuid,target_period_id uuid,target_version integer) returns void
language plpgsql security definer set search_path='' as $$
declare p public.payroll_draft_periods; src jsonb;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 select * into p from public.payroll_draft_periods where company_id=target_company_id and id=target_period_id for update;
 if not found or target_version is null or target_version<>p.version then raise exception 'Draft changed; reload' using errcode='40001'; end if;
 src:=private.payroll_draft_source(target_company_id,p.month); perform private.require_payroll_review(src);
 if p.source_hash<>md5(src::text) or p.adjustments_revision<>p.calculated_adjustments_revision then raise exception 'Draft stale; refresh' using errcode='40001'; end if;
 update public.payroll_draft_periods set reviewed_version=version,reviewed_by=auth.uid(),reviewed_at=clock_timestamp() where id=p.id;
end $$;

-- All salary-bearing JSON projections explicitly stringify BIGINT values before PostgREST serialization.
create function public.read_payroll_profiles(target_company_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 return jsonb_build_object('profiles',coalesce((select jsonb_agg((to_jsonb(p)-'monthly_salary_minor')||jsonb_build_object('monthly_salary_minor',p.monthly_salary_minor::text,'employee_name',e.name,'employee_status',e.status) order by p.payroll_id,p.id)
  from public.payroll_profiles p join public.parties e on e.company_id=p.company_id and e.id=p.employee_id where p.company_id=target_company_id),'[]'::jsonb),
  'employees',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.parties where company_id=target_company_id and type='EMPLOYEE'),'[]'::jsonb),
  'projects',coalesce((select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.projects where company_id=target_company_id),'[]'::jsonb));
end $$;
create function public.read_payroll_draft(target_company_id uuid,target_month date) returns jsonb language plpgsql stable security definer set search_path='' as $$
declare p public.payroll_draft_periods; src jsonb; review_valid boolean; stale boolean;
begin
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Payroll denied' using errcode='42501'; end if;
 if target_month is null or extract(day from target_month)<>1 then raise exception 'First day of month required' using errcode='23514'; end if;
 src:=private.payroll_draft_source(target_company_id,target_month);
 review_valid:=coalesce(src->'attendance'->>'reviewed_revision'=src->'attendance'->>'revision',false);
 select * into p from public.payroll_draft_periods where company_id=target_company_id and month=target_month;
 stale:=p.id is not null and (not review_valid or p.source_hash<>md5(src::text) or p.adjustments_revision<>p.calculated_adjustments_revision);
 return jsonb_build_object('attendance_review_valid',review_valid,'stale',stale,
  'review_valid',p.id is not null and not stale and coalesce(p.reviewed_version=p.version,false),'period',case when p.id is null then null else to_jsonb(p) end,
  'rows',coalesce((select jsonb_agg((to_jsonb(r)-array['monthly_salary_minor','absence_deduction_minor','additions_minor','deductions_minor','gross_salary_minor','net_salary_minor'])||
   jsonb_build_object('monthly_salary_minor',r.monthly_salary_minor::text,'absence_deduction_minor',r.absence_deduction_minor::text,'additions_minor',r.additions_minor::text,
    'deductions_minor',r.deductions_minor::text,'gross_salary_minor',r.gross_salary_minor::text,'net_salary_minor',r.net_salary_minor::text) order by r.payroll_id,r.id)
   from public.payroll_draft_rows r where r.period_id=p.id and r.company_id=target_company_id),'[]'::jsonb),
  'adjustments',coalesce((select jsonb_agg((to_jsonb(a)-'amount_minor')||jsonb_build_object('amount_minor',a.amount_minor::text) order by a.created_at,a.id)
   from public.payroll_draft_adjustments a join public.payroll_draft_rows r on r.id=a.row_id and r.company_id=a.company_id where r.period_id=p.id and a.company_id=target_company_id),'[]'::jsonb));
end $$;

-- Uniform least privilege; mutations and audit are server-owned, no generic browser DML.
do $$ declare t text; begin
 foreach t in array array['payroll_profiles','payroll_draft_periods','payroll_draft_rows','payroll_draft_adjustments','payroll_draft_audit'] loop
  execute format('alter table public.%I enable row level security',t); execute format('alter table public.%I force row level security',t);
  execute format('create policy payroll_staff_read on public.%I for select to authenticated using(public.has_permission(company_id,''payroll.manage''))',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('grant select on public.%I to authenticated,service_role',t);
  execute format('create trigger payroll_no_delete before delete on public.%I for each row execute function private.payroll_draft_no_delete()',t);
  if t='payroll_draft_audit' then execute format('create trigger payroll_audit_immutable before update on public.%I for each row execute function private.payroll_draft_no_delete()',t);
  else execute format('create trigger payroll_audit after insert or update on public.%I for each row execute function private.payroll_draft_audit_change()',t); end if;
 end loop;
end $$;
revoke all on function private.payroll_draft_audit_change(),private.payroll_draft_no_delete(),private.payroll_profile_employee_guard(),
 private.calculate_payroll_draft(bigint,integer,integer,numeric,numeric),private.payroll_draft_source(uuid,date),private.require_payroll_review(jsonb) from public,anon,authenticated,service_role;
revoke all on function public.save_payroll_profile(uuid,uuid,integer,text,text,text,text,uuid,bigint,text,public.account_status),
 public.refresh_payroll_draft(uuid,date,integer),public.save_payroll_draft_adjustment(uuid,uuid,uuid,integer,text,bigint,text,boolean,text),
 public.review_payroll_draft(uuid,uuid,integer),public.read_payroll_profiles(uuid),public.read_payroll_draft(uuid,date) from public,anon,authenticated,service_role;
grant execute on function public.save_payroll_profile(uuid,uuid,integer,text,text,text,text,uuid,bigint,text,public.account_status),
 public.refresh_payroll_draft(uuid,date,integer),public.save_payroll_draft_adjustment(uuid,uuid,uuid,integer,text,bigint,text,boolean,text),
 public.review_payroll_draft(uuid,uuid,integer),public.read_payroll_profiles(uuid),public.read_payroll_draft(uuid,date) to authenticated;
