-- P6C Slice 6: intentionally narrow authenticated Party writes to Suppliers.
-- Prepared only. Apply through canonical Development migration workflow.
revoke insert, update, delete, truncate on public.parties from authenticated;
grant insert (company_id, name, code, trn, contact_person, phone, email, address, notes)
  on public.parties to authenticated;
grant update (name, code, trn, contact_person, phone, email, address, notes, status)
  on public.parties to authenticated;

-- Restrictive policies AND the existing P4 permission/role policies together.
-- SELECT and trusted operations are unchanged.
create policy parties_insert_supplier_only on public.parties
  as restrictive for insert to authenticated
  with check (type = 'SUPPLIER');
create policy parties_update_supplier_only on public.parties
  as restrictive for update to authenticated
  using (type = 'SUPPLIER') with check (type = 'SUPPLIER');

drop trigger parties_set_updated_at on public.parties;
create function public.prepare_supplier_party_mutation()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
declare
  -- Exactly JavaScript String.trim whitespace, including Unicode separators.
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if tg_op = 'INSERT' and current_user = 'authenticated' then
    new.type := 'SUPPLIER';
    new.status := 'ACTIVE';
  end if;

  -- Preserve old trusted non-Supplier INSERT/default and UPDATE/now semantics.
  -- Supplier-touching includes trusted type transitions in either direction;
  -- existing subcontractor-type protection remains independently authoritative.
  if new.type is distinct from 'SUPPLIER'::public.party_type then
    if tg_op = 'INSERT' then return new; end if;
    if old.type is distinct from 'SUPPLIER'::public.party_type then
      new.updated_at := now();
      return new;
    end if;
  end if;

  if new.type = 'SUPPLIER' then
    new.name := btrim(new.name, trim_chars);
    new.code := nullif(btrim(new.code, trim_chars), '');
    new.trn := nullif(btrim(new.trn, trim_chars), '');
    new.contact_person := nullif(btrim(new.contact_person, trim_chars), '');
    new.phone := nullif(btrim(new.phone, trim_chars), '');
    new.email := nullif(btrim(new.email, trim_chars), '');
    new.address := nullif(btrim(new.address, trim_chars), '');
    new.notes := nullif(btrim(new.notes, trim_chars), '');
  end if;

  if current_user = 'authenticated' and auth.uid() is null then
    raise exception 'Authenticated Supplier actor required' using errcode = '42501';
  end if;
  if tg_op = 'INSERT' then
    if current_user = 'authenticated' then
      new.created_by := auth.uid();
      new.updated_by := auth.uid();
      new.created_at := clock_timestamp();
      new.updated_at := new.created_at;
    end if;
  else
    if new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Supplier creation provenance is immutable' using errcode = '23514';
    end if;
    if current_user = 'authenticated' then new.updated_by := auth.uid(); end if;
    new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  end if;
  return new;
end;
$$;
revoke all on function public.prepare_supplier_party_mutation() from public, anon, authenticated, service_role;
create trigger parties_prepare_supplier_mutation before insert or update on public.parties
  for each row execute function public.prepare_supplier_party_mutation();

-- Fail closed on residual/inherited column or table grants.
do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.parties', 'INSERT,UPDATE,DELETE,TRUNCATE') then
    raise exception 'Unexpected broad Party write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.parties'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.parties', c.attname, 'INSERT')
       <> (c.attname = any(array['company_id','name','code','trn','contact_person','phone','email','address','notes']))
       or has_column_privilege('authenticated', 'public.parties', c.attname, 'UPDATE')
       <> (c.attname = any(array['name','code','trn','contact_person','phone','email','address','notes','status'])) then
      raise exception 'Unexpected Party column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
