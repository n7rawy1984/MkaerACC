-- Forward correction: preserve the preceding 59 migration files. Hosted history
-- is unverified. No timestamp ordering; transaction locks plus monotonic epochs.
-- Administrative traffic is low-volume: one transaction advisory gate deliberately
-- serializes platform mutations, including delivery acknowledgement. Financial RPCs
-- do not acquire this gate and are unchanged.
create function private.lock_platform_authorization() returns void
language sql set search_path='' as $$
 select pg_advisory_xact_lock(714209381506128::bigint);
$$;
revoke all on function private.lock_platform_authorization() from public,anon,authenticated,service_role;

create table private.platform_access_fences (
 company_id uuid not null references public.companies(id) on delete restrict,
 recipient_key text not null check(recipient_key=lower(btrim(recipient_key))),
 generation bigint not null default 0 check(generation>=0),
 primary key(company_id,recipient_key)
);
alter table private.platform_access_fences enable row level security;
alter table private.platform_access_fences force row level security;
revoke all on private.platform_access_fences from public,anon,authenticated,service_role;
alter table public.profiles add column platform_access_epoch bigint not null default 0;
alter table private.system_administrators add column platform_access_epoch bigint not null default 0;
create function private.advance_platform_identity_epoch() returns trigger
language plpgsql set search_path='' as $$ begin
 -- Epoch is maintained by the database, including trusted operational updates.
 new.platform_access_epoch:=old.platform_access_epoch;
 if new.status is distinct from old.status then new.platform_access_epoch:=old.platform_access_epoch+1; end if;
 return new;
end $$;
revoke all on function private.advance_platform_identity_epoch() from public,anon,authenticated,service_role;
create trigger platform_profile_epoch before update on public.profiles
 for each row execute function private.advance_platform_identity_epoch();
create trigger platform_registry_epoch before update on private.system_administrators
 for each row execute function private.advance_platform_identity_epoch();

alter table private.platform_invitations
 add column access_generation bigint not null default 0,
 add column recipient_epoch bigint not null default 0,
 add column recipient_user_id uuid references auth.users(id) on delete restrict,
 add column recipient_generation bigint not null default 0,
 add column issuer_epoch bigint not null default 0,
 add column issuer_profile_epoch bigint not null default 0,
 add column invalidation_reason text;

create function private.invalidate_platform_invitations(cid uuid,recipient_email text,actor uuid,operation uuid,reason text,recipient_user uuid default null)
returns void language plpgsql security definer set search_path='' as $$
declare invalidated uuid; subject uuid:=recipient_user;
begin
 perform private.lock_platform_authorization();
 if subject is null then select id into subject from auth.users where lower(email)=recipient_email; end if;
 if recipient_email is not null then
  insert into private.platform_access_fences(company_id,recipient_key,generation) values(cid,'email:'||recipient_email,1)
  on conflict(company_id,recipient_key) do update set generation=platform_access_fences.generation+1;
 end if;
 if subject is not null then
  insert into private.platform_access_fences(company_id,recipient_key,generation) values(cid,'user:'||subject::text,1)
  on conflict(company_id,recipient_key) do update set generation=platform_access_fences.generation+1;
 end if;
 for invalidated in update private.platform_invitations set state='REVOKED',version=version+1,invalidation_reason=reason
   where company_id=cid and (email=recipient_email or recipient_user_id=subject) and state='PENDING' returning id loop
  update private.platform_delivery_jobs set state='CANCELLED',lease_id=null,leased_until=null,updated_at=now()
   where invitation_id=invalidated;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
   values(actor,'INVITATION_INVALIDATED',invalidated,operation,
    jsonb_build_object('company_id',cid,'reason',reason,'cause','ACCESS_DECISION'));
 end loop;
end $$;
revoke all on function private.invalidate_platform_invitations(uuid,text,uuid,uuid,text,uuid) from public,anon,authenticated,service_role;

-- Fail closed for invitations predating this correction: their authorization
-- ordering cannot be reconstructed. History remains; a new authorized invite works.
update private.platform_invitations set state='REVOKED',version=version+1,
 invalidation_reason='SECURITY_CORRECTION_REISSUE_REQUIRED' where state='PENDING';
update private.platform_delivery_jobs j set state='CANCELLED',lease_id=null,leased_until=null,updated_at=now()
 from private.platform_invitations i where i.id=j.invitation_id and i.invalidation_reason='SECURITY_CORRECTION_REISSUE_REQUIRED';
insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
 select created_by,'INVITATION_INVALIDATED',id,id,
 jsonb_build_object('reason','SECURITY_CORRECTION_REISSUE_REQUIRED','cause','CANONICAL_MIGRATION')
 from private.platform_invitations where invalidation_reason='SECURITY_CORRECTION_REISSUE_REQUIRED';

create function private.check_platform_invitation_authority(inv private.platform_invitations,allow_expired boolean default false) returns void
language plpgsql security definer set search_path='' as $$
begin
 if inv.id is null or inv.state='REVOKED' or (inv.expires_at<=now() and not allow_expired)
 or inv.access_generation<>coalesce((select generation from private.platform_access_fences where company_id=inv.company_id and recipient_key='email:'||inv.email),0)
 or exists(select 1 from auth.users u join public.profiles p on p.user_id=u.id
   where lower(u.email)=inv.email and (p.status<>'ACTIVE' or p.platform_access_epoch<>inv.recipient_epoch
   or (inv.recipient_user_id is not null and inv.recipient_user_id<>u.id)
   or inv.recipient_generation<>coalesce((select generation from private.platform_access_fences
     where company_id=inv.company_id and recipient_key='user:'||u.id::text),0)))
 then raise exception 'Invitation superseded or unavailable' using errcode='42501'; end if;
 perform 1 from private.system_administrators a join public.profiles p on p.user_id=a.user_id
 where a.user_id=inv.created_by and a.status='ACTIVE' and p.status='ACTIVE'
 and a.platform_access_epoch=inv.issuer_epoch and p.platform_access_epoch=inv.issuer_profile_epoch for share of a,p;
 if not found then raise exception 'Inviter authority superseded' using errcode='42501'; end if;
 if exists(select 1 from private.platform_entities where company_id=inv.company_id and lifecycle in ('SUSPENDED','ARCHIVED')) then
 raise exception 'Entity unavailable' using errcode='42501'; end if;
end $$;
revoke all on function private.check_platform_invitation_authority(private.platform_invitations,boolean) from public,anon,authenticated,service_role;

create or replace function public.platform_admin_command(command_name text,request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; p jsonb:='{}'; k text; v jsonb;
  allowed text[]; command_hash bytea; prior private.platform_requests; result jsonb;
  target uuid; cid uuid; uid uuid; customer uuid; entity private.platform_entities;
  old_status text; next_status text; expected integer; reason text; label text; membership uuid; locked_company uuid; recipient_email text; fence_company uuid;
begin
  perform private.lock_platform_authorization();
  actor:=private.platform_actor();
  if request_id is null or jsonb_typeof(business_input) is distinct from 'object' or octet_length(business_input::text)>12000 then
    raise exception 'Invalid request' using errcode='22023'; end if;
  allowed:=case command_name
    when 'create_customer' then array['code','name','contact_email']
    when 'update_customer' then array['id','version','name','contact_email']
    when 'create_entity' then array['code','name','legal_name','trn','address','tenant_slug','locale','customer_id','entity_kind','region','initial_admin_id']
    when 'update_entity' then array['id','version','name','legal_name','trn','address','customer_id','entity_kind','region','plan_key']
    when 'set_lifecycle' then array['id','version','state','reason']
    when 'set_membership' then array['company_id','user_id','role','version','reason']
    when 'set_user_status' then array['id','version','status','reason']
    when 'update_settings' then array['version','support_email','notice_en','notice_ar']
    else null end;
  if allowed is null then raise exception 'Unsupported command' using errcode='22023'; end if;
  for k,v in select * from jsonb_each(business_input) loop
    if k<>all(allowed) or jsonb_typeof(v) not in ('string','null') then
      raise exception 'Unsupported field' using errcode='22023'; end if;
    if v<>'null'::jsonb and nullif(btrim(v#>>'{}'),'') is not null then
      p:=p||jsonb_build_object(k,case when k='contact_email' or k='support_email' then lower(btrim(v#>>'{}')) else btrim(v#>>'{}') end);
    end if;
  end loop;
  command_hash:=sha256(convert_to(command_name||':'||p::text,'UTF8'));
  insert into private.platform_requests(actor_id,request_id,command_name,request_hash)
    values(actor,request_id,command_name,command_hash) on conflict do nothing;
  select * into prior from private.platform_requests r where r.actor_id=actor and r.request_id=platform_admin_command.request_id for update;
  if prior.request_hash<>command_hash or prior.command_name<>command_name then
    raise exception 'Idempotency mismatch' using errcode='22023'; end if;
  if prior.receipt is not null then return prior.receipt; end if;

  if command_name in ('create_customer','update_customer') then
    label:=private.platform_text(p,'name');
    if p ? 'contact_email' and p->>'contact_email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception 'Invalid email' using errcode='22023'; end if;
    if command_name='create_customer' then
      insert into private.platform_customers(code,name,contact_email)
        values(private.platform_text(p,'code',50),label,private.platform_text(p,'contact_email',254,false)) returning id into target;
    else
      target:=(p->>'id')::uuid; expected:=(p->>'version')::integer;
      update private.platform_customers set name=label,contact_email=private.platform_text(p,'contact_email',254,false),version=version+1
        where id=target and version=expected;
      if not found then raise exception 'Stale customer' using errcode='40001'; end if;
    end if;
  elsif command_name='create_entity' then
    label:=private.platform_text(p,'name');
    if coalesce(p->>'entity_kind','') not in ('BUSINESS','PERSONAL') or coalesce(p->>'locale','') not in ('en','ar')
       or coalesce(p->>'tenant_slug','') !~ '^[a-z0-9]+(-[a-z0-9]+)*$' then
      raise exception 'Invalid entity kind, locale or slug' using errcode='22023'; end if;
    customer:=(p->>'customer_id')::uuid; uid:=(p->>'initial_admin_id')::uuid;
    if uid is not null then
      perform private.lock_platform_user(uid);
      if uid=actor or exists(select 1 from private.system_administrators where user_id=uid) then
        raise exception 'Platform identity cannot enroll in accounting' using errcode='42501'; end if;
      perform 1 from public.profiles where user_id=uid and status='ACTIVE' for share;
      if not found then raise exception 'Initial admin identity unavailable' using errcode='22023'; end if;
    end if;
    insert into public.companies(code,name,legal_name,trn,address,status,created_by,updated_by)
      values(private.platform_text(p,'code',50),label,private.platform_text(p,'legal_name',200,false),
        private.platform_text(p,'trn',100,false),private.platform_text(p,'address',1000,false),'INACTIVE',actor,actor) returning id into target;
    insert into public.company_settings(company_id,tenant_slug,default_locale,created_by,updated_by)
      values(target,private.platform_text(p,'tenant_slug',63),(p->>'locale')::public.app_locale,actor,actor);
    insert into private.platform_entities(company_id,customer_id,entity_kind,lifecycle,onboarding,region)
      values(target,customer,p->>'entity_kind','DRAFT',case when uid is null then 'PENDING_ADMIN' else 'ADMIN_ASSIGNED' end,private.platform_text(p,'region',100,false));
    if uid is not null then membership:=private.platform_member(actor,target,uid,'ACCOUNTING_ADMIN',request_id); end if;
  elsif command_name in ('update_entity','set_lifecycle','set_membership') then
    cid:=coalesce(p->>'id',p->>'company_id')::uuid; expected:=(p->>'version')::integer;
    if command_name='set_membership' then perform private.lock_platform_user((p->>'user_id')::uuid); end if;
    perform 1 from public.companies where id=cid for update;
    if not found then raise exception 'Entity not found' using errcode='22023'; end if;
    select * into entity from private.platform_entities where company_id=cid for update;
    -- Adopt administrative metadata lazily; never classify or move existing books.
    if not found and expected=0 then
      insert into private.platform_entities(company_id,lifecycle,onboarding)
        select c.id,case when c.status='ACTIVE' then 'ACTIVE' else 'SUSPENDED' end,
          case when exists(select 1 from public.company_memberships m where m.company_id=cid and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE') then 'ADMIN_ASSIGNED' else 'PENDING_ADMIN' end
        from public.companies c where c.id=cid returning * into entity;
      expected:=1;
    end if;
    if expected is null or entity.version is distinct from expected then
      raise exception 'Stale entity' using errcode='40001'; end if;
    target:=cid;
    if command_name='update_entity' then
      if coalesce(p->>'entity_kind','') not in ('BUSINESS','PERSONAL') or coalesce(p->>'plan_key','') not in ('UNASSIGNED','TRIAL','STANDARD') then
        raise exception 'Invalid classification or plan' using errcode='22023'; end if;
      update public.companies set name=private.platform_text(p,'name'),legal_name=private.platform_text(p,'legal_name',200,false),
        trn=private.platform_text(p,'trn',100,false),address=private.platform_text(p,'address',1000,false),updated_by=actor where id=cid;
      update private.platform_entities set customer_id=(p->>'customer_id')::uuid,entity_kind=p->>'entity_kind',
        region=private.platform_text(p,'region',100,false),plan_key=p->>'plan_key' where company_id=cid;
    elsif command_name='set_membership' then
      reason:=private.platform_text(p,'reason',500);
      membership:=private.platform_member(actor,cid,(p->>'user_id')::uuid,p->>'role',request_id);
      select lower(email) into recipient_email from auth.users where id=(p->>'user_id')::uuid;
      perform private.invalidate_platform_invitations(cid,recipient_email,actor,request_id,reason,(p->>'user_id')::uuid);
      update private.platform_entities set onboarding='ADMIN_ASSIGNED' where company_id=cid and exists(
        select 1 from public.company_memberships m join public.profiles f on f.user_id=m.user_id
        where m.company_id=cid and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and f.status='ACTIVE');
    else
      reason:=private.platform_text(p,'reason',500); next_status:=p->>'state'; old_status:=entity.lifecycle;
      if next_status is null or not (
        (old_status='DRAFT' and next_status in ('ACTIVE','ARCHIVED')) or
        (old_status='ACTIVE' and next_status in ('SUSPENDED','ARCHIVED')) or
        (old_status='SUSPENDED' and next_status in ('ACTIVE','ARCHIVED')) or
        (old_status='ARCHIVED' and next_status='SUSPENDED')) then
        raise exception 'Invalid lifecycle transition' using errcode='23514'; end if;
      if next_status='ACTIVE' and not exists(select 1 from public.company_memberships m join public.profiles f on f.user_id=m.user_id
        where m.company_id=cid and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and f.status='ACTIVE') then
        raise exception 'Active Accounting Admin required' using errcode='23514'; end if;
      update public.companies set status=case when next_status='ACTIVE' then 'ACTIVE'::public.account_status else 'INACTIVE'::public.account_status end,
        updated_by=actor where id=cid;
      update private.platform_entities set lifecycle=next_status where company_id=cid;
      if next_status in ('SUSPENDED','ARCHIVED') then
        for recipient_email in select distinct email from private.platform_invitations where company_id=cid loop
          if recipient_email is not null then perform private.invalidate_platform_invitations(cid,recipient_email,actor,request_id,reason); end if;
        end loop;
      end if;
    end if;
    update private.platform_entities set version=version+1 where company_id=cid;
  elsif command_name='set_user_status' then
    target:=(p->>'id')::uuid; reason:=private.platform_text(p,'reason',500); next_status:=p->>'status';
    if target is null or target=actor or exists(select 1 from private.system_administrators where user_id=target) then
      raise exception 'Privileged identity administration requires protected recovery' using errcode='42501'; end if;
    perform private.lock_platform_user(target);
    if next_status is null or next_status not in ('ACTIVE','INACTIVE') then raise exception 'Invalid status' using errcode='22023'; end if;
    -- Lock affected Companies in deterministic order, matching membership commands.
    for locked_company in select c.id from public.companies c where exists(
      select 1 from public.company_memberships m where m.company_id=c.id and m.user_id=target and m.status='ACTIVE') order by c.id for update of c loop
      if next_status='INACTIVE' and exists(select 1 from public.company_memberships m where m.company_id=locked_company and m.user_id=target and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE')
        and not exists(select 1 from public.company_memberships m join public.profiles f on f.user_id=m.user_id where m.company_id=locked_company and m.user_id<>target and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and f.status='ACTIVE') then
        raise exception 'Last active Accounting Admin must be replaced first' using errcode='23514'; end if;
    end loop;
    select status::text into old_status from public.profiles where user_id=target for update;
    update public.profiles set status=next_status::public.account_status
      where user_id=target and updated_at=(p->>'version')::timestamptz;
    if not found then raise exception 'Stale user profile' using errcode='40001'; end if;
    if next_status='INACTIVE' then
      select lower(email) into recipient_email from auth.users where id=target;
      for fence_company in select distinct company_id from private.platform_invitations where email=recipient_email or recipient_user_id=target
        union select company_id from public.company_memberships where user_id=target loop
        perform private.invalidate_platform_invitations(fence_company,recipient_email,actor,request_id,reason,target);
      end loop;
      delete from auth.sessions where user_id=target;
    end if;
  elsif command_name='update_settings' then
    expected:=(p->>'version')::integer;
    if p ? 'support_email' and p->>'support_email' !~ '^[^[:space:]@]+@[^[:space:]@]+\.[^[:space:]@]+$' then
      raise exception 'Invalid support email' using errcode='22023'; end if;
    update private.platform_settings set support_email=private.platform_text(p,'support_email',254,false),
      notice_en=coalesce(private.platform_text(p,'notice_en',500,false),''),notice_ar=coalesce(private.platform_text(p,'notice_ar',500,false),''),version=version+1
      where singleton and version=expected;
    if not found then raise exception 'Stale settings' using errcode='40001'; end if;
    target:=actor;
  end if;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(actor,command_name,target,request_id,jsonb_strip_nulls(jsonb_build_object('reason',reason,'from',old_status,'to',next_status,
      'fields',to_jsonb(array(select jsonb_object_keys(p))),'expected_version',p->>'version')));
  result:=jsonb_build_object('id',target,'request_id',request_id,'command',command_name,'status','CONFIRMED');
  update private.platform_requests r set receipt=result where r.actor_id=actor and r.request_id=platform_admin_command.request_id;
  return result;
end $$;


create or replace function public.platform_invitation_command(command_name text,request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; p jsonb:='{}'; k text; v jsonb; allowed text[];
  h bytea; prior private.platform_requests; inv private.platform_invitations; target uuid; result jsonb;
begin
  perform private.lock_platform_authorization();
  actor:=private.platform_actor();
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
    update private.platform_invitations i set
      access_generation=coalesce((select generation from private.platform_access_fences f where f.company_id=i.company_id and f.recipient_key='email:'||i.email),0),
      recipient_user_id=(select id from auth.users where lower(email)=i.email),
      recipient_generation=coalesce((select f.generation from private.platform_access_fences f join auth.users u
        on f.recipient_key='user:'||u.id::text where f.company_id=i.company_id and lower(u.email)=i.email),0),
      recipient_epoch=coalesce((select f.platform_access_epoch from auth.users u join public.profiles f on f.user_id=u.id where lower(u.email)=i.email),0),
      issuer_epoch=(select platform_access_epoch from private.system_administrators where user_id=actor),
      issuer_profile_epoch=(select platform_access_epoch from public.profiles where user_id=actor)
      where i.id=target;
    select * into inv from private.platform_invitations where id=target;
    perform private.check_platform_invitation_authority(inv);
    insert into private.platform_delivery_jobs(invitation_id) values(target);
  else
    target:=(p->>'id')::uuid;
    select * into inv from private.platform_invitations where id=target for update;
    if inv.id is null or inv.version is distinct from (p->>'version')::integer or inv.state<>'PENDING' then
      raise exception 'Stale invitation' using errcode='40001'; end if;
    if command_name='resend' then perform private.check_platform_invitation_authority(inv,true); end if;
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
create or replace function public.accept_platform_invitation(invitation_id uuid) returns uuid
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); email text; inv private.platform_invitations; result uuid; cid uuid;
begin
  perform private.lock_platform_authorization();
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
  perform private.check_platform_invitation_authority(inv);
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
  update private.platform_entities set onboarding=case when inv.role='ACCOUNTING_ADMIN' then 'ADMIN_ASSIGNED' else onboarding end,version=version+1
    where company_id=cid;
  update private.platform_delivery_jobs j set state='CANCELLED',lease_id=null,leased_until=null,updated_at=now() where j.invitation_id=inv.id and j.state<>'DELIVERED';
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(actor,'INVITATION_ACCEPTED',inv.id,inv.id,jsonb_build_object('company_id',cid,'membership_id',result));
  return cid;
end $$;
create or replace function public.claim_platform_delivery(invitation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid; inv private.platform_invitations; job private.platform_delivery_jobs; lease uuid:=gen_random_uuid();
begin
  perform private.lock_platform_authorization();
  actor:=private.platform_actor();
  select * into inv from private.platform_invitations where id=invitation_id for update;
  if inv.id is null or inv.state<>'PENDING' or inv.expires_at<=now() then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  perform private.check_platform_invitation_authority(inv);
  select * into job from private.platform_delivery_jobs where platform_delivery_jobs.invitation_id=claim_platform_delivery.invitation_id for update;
  if job.state not in ('QUEUED','FAILED') and not(job.state='DELIVERING' and job.leased_until<now()) then
    raise exception 'Delivery unavailable' using errcode='40001'; end if;
  update private.platform_delivery_jobs set state='DELIVERING',delivery_actor_id=actor,lease_id=lease,leased_until=now()+interval '2 minutes',attempts=attempts+1,updated_at=now()
    where platform_delivery_jobs.invitation_id=inv.id;
  insert into private.platform_events(actor_id,action,target_id,request_id) values(actor,'INVITATION_DELIVERY_STARTED',inv.id,lease);
  return jsonb_build_object('id',inv.id,'email',inv.email,'lease_id',lease);
end $$;
create or replace function public.finish_platform_delivery(invitation_id uuid,lease_id uuid,outcome text) returns void
language plpgsql security definer set search_path='' as $$
declare inv private.platform_invitations; delivery_actor uuid;
begin
  perform private.lock_platform_authorization();
  if outcome<>all(array['DELIVERED','AUTH_DELIVERY_FAILED','CONFIGURATION_REQUIRED','DELIVERY_UNCERTAIN']) or outcome is null then
    raise exception 'Invalid delivery result' using errcode='22023'; end if;
  select * into inv from private.platform_invitations where id=invitation_id for update;
  perform private.check_platform_invitation_authority(inv);
  if inv.state<>'PENDING' then raise exception 'Invitation unavailable' using errcode='40001'; end if;
  update private.platform_delivery_jobs j set state=case when outcome='DELIVERED' then 'DELIVERED' else 'FAILED' end,
    error_code=case when outcome='DELIVERED' then null else outcome end,lease_id=null,leased_until=null,updated_at=now()
    where j.invitation_id=finish_platform_delivery.invitation_id and j.lease_id=finish_platform_delivery.lease_id and j.state='DELIVERING' and j.leased_until>now()
    returning j.delivery_actor_id into delivery_actor;
  if not found then raise exception 'Stale delivery lease' using errcode='40001'; end if;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(delivery_actor,'INVITATION_DELIVERY_RESULT',inv.id,lease_id,jsonb_build_object('outcome',outcome,'source','AUTH_SERVICE'));
end $$;
create or replace function public.list_platform_invitations(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_actor();
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
