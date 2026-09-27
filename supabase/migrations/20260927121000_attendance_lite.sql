-- Attendance Lite. No journals, money, payroll profile or browser month-lock command.
insert into public.permissions(key, description) values
 ('attendance.record','Read assigned attendance roster and record absence exceptions'),
 ('attendance.review','Read and confirm Company attendance for payroll preparation'),
 ('attendance.manage','Manage employee site assignments and correct attendance');
insert into public.role_permissions(role,permission_key) values
 ('FOREMAN','attendance.record'),
 ('ACCOUNTING_ADMIN','attendance.record'),('ACCOUNTING_ADMIN','attendance.review'),('ACCOUNTING_ADMIN','attendance.manage'),
 ('ACCOUNTANT','attendance.review');

create table public.employee_site_assignments (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 employee_id uuid not null, project_id uuid not null, starts_on date not null, ends_on date,
 version integer not null default 1 check(version > 0), created_by uuid not null references auth.users(id) on delete restrict,
 created_at timestamptz not null default now(), updated_by uuid not null references auth.users(id) on delete restrict,
 updated_at timestamptz not null default now(),
 check(ends_on is null or ends_on >= starts_on),
 foreign key(company_id,employee_id) references public.parties(company_id,id) on delete restrict,
 foreign key(company_id,project_id) references public.projects(company_id,id) on delete restrict,
 unique(company_id,id)
);
create index employee_site_assignments_employee on public.employee_site_assignments(company_id,employee_id,starts_on);
create table public.attendance_periods (
 company_id uuid not null references public.companies(id) on delete restrict, month date not null check(extract(day from month)=1),
 revision integer not null default 0 check(revision>=0), reviewed_revision integer, reviewed_by uuid references auth.users(id) on delete restrict,
 reviewed_at timestamptz, locked_at timestamptz,
 primary key(company_id,month),
 check ((reviewed_revision is null and reviewed_by is null and reviewed_at is null) or
        (reviewed_revision = revision and reviewed_by is not null and reviewed_at is not null)),
 check(locked_at is null or reviewed_revision is not null)
);
create table public.attendance_exceptions (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 employee_id uuid not null, project_id uuid not null, absence_date date not null,
 kind text not null check(kind in ('HALF_DAY','FULL_DAY')), note text check(length(note)<=1000),
 voided boolean not null default false, version integer not null default 1 check(version>0),
 created_by uuid not null references auth.users(id) on delete restrict, created_at timestamptz not null default now(),
 updated_by uuid not null references auth.users(id) on delete restrict, updated_at timestamptz not null default now(),
 correction_reason text check(length(correction_reason) between 1 and 1000),
 unique(company_id,employee_id,absence_date),
 foreign key(company_id,employee_id) references public.parties(company_id,id) on delete restrict,
 foreign key(company_id,project_id) references public.projects(company_id,id) on delete restrict
);
create index attendance_exceptions_month on public.attendance_exceptions(company_id,absence_date,project_id);
create table public.attendance_audit (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 entity text not null, entity_id text not null, actor_id uuid not null references auth.users(id) on delete restrict,
 occurred_at timestamptz not null default now(), before_row jsonb, after_row jsonb not null
);

-- One deterministic lock order for assignment, exception, review and future payroll lock.
create function private.attendance_company_lock(target_company_id uuid) returns void language sql
set search_path='' as $$ select pg_catalog.pg_advisory_xact_lock(pg_catalog.hashtextextended('attendance:'||target_company_id::text,0)); $$;
create function private.attendance_staff(target_company_id uuid) returns boolean language sql stable
set search_path='' as $$ select public.has_permission(target_company_id,'attendance.review'); $$;
create function private.attendance_scope(target_company_id uuid,target_project_id uuid) returns boolean language sql stable
set search_path='' as $$ select public.has_permission(target_company_id,'attendance.record') and
 (public.has_permission(target_company_id,'attendance.manage') or public.has_active_project_assignment(target_company_id,target_project_id)); $$;

-- Assignment invariants also protect trusted direct writes and concurrent inserts.
create function private.validate_employee_site_assignment() returns trigger language plpgsql set search_path='' as $$
begin
 perform private.attendance_company_lock(new.company_id);
 if not exists(select 1 from public.parties where id=new.employee_id and company_id=new.company_id and type='EMPLOYEE') then
  raise exception 'Employee required' using errcode='23514'; end if;
 if tg_op='UPDATE' and (new.id,new.company_id,new.employee_id,new.project_id,new.starts_on,new.created_by,new.created_at)
  is distinct from (old.id,old.company_id,old.employee_id,old.project_id,old.starts_on,old.created_by,old.created_at) then
  raise exception 'Assignment identity is immutable' using errcode='23514'; end if;
 if exists(select 1 from public.employee_site_assignments a where a.company_id=new.company_id and a.employee_id=new.employee_id and a.id<>new.id
  and daterange(a.starts_on,a.ends_on,'[]') && daterange(new.starts_on,new.ends_on,'[]')) then
  raise exception 'Employee already assigned for these dates' using errcode='23514'; end if;
 if tg_op='INSERT' and exists(select 1 from public.attendance_periods p where p.company_id=new.company_id and p.locked_at is not null
  and daterange(p.month,(p.month+interval '1 month')::date,'[)') && daterange(new.starts_on,new.ends_on,'[]')) then
  raise exception 'Attendance month locked' using errcode='23514'; end if;
 if tg_op='UPDATE' then
  if new.ends_on is distinct from old.ends_on then
   if exists(select 1 from public.attendance_periods p where p.company_id=new.company_id and p.locked_at is not null
    and daterange(p.month,(p.month+interval '1 month')::date,'[)') &&
     daterange(least(coalesce(old.ends_on,'infinity'::date),coalesce(new.ends_on,'infinity'::date))+1,
               greatest(coalesce(old.ends_on,'infinity'::date),coalesce(new.ends_on,'infinity'::date)),'[]')) then
    raise exception 'Attendance month locked' using errcode='23514'; end if;
  end if;
  if exists(select 1 from public.attendance_exceptions e where e.company_id=old.company_id and e.employee_id=old.employee_id
    and e.project_id=old.project_id and e.absence_date between old.starts_on and coalesce(old.ends_on,'infinity'::date)
    and not (e.absence_date between new.starts_on and coalesce(new.ends_on,'infinity'::date))) then
   raise exception 'Assignment cannot strand attendance history' using errcode='23514'; end if;
 end if;
 return new;
end $$;
create trigger employee_site_assignment_guard before insert or update on public.employee_site_assignments
 for each row execute function private.validate_employee_site_assignment();

create function private.attendance_audit_change() returns trigger language plpgsql set search_path='' as $$
begin
 insert into public.attendance_audit(company_id,entity,entity_id,actor_id,before_row,after_row)
 values(new.company_id,tg_table_name,coalesce(to_jsonb(new)->>'id',to_jsonb(new)->>'month'),auth.uid(),
 case when tg_op='UPDATE' then to_jsonb(old) else null end,to_jsonb(new));
 return new;
end $$;
create trigger attendance_exception_audit after insert or update on public.attendance_exceptions for each row execute function private.attendance_audit_change();
create trigger employee_site_assignment_audit after insert or update on public.employee_site_assignments for each row execute function private.attendance_audit_change();
create trigger attendance_period_audit after insert or update on public.attendance_periods for each row execute function private.attendance_audit_change();
create function private.attendance_no_delete() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Attendance history is immutable; use correction or void' using errcode='23514'; end $$;
create trigger attendance_no_delete before delete on public.attendance_exceptions for each row execute function private.attendance_no_delete();
create trigger assignment_no_delete before delete on public.employee_site_assignments for each row execute function private.attendance_no_delete();
create trigger period_no_delete before delete on public.attendance_periods for each row execute function private.attendance_no_delete();
create trigger attendance_audit_immutable before update or delete on public.attendance_audit for each row execute function private.attendance_no_delete();

create function public.save_employee_site_assignment(target_company_id uuid,target_employee_id uuid,target_project_id uuid,
 target_starts_on date,target_ends_on date,target_assignment_id uuid default null,target_version integer default 0,target_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare result_id uuid; old_row public.employee_site_assignments;
begin
 if not public.has_permission(target_company_id,'attendance.manage') then raise exception 'Attendance administration denied' using errcode='42501'; end if;
 perform private.attendance_company_lock(target_company_id);
 if target_assignment_id is null then
  if not exists(select 1 from public.parties where company_id=target_company_id and id=target_employee_id and type='EMPLOYEE' and status='ACTIVE')
   or not exists(select 1 from public.projects where company_id=target_company_id and id=target_project_id and status<>'CLOSED') then
   raise exception 'Eligible employee and project required' using errcode='23514'; end if;
  insert into public.employee_site_assignments(company_id,employee_id,project_id,starts_on,ends_on,created_by,updated_by)
   values(target_company_id,target_employee_id,target_project_id,target_starts_on,target_ends_on,auth.uid(),auth.uid()) returning id into result_id;
 else
  if nullif(btrim(target_reason),'') is null or length(target_reason)>1000 then raise exception 'Correction reason required' using errcode='23514'; end if;
  select * into old_row from public.employee_site_assignments where company_id=target_company_id and id=target_assignment_id for update;
  if not found or old_row.version<>target_version then raise exception 'Assignment changed; refresh' using errcode='40001'; end if;
  if (old_row.employee_id,old_row.project_id,old_row.starts_on) is distinct from (target_employee_id,target_project_id,target_starts_on) then
   raise exception 'Only assignment end date may change' using errcode='23514'; end if;
  update public.employee_site_assignments set ends_on=target_ends_on,version=version+1,updated_by=auth.uid(),updated_at=clock_timestamp()
   where id=target_assignment_id returning id into result_id;
  insert into public.attendance_audit(company_id,entity,entity_id,actor_id,after_row)
   values(target_company_id,'assignment_correction_reason',result_id::text,auth.uid(),jsonb_build_object('reason',btrim(target_reason)));
 end if;
 update public.attendance_periods set revision=revision+1,reviewed_revision=null,reviewed_at=null,reviewed_by=null
 where company_id=target_company_id and locked_at is null
  and (month+interval '1 month')::date>target_starts_on
  and month<=greatest(coalesce(target_ends_on,'infinity'::date),coalesce(old_row.ends_on,'infinity'::date));
 return result_id;
end $$;

create function public.save_attendance_exception(target_company_id uuid,target_project_id uuid,target_employee_id uuid,target_date date,
 target_kind text,target_note text,target_version integer,target_void boolean default false,target_reason text default null)
returns uuid language plpgsql security definer set search_path='' as $$
declare existing public.attendance_exceptions; period_row public.attendance_periods; result_id uuid;
begin
 if not private.attendance_scope(target_company_id,target_project_id) then raise exception 'Attendance scope denied' using errcode='42501'; end if;
 if target_date is null or target_date>(current_timestamp at time zone 'UTC')::date then raise exception 'Future or missing date' using errcode='23514'; end if;
 if target_kind is null or target_kind not in ('HALF_DAY','FULL_DAY') or target_version is null or target_version<0 or target_void is null then
  raise exception 'Invalid attendance input' using errcode='23514'; end if;
 perform private.attendance_company_lock(target_company_id);
 if not exists(select 1 from public.employee_site_assignments a where a.company_id=target_company_id and a.employee_id=target_employee_id
  and a.project_id=target_project_id and target_date between a.starts_on and coalesce(a.ends_on,'infinity'::date)) then
  raise exception 'Employee not assigned on date' using errcode='23514'; end if;
 insert into public.attendance_periods(company_id,month) values(target_company_id,date_trunc('month',target_date)::date) on conflict do nothing;
 select * into period_row from public.attendance_periods where company_id=target_company_id and month=date_trunc('month',target_date)::date for update;
 if period_row.locked_at is not null then raise exception 'Attendance month locked' using errcode='23514'; end if;
 select * into existing from public.attendance_exceptions where company_id=target_company_id and employee_id=target_employee_id and absence_date=target_date for update;
 if found then
  if existing.project_id<>target_project_id or (existing.created_by<>auth.uid() and not public.has_permission(target_company_id,'attendance.manage')) then
   raise exception 'Only recorder or Accounting Admin can correct' using errcode='42501'; end if;
  if existing.version<>target_version then raise exception 'Attendance changed; refresh' using errcode='40001'; end if;
  if nullif(btrim(target_reason),'') is null then raise exception 'Correction reason required' using errcode='23514'; end if;
  update public.attendance_exceptions set kind=target_kind,note=nullif(btrim(target_note),''),voided=target_void,
   version=version+1,updated_by=auth.uid(),updated_at=clock_timestamp(),correction_reason=btrim(target_reason)
   where id=existing.id returning id into result_id;
 else
  if target_version<>0 or target_void then raise exception 'Attendance changed; refresh' using errcode='40001'; end if;
  insert into public.attendance_exceptions(company_id,employee_id,project_id,absence_date,kind,note,created_by,updated_by)
   values(target_company_id,target_employee_id,target_project_id,target_date,target_kind,nullif(btrim(target_note),''),auth.uid(),auth.uid()) returning id into result_id;
 end if;
 update public.attendance_periods set revision=revision+1,reviewed_revision=null,reviewed_by=null,reviewed_at=null
  where company_id=target_company_id and month=period_row.month;
 return result_id;
end $$;

create function public.confirm_attendance_review(target_company_id uuid,target_month date,target_revision integer)
returns void language plpgsql security definer set search_path='' as $$
declare p public.attendance_periods;
begin
 if not private.attendance_staff(target_company_id) then raise exception 'Attendance review denied' using errcode='42501'; end if;
 if target_month is null or extract(day from target_month)<>1 or target_month>date_trunc('month',(current_timestamp at time zone 'UTC'))::date then
  raise exception 'Invalid month' using errcode='23514'; end if;
 perform private.attendance_company_lock(target_company_id);
 insert into public.attendance_periods(company_id,month) values(target_company_id,target_month) on conflict do nothing;
 select * into p from public.attendance_periods where company_id=target_company_id and month=target_month for update;
 if p.locked_at is not null or target_revision is null or p.revision<>target_revision then raise exception 'Month locked or review stale' using errcode='40001'; end if;
 update public.attendance_periods set reviewed_revision=revision,reviewed_by=auth.uid(),reviewed_at=clock_timestamp()
  where company_id=target_company_id and month=target_month;
end $$;

-- Future payroll POST must call this in its own atomic transaction. Never browser-executable.
create function private.lock_attendance_month(target_company_id uuid,target_month date,target_revision integer)
returns void language plpgsql set search_path='' as $$
begin
 perform private.attendance_company_lock(target_company_id);
 update public.attendance_periods set locked_at=clock_timestamp() where company_id=target_company_id and month=target_month
  and revision=target_revision and reviewed_revision=revision and locked_at is null;
 if not found then raise exception 'Reviewed open attendance month required' using errcode='23514'; end if;
end $$;

-- Safe projections: no Party contact, payroll profile, money, or financial joins.
create function public.attendance_context(target_company_id uuid) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not (private.attendance_staff(target_company_id) or public.has_permission(target_company_id,'attendance.record')) then
  raise exception 'Attendance access denied' using errcode='42501'; end if;
 return jsonb_build_object('today',(current_timestamp at time zone 'UTC')::date,'projects',coalesce((
  select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name) order by p.name,p.id) from public.projects p
  where p.company_id=target_company_id and (private.attendance_staff(target_company_id) or private.attendance_scope(target_company_id,p.id))),'[]'::jsonb),
  'employees',case when public.has_permission(target_company_id,'attendance.manage') then coalesce((
   select jsonb_agg(jsonb_build_object('id',id,'name',name) order by name,id) from public.parties where company_id=target_company_id and type='EMPLOYEE' and status='ACTIVE'),'[]'::jsonb) else '[]'::jsonb end);
end $$;
create function public.attendance_day(target_company_id uuid,target_project_id uuid,target_date date) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not (private.attendance_staff(target_company_id) or private.attendance_scope(target_company_id,target_project_id)) then
  raise exception 'Attendance scope denied' using errcode='42501'; end if;
 return jsonb_build_object('locked',exists(select 1 from public.attendance_periods where company_id=target_company_id and month=date_trunc('month',target_date)::date and locked_at is not null),
 'rows',coalesce((select jsonb_agg(jsonb_build_object('employee_id',a.employee_id,'employee_name',e.name,'entry',to_jsonb(x)) order by e.name,a.employee_id)
 from public.employee_site_assignments a join public.parties e on e.company_id=a.company_id and e.id=a.employee_id
 left join public.attendance_exceptions x on x.company_id=a.company_id and x.employee_id=a.employee_id and x.absence_date=target_date
 where a.company_id=target_company_id and a.project_id=target_project_id and target_date between a.starts_on and coalesce(a.ends_on,'infinity'::date)),'[]'::jsonb));
end $$;
create function public.attendance_month(target_company_id uuid,target_month date) returns jsonb language plpgsql stable security definer set search_path='' as $$
begin
 if not private.attendance_staff(target_company_id) then raise exception 'Attendance review denied' using errcode='42501'; end if;
 if target_month is null or extract(day from target_month)<>1 then raise exception 'First day of month required' using errcode='23514'; end if;
 return jsonb_build_object('period',coalesce((select to_jsonb(p) from public.attendance_periods p where company_id=target_company_id and month=target_month),
 jsonb_build_object('revision',0,'reviewed_revision',null,'locked_at',null)),
 'assignments',coalesce((select jsonb_agg(to_jsonb(a)||jsonb_build_object('employee_name',e.name,'project_name',p.name) order by e.name,a.starts_on,a.id)
 from public.employee_site_assignments a join public.parties e on e.company_id=a.company_id and e.id=a.employee_id
 join public.projects p on p.company_id=a.company_id and p.id=a.project_id where a.company_id=target_company_id
 and a.starts_on<(target_month+interval '1 month')::date and coalesce(a.ends_on,'infinity'::date)>=target_month),'[]'::jsonb),
 'exceptions',coalesce((select jsonb_agg(to_jsonb(x)||jsonb_build_object('employee_name',e.name,'project_name',p.name) order by x.absence_date,e.name,x.id)
 from public.attendance_exceptions x join public.parties e on e.company_id=x.company_id and e.id=x.employee_id
 join public.projects p on p.company_id=x.company_id and p.id=x.project_id where x.company_id=target_company_id
 and x.absence_date>=target_month and x.absence_date<(target_month+interval '1 month')::date),'[]'::jsonb));
end $$;

alter table public.employee_site_assignments enable row level security;
alter table public.employee_site_assignments force row level security;
alter table public.attendance_exceptions enable row level security;
alter table public.attendance_exceptions force row level security;
alter table public.attendance_periods enable row level security;
alter table public.attendance_periods force row level security;
alter table public.attendance_audit enable row level security;
alter table public.attendance_audit force row level security;
-- Staff raw reads only. Foreman uses scoped projections, with no broad Party grant.
create policy attendance_assignment_staff on public.employee_site_assignments for select to authenticated using(public.has_permission(company_id,'attendance.review'));
create policy attendance_exception_staff on public.attendance_exceptions for select to authenticated using(public.has_permission(company_id,'attendance.review'));
create policy attendance_period_staff on public.attendance_periods for select to authenticated using(public.has_permission(company_id,'attendance.review'));
create policy attendance_audit_staff on public.attendance_audit for select to authenticated using(public.has_permission(company_id,'attendance.review'));
revoke all on public.employee_site_assignments,public.attendance_exceptions,public.attendance_periods,public.attendance_audit from public,anon,authenticated,service_role;
grant select on public.employee_site_assignments,public.attendance_exceptions,public.attendance_periods,public.attendance_audit to authenticated,service_role;

-- Explicit signatures and grants: no generic/private command exposed.
revoke all on function private.attendance_company_lock(uuid),private.attendance_staff(uuid),private.attendance_scope(uuid,uuid),
 private.validate_employee_site_assignment(),private.attendance_audit_change(),private.attendance_no_delete(),private.lock_attendance_month(uuid,date,integer)
 from public,anon,authenticated,service_role;
revoke all on function public.save_employee_site_assignment(uuid,uuid,uuid,date,date,uuid,integer,text),
 public.save_attendance_exception(uuid,uuid,uuid,date,text,text,integer,boolean,text),public.confirm_attendance_review(uuid,date,integer),
 public.attendance_context(uuid),public.attendance_day(uuid,uuid,date),public.attendance_month(uuid,date) from public,anon,authenticated,service_role;
grant execute on function public.save_employee_site_assignment(uuid,uuid,uuid,date,date,uuid,integer,text),
 public.save_attendance_exception(uuid,uuid,uuid,date,text,text,integer,boolean,text),public.confirm_attendance_review(uuid,date,integer),
 public.attendance_context(uuid),public.attendance_day(uuid,uuid,date),public.attendance_month(uuid,date) to authenticated;
