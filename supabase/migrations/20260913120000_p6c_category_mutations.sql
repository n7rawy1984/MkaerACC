-- P6C Slice 5: category-only browser business fields and database provenance.
revoke insert, update on public.expense_categories from authenticated;
grant insert (company_id, code, name, description) on public.expense_categories to authenticated;
grant update (code, name, description, status) on public.expense_categories to authenticated;

drop trigger expense_categories_set_updated_at on public.expense_categories;

create function public.prepare_expense_category_mutation()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  new.code := btrim(new.code);
  new.name := btrim(new.name);
  new.description := nullif(btrim(new.description), '');

  if tg_op = 'INSERT' then
    -- Actual invoker role, not JWT presence, distinguishes browser provenance.
    if current_user = 'authenticated' then
      if auth.uid() is null then
        raise exception 'Authenticated category actor required' using errcode = '42501';
      end if;
      new.created_by := auth.uid();
      new.updated_by := auth.uid();
      new.created_at := clock_timestamp();
      new.updated_at := new.created_at;
    end if;
    -- Trusted insertion retains supplied/default historical timestamps and actors.
  else
    if new.created_by is distinct from old.created_by
       or new.created_at is distinct from old.created_at then
      raise exception 'Category creation provenance is immutable' using errcode = '23514';
    end if;
    if current_user = 'authenticated' then
      if auth.uid() is null then
        raise exception 'Authenticated category actor required' using errcode = '42501';
      end if;
      new.updated_by := auth.uid();
    end if;
    new.updated_at := greatest(clock_timestamp(), old.updated_at + interval '1 microsecond');
  end if;
  return new;
end;
$$;

revoke all on function public.prepare_expense_category_mutation() from public, anon, authenticated, service_role;
create trigger expense_categories_prepare_mutation
  before insert or update on public.expense_categories
  for each row execute function public.prepare_expense_category_mutation();

-- Fail the migration if inherited or residual column grants broaden the contract.
do $$
declare c record;
begin
  if has_table_privilege('authenticated', 'public.expense_categories', 'INSERT')
     or has_table_privilege('authenticated', 'public.expense_categories', 'UPDATE') then
    raise exception 'Unexpected broad category write privilege';
  end if;
  for c in select attname from pg_attribute
    where attrelid = 'public.expense_categories'::regclass and attnum > 0 and not attisdropped
  loop
    if has_column_privilege('authenticated', 'public.expense_categories', c.attname, 'INSERT')
       <> (c.attname = any(array['company_id','code','name','description']))
       or has_column_privilege('authenticated', 'public.expense_categories', c.attname, 'UPDATE')
       <> (c.attname = any(array['code','name','description','status'])) then
      raise exception 'Unexpected category column privilege: %', c.attname;
    end if;
  end loop;
end;
$$;
