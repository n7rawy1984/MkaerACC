-- P6C Slice 12: existing EMPLOYEE Party display name only.
-- Existing Supplier/OTHER grants and behavior are unchanged. Column grants
-- are shared across Party types, so the trigger enforces the EMPLOYEE scope.
drop policy parties_update_supplier_or_other on public.parties;
create policy parties_update_supplier_other_or_employee on public.parties
  as restrictive for update to authenticated
  using (type in ('SUPPLIER', 'OTHER', 'EMPLOYEE'))
  with check (type in ('SUPPLIER', 'OTHER', 'EMPLOYEE'));

create function public.prepare_employee_party_name_update()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if old.type <> 'EMPLOYEE' then return new; end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Party actor required' using errcode = '42501';
    end if;
    -- Runs after Supplier preparation, which stamps non-Supplier updated_at.
    if (to_jsonb(new) - array['name','updated_at']) is distinct from
       (to_jsonb(old) - array['name','updated_at']) then
      raise exception 'EMPLOYEE Party updates allow name only' using errcode = '42501';
    end if;
    new.name := btrim(new.name, trim_chars);
    new.updated_by := auth.uid();
  end if;
  -- Trusted provisioning keeps its metadata/actor inputs, but cannot reuse a token.
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_employee_party_name_update() from public, anon, authenticated, service_role;
create trigger parties_prepare_y_employee_name before update on public.parties
  for each row execute function public.prepare_employee_party_name_update();
