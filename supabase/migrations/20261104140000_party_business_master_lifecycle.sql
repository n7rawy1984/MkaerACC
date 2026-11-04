-- CON-03/CON-05: same Party identities; optional business metadata and controlled status.
alter table public.parties
 add column legal_name text, add column business_classification text,
 add column trade_license_number text, add column trade_license_authority text,
 add column trade_license_expiry date, add column country_code text,
 add column region text, add column payment_terms text;

create table public.party_business_changes (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 party_id uuid not null, actor_id uuid references auth.users(id) on delete restrict,
 changed_at timestamptz not null, kind text not null check(kind in ('CREATE','EDIT','STATUS')),
 before_data jsonb, after_data jsonb not null,
 unique(company_id,id),unique(company_id,party_id,changed_at),
 foreign key(company_id,party_id) references public.parties(company_id,id) on delete restrict
);
create table public.party_business_requests (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 party_id uuid not null, event_id uuid not null unique, request_id uuid not null, actor_id uuid not null references auth.users(id) on delete restrict,
 reason text, input_hash text not null, created_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id), foreign key(company_id,party_id) references public.parties(company_id,id) on delete restrict,
 foreign key(company_id,event_id) references public.party_business_changes(company_id,id) on delete restrict
);
alter table public.party_business_changes enable row level security;
alter table public.party_business_changes force row level security;
alter table public.party_business_requests enable row level security;
alter table public.party_business_requests force row level security;
revoke all on public.party_business_changes,public.party_business_requests from public,anon,authenticated,service_role;
grant select on public.party_business_changes,public.party_business_requests to authenticated;
create policy party_business_changes_read on public.party_business_changes for select to authenticated using(exists(select 1 from public.parties p where p.company_id=party_business_changes.company_id and p.id=party_business_changes.party_id));
create policy party_business_requests_read on public.party_business_requests for select to authenticated using(exists(select 1 from public.parties p where p.company_id=party_business_requests.company_id and p.id=party_business_requests.party_id));
create trigger party_business_changes_immutable before update or delete on public.party_business_changes for each row execute function private.protect_project_cost_correction();
create trigger party_business_requests_immutable before update or delete on public.party_business_requests for each row execute function private.protect_project_cost_correction();

create function private.party_business_snapshot(p public.parties) returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('id',p.id,'company_id',p.company_id,'type',p.type,'name',p.name,'code',p.code,'status',p.status,'updated_at',p.updated_at,
 'legal_name',p.legal_name,'business_classification',p.business_classification,'trade_license_number',p.trade_license_number,'trade_license_authority',p.trade_license_authority,'trade_license_expiry',p.trade_license_expiry,'country_code',p.country_code,'region',p.region,'payment_terms',p.payment_terms,
 'trn',p.trn,'contact_person',p.contact_person,'phone',p.phone,'email',p.email,'address',p.address,'notes',p.notes);
$$;
revoke all on function private.party_business_snapshot(public.parties) from public,anon,authenticated,service_role;

-- No secret flags: direct status DML is blocked; authorized commands execute as owner.
-- Metadata-only legacy edits/creation remain compatible and are also audited.
create function private.guard_party_business_lifecycle() returns trigger language plpgsql set search_path='' as $$
begin
 if old.type not in ('SUPPLIER','SUBCONTRACTOR') then if tg_op='DELETE' then return old;else return new;end if;end if;
 if tg_op='DELETE' then raise exception 'Business Party identity is retained; deactivate instead' using errcode='23514';end if;
 if current_user='authenticated' and new.status is distinct from old.status then raise exception 'Use the controlled Party status command with a reason' using errcode='42501';end if;
 return new;
end;$$;
revoke all on function private.guard_party_business_lifecycle() from public,anon,authenticated,service_role;
create trigger parties_business_lifecycle_guard before update or delete on public.parties for each row execute function private.guard_party_business_lifecycle();

create function private.audit_party_business_change() returns trigger language plpgsql security definer set search_path='' as $$
declare prior jsonb;current_data jsonb;begin
 if new.type not in ('SUPPLIER','SUBCONTRACTOR') then return new;end if;
 current_data:=private.party_business_snapshot(new);
 if tg_op='UPDATE' then prior:=private.party_business_snapshot(old);if (prior-'updated_at')=(current_data-'updated_at') then return new;end if;end if;
 insert into public.party_business_changes(company_id,party_id,actor_id,changed_at,kind,before_data,after_data)
 values(new.company_id,new.id,auth.uid(),new.updated_at,case when tg_op='INSERT' then 'CREATE' when old.status is distinct from new.status then 'STATUS' else 'EDIT' end,prior,current_data);
 return new;
end;$$;
revoke all on function private.audit_party_business_change() from public,anon,authenticated,service_role;
create trigger parties_business_audit after insert or update on public.parties for each row execute function private.audit_party_business_change();

create function private.party_business_authority(cid uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();begin
 perform 1 from public.companies where id=cid for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=cid and user_id=actor for share;
 if actor is null or not (public.has_company_role(cid,'ACCOUNTING_ADMIN') or public.has_company_role(cid,'PROCUREMENT')) or not public.has_permission(cid,'party.manage') then raise exception 'Party management denied' using errcode='42501';end if;
 return actor;
end;$$;
revoke all on function private.party_business_authority(uuid) from public,anon,authenticated,service_role;

create function private.party_business_patch(patch jsonb) returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;v text;result jsonb:='{}';max_length integer;begin
 if patch is null or jsonb_typeof(patch)<>'object' then raise exception 'Invalid Party fields' using errcode='22023';end if;
 for k in select jsonb_object_keys(patch) loop
  if k<>all(array['name','code','legal_name','business_classification','trade_license_number','trade_license_authority','trade_license_expiry','country_code','region','payment_terms','trn','contact_person','phone','email','address','notes']) or jsonb_typeof(patch->k) not in ('string','null') then raise exception 'Invalid Party field' using errcode='22023';end if;
  v:=private.correction_text(patch->>k);
  max_length:=case when k='code' then 50 when k='country_code' then 2 when k in ('notes','address','payment_terms') then 2000 when k in ('trn','phone') then 100 else 200 end;
  if length(v)>max_length or (k='name' and v is null) then raise exception 'Invalid Party field length' using errcode='22023';end if;
  if k='country_code' and v is not null then v:=upper(v);if v!~'^[A-Z]{2}$' then raise exception 'Two-letter country code required' using errcode='22023';end if;end if;
  if k='trade_license_expiry' and v is not null then
   if v!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$' then raise exception 'ISO expiry date required' using errcode='22023';end if;
   begin v:=(v::date)::text;exception when datetime_field_overflow or invalid_datetime_format then raise exception 'Invalid expiry date' using errcode='22023';end;
  end if;
  result:=result||jsonb_build_object(k,v);
 end loop;
 return result;
end;$$;
revoke all on function private.party_business_patch(jsonb) from public,anon,authenticated,service_role;

create function private.party_business_proposal(p public.parties,patch jsonb,target_status text) returns jsonb language plpgsql stable set search_path='' as $$
declare result jsonb;begin
 if target_status is not null then
  if target_status not in ('ACTIVE','INACTIVE') or patch<>'{}'::jsonb or target_status=p.status::text then raise exception 'Invalid status transition' using errcode='22023';end if;
  return private.party_business_snapshot(p)||jsonb_build_object('status',target_status);
 end if;
 if patch='{}'::jsonb then raise exception 'No metadata supplied' using errcode='22023';end if;
 result:=private.party_business_snapshot(p)||patch;
 if result=private.party_business_snapshot(p) then raise exception 'No metadata changed' using errcode='22023';end if;
 -- Optional UAE format check, never a registration verification or requirement for foreign parties.
 if result->>'country_code'='AE' and result->>'trn' is not null and result->>'trn'!~'^[0-9]{15}$' then raise exception 'UAE TRN format requires 15 digits' using errcode='22023';end if;
 return result;
end;$$;
revoke all on function private.party_business_proposal(public.parties,jsonb,text) from public,anon,authenticated,service_role;

create function private.party_identity_key(value text) returns text language sql immutable set search_path='' as $$select lower(regexp_replace(private.correction_text(value),'[[:space:]]+',' ','g'));$$;
revoke all on function private.party_identity_key(text) from public,anon,authenticated,service_role;
create function private.party_business_duplicate(cid uuid,pid uuid,proposed jsonb) returns boolean language sql stable set search_path='' as $$
 select exists(select 1 from public.parties p where p.company_id=cid and p.id<>pid and p.type in ('SUPPLIER','SUBCONTRACTOR') and (
 private.party_identity_key(p.name)=private.party_identity_key(proposed->>'name')
 or private.party_identity_key(coalesce(p.legal_name,p.name))=private.party_identity_key(coalesce(proposed->>'legal_name',proposed->>'name'))
 or (proposed->>'trn' is not null and private.party_identity_key(p.trn)=private.party_identity_key(proposed->>'trn'))
 or (proposed->>'trade_license_number' is not null and proposed->>'trade_license_authority' is not null and proposed->>'country_code' is not null and private.party_identity_key(p.trade_license_number)=private.party_identity_key(proposed->>'trade_license_number') and private.party_identity_key(p.trade_license_authority)=private.party_identity_key(proposed->>'trade_license_authority') and p.country_code=proposed->>'country_code')));
$$;
revoke all on function private.party_business_duplicate(uuid,uuid,jsonb) from public,anon,authenticated,service_role;

create function public.preview_party_business_change(target_company_id uuid,target_party_id uuid,expected_updated_at timestamptz,patch jsonb,target_status text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare p public.parties;proposal jsonb;begin
 perform private.party_business_authority(target_company_id);
 select * into p from public.parties where company_id=target_company_id and id=target_party_id and type in ('SUPPLIER','SUBCONTRACTOR');
 if not found then raise exception 'Business Party unavailable' using errcode='42501';end if;
 if expected_updated_at is null or p.updated_at<>expected_updated_at then raise exception 'Party changed; refresh' using errcode='40001';end if;
 proposal:=private.party_business_proposal(p,private.party_business_patch(patch),target_status);
 return jsonb_build_object('before',private.party_business_snapshot(p),'after',proposal,'duplicate_warning',target_status is null and private.party_business_duplicate(target_company_id,target_party_id,proposal));
end;$$;

create function public.update_party_business_master(target_company_id uuid,target_party_id uuid,expected_updated_at timestamptz,request_id uuid,patch jsonb,target_status text,reason text,duplicates_acknowledged boolean)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;normalized jsonb:=private.party_business_patch(patch);why text:=private.correction_text(reason);digest text;p public.parties;proposal jsonb;saved public.party_business_requests;event uuid;begin
 actor:=private.party_business_authority(target_company_id);
 if target_party_id is null or expected_updated_at is null or request_id is null or coalesce(length(why),0)>500 or (target_status is not null and why is null) or duplicates_acknowledged is null then raise exception 'Valid request and status reason required' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'party',target_party_id,'expected',extract(epoch from expected_updated_at),'patch',normalized,'status',target_status,'reason',why,'duplicates',duplicates_acknowledged)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('party-business:'||target_company_id::text||':'||request_id::text,0));
 select * into saved from public.party_business_requests r where r.company_id=target_company_id and r.request_id=update_party_business_master.request_id;
 if found then if saved.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return to_jsonb(saved)-'input_hash';end if;
 select * into p from public.parties where company_id=target_company_id and id=target_party_id and type in ('SUPPLIER','SUBCONTRACTOR') for update;
 if not found then raise exception 'Business Party unavailable' using errcode='42501';end if;
 if p.updated_at<>expected_updated_at then raise exception 'Party changed; refresh' using errcode='40001';end if;
 proposal:=private.party_business_proposal(p,normalized,target_status);
 if target_status is null and private.party_business_duplicate(target_company_id,target_party_id,proposal) and not duplicates_acknowledged then raise exception 'Possible duplicate; explicit review required' using errcode='23505';end if;
 update public.parties set name=proposal->>'name',code=proposal->>'code',legal_name=proposal->>'legal_name',business_classification=proposal->>'business_classification',
 trade_license_number=proposal->>'trade_license_number',trade_license_authority=proposal->>'trade_license_authority',trade_license_expiry=(proposal->>'trade_license_expiry')::date,
 country_code=proposal->>'country_code',region=proposal->>'region',payment_terms=proposal->>'payment_terms',trn=proposal->>'trn',contact_person=proposal->>'contact_person',phone=proposal->>'phone',email=proposal->>'email',address=proposal->>'address',notes=proposal->>'notes',status=(proposal->>'status')::public.account_status,updated_by=actor
 where company_id=target_company_id and id=target_party_id returning * into p;
 select id into event from public.party_business_changes c where c.company_id=target_company_id and c.party_id=target_party_id and c.changed_at=p.updated_at;
 if event is null then raise exception 'Party audit event missing' using errcode='23514';end if;
 insert into public.party_business_requests(company_id,party_id,event_id,request_id,actor_id,reason,input_hash) values(target_company_id,target_party_id,event,request_id,actor,why,digest) returning * into saved;
 return to_jsonb(saved)-'input_hash';
end;$$;
revoke all on function public.preview_party_business_change(uuid,uuid,timestamptz,jsonb,text) from public,anon,authenticated,service_role;
revoke all on function public.update_party_business_master(uuid,uuid,timestamptz,uuid,jsonb,text,text,boolean) from public,anon,authenticated,service_role;
grant execute on function public.preview_party_business_change(uuid,uuid,timestamptz,jsonb,text),public.update_party_business_master(uuid,uuid,timestamptz,uuid,jsonb,text,text,boolean) to authenticated;

-- Confirmed concurrency defect: the existing Expense engine checks Supplier status
-- before its FK wait. Serialize new recognition with deactivation at insertion.
-- Existing liabilities/payments/certificates/retention and posted updates are untouched.
create function private.guard_expense_supplier_lifecycle() returns trigger language plpgsql security definer set search_path='' as $$
declare active_status public.account_status;begin
 if new.supplier_id is not null then
  select status into active_status from public.parties where company_id=new.company_id and id=new.supplier_id and type='SUPPLIER' for share;
  if active_status is distinct from 'ACTIVE' then raise exception 'Active same-Company Supplier required for new Expense recognition' using errcode='23514';end if;
 end if;
 return new;
end;$$;
revoke all on function private.guard_expense_supplier_lifecycle() from public,anon,authenticated,service_role;
create trigger expenses_supplier_lifecycle before insert on public.expenses for each row execute function private.guard_expense_supplier_lifecycle();
