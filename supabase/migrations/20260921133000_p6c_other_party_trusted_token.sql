-- Forward correction: OTHER tokens must also advance after trusted updates.
-- Preserve trusted INSERT/provisioning and all permitted metadata/actor inputs.
-- Browser name-only guard and normalization, policies/grants remain unchanged.
create or replace function public.prepare_other_party_name_update()
returns trigger language plpgsql security invoker set search_path = ''
as $$
declare
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if old.type <> 'OTHER' then return new; end if;
  if current_user = 'authenticated' then
    if auth.uid() is null then
      raise exception 'Authenticated Party actor required' using errcode = '42501';
    end if;
    -- Runs after Slice 6 preparation, which stamps non-Supplier updated_at.
    -- Exempt only that token and name; all other columns must remain unchanged.
    if (to_jsonb(new) - array['name','updated_at']) is distinct from
       (to_jsonb(old) - array['name','updated_at']) then
      raise exception 'OTHER Party updates allow name only' using errcode = '42501';
    end if;
    new.name := btrim(new.name, trim_chars);
    new.updated_by := auth.uid();
  end if;
  new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  return new;
end;
$$;
revoke all on function public.prepare_other_party_name_update() from public, anon, authenticated, service_role;
