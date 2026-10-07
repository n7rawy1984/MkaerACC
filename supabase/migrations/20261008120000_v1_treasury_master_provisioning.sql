-- Treasury master data only: no GL creation, balances, journals or payment changes.
-- Existing browser DML grants, RLS and permanent mapping trigger remain intact.
create function public.create_treasury_master(target_company_id uuid, business_input jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
 actor uuid := auth.uid(); v jsonb := business_input; k text; result_id uuid;
 account_id uuid; project_id uuid; account_row public.accounts; project_status public.project_status;
 trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
  || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
  || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
  || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
 if actor is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
  or not public.has_permission(target_company_id,'treasury.manage') then
  raise exception 'Treasury creation denied' using errcode='42501';
 end if;
 if v is null or jsonb_typeof(v)<>'object' then raise exception 'Invalid input' using errcode='22023'; end if;
 for k in select jsonb_object_keys(v) loop
  if k <> all(array['code','name','type','gl_account_id','project_id','status','bank_name','account_reference','notes'])
   or jsonb_typeof(v->k) not in ('string','null') then raise exception 'Invalid input' using errcode='22023'; end if;
  v:=jsonb_set(v,array[k],coalesce(to_jsonb(nullif(btrim(v->>k,trim_chars),'')),'null'::jsonb));
 end loop;
 if v->>'code' is null or v->>'name' is null or v->>'type' is null or v->>'gl_account_id' is null then
  raise exception 'Required Treasury fields missing' using errcode='23514';
 end if;
 account_id:=(v->>'gl_account_id')::uuid; project_id:=(v->>'project_id')::uuid;
 -- Lock authoritative GL while validating; one-to-one mapping uniqueness resolves races.
 select a.* into account_row from public.accounts a
  where a.company_id=target_company_id and a.id=account_id for share;
 -- System/subledger accounts represent other business dimensions, not money locations.
 if not found or account_row.account_type<>'ASSET' or account_row.status<>'ACTIVE'
  or account_row.requires_party or account_row.system_key is not null then
  raise exception 'An active same-company non-system, non-party Asset GL is required' using errcode='23514';
 end if;
 if project_id is not null then
  select p.status into project_status from public.projects p
   where p.company_id=target_company_id and p.id=project_id for share;
  if not found or project_status='CLOSED' then raise exception 'Invalid Project' using errcode='23514'; end if;
 end if;
 insert into public.treasury_accounts(company_id,code,name,type,gl_account_id,project_id,status,bank_name,account_reference,notes,created_by,updated_by,created_at,updated_at)
 values(target_company_id,v->>'code',v->>'name',(v->>'type')::public.treasury_account_type,account_id,project_id,
  coalesce(v->>'status','ACTIVE')::public.account_status,v->>'bank_name',v->>'account_reference',v->>'notes',actor,actor,statement_timestamp(),statement_timestamp())
 returning id into result_id;
 return result_id;
end; $$;

create function public.set_treasury_master_status(target_company_id uuid, target_treasury_id uuid,
 target_status public.account_status, expected_updated_at timestamptz)
returns uuid language plpgsql security definer set search_path = '' as $$
declare actor uuid:=auth.uid(); treasury_row public.treasury_accounts;
begin
 if actor is null or not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN')
  or not public.has_permission(target_company_id,'treasury.manage') then
  raise exception 'Treasury status change denied' using errcode='42501';
 end if;
 if target_status is null or expected_updated_at is null then raise exception 'Invalid input' using errcode='22023'; end if;
 select t.* into treasury_row from public.treasury_accounts t
  where t.company_id=target_company_id and t.id=target_treasury_id for update;
 if not found then raise exception 'Treasury unavailable' using errcode='42501'; end if;
 if treasury_row.updated_at<>expected_updated_at then raise exception 'Stale Treasury' using errcode='40001'; end if;
 update public.treasury_accounts set status=target_status,updated_by=actor where id=treasury_row.id;
 return treasury_row.id;
end; $$;
revoke all on function public.create_treasury_master(uuid,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.set_treasury_master_status(uuid,uuid,public.account_status,timestamptz) from public,anon,authenticated,service_role;
grant execute on function public.create_treasury_master(uuid,jsonb) to authenticated;
grant execute on function public.set_treasury_master_status(uuid,uuid,public.account_status,timestamptz) to authenticated;
