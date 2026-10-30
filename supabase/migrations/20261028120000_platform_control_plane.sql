-- Local implementation only. Apply to Development only after explicit authorization.
-- Company remains the financial boundary. No financial helper/policy is replaced.
alter table private.system_administrators add column platform_role text not null
  default 'PLATFORM_OWNER' check (platform_role = 'PLATFORM_OWNER');

create table private.platform_customers (
  id uuid primary key default gen_random_uuid(),
  code text not null check (length(code) between 1 and 50 and code = btrim(code)),
  name text not null check (length(name) between 1 and 200 and name = btrim(name)),
  contact_email text check (contact_email is null or length(contact_email) <= 254),
  version integer not null default 1 check (version > 0),
  created_at timestamptz not null default now()
);
create unique index platform_customer_code on private.platform_customers(lower(code));

-- Absent rows mean legacy/unclassified, never an inferred legal classification.
create table private.platform_entities (
  company_id uuid primary key references public.companies(id) on delete restrict,
  customer_id uuid references private.platform_customers(id) on delete restrict,
  entity_kind text check (entity_kind in ('BUSINESS','PERSONAL')),
  lifecycle text not null check (lifecycle in ('DRAFT','ACTIVE','SUSPENDED','ARCHIVED')),
  onboarding text not null check (onboarding in ('PENDING_ADMIN','ADMIN_ASSIGNED')),
  accounting_setup text not null default 'INCOMPLETE' check (accounting_setup = 'INCOMPLETE'),
  plan_key text not null default 'UNASSIGNED' check (plan_key in ('UNASSIGNED','TRIAL','STANDARD')),
  region text check (region is null or length(region) <= 100),
  version integer not null default 1 check (version > 0)
);
create index platform_entities_customer on private.platform_entities(customer_id,company_id);
create index platform_entities_lifecycle on private.platform_entities(lifecycle,company_id);

create table private.platform_requests (
  actor_id uuid not null references auth.users(id) on delete restrict,
  request_id uuid not null,
  command_name text not null,
  request_hash bytea not null check (octet_length(request_hash)=32),
  receipt jsonb,
  created_at timestamptz not null default now(),
  primary key(actor_id,request_id)
);
create table private.platform_events (
  id uuid primary key default gen_random_uuid(),
  actor_id uuid not null references auth.users(id) on delete restrict,
  action text not null,
  target_id uuid not null,
  request_id uuid not null,
  metadata jsonb not null default '{}' check (octet_length(metadata::text)<=4000),
  created_at timestamptz not null default clock_timestamp()
);
create index platform_events_time on private.platform_events(created_at desc,id);
create index platform_events_target on private.platform_events(target_id,created_at desc);
create table private.platform_settings (
  singleton boolean primary key default true check(singleton),
  support_email text check (support_email is null or length(support_email)<=254),
  notice_en text not null default '' check(length(notice_en)<=500),
  notice_ar text not null default '' check(length(notice_ar)<=500),
  version integer not null default 1 check(version>0)
);
insert into private.platform_settings(singleton) values(true);

create function private.reject_platform_audit_mutation() returns trigger
language plpgsql set search_path='' as $$
begin raise exception 'Platform audit is append-only' using errcode='42501'; end $$;
create trigger platform_events_immutable before update or delete or truncate on private.platform_events
  for each statement execute function private.reject_platform_audit_mutation();

-- RLS without browser policies is intentional: access is through narrow definer commands.
do $$ declare t text; begin
  foreach t in array array['platform_customers','platform_entities','platform_requests','platform_events','platform_settings'] loop
    execute format('alter table private.%I enable row level security',t);
    execute format('alter table private.%I force row level security',t);
    execute format('revoke all on private.%I from public,anon,authenticated,service_role',t);
  end loop;
end $$;

-- Identity is always auth.uid(); caller UUIDs and JWT role metadata never authorize.
-- SHARE locks serialize new commands against profile/registry/session revocation.
create function private.platform_actor(require_step_up boolean default true) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid := auth.uid(); claims jsonb := auth.jwt(); session_id uuid;
  method jsonb; fresh boolean := false; session_factor uuid; session_aal text;
begin
  if actor is null then raise exception 'Denied' using errcode='42501'; end if;
  perform 1 from private.system_administrators a join public.profiles p on p.user_id=a.user_id
    where a.user_id=actor and a.status='ACTIVE' and a.platform_role='PLATFORM_OWNER'
      and p.status='ACTIVE' for share of a,p;
  if not found then raise exception 'Denied' using errcode='42501'; end if;
  begin session_id := (claims->>'session_id')::uuid;
  exception when invalid_text_representation then raise exception 'Denied' using errcode='42501'; end;
  select s.factor_id,s.aal into session_factor,session_aal from auth.sessions s join auth.users u on u.id=s.user_id
    where s.id=session_id and s.user_id=actor and (s.not_after is null or s.not_after>clock_timestamp())
      and (u.banned_until is null or u.banned_until<clock_timestamp()) for share of s,u;
  if not found then raise exception 'Session revoked' using errcode='42501'; end if;
  if require_step_up then
    if claims->>'aal' is distinct from 'aal2' or session_aal is distinct from 'aal2' then
      raise exception 'MFA_REQUIRED' using errcode='42501'; end if;
    perform 1 from auth.mfa_factors f where f.id=session_factor and f.user_id=actor and f.factor_type='totp' and f.status='verified' for share;
    if not found then raise exception 'MFA_REQUIRED' using errcode='42501'; end if;
    for method in select value from jsonb_array_elements(
      case when jsonb_typeof(claims->'amr')='array' then claims->'amr' else '[]'::jsonb end) loop
      if method->>'method'='totp' and coalesce(method->>'timestamp','') ~ '^[0-9]{1,12}$' then
        fresh := fresh or (to_timestamp((method->>'timestamp')::double precision)
          between clock_timestamp()-interval '10 minutes' and clock_timestamp()+interval '5 seconds');
      end if;
    end loop;
    if not fresh then raise exception 'MFA_REQUIRED' using errcode='42501'; end if;
  end if;
  return actor;
end $$;

create function public.get_platform_context() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; begin
  actor := private.platform_actor(false);
  begin perform private.platform_actor(true);
  exception when insufficient_privilege then
    return jsonb_build_object('user_id',actor,'role','PLATFORM_OWNER','step_up_required',true);
  end;
  return jsonb_build_object('user_id',actor,'role','PLATFORM_OWNER','step_up_required',false);
end $$;

create function public.list_platform_entities(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_actor();
  if page_offset<0 or page_offset>100000 or page_size not between 1 and 100 or length(search)>100
     or page_offset is null or page_size is null or search is null then
    raise exception 'Invalid page' using errcode='22023'; end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
    select c.id,c.code,c.name,c.legal_name,c.trn,c.address,c.status,
      e.customer_id,e.entity_kind,coalesce(e.lifecycle,case when c.status='ACTIVE' then 'ACTIVE' else 'SUSPENDED' end) lifecycle,
      coalesce(e.onboarding,'LEGACY') onboarding,coalesce(e.accounting_setup,'UNASSESSED') accounting_setup,
      coalesce(e.plan_key,'UNASSIGNED') plan_key,e.region,coalesce(e.version,0) version
    from public.companies c left join private.platform_entities e on e.company_id=c.id
    where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search
    order by c.id limit page_size offset page_offset
  ) q;
  return jsonb_build_object('items',result,'has_more',exists(select 1 from public.companies c
    where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search offset page_offset+page_size));
end $$;

create function public.get_platform_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.platform_actor();
  return jsonb_build_object('entities',(select count(*) from public.companies),
    'active',(select count(*) from public.companies where status='ACTIVE'),
    'customers',(select count(*) from private.platform_customers),
    'users',(select count(*) from public.profiles),
    'pending_setup',(select count(*) from private.platform_entities where accounting_setup='INCOMPLETE'),
    'pending_invitations',(select count(*) from private.platform_invitations where state='PENDING' and expires_at>now()),
    'delivery_failures',(select count(*) from private.platform_delivery_jobs where state='FAILED'),
    'suspended',(select count(*) from public.companies c left join private.platform_entities e on e.company_id=c.id
      where coalesce(e.lifecycle,case when c.status='ACTIVE' then 'ACTIVE' else 'SUSPENDED' end)='SUSPENDED'),
    'archived',(select count(*) from private.platform_entities where lifecycle='ARCHIVED'),
    'checked_at',clock_timestamp(),'billing_enabled',false);
end $$;

revoke all on function private.platform_actor(boolean),private.reject_platform_audit_mutation()
  from public,anon,authenticated,service_role;
revoke all on function public.get_platform_context(),public.list_platform_entities(integer,integer,text),public.get_platform_overview()
  from public,anon,authenticated,service_role;
grant execute on function public.get_platform_context(),public.list_platform_entities(integer,integer,text),public.get_platform_overview()
  to authenticated;
