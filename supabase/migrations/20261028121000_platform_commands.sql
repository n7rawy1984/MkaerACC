-- Administrative use cases only; no journal/GL/treasury/source mutations.
create function private.platform_text(p jsonb,k text,max_length integer default 200,required boolean default true)
returns text language plpgsql set search_path='' as $$
declare v text := nullif(btrim(p->>k),''); begin
  if (required and v is null) or length(v)>max_length then
    raise exception 'Invalid %',k using errcode='22023'; end if;
  return v;
end $$;

-- Serialize membership grants with whole-user deactivation before enumerating
-- Companies, including a concurrent grant into a previously unrelated Company.
create function private.lock_platform_user(target_user uuid) returns void
language sql set search_path='' as $$
  select pg_advisory_xact_lock(hashtextextended('platform-user:'||target_user::text,0));
$$;

create function private.platform_member(actor uuid,cid uuid,uid uuid,new_role text,request_id uuid)
returns uuid language plpgsql security definer set search_path='' as $$
declare current_membership public.company_memberships; result uuid;
begin
  if uid is null or uid=actor or exists(select 1 from private.system_administrators where user_id=uid) then
    raise exception 'Self/privileged membership assignment denied' using errcode='42501'; end if;
  if new_role <> all(array['ACCOUNTING_ADMIN','ACCOUNTANT','PROJECT_MANAGER','DATA_ENTRY','PROCUREMENT','MANAGEMENT_VIEWER','FOREMAN','REVOKED'])
     or new_role is null then raise exception 'Role denied' using errcode='22023'; end if;
  perform private.lock_platform_user(uid);
  -- Single Company lock serializes all membership and lifecycle operations.
  perform 1 from public.companies where id=cid for update;
  if not found then raise exception 'Entity not found' using errcode='22023'; end if;
  perform 1 from public.profiles where user_id=uid and (new_role='REVOKED' or status='ACTIVE') for share;
  if not found then raise exception 'Active existing identity required' using errcode='22023'; end if;
  select * into current_membership from public.company_memberships
    where company_id=cid and user_id=uid and status='ACTIVE' for update;
  if current_membership.role='ACCOUNTING_ADMIN' and new_role<>'ACCOUNTING_ADMIN' and not exists(
    select 1 from public.company_memberships m join public.profiles p on p.user_id=m.user_id
    where m.company_id=cid and m.user_id<>uid and m.role='ACCOUNTING_ADMIN' and m.status='ACTIVE' and p.status='ACTIVE') then
    raise exception 'Last active Accounting Admin must be replaced first' using errcode='23514'; end if;
  if new_role='REVOKED' then
    if current_membership.id is null then raise exception 'Active membership required' using errcode='22023'; end if;
    update public.company_memberships set status='INACTIVE',updated_by=actor where id=current_membership.id;
    result:=current_membership.id;
  elsif current_membership.id is null then
    insert into public.company_memberships(company_id,user_id,role,status,created_by,updated_by)
      values(cid,uid,new_role::public.company_role,'ACTIVE',actor,actor) returning id into result;
  else
    update public.company_memberships set role=new_role::public.company_role,updated_by=actor where id=current_membership.id;
    result:=current_membership.id;
  end if;
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(actor,'MEMBERSHIP_CHANGED',result,request_id,
      jsonb_build_object('company_id',cid,'user_id',uid,'previous_role',current_membership.role,'role',new_role));
  return result;
end $$;

create function public.platform_admin_command(command_name text,request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=private.platform_actor(); p jsonb:='{}'; k text; v jsonb;
  allowed text[]; command_hash bytea; prior private.platform_requests; result jsonb;
  target uuid; cid uuid; uid uuid; customer uuid; entity private.platform_entities;
  old_status text; next_status text; expected integer; reason text; label text; membership uuid; locked_company uuid;
begin
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
    if next_status='INACTIVE' then delete from auth.sessions where user_id=target; end if;
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

create function public.platform_directory(resource text,page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb; begin
  perform private.platform_actor();
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

revoke all on function private.platform_text(jsonb,text,integer,boolean),private.platform_member(uuid,uuid,uuid,text,uuid),private.lock_platform_user(uuid)
  from public,anon,authenticated,service_role;
revoke all on function public.platform_admin_command(text,uuid,jsonb),public.platform_directory(text,integer,integer,text)
  from public,anon,authenticated,service_role;
grant execute on function public.platform_admin_command(text,uuid,jsonb),public.platform_directory(text,integer,integer,text) to authenticated;
