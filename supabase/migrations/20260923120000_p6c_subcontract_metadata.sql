-- P6C Slice 16: existing Subcontract descriptive metadata UPDATE only.
-- Contract identity, ownership, economics, status and provenance remain protected.
revoke insert, update, delete, truncate on public.subcontracts from authenticated;
grant update (scope_of_work, start_date, expected_end_date, notes) on public.subcontracts to authenticated;

drop trigger subcontracts_set_updated_at on public.subcontracts;

create function public.prepare_subcontract_metadata_update()
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
    raise exception 'Subcontract creation provenance is immutable' using errcode = '23514';
  end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Subcontract actor required' using errcode = '42501';
    end if;
    new.updated_by := auth.uid();
  end if;
  new.scope_of_work := btrim(new.scope_of_work, trim_chars);
  new.notes := nullif(btrim(new.notes, trim_chars), '');
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;

revoke all on function public.prepare_subcontract_metadata_update() from public, anon, authenticated, service_role;

create trigger subcontracts_prepare_metadata_update before update on public.subcontracts
  for each row execute function public.prepare_subcontract_metadata_update();

do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.subcontracts', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Subcontract write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.subcontracts'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.subcontracts', c.attname, 'INSERT')
       or has_column_privilege('authenticated', 'public.subcontracts', c.attname, 'UPDATE')
          <> (c.attname = any(array['scope_of_work','start_date','expected_end_date','notes'])) then
      raise exception 'Unexpected Subcontract column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
