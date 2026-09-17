-- P6C Slice 8: existing Project descriptive metadata UPDATE only.
-- Preserve P4 role/assignment RLS, trusted provisioning and all financial fields.
-- Browser creation/status/dates/code/amounts remain outside this slice.
revoke insert, update, delete, truncate on public.projects from authenticated;
grant update (name, client_name, location, contract_number, notes) on public.projects to authenticated;

drop trigger projects_set_updated_at on public.projects;
create function public.prepare_project_metadata_update()
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
    raise exception 'Project creation provenance is immutable' using errcode = '23514';
  end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Project actor required' using errcode = '42501';
    end if;
    new.updated_by := auth.uid();
  end if;
  new.name := btrim(new.name, trim_chars);
  new.client_name := nullif(btrim(new.client_name, trim_chars), '');
  new.location := nullif(btrim(new.location, trim_chars), '');
  new.contract_number := nullif(btrim(new.contract_number, trim_chars), '');
  new.notes := nullif(btrim(new.notes, trim_chars), '');
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_project_metadata_update() from public, anon, authenticated, service_role;
-- INSERT/defaults/trusted provisioning provenance are deliberately untouched.
create trigger projects_prepare_metadata_update before update on public.projects
  for each row execute function public.prepare_project_metadata_update();

do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.projects', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Project write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.projects'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.projects', c.attname, 'INSERT')
       or has_column_privilege('authenticated', 'public.projects', c.attname, 'UPDATE')
       <> (c.attname = any(array['name','client_name','location','contract_number','notes'])) then
      raise exception 'Unexpected Project column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
