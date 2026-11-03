-- Recipient-only onboarding read. Existing acceptance/mutation/MFA guards unchanged.
create function public.get_my_platform_invitation(invitation_id uuid) returns jsonb
language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid(); recipient_email text; needs_password boolean;
  inv private.platform_invitations; company public.companies;
begin
  if actor is null then raise exception 'Sign in required' using errcode='42501'; end if;
  select lower(u.email),coalesce(u.encrypted_password,'')='' into recipient_email,needs_password
    from auth.users u join auth.sessions s on s.user_id=u.id
    join public.profiles p on p.user_id=u.id and p.status='ACTIVE'
    where u.id=actor and u.email_confirmed_at is not null
      and (u.banned_until is null or u.banned_until<now())
      and s.id=(auth.jwt()->>'session_id')::uuid and (s.not_after is null or s.not_after>now());
  if recipient_email is null then raise exception 'Sign in required' using errcode='42501'; end if;
  select * into inv from private.platform_invitations where id=invitation_id;
  if inv.id is null or inv.email<>recipient_email or inv.state not in ('PENDING','ACCEPTED')
    or (inv.state='ACCEPTED' and inv.accepted_by is distinct from actor) then
    raise exception 'Invitation unavailable' using errcode='42501'; end if;
  perform private.check_platform_invitation_authority(inv);
  select * into company from public.companies where id=inv.company_id;
  if company.id is null then raise exception 'Invitation unavailable' using errcode='42501'; end if;
  return jsonb_build_object('user_id',actor,'invitation_id',inv.id,'company_id',company.id,
    'company_name',company.name,'role',inv.role,'state',inv.state,
    'password_required',needs_password,'company_active',company.status='ACTIVE');
end $$;
revoke all on function public.get_my_platform_invitation(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_platform_invitation(uuid) to authenticated;
