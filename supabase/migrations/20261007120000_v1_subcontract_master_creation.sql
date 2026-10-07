-- V1 master creation only. Existing browser DML grants and policies stay intact.
create function public.create_subcontractor_party(target_company_id uuid, business_input jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); result_id uuid; v jsonb := business_input; k text;
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if actor is null or not public.has_company_role(target_company_id, 'ACCOUNTING_ADMIN')
     or not public.has_permission(target_company_id, 'party.manage') then
    raise exception 'Creation denied' using errcode = '42501';
  end if;
  if v is null or jsonb_typeof(v) <> 'object' then raise exception 'Invalid input' using errcode = '22023'; end if;
  for k in select jsonb_object_keys(v) loop
    if k <> all(array['name','code','trn','contact_person','phone','email','address','notes'])
       or jsonb_typeof(v->k) not in ('string','null') then
      raise exception 'Invalid input' using errcode = '22023';
    end if;
    v := jsonb_set(v, array[k], coalesce(to_jsonb(nullif(btrim(v->>k, trim_chars), '')), 'null'::jsonb));
  end loop;
  if v->>'name' is null then raise exception 'Name required' using errcode = '23514'; end if;
  insert into public.parties(company_id,type,status,name,code,trn,contact_person,phone,email,address,notes,created_by,updated_by,created_at,updated_at)
  values(target_company_id,'SUBCONTRACTOR','ACTIVE',v->>'name',v->>'code',v->>'trn',v->>'contact_person',v->>'phone',v->>'email',v->>'address',v->>'notes',actor,actor,statement_timestamp(),statement_timestamp())
  returning id into result_id;
  return result_id;
end; $$;

create function public.create_subcontract(target_company_id uuid, business_input jsonb)
returns uuid language plpgsql security definer set search_path = '' as $$
declare
  actor uuid := auth.uid(); result_id uuid; v jsonb := business_input; k text;
  project_id uuid; party_id uuid; original_value bigint; variations bigint; retention integer;
  project_status public.project_status; party_status public.account_status;
  trim_chars text := E' \t\n\r\f' || chr(11) || chr(160) || chr(5760)
    || chr(8192) || chr(8193) || chr(8194) || chr(8195) || chr(8196) || chr(8197)
    || chr(8198) || chr(8199) || chr(8200) || chr(8201) || chr(8202)
    || chr(8232) || chr(8233) || chr(8239) || chr(8287) || chr(12288) || chr(65279);
begin
  if actor is null or not public.has_company_role(target_company_id, 'ACCOUNTING_ADMIN')
     or not public.has_permission(target_company_id, 'subcontract.manage') then
    raise exception 'Creation denied' using errcode = '42501';
  end if;
  if v is null or jsonb_typeof(v) <> 'object' then raise exception 'Invalid input' using errcode = '22023'; end if;
  for k in select jsonb_object_keys(v) loop
    if k <> all(array['project_id','subcontractor_id','contract_number','scope_of_work','original_contract_value_minor','approved_variations_minor','retention_bps','start_date','expected_end_date','status','notes'])
       or jsonb_typeof(v->k) not in ('string','null') then
      raise exception 'Invalid input' using errcode = '22023';
    end if;
    v := jsonb_set(v, array[k], coalesce(to_jsonb(nullif(btrim(v->>k, trim_chars), '')), 'null'::jsonb));
  end loop;
  if v->>'project_id' is null or v->>'subcontractor_id' is null
     or v->>'contract_number' is null or v->>'scope_of_work' is null
     or v->>'original_contract_value_minor' is null or v->>'retention_bps' is null
     or v->>'original_contract_value_minor' !~ '^[0-9]+$'
     or coalesce(v->>'approved_variations_minor','0') !~ '^-?[0-9]+$'
     or v->>'retention_bps' !~ '^[0-9]+$' then
    raise exception 'Invalid input' using errcode = '22023';
  end if;
  project_id := (v->>'project_id')::uuid; party_id := (v->>'subcontractor_id')::uuid;
  original_value := (v->>'original_contract_value_minor')::bigint;
  variations := coalesce(v->>'approved_variations_minor','0')::bigint;
  retention := (v->>'retention_bps')::integer;
  -- Lock authoritative masters so closure/deactivation cannot race creation.
  select p.status into project_status from public.projects p
    where p.id = project_id and p.company_id = target_company_id for share;
  if not found or project_status = 'CLOSED' then raise exception 'Invalid project' using errcode = '23514'; end if;
  select p.status into party_status from public.parties p
    where p.id = party_id and p.company_id = target_company_id and p.type = 'SUBCONTRACTOR' for share;
  if not found or party_status <> 'ACTIVE' then raise exception 'Invalid subcontractor' using errcode = '23514'; end if;
  insert into public.subcontracts(company_id,project_id,subcontractor_id,contract_number,scope_of_work,original_contract_value_minor,approved_variations_minor,retention_bps,start_date,expected_end_date,status,notes,created_by,updated_by,created_at,updated_at)
  values(target_company_id,project_id,party_id,v->>'contract_number',v->>'scope_of_work',original_value,variations,retention,(v->>'start_date')::date,(v->>'expected_end_date')::date,coalesce(v->>'status','ACTIVE')::public.subcontract_status,v->>'notes',actor,actor,statement_timestamp(),statement_timestamp())
  returning id into result_id;
  return result_id;
end; $$;
revoke all on function public.create_subcontractor_party(uuid,jsonb) from public,anon,authenticated,service_role;
revoke all on function public.create_subcontract(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.create_subcontractor_party(uuid,jsonb) to authenticated;
grant execute on function public.create_subcontract(uuid,jsonb) to authenticated;
