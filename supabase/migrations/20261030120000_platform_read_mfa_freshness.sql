-- Separate durable AAL2 read access from fresh-TOTP sensitive mutations.
-- Development only after explicit approval. All previously applied files unchanged.
create function private.platform_read_actor() returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.platform_actor(false); claims jsonb:=auth.jwt();
  live_factor uuid; live_aal text;
begin
  select s.factor_id,s.aal into live_factor,live_aal from auth.sessions s
    where s.id=(claims->>'session_id')::uuid and s.user_id=actor for share;
  if claims->>'aal' is distinct from 'aal2' or live_aal is distinct from 'aal2' then
    raise exception 'MFA_REQUIRED' using errcode='42501';
  end if;
  perform 1 from auth.mfa_factors f where f.id=live_factor and f.user_id=actor
    and f.factor_type='totp' and f.status='verified' for share;
  if not found then raise exception 'MFA_REQUIRED' using errcode='42501'; end if;
  -- AAL and the live verified factor must remain valid. No AMR age limit here.
  -- Mutations still call the unchanged platform_actor(true), including its
  -- signed TOTP AMR check and existing ten-minute freshness window.
  return actor;
end $$;
revoke all on function private.platform_read_actor() from public,anon,authenticated,service_role;

create or replace function public.get_platform_context() returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; begin
  actor:=private.platform_actor(false);
  begin perform private.platform_read_actor();
  exception when insufficient_privilege then
    if sqlerrm<>'MFA_REQUIRED' then raise; end if;
    return jsonb_build_object('user_id',actor,'role','PLATFORM_OWNER','step_up_required',true);
  end;
  return jsonb_build_object('user_id',actor,'role','PLATFORM_OWNER','step_up_required',false);
end $$;

create or replace function public.list_platform_entities(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_read_actor();
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

create or replace function public.get_platform_overview() returns jsonb
language plpgsql security definer set search_path='' as $$
begin
  perform private.platform_read_actor();
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

create or replace function public.platform_directory(resource text,page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_read_actor();
  if page_offset is null or page_offset<0 or page_offset>100000 or page_size is null or page_size not between 1 and 100
    or search is null or length(search)>100 then raise exception 'Invalid page' using errcode='22023'; end if;
  if resource='customers' then
    select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
      select id,code,name,contact_email,version from private.platform_customers
      where name ilike '%'||search||'%' or code ilike '%'||search||'%' order by id limit page_size+1 offset page_offset) q;
  elsif resource='users' then
    select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
      select p.user_id id,p.display_name name,p.email_snapshot email,p.status,p.updated_at::text version,
        exists(select 1 from private.system_administrators a where a.user_id=p.user_id) platform_identity
      from public.profiles p where p.display_name ilike '%'||search||'%' or p.email_snapshot ilike '%'||search||'%'
      order by p.user_id limit page_size+1 offset page_offset) q;
  elsif resource='memberships' then
    select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
      select m.id,m.company_id,c.name company_name,m.user_id,p.display_name name,m.role,m.status,coalesce(e.version,0) version
      from public.company_memberships m join public.companies c on c.id=m.company_id join public.profiles p on p.user_id=m.user_id
      left join private.platform_entities e on e.company_id=m.company_id
      where c.name ilike '%'||search||'%' or p.display_name ilike '%'||search||'%'
      order by m.id limit page_size+1 offset page_offset) q;
  elsif resource='audit' then
    select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
      select id,actor_id,action,target_id,request_id,metadata,created_at from private.platform_events
      where action ilike '%'||search||'%' order by created_at desc,id limit page_size+1 offset page_offset) q;
  elsif resource='settings' then
    select jsonb_build_array(to_jsonb(s)) into result from private.platform_settings s;
  else raise exception 'Unsupported directory' using errcode='22023'; end if;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]') from jsonb_array_elements(result) with ordinality x(value,n) where n<=page_size),
    'has_more',jsonb_array_length(result)>page_size);
end $$;

create or replace function public.list_platform_invitations(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_read_actor();
  if page_offset is null or page_offset<0 or page_offset>100000 or page_size is null or page_size not between 1 and 100 or search is null or length(search)>100 then
    raise exception 'Invalid page' using errcode='22023'; end if;
  select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
    select i.id,i.company_id,c.name company_name,i.email,i.role,i.state,i.invalidation_reason,i.expires_at,i.version,
      j.state delivery,j.attempts,j.error_code from private.platform_invitations i
      join public.companies c on c.id=i.company_id join private.platform_delivery_jobs j on j.invitation_id=i.id
      where i.email ilike '%'||search||'%' or c.name ilike '%'||search||'%' order by i.id limit page_size+1 offset page_offset) q;
  return jsonb_build_object('items',(select coalesce(jsonb_agg(value),'[]') from jsonb_array_elements(result) with ordinality x(value,n) where n<=page_size),
    'has_more',jsonb_array_length(result)>page_size);
end $$;

-- Existing public signatures/ACLs are preserved by CREATE OR REPLACE.
-- No table, role, policy, financial function or mutation guard is changed.
