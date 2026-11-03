-- M3 / PRJ-01: only the explicitly specified PLANNING -> ACTIVE transition.
-- Local preparation. No journal, financial command or existing RLS/grant change.
create table public.project_activation_events (
 id uuid primary key default gen_random_uuid(),
 company_id uuid not null,
 project_id uuid not null,
 request_id uuid not null,
 actor_id uuid not null references auth.users(id) on delete restrict,
 reason text not null check(length(reason) between 1 and 500),
 input_hash text not null,
 previous_status public.project_status not null check(previous_status='PLANNING'),
 new_status public.project_status not null check(new_status='ACTIVE'),
 previous_updated_at timestamptz not null,
 project_updated_at timestamptz not null,
 activated_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,project_id) references public.projects(company_id,id) on delete restrict,
 unique(company_id,request_id),
 unique(company_id,project_id)
);
alter table public.project_activation_events enable row level security;
alter table public.project_activation_events force row level security;
revoke all on public.project_activation_events from public,anon,authenticated,service_role;
grant select on public.project_activation_events to authenticated;
create policy project_activation_read on public.project_activation_events
 for select to authenticated using(public.can_access_project(company_id,project_id));

create function private.prevent_project_activation_event_change() returns trigger
language plpgsql security invoker set search_path='' as $$
begin raise exception 'Project activation history is immutable' using errcode='23514';end;$$;
revoke all on function private.prevent_project_activation_event_change() from public,anon,authenticated,service_role;
create trigger project_activation_history_immutable before update or delete on public.project_activation_events
 for each row execute function private.prevent_project_activation_event_change();

create function public.activate_project(target_company_id uuid,target_project_id uuid,
 expected_updated_at timestamptz,request_id uuid,reason text) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); normalized_reason text;
 trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
  || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
  || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
  || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
 digest text; prior public.project_activation_events; original public.projects;
 activated public.projects; event_id uuid;
begin
 normalized_reason:=nullif(btrim(reason,trim_chars),'');
 if actor is null or target_company_id is null or target_project_id is null or request_id is null
 or expected_updated_at is null or normalized_reason is null or length(normalized_reason)>500 then
  raise exception 'Invalid activation request' using errcode='22023';end if;
 -- Preserve the existing single-accountant authority. Lock authority rows against
 -- concurrent suspension/revocation; no new role, permission or financial bypass.
 perform 1 from public.companies where id=target_company_id for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=target_company_id and user_id=actor for share;
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
 or not public.has_permission(target_company_id,'project.manage') then
  raise exception 'Project activation denied' using errcode='42501';end if;
 digest:=encode(extensions.digest(jsonb_build_object('company',target_company_id,'project',target_project_id,
  'actor',actor,'expected_epoch',extract(epoch from expected_updated_at),'reason',normalized_reason)::text,'sha256'),'hex');
 -- Serialize the same request even when concurrently reused for another Project.
 perform pg_advisory_xact_lock(hashtextextended('project-activation:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.project_activation_events e
 where e.company_id=target_company_id and e.request_id=activate_project.request_id;
 if found then
  if prior.input_hash<>digest or prior.actor_id<>actor then
   raise exception 'Activation request does not match' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'project_id',prior.project_id,
   'request_id',prior.request_id,'status',prior.new_status,'updated_at',prior.project_updated_at);
 end if;
 select * into original from public.projects where company_id=target_company_id and id=target_project_id for update;
 if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 if original.status<>'PLANNING' or original.updated_at<>expected_updated_at then
  raise exception 'Project changed; refresh before activation' using errcode='40001';end if;
 update public.projects set status='ACTIVE',updated_by=actor
 where company_id=target_company_id and id=target_project_id returning * into activated;
 -- Existing metadata triggers must not silently normalize unrelated legacy fields.
 if (to_jsonb(original)-array['status','updated_at','updated_by']) is distinct from
    (to_jsonb(activated)-array['status','updated_at','updated_by']) then
  raise exception 'Review project metadata before activation' using errcode='23514';end if;
 insert into public.project_activation_events(company_id,project_id,request_id,actor_id,reason,input_hash,
  previous_status,new_status,previous_updated_at,project_updated_at)
 values(target_company_id,target_project_id,request_id,actor,normalized_reason,digest,
  original.status,activated.status,original.updated_at,activated.updated_at) returning id into event_id;
 return jsonb_build_object('id',event_id,'company_id',target_company_id,'project_id',target_project_id,
  'request_id',request_id,'status',activated.status,'updated_at',activated.updated_at);
end;$$;
revoke all on function public.activate_project(uuid,uuid,timestamptz,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.activate_project(uuid,uuid,timestamptz,uuid,text) to authenticated;
