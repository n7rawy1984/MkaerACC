-- 84: Employee master metadata; existing Party, dated terms and payroll remain authoritative.
create table public.employee_master_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,employee_id uuid not null,
 request_id uuid,request_hash text,actor_id uuid references auth.users(id),
 reason text not null,before_data jsonb,after_data jsonb not null,created_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id),foreign key(company_id,employee_id)references public.parties(company_id,id)
);
alter table public.employee_master_events enable row level security;
alter table public.employee_master_events force row level security;
revoke all on public.employee_master_events from public,anon,authenticated,service_role;
grant select on public.employee_master_events to authenticated;
create policy employee_audit_read on public.employee_master_events for select to authenticated using(public.has_permission(company_id,'payroll.manage'));
create trigger employee_events_immutable before update or delete on public.employee_master_events for each row execute function private.financial_evidence_immutable();
create function public.command_employee_master(cid uuid,request_id uuid,employee uuid,expected_updated_at timestamptz,input jsonb,reason text)
returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;saved public.employee_master_events;p public.parties;before_row jsonb;v jsonb:=input;k text;pid uuid;latest public.hr_term_events;
begin
 actor:=private.operational_finance_actor(cid,'party.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin required' using errcode='42501';end if;
 perform private.attendance_company_lock(cid);
 if request_id is null or v is null or jsonb_typeof(v)<>'object' or octet_length(v::text)>12000 or coalesce(length(private.correction_text(reason)),0)not between 1 and 1000 then raise exception 'Employee inputs and change reason required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
  if k<>all(array['name','code','phone','email','address','notes','status','distinct_employee'])or jsonb_typeof(v->k)not in('string','boolean','null')then raise exception 'Unsupported employee field'using errcode='22023';end if;
  if k<>'distinct_employee'then
   if jsonb_typeof(v->k)not in('string','null')or coalesce(length(v->>k),0)>(case when k in('notes','address')then 2000 when k='code'then 50 else 200 end)then raise exception 'Invalid employee field'using errcode='22023';end if;
   v:=jsonb_set(v,array[k],coalesce(to_jsonb(private.correction_text(v->>k)),'null'::jsonb));
  end if;
 end loop;
 if v->>'name'is null or v->>'status'is null or v->>'status'not in('ACTIVE','INACTIVE')then raise exception 'Name and master status required'using errcode='23514';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'employee',employee,'expected',expected_updated_at,'input',v,'reason',private.correction_text(reason))::text,'UTF8'),'sha256'),'hex');
 select * into saved from public.employee_master_events e where e.company_id=cid and e.request_id=command_employee_master.request_id;
 if found then if saved.request_hash<>h then raise exception 'Changed employee request'using errcode='22023';end if;return saved.after_data;end if;
 if employee is not null then
  select * into p from public.parties where company_id=cid and id=employee for update;
  if not found or not private.party_has_person_role(cid,p.id,'EMPLOYEE')then raise exception 'Company Employee required'using errcode='42501';end if;
  if p.updated_at is distinct from expected_updated_at then raise exception 'Employee changed; reload'using errcode='40001';end if;
  before_row:=to_jsonb(p);pid:=p.id;v:=jsonb_build_object('code',p.code,'phone',p.phone,'email',p.email,'address',p.address,'notes',p.notes)||v;
  if p.status='ACTIVE'and v->>'status'='INACTIVE'then
   select * into latest from public.hr_term_events where company_id=cid and employee_id=pid order by version desc limit 1;
   if latest.id is not null and(latest.status<>'ENDED'or latest.effective_on>(now()at time zone'Asia/Dubai')::date)then raise exception 'End effective employment terms before deactivating this master'using errcode='23514';end if;
   if latest.id is null and exists(select 1 from public.payroll_profiles where company_id=cid and employee_id=pid and status='ACTIVE')then raise exception 'Deactivate the payroll profile before this master'using errcode='23514';end if;
  end if;
 else
  if expected_updated_at is not null then raise exception 'New employee cannot carry an existing version'using errcode='22023';end if;
 end if;
 if exists(select 1 from public.parties x where x.company_id=cid and (pid is null or x.id<>pid)and private.party_has_person_role(cid,x.id,'EMPLOYEE')and private.party_identity_key(x.name)=private.party_identity_key(v->>'name'))and(v->'distinct_employee'is distinct from'true'::jsonb or v->>'code'is null)then raise exception 'Possible existing employee: select it or provide a distinct code and explicit confirmation'using errcode='23505';end if;
 if pid is null then pid:=public.create_person_party(cid,jsonb_build_object('kind','EMPLOYEE','name',v->>'name','code',v->>'code','status',v->>'status','notes',v->>'notes'));end if;
 update public.parties set name=v->>'name',code=v->>'code',phone=v->>'phone',email=v->>'email',address=v->>'address',notes=v->>'notes',status=(v->>'status')::public.account_status,updated_by=actor where company_id=cid and id=pid returning *into p;
 insert into public.employee_master_events(company_id,employee_id,request_id,request_hash,actor_id,reason,before_data,after_data)values(cid,pid,request_id,h,actor,private.correction_text(reason),before_row,to_jsonb(p));
 return to_jsonb(p);
end$$;
revoke all on function public.command_employee_master(uuid,uuid,uuid,timestamptz,jsonb,text)from public,anon,authenticated,service_role;
grant execute on function public.command_employee_master(uuid,uuid,uuid,timestamptz,jsonb,text)to authenticated;

-- Preserve an audit of legacy name edits and trusted provisioning as well as explicit command reasons.
create function private.audit_employee_master_metadata()returns trigger language plpgsql security definer set search_path=''as $$begin
 if not private.party_has_person_role(new.company_id,new.id,'EMPLOYEE')then return new;end if;
 if tg_op='UPDATE'and(to_jsonb(new)-array['updated_at','updated_by'])is not distinct from(to_jsonb(old)-array['updated_at','updated_by'])then return new;end if;
 insert into public.employee_master_events(company_id,employee_id,actor_id,reason,before_data,after_data)values(new.company_id,new.id,auth.uid(),case when tg_op='INSERT'then 'Employee registered'else 'Employee metadata changed'end,case when tg_op='INSERT'then null else to_jsonb(old)end,to_jsonb(new));return new;
end$$;
revoke all on function private.audit_employee_master_metadata()from public,anon,authenticated,service_role;
create trigger employee_master_metadata_audit after insert or update on public.parties for each row execute function private.audit_employee_master_metadata();
