-- PRJ-01: operational lifecycle only. Financial closure remains unavailable.
-- Existing activation, financial commands, policies and posted history are preserved.
create table public.project_lifecycle_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,
 project_id uuid not null,request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,
 previous_status public.project_status not null,new_status public.project_status not null,
 effective_date date not null,reason text not null check(length(reason) between 1 and 500),
 input_hash text not null,review_hash text not null,dependencies jsonb not null check(jsonb_typeof(dependencies)='object'),
 previous_updated_at timestamptz not null,project_updated_at timestamptz not null,
 recorded_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id),foreign key(company_id,project_id) references public.projects(company_id,id) on delete restrict,
 check((previous_status='ACTIVE' and new_status in ('ON_HOLD','COMPLETED')) or
 (previous_status='ON_HOLD' and new_status='ACTIVE') or (previous_status='COMPLETED' and new_status='ACTIVE'))
);
alter table public.project_lifecycle_events enable row level security;
alter table public.project_lifecycle_events force row level security;
revoke all on public.project_lifecycle_events from public,anon,authenticated,service_role;
grant select on public.project_lifecycle_events to authenticated;
-- Snapshots include total Project cost (including Payroll); never leak restricted totals.
create policy project_lifecycle_history_read on public.project_lifecycle_events for select to authenticated
 using((public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT'))
 and public.has_permission(company_id,'payroll.manage') and public.can_access_project(company_id,project_id));
create trigger project_lifecycle_immutable before update or delete on public.project_lifecycle_events
 for each row execute function private.protect_project_cost_correction();

create function private.project_lifecycle_actor(cid uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();begin
 perform 1 from public.companies where id=cid for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=cid and user_id=actor for share;
 if actor is null or not public.has_company_role(cid,'ACCOUNTING_ADMIN') or not public.has_permission(cid,'project.manage')
 or not public.has_permission(cid,'payroll.manage') then raise exception 'Project lifecycle denied' using errcode='42501';end if;
 return actor;
end;$$;
revoke all on function private.project_lifecycle_actor(uuid) from public,anon,authenticated,service_role;

create function private.project_lifecycle_dependencies(cid uuid,pid uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
 'pending_sources',(select count(*) from public.historical_source_records r left join public.source_expense_allocation_events a on a.company_id=r.company_id and a.id=r.expense_allocation_id
 where r.company_id=cid and r.review_status<>'CANCELLED' and r.record_type='GENERAL' and r.expense_id is null and not exists(select 1 from private.financial_command_requests q where q.company_id=cid and q.idempotency_key=r.id and q.command_type='POST_EXPENSE' and q.status='COMPLETED') and
 (r.assigned_project_id=pid or (r.allocation_scope is null and r.expense_allocation_id is null and r.completion->>'project_id'=pid::text) or exists(select 1 from jsonb_array_elements(coalesce(a.plan->'destinations','[]'::jsonb)) d where d->>'project_id'=pid::text))),
 'open_subcontracts',(select count(*) from public.subcontracts s where s.company_id=cid and s.project_id=pid and s.status<>'CLOSED'),
 'draft_certificates',(select count(*) from public.subcontractor_certificates c where c.company_id=cid and c.project_id=pid and c.status='DRAFT'),
 'pending_corrections',(select count(*) from public.expense_correction_reviews r
 where r.company_id=cid and (r.original_project_id=pid or r.proposed_project_id=pid or exists(select 1 from public.expenses e, lateral jsonb_array_elements(coalesce(e.allocation_plan->'destinations','[]'::jsonb)) d where e.company_id=cid and e.id=r.expense_id and d->>'project_id'=pid::text))
 and not exists(select 1 from public.expense_correction_reviews n where n.company_id=cid and n.previous_review_id=r.id)
 and not exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.review_id=r.id)),
 'posted_split_expenses',(select count(*) from public.expenses e where e.company_id=cid and e.allocation_plan is not null and exists(select 1 from jsonb_array_elements(e.allocation_plan->'destinations') d where d->>'project_id'=pid::text)),
 'cost_debit_minor',(select coalesce(sum(l.debit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'),
 'cost_credit_minor',(select coalesce(sum(l.credit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'),
 -- Separate actual GL dimensions; never net assets, liabilities or contracts together.
 'obligations',coalesce((select jsonb_agg(to_jsonb(b) order by account_code,subcontract_id,party_id) from
 (select a.code account_code,a.name account_name,a.system_key::text category,l.subcontract_id,l.party_id,s.contract_number,
 sum(l.debit_minor::numeric-l.credit_minor::numeric)::text balance_minor
 from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id
 left join public.subcontracts s on s.company_id=l.company_id and s.id=l.subcontract_id
 where l.company_id=cid and l.project_id=pid and a.requires_party and a.account_type in ('ASSET','LIABILITY','EQUITY')
 group by a.id,a.code,a.name,a.system_key,l.subcontract_id,l.party_id,s.contract_number
 having sum(l.debit_minor::numeric-l.credit_minor::numeric)<>0) b),'[]'::jsonb),
 'coverage','PROJECT_JOURNAL_DIMENSIONS_ONLY','closure','POLICY_UNAVAILABLE');
$$;
revoke all on function private.project_lifecycle_dependencies(uuid,uuid) from public,anon,authenticated,service_role;

create function public.preview_project_lifecycle(target_company_id uuid,target_project_id uuid,expected_updated_at timestamptz,target_status public.project_status)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.projects;deps jsonb;allowed boolean;begin
 perform private.project_lifecycle_actor(target_company_id);
 select * into p from public.projects where company_id=target_company_id and id=target_project_id for share;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 if expected_updated_at is null or p.updated_at<>expected_updated_at then raise exception 'Project changed' using errcode='40001';end if;
 allowed:=(p.status='ACTIVE' and target_status in ('ON_HOLD','COMPLETED')) or (p.status in ('ON_HOLD','COMPLETED') and target_status='ACTIVE');
 deps:=private.project_lifecycle_dependencies(target_company_id,target_project_id);
 return jsonb_build_object('company_id',p.company_id,'project_id',p.id,'project_code',p.code,'project_name',p.name,'status',p.status,'updated_at',p.updated_at,
 'target_status',target_status,'allowed',coalesce(allowed,false),'blocked_reason',case when target_status='CLOSED' then 'CLOSURE_POLICY_UNAVAILABLE' when not coalesce(allowed,false) then 'TRANSITION_UNAVAILABLE' else null end,
 'effective_date',(current_timestamp at time zone 'Asia/Dubai')::date,'dependencies',deps,
 'review_hash',encode(extensions.digest(deps::text,'sha256'),'hex'));
end;$$;
revoke all on function public.preview_project_lifecycle(uuid,uuid,timestamptz,public.project_status) from public,anon,authenticated,service_role;
grant execute on function public.preview_project_lifecycle(uuid,uuid,timestamptz,public.project_status) to authenticated;

create function public.transition_project(target_company_id uuid,target_project_id uuid,expected_updated_at timestamptz,
 target_status public.project_status,effective_date date,reason text,request_id uuid,review_hash text,obligations_acknowledged boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;why text:=private.correction_text(reason);p public.projects;changed public.projects;prior public.project_lifecycle_events;
 digest text;deps jsonb;actual_review text;result public.project_lifecycle_events;
begin
 actor:=private.project_lifecycle_actor(target_company_id);
 if target_project_id is null or expected_updated_at is null or request_id is null or target_status is null or effective_date is null or why is null or length(why)>500 or review_hash is null or review_hash!~'^[0-9a-f]{64}$' or obligations_acknowledged is distinct from true then raise exception 'Invalid lifecycle confirmation' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('company',target_company_id,'project',target_project_id,'actor',actor,'expected_epoch',extract(epoch from expected_updated_at),
 'target',target_status,'date',effective_date,'reason',why,'review',review_hash,'acknowledged',true)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('project-lifecycle:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.project_lifecycle_events e where e.company_id=target_company_id and e.request_id=transition_project.request_id;
 if found then
  if prior.input_hash<>digest or prior.actor_id<>actor then raise exception 'Lifecycle request does not match' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'project_id',prior.project_id,'request_id',prior.request_id,'status',prior.new_status,'updated_at',prior.project_updated_at);
 end if;
 select * into p from public.projects where company_id=target_company_id and id=target_project_id for update;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 if p.updated_at<>expected_updated_at then raise exception 'Project changed' using errcode='40001';end if;
 if target_status='CLOSED' then raise exception 'Financial closure policy is unavailable; existing obligations must remain settleable' using errcode='23514';end if;
 if not ((p.status='ACTIVE' and target_status in ('ON_HOLD','COMPLETED')) or (p.status in ('ON_HOLD','COMPLETED') and target_status='ACTIVE')) then raise exception 'Unsupported lifecycle transition' using errcode='23514';end if;
 -- Immediate operational transition; never backdate/schedule a financial lock or recognition.
 if effective_date<>(current_timestamp at time zone 'Asia/Dubai')::date then raise exception 'Lifecycle changes take effect today' using errcode='22023';end if;
 deps:=private.project_lifecycle_dependencies(target_company_id,target_project_id);actual_review:=encode(extensions.digest(deps::text,'sha256'),'hex');
 if actual_review<>review_hash then raise exception 'Project dependencies changed; review again' using errcode='40001';end if;
 update public.projects set status=target_status,updated_by=actor where company_id=target_company_id and id=target_project_id returning * into changed;
 if (to_jsonb(p)-array['status','updated_at','updated_by']) is distinct from (to_jsonb(changed)-array['status','updated_at','updated_by']) then raise exception 'Review legacy Project metadata before transition' using errcode='23514';end if;
 insert into public.project_lifecycle_events(company_id,project_id,request_id,actor_id,previous_status,new_status,effective_date,reason,input_hash,review_hash,dependencies,previous_updated_at,project_updated_at)
 values(target_company_id,target_project_id,request_id,actor,p.status,changed.status,effective_date,why,digest,actual_review,deps,p.updated_at,changed.updated_at) returning * into result;
 return jsonb_build_object('id',result.id,'company_id',result.company_id,'project_id',result.project_id,'request_id',result.request_id,'status',result.new_status,'updated_at',result.project_updated_at);
end;$$;
revoke all on function public.transition_project(uuid,uuid,timestamptz,public.project_status,date,text,uuid,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.transition_project(uuid,uuid,timestamptz,public.project_status,date,text,uuid,text,boolean) to authenticated;
