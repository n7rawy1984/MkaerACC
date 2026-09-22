-- P6C Slice 14: existing OWNER Party display name only.
-- Existing Supplier/OTHER/EMPLOYEE/CUSTODIAN grants and behavior are unchanged. Column grants
-- are shared across Party types, so the trigger enforces the OWNER scope.
drop policy parties_update_supplier_other_employee_or_custodian on public.parties;
create policy parties_update_supplier_other_employee_custodian_or_owner on public.parties
  as restrictive for update to authenticated
  using (type in ('SUPPLIER', 'OTHER', 'EMPLOYEE', 'CUSTODIAN', 'OWNER'))
  with check (type in ('SUPPLIER', 'OTHER', 'EMPLOYEE', 'CUSTODIAN', 'OWNER'));

create function public.prepare_owner_party_name_update()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if old.type <> 'OWNER' then return new; end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Party actor required' using errcode = '42501';
    end if;
    -- Runs after Supplier preparation, which stamps non-Supplier updated_at.
    if (to_jsonb(new) - array['name','updated_at']) is distinct from
       (to_jsonb(old) - array['name','updated_at']) then
      raise exception 'OWNER Party updates allow name only' using errcode = '42501';
    end if;
    new.name := btrim(new.name, trim_chars);
    new.updated_by := auth.uid();
  end if;
  -- Trusted provisioning keeps its metadata/actor inputs, but cannot reuse a token.
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_owner_party_name_update() from public, anon, authenticated, service_role;
create trigger parties_prepare_w_owner_name before update on public.parties
  for each row execute function public.prepare_owner_party_name_update();
