-- P6C Slice 7: existing Company metadata only. No identity/status/branding writes.
-- Preserve companies_update_config_admin and forced RLS; company.manage remains
-- ACCOUNTING_ADMIN and SYSTEM_ADMIN within their own active membership.
revoke insert, update, delete, truncate on public.companies from authenticated;
grant update (legal_name, trn, address, notes) on public.companies to authenticated;

drop trigger companies_set_updated_at on public.companies;
create function public.prepare_company_profile_update()
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
    raise exception 'Company creation provenance is immutable' using errcode = '23514';
  end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Company actor required' using errcode = '42501';
    end if;
    new.updated_by := auth.uid();
  end if;
  new.legal_name := nullif(btrim(new.legal_name, trim_chars), '');
  new.trn := nullif(btrim(new.trn, trim_chars), '');
  new.address := nullif(btrim(new.address, trim_chars), '');
  new.notes := nullif(btrim(new.notes, trim_chars), '');
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_company_profile_update() from public, anon, authenticated, service_role;
-- INSERT/defaults/trusted provisioning provenance are deliberately untouched.
create trigger companies_prepare_profile_update before update on public.companies
  for each row execute function public.prepare_company_profile_update();

do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.companies', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Company write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.companies'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.companies', c.attname, 'INSERT')
       or has_column_privilege('authenticated', 'public.companies', c.attname, 'UPDATE')
       <> (c.attname = any(array['legal_name','trn','address','notes'])) then
      raise exception 'Unexpected Company column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
