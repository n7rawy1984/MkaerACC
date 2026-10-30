-- REVIEW ONLY: owner intent is confirmed; execution approval is NOT yet given.
-- Operational data correction, NOT a migration. No account creation or schema change.
-- Never execute standalone: the protected operator must first verify project
-- eqnzueginpkskbnqvgoc / MakerACC-Development and obtain explicit approval.
-- Only that verified executor may set the two transaction-local settings below.
begin;
set local lock_timeout = '5s';
set local statement_timeout = '15s';
do $transfer$
declare
  previous_owner constant uuid := 'e1ef565b-c54d-4b52-bba3-360a03da7aa3';
  intended_owner constant uuid := 'ebcf7115-6cd9-49be-af25-8e57b5befd75';
  operation_id constant uuid := 'd362061b-17d0-4eb2-9a9b-3d690fc8a817';
  previous_epoch bigint;
  affected integer;
begin
  if current_user <> 'postgres' then
    raise exception 'Protected postgres operator required' using errcode='42501';
  end if;
  if current_setting('narvo.verified_project_ref',true) is distinct from 'eqnzueginpkskbnqvgoc'
     or current_setting('narvo.owner_transfer_approval',true) is distinct from operation_id::text then
    raise exception 'Verified Development target and explicit transfer approval required' using errcode='42501';
  end if;
  -- These settings are operator guardrails, not proof of browser authentication.
  -- They must be supplied only AFTER real external identity/approval checks.
  perform private.lock_platform_authorization();
  lock table private.system_administrators in share row exclusive mode;
  if (select count(*) from private.system_administrators) <> 1 then
    raise exception 'Registry inventory changed; stop for review' using errcode='23514';
  end if;
  select platform_access_epoch into previous_epoch
    from private.system_administrators
    where user_id=previous_owner and status='ACTIVE' and platform_role='PLATFORM_OWNER'
    for update;
  if not found then
    raise exception 'Previously approved owner state changed' using errcode='23514';
  end if;
  if exists(select 1 from private.system_administrators where user_id=intended_owner)
     or exists(select 1 from private.platform_events where request_id=operation_id) then
    raise exception 'Transfer already executed or target history changed' using errcode='23514';
  end if;
  -- Lock authoritative existing identities/profiles; never replace or rekey them.
  perform 1 from auth.users where id in (previous_owner,intended_owner) order by id for share;
  get diagnostics affected=row_count;
  if affected<>2 then raise exception 'Existing Auth identity missing' using errcode='23514'; end if;
  perform 1 from public.profiles where user_id in (previous_owner,intended_owner)
    and status='ACTIVE' order by user_id for share;
  get diagnostics affected=row_count;
  if affected<>2 then raise exception 'Existing ACTIVE profile missing' using errcode='23514'; end if;
  if not exists(select 1 from auth.users where id=intended_owner
     and email_confirmed_at is not null and (banned_until is null or banned_until<=clock_timestamp())) then
    raise exception 'Target identity is unconfirmed or banned' using errcode='23514';
  end if;
  if exists(select 1 from public.company_memberships where user_id in (previous_owner,intended_owner)) then
    raise exception 'Expected zero Company memberships changed; stop for review' using errcode='23514';
  end if;

  update private.system_administrators set status='INACTIVE',updated_by=intended_owner
    where user_id=previous_owner and status='ACTIVE' and platform_role='PLATFORM_OWNER';
  -- Existing trigger advances the old authority epoch; no trigger bypass.
  insert into private.system_administrators(user_id,status,platform_role,created_by,updated_by)
    values(intended_owner,'ACTIVE','PLATFORM_OWNER',intended_owner,intended_owner);
  insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
    values(intended_owner,'platform_owner_transferred',intended_owner,operation_id,
      jsonb_build_object('previous_owner',previous_owner,'intended_owner',intended_owner,
        'project_ref','eqnzueginpkskbnqvgoc','execution_role',current_user,
        'execution_method','protected_operator_owner_approved_operational_correction',
        'actor_attribution','approving product owner selected this existing Auth identity; not target JWT/MFA authentication',
        'application_mfa_bypassed',false));

  if (select count(*) from private.system_administrators where status='ACTIVE')<>1
     or not exists(select 1 from private.system_administrators where user_id=intended_owner
       and status='ACTIVE' and platform_role='PLATFORM_OWNER')
     or not exists(select 1 from private.system_administrators where user_id=previous_owner
       and status='INACTIVE' and platform_access_epoch=previous_epoch+1)
     or exists(select 1 from public.company_memberships where user_id in (previous_owner,intended_owner)) then
    raise exception 'Transfer postconditions failed' using errcode='23514';
  end if;
end
$transfer$;
commit;
