-- P5A corrective migration: a polymorphic trigger record must branch before
-- accessing table-specific fields.

create or replace function private.enforce_journal_balance()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
declare
  target_journal_entry_id uuid;
begin
  if tg_table_name = 'journal_entries' then
    target_journal_entry_id := new.id;
  else
    target_journal_entry_id := new.journal_entry_id;
  end if;
  perform private.assert_journal_balanced(target_journal_entry_id);
  return new;
end;
$$;

revoke all on function private.enforce_journal_balance()
  from public, anon, authenticated, service_role;
