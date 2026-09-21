-- P6C Slice 9: existing Account display name UPDATE only.
-- Preserve P4 account.manage RLS, trusted provisioning and all financial fields.
-- Browser creation/code/type/hierarchy/party/system-key/status writes remain excluded.
revoke insert, update, delete, truncate on public.accounts from authenticated;
grant update (name) on public.accounts to authenticated;

drop trigger accounts_set_updated_at on public.accounts;
create function public.prepare_account_display_name_update()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  -- Exactly JavaScript String.trim whitespace; preserve internal text and case.
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if new.created_by is distinct from old.created_by
     or new.created_at is distinct from old.created_at then
    raise exception 'Account creation provenance is immutable' using errcode = '23514';
  end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Account actor required' using errcode = '42501';
    end if;
    new.updated_by := auth.uid();
  end if;
  new.name := btrim(new.name, trim_chars);
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_account_display_name_update() from public, anon, authenticated, service_role;
-- INSERT/defaults/trusted provisioning provenance are deliberately untouched.
create trigger accounts_prepare_name_update before update on public.accounts
  for each row execute function public.prepare_account_display_name_update();

do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.accounts', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Account write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.accounts'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.accounts', c.attname, 'INSERT')
       or has_column_privilege('authenticated', 'public.accounts', c.attname, 'UPDATE')
       <> (c.attname = any(array['name'])) then
      raise exception 'Unexpected Account column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
