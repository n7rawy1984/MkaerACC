-- P6C Slice 10: existing Treasury display name UPDATE only.
-- Preserve P4 treasury.manage RLS, trusted provisioning and all financial fields.
-- Browser creation/code/type/Project/GL/bank/reference/notes/status writes remain excluded.
revoke insert, update, delete, truncate on public.treasury_accounts from authenticated;
grant update (name) on public.treasury_accounts to authenticated;

drop trigger treasury_accounts_set_updated_at on public.treasury_accounts;
create function public.prepare_treasury_display_name_update()
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
    raise exception 'Treasury creation provenance is immutable' using errcode = '23514';
  end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Treasury actor required' using errcode = '42501';
    end if;
    new.updated_by := auth.uid();
  end if;
  new.name := btrim(new.name, trim_chars);
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_treasury_display_name_update() from public, anon, authenticated, service_role;
-- INSERT/defaults/trusted provisioning provenance are deliberately untouched.
create trigger treasury_accounts_prepare_name_update before update on public.treasury_accounts
  for each row execute function public.prepare_treasury_display_name_update();

do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.treasury_accounts', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Treasury write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.treasury_accounts'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.treasury_accounts', c.attname, 'INSERT')
       or has_column_privilege('authenticated', 'public.treasury_accounts', c.attname, 'UPDATE')
       <> (c.attname = any(array['name'])) then
      raise exception 'Unexpected Treasury column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
