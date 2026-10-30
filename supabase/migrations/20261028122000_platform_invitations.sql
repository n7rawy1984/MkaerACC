create table private.platform_invitations (
  id uuid primary key default gen_random_uuid(),
  company_id uuid not null references public.companies(id) on delete restrict,
  email text not null check (email=lower(btrim(email)) and length(email)<=254 and email ~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$'),
  role public.company_role not null check(role in ('ACCOUNTING_ADMIN','ACCOUNTANT','PROJECT_MANAGER','DATA_ENTRY','PROCUREMENT','MANAGEMENT_VIEWER','FOREMAN')),
  state text not null default 'PENDING' check(state in ('PENDING','ACCEPTED','REVOKED')),
  created_by uuid not null references auth.users(id) on delete restrict,
  accepted_by uuid references auth.users(id) on delete restrict,
  expires_at timestamptz not null default now()+interval '7 days',
  version integer not null default 1 check(version>0),
  created_at timestamptz not null default now()
);
create unique index platform_invitation_pending on private.platform_invitations(company_id,email) where state='PENDING';
create index platform_invitation_expiry on private.platform_invitations(state,expires_at);
create table private.platform_delivery_jobs (
  invitation_id uuid primary key references private.platform_invitations(id) on delete restrict,
  state text not null default 'QUEUED' check(state in ('QUEUED','DELIVERING','DELIVERED','FAILED','CANCELLED')),
  attempts integer not null default 0 check(attempts>=0),
  delivery_actor_id uuid references auth.users(id) on delete restrict,
  lease_id uuid,
  leased_until timestamptz,
  error_code text check(error_code in ('AUTH_DELIVERY_FAILED','CONFIGURATION_REQUIRED','DELIVERY_UNCERTAIN')),
  updated_at timestamptz not null default now()
);
alter table private.platform_invitations enable row level security;
alter table private.platform_invitations force row level security;
alter table private.platform_delivery_jobs enable row level security;
alter table private.platform_delivery_jobs force row level security;
revoke all on private.platform_invitations,private.platform_delivery_jobs from public,anon,authenticated,service_role;

create function public.platform_invitation_command(command_name text,request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.platform_actor(); p jsonb:='{}'; k text; v jsonb; allowed text[];
  h bytea; prior private.platform_requests; inv private.platform_invitations; target uuid; result jsonb;
begin
  if request_id is null or jsonb_typeof(business_input) is distinct from 'object' or octet_length(business_input::text)>4000 then
    raise exception 'Invalid request' using errcode='22023'; end if;
  allowed:=case command_name when 'invite' then array['company_id','email','role']
    when 'resend' then array['id','version'] when 'revoke' then array['id','version','reason'] else null end;
  if allowed is null then raise exception 'Invalid invitation operation' using errcode='22023'; end if;
  for k,v in select * from jsonb_each(business_input) loop
    if k<>all(allowed) or jsonb_typeof(v)<>'string' then raise exception 'Invalid field' using errcode='22023'; end if;
    p:=p||jsonb_build_object(k,case when k='email' then lower(btrim(v#>>'{}')) else btrim(v#>>'{}') end);
  end loop;
  h:=sha256(convert_to(command_name||':'||p::text,'UTF8'));
  insert into private.platform_requests(actor_id,request_id,command_name,request_hash)
    values(actor,request_id,'invitation_'||command_name,h) on conflict do nothing;
  select * into prior from private.platform_requests r where r.actor_id=actor and r.request_id=platform_invitation_command.request_id for update;
  if prior.request_hash<>h or prior.command_name<>'invitation_'||command_name then raise exception 'Idempotency mismatch' using errcode='22023'; end if;
  if prior.receipt is not null then return prior.receipt; end if;
  if command_name='invite' then
    perform 1 from public.companies where id=(p->>'company_id')::uuid for update;
    if not found then raise exception 'Entity unavailable' using errcode='22023'; end if;
    if exists(select 1 from auth.users u join private.system_administrators a on a.user_id=u.id where lower(u.email)=p->>'email') then
      raise exception 'Platform principal cannot receive accounting invitation' using errcode='42501'; end if;
    insert into private.platform_invitations(company_id,email,role,created_by)
      values((p->>'company_id')::uuid,private.platform_text(p,'email',254),(p->>'role')::public.company_role,actor) returning id into target;
    insert into private.platform_delivery_jobs(invitation_id) values(target);
  else
    target:=(p->>'id')::uuid;
    select * into inv from private.platform_invitations where id=target for update;
    if inv.id is null or inv.version is distinct from (p->>'version')::integer or inv.state<>'PENDING' then
      raise exception 'Stale invitation' using errcode='40001'; end if;
    if command_name='revoke' then
      perform private.platform_text(p,'reason',500);
      update private.platform_invitations set state='REVOKED',version=version+1 where id=target;
      update private.platform_delivery_jobs set state='CANCELLED',lease_id=null,leased_until=null,updated_at=now() where invitation_id=target;
    else
      update private.platform_invitations set expires_at=now()+interval '7 days',version=version+1 where id=target;
      -- Never dispatch a second delivery while a lease may still be sending.
      update private.platform_delivery_jobs set state='QUEUED',error_code=null,updated_at=now()
        where invitation_id=target and (state<>'DELIVERING' or leased_until<now());
      if not found then raise exception 'Delivery in progress' using errcode='40001'; end if;
    end if;
  end if;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(actor,'invitation_'||command_name,target,request_id,jsonb_strip_nulls(jsonb_build_object('reason',p->>'reason')));
  result:=jsonb_build_object('id',target,'request_id',request_id,'command','invitation_'||command_name,'status','CONFIRMED');
  update private.platform_requests r set receipt=result where r.actor_id=actor and r.request_id=platform_invitation_command.request_id;
  return result;
end $$;

create function public.list_platform_invitations(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_actor();
  if page_offset is null or page_offset<0 or page_offset>100000 or page_size is null or page_size not between 1 and 100 or search is null or length(search)>100 then
    raise exception 'Invalid page' using errcode='22023'; end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
    select i.id,i.company_id,c.name company_name,i.email,i.role,i.state,i.expires_at,i.version,
      j.state delivery,j.attempts,j.error_code from private.platform_invitations i
      join public.companies c on c.id=i.company_id join private.platform_delivery_jobs j on j.invitation_id=i.id
      where i.email ilike '%'||search||'%' or c.name ilike '%'||search||'%' order by i.id limit page_size+1 offset page_offset) q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]') from jsonb_array_elements(result) with ordinality x(value,n) where n<=page_size),
    'has_more',jsonb_array_length(result)>page_size);
end $$;

create function public.accept_platform_invitation(invitation_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); email text; inv private.platform_invitations; result uuid; cid uuid;
begin
  -- Ordinary intended recipients need a live verified identity, not platform privilege.
  if actor is null then raise exception 'Verified live identity required' using errcode='42501'; end if;
  perform private.lock_platform_user(actor);
  select lower(u.email) into email from auth.users u join auth.sessions s on s.user_id=u.id
    join public.profiles p on p.user_id=u.id and p.status='ACTIVE'
    where u.id=actor and u.email_confirmed_at is not null and (u.banned_until is null or u.banned_until<now())
      and s.id=(auth.jwt()->>'session_id')::uuid and (s.not_after is null or s.not_after>now()) for share of u,s,p;
  if email is null then raise exception 'Verified live identity required' using errcode='42501'; end if;
  select company_id into cid from private.platform_invitations where id=invitation_id;
  perform 1 from public.companies where id=cid for update;
  select * into inv from private.platform_invitations where id=invitation_id for update;
  if inv.id is null or inv.email<>email or inv.state='REVOKED' or inv.expires_at<=now() then
    raise exception 'Invitation unavailable' using errcode='42501'; end if;
  if inv.state='ACCEPTED' and inv.accepted_by=actor then return inv.company_id; end if;
  if inv.state<>'PENDING' then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  perform 1 from private.system_administrators a join public.profiles p on p.user_id=a.user_id
    where a.user_id=inv.created_by and a.status='ACTIVE' and p.status='ACTIVE' for share of a,p;
  if not found then raise exception 'Inviter authority revoked' using errcode='42501'; end if;
  -- An old invitation must never change an existing member's current role.
  if exists(select 1 from public.company_memberships where company_id=cid and user_id=actor and status='ACTIVE') then
    raise exception 'Membership already exists; administrator must review' using errcode='23514'; end if;
  result:=private.platform_member(inv.created_by,cid,actor,inv.role::text,inv.id);
  update private.platform_invitations set state='ACCEPTED',accepted_by=actor,version=version+1 where id=inv.id;
  update private.platform_entities set onboarding='ADMIN_ASSIGNED',version=version+1
    where company_id=cid and inv.role='ACCOUNTING_ADMIN';
  update private.platform_delivery_jobs j set state='CANCELLED',lease_id=null,leased_until=null,updated_at=now() where j.invitation_id=inv.id and j.state<>'DELIVERED';
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(actor,'INVITATION_ACCEPTED',inv.id,inv.id,jsonb_build_object('company_id',cid,'membership_id',result));
  return cid;
end $$;

-- A caller-authorized lease; only the trusted delivery service may acknowledge it.
create function public.claim_platform_delivery(invitation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.platform_actor(); inv private.platform_invitations; job private.platform_delivery_jobs; lease uuid:=gen_random_uuid();
begin
  select * into inv from private.platform_invitations where id=invitation_id for update;
  if inv.id is null or inv.state<>'PENDING' or inv.expires_at<=now() then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  select * into job from private.platform_delivery_jobs where platform_delivery_jobs.invitation_id=claim_platform_delivery.invitation_id for update;
  if job.state not in ('QUEUED','FAILED') and not(job.state='DELIVERING' and job.leased_until<now()) then
    raise exception 'Delivery unavailable' using errcode='40001'; end if;
  update private.platform_delivery_jobs set state='DELIVERING',delivery_actor_id=actor,lease_id=lease,leased_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now()
    where platform_delivery_jobs.invitation_id=inv.id;
  insert into private.platform_events(actor_id,action,target_id,request_id) values(actor,'INVITATION_DELIVERY_STARTED',inv.id,lease);
  return jsonb_build_object('id',inv.id,'email',inv.email,'lease_id',lease);
end $$;

create function public.finish_platform_delivery(invitation_id uuid,lease_id uuid,outcome text) returns void
language plpgsql security definer set search_path='' as $$
declare inv private.platform_invitations; delivery_actor uuid;
begin
  if outcome<>all(array['DELIVERED','AUTH_DELIVERY_FAILED','CONFIGURATION_REQUIRED','DELIVERY_UNCERTAIN']) or outcome is null then
    raise exception 'Invalid delivery result' using errcode='22023'; end if;
  select * into inv from private.platform_invitations where id=invitation_id for update;
  if inv.state<>'PENDING' then raise exception 'Invitation unavailable' using errcode='40001'; end if;
  update private.platform_delivery_jobs j set state=case when outcome='DELIVERED' then 'DELIVERED' else 'FAILED' end,
    error_code=case when outcome='DELIVERED' then null else outcome end,lease_id=null,leased_until=null,updated_at=now()
    where j.invitation_id=finish_platform_delivery.invitation_id and j.lease_id=finish_platform_delivery.lease_id and j.state='DELIVERING' and j.leased_until>now()
    returning j.delivery_actor_id into delivery_actor;
  if not found then raise exception 'Stale delivery lease' using errcode='40001'; end if;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(delivery_actor,'INVITATION_DELIVERY_RESULT',inv.id,lease_id,jsonb_build_object('outcome',outcome,'source','AUTH_SERVICE'));
end $$;

revoke all on function public.platform_invitation_command(text,uuid,jsonb),public.list_platform_invitations(integer,integer,text),
  public.accept_platform_invitation(uuid),public.claim_platform_delivery(uuid),public.finish_platform_delivery(uuid,uuid,text)
  from public,anon,authenticated,service_role;
grant execute on function public.platform_invitation_command(text,uuid,jsonb),public.list_platform_invitations(integer,integer,text),
  public.accept_platform_invitation(uuid),public.claim_platform_delivery(uuid) to authenticated;
grant execute on function public.finish_platform_delivery(uuid,uuid,text) to service_role;
