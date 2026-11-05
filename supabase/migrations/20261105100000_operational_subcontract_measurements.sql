-- Operational subcontract terms and measured certification. No backfill or journals at activation.
create unique index subcontracts_company_identity on public.subcontracts(company_id,id);
create table public.subcontract_term_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),subcontract_id uuid not null,
 request_key uuid not null,request_hash text not null,
 version integer not null check(version>0),terms jsonb not null,previous_state jsonb not null,
 reason text not null check(length(reason) between 1 and 1000),evidence_reference text not null check(length(evidence_reference) between 1 and 2000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),unique(company_id,subcontract_id,version),
 foreign key(company_id,subcontract_id) references public.subcontracts(company_id,id)
);
create table public.subcontract_measurements (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),subcontract_id uuid not null,terms_id uuid not null,certificate_id uuid not null,
 request_key uuid not null,request_hash text not null,quantities jsonb not null,total_minor bigint not null check(total_minor between 1 and 9000000000000000),
 evidence_reference text not null check(length(evidence_reference) between 1 and 2000),tax_basis_reference text not null check(length(tax_basis_reference) between 1 and 2000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),unique(company_id,certificate_id),
 foreign key(company_id,subcontract_id) references public.subcontracts(company_id,id),
 foreign key(company_id,terms_id) references public.subcontract_term_events(company_id,id),
 foreign key(company_id,certificate_id) references public.subcontractor_certificates(company_id,id)
);
create table public.subcontract_certificate_withdrawals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),certificate_id uuid not null,
 reason text not null check(length(reason) between 1 and 1000),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,certificate_id),foreign key(company_id,certificate_id) references public.subcontractor_certificates(company_id,id)
);
do $$ declare t text;begin
 foreach t in array array['subcontract_term_events','subcontract_measurements','subcontract_certificate_withdrawals'] loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy financial_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'') or public.has_company_role(company_id,''ACCOUNTANT'') or public.has_company_role(company_id,''MANAGEMENT_VIEWER''))',t);
 execute format('create trigger immutable_evidence before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
 end loop;
end;$$;
create function public.amend_operational_subcontract(cid uuid,sid uuid,expected_version integer,request_id uuid,input jsonb,reason text,evidence text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
 declare actor uuid;s public.subcontracts;e public.subcontract_term_events;prior public.subcontract_term_events;v jsonb:=input;k text;x jsonb;boq jsonb:='[]';h text;n integer;rev bigint;ret integer;state public.subcontract_status;certified numeric;
 begin
 actor:=private.operational_finance_actor(cid,'subcontract.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin required' using errcode='42501';end if;
 if request_id is null or jsonb_typeof(v) is distinct from 'object' or coalesce(length(btrim(reason)),0) not between 1 and 1000 or coalesce(length(btrim(evidence)),0) not between 1 and 2000 then raise exception 'Evidenced amendment required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop if k<>all(array['mode','boq','variations_minor','retention_bps','status','signed_date','actual_start_date','document_reference']) then raise exception 'Unsupported commercial field' using errcode='22023';end if;end loop;
 if v->>'mode' is null or v->>'mode' not in ('FIXED_PRICE','UNIT_RATE_UNCAPPED') or jsonb_typeof(v->'boq') is distinct from 'array' or jsonb_array_length(v->'boq')>100 then raise exception 'Explicit contract mode and BOQ required' using errcode='22023';end if;
 for x in select value from jsonb_array_elements(v->'boq') loop
 if jsonb_typeof(x)<>'object' or coalesce(length(btrim(x->>'code')),0) not between 1 and 50 or coalesce(length(btrim(x->>'description')),0) not between 1 and 500 or coalesce(length(btrim(x->>'unit')),0) not between 1 and 50 or coalesce(x->>'rate_minor','')!~'^[0-9]+$' or (x->>'rate_minor')::numeric not between 1 and 9000000000000000 then raise exception 'Exact approved BOQ unit/rate required' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(boq) b where b->>'code'=btrim(x->>'code')) then raise exception 'Duplicate BOQ code' using errcode='23505';end if;
 boq:=boq||jsonb_build_array(jsonb_build_object('code',btrim(x->>'code'),'description',btrim(x->>'description'),'unit',btrim(x->>'unit'),'rate_minor',((x->>'rate_minor')::bigint)::text));end loop;
 if (v->>'mode'='FIXED_PRICE' and jsonb_array_length(boq)<>0) or (v->>'mode'='UNIT_RATE_UNCAPPED' and jsonb_array_length(boq)=0) then raise exception 'BOQ required only for unit-rate agreement' using errcode='23514';end if;
 if coalesce(v->>'variations_minor','')!~'^-?[0-9]+$' or coalesce(v->>'retention_bps','')!~'^[0-9]+$' then raise exception 'Exact commercial amounts required' using errcode='22023';end if;
 rev:=(v->>'variations_minor')::bigint;ret:=(v->>'retention_bps')::integer;state:=(v->>'status')::public.subcontract_status;
 if ret not between 0 and 10000 or state is null then raise exception 'Valid retention and status required' using errcode='22023';end if;
 foreach k in array array['signed_date','actual_start_date'] loop if nullif(v->>k,'') is not null and ((v->>k)::date>current_date or (v->>k)::date<'2000-01-01') then raise exception 'Actual nonfuture dates required' using errcode='22023';end if;end loop;
 if coalesce(length(btrim(v->>'document_reference')),0) not between 1 and 2000 then raise exception 'Controlled document reference required' using errcode='22023';end if;
 v:=jsonb_build_object('mode',v->>'mode','boq',(select coalesce(jsonb_agg(b order by b->>'code'),'[]') from jsonb_array_elements(boq) b),'variations_minor',rev::text,'retention_bps',ret,'status',state,'signed_date',nullif(v->>'signed_date','')::date,'actual_start_date',nullif(v->>'actual_start_date','')::date,'document_reference',btrim(v->>'document_reference'));
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'contract',sid,'version',expected_version,'input',v,'reason',btrim(reason),'evidence',btrim(evidence))::text,'UTF8'),'sha256'),'hex');
 select * into s from public.subcontracts where company_id=cid and id=sid for update;
 if not found then raise exception 'Same-Company contract required' using errcode='42501';end if;
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into e from public.subcontract_term_events where company_id=cid and request_key=request_id;
 if found then if e.request_hash<>h then raise exception 'Changed amendment intent' using errcode='22023';end if;return jsonb_build_object('id',e.id,'subcontract_id',sid,'replayed',true);end if;
 select * into prior from public.subcontract_term_events where company_id=cid and subcontract_id=sid order by version desc limit 1;
 n:=coalesce(prior.version,0);if expected_version is distinct from n then raise exception 'Stale commercial version' using errcode='40001';end if;
 if exists(select 1 from public.subcontract_measurements m join public.subcontractor_certificates c on c.company_id=m.company_id and c.id=m.certificate_id where m.company_id=cid and m.subcontract_id=sid and c.status='DRAFT' and not exists(select 1 from public.subcontract_certificate_withdrawals w where w.company_id=cid and w.certificate_id=c.id)) then raise exception 'Resolve pending measured certificate before amending terms' using errcode='23514';end if;
 if not exists(select 1 from public.projects where company_id=cid and id=s.project_id and status<>'CLOSED') then raise exception 'Closed Project cannot create new commercial commitments' using errcode='23514';end if;
 if n>0 and prior.terms->>'mode'<>v->>'mode' then raise exception 'Contract pricing model is immutable after establishment' using errcode='23514';end if;
 if s.status='CLOSED' or (s.status='COMPLETED' and state='ACTIVE') or (s.status='ACTIVE' and state='CLOSED') then raise exception 'Controlled Active to Completed to Closed only; reopening needs separate review' using errcode='23514';end if;
 if state<>s.status and exists(select 1 from public.subcontractor_certificates where company_id=cid and subcontract_id=sid and status='DRAFT' and not exists(select 1 from public.subcontract_certificate_withdrawals w where w.company_id=cid and w.certificate_id=public.subcontractor_certificates.id)) then raise exception 'Resolve draft certificates before transition' using errcode='23514';end if;
 if v->>'mode'='UNIT_RATE_UNCAPPED' and (s.original_contract_value_minor<>0 or rev<>0) then raise exception 'Uncapped agreement has no invented monetary contract total' using errcode='23514';end if;
 select coalesce(sum(gross_certified_minor),0) into certified from public.subcontractor_certificates where company_id=cid and subcontract_id=sid and status='POSTED';
 if v->>'mode'='FIXED_PRICE' and (s.original_contract_value_minor::numeric+rev<certified or s.original_contract_value_minor::numeric+rev<0) then raise exception 'Revised fixed value cannot undercut certified work' using errcode='23514';end if;
 if v->>'mode'='UNIT_RATE_UNCAPPED' and certified>0 and (n=0 or exists(select 1 from jsonb_array_elements(prior.terms->'boq') old_line where not exists(select 1 from jsonb_array_elements(v->'boq') new_line where new_line->>'code'=old_line->>'code' and new_line->>'rate_minor'=old_line->>'rate_minor' and new_line->>'unit'=old_line->>'unit'))) then raise exception 'Posted measured rates cannot be repriced; reverse dependent events first' using errcode='23514';end if;
 if state='ACTIVE' and not exists(select 1 from public.parties where company_id=cid and id=s.subcontractor_id and type='SUBCONTRACTOR' and status='ACTIVE') then raise exception 'Active Subcontractor required for new commercial commitments' using errcode='23514';end if;
 if state='CLOSED' and private.subcontractor_advance_balance_minor(cid,sid)<>0 then raise exception 'Reconcile advance before closure' using errcode='23514';end if;
 insert into public.subcontract_term_events(company_id,subcontract_id,request_key,request_hash,version,terms,previous_state,reason,evidence_reference,created_by) values(cid,sid,request_id,h,n+1,v,to_jsonb(s),btrim(reason),btrim(evidence),actor) returning * into e;
 update public.subcontracts set approved_variations_minor=rev,retention_bps=ret,status=state,updated_by=actor where company_id=cid and id=sid;
 return jsonb_build_object('id',e.id,'subcontract_id',sid,'replayed',false);
 end;$$;
create table private.subcontract_creation_receipts(company_id uuid not null references public.companies(id),request_key uuid not null,request_hash text not null,receipt jsonb not null,primary key(company_id,request_key));
alter table private.subcontract_creation_receipts enable row level security;
alter table private.subcontract_creation_receipts force row level security;
create trigger immutable_evidence before update or delete on private.subcontract_creation_receipts for each row execute function private.financial_evidence_immutable();
revoke all on private.subcontract_creation_receipts from public,anon,authenticated,service_role;
create function public.create_operational_subcontract(cid uuid,request_id uuid,business jsonb,terms jsonb,reason text,evidence text) returns jsonb language plpgsql security definer set search_path='' as $$
 declare actor uuid;h text;prior private.subcontract_creation_receipts;sid uuid;r jsonb;begin
 actor:=private.operational_finance_actor(cid,'subcontract.manage');if not public.has_company_role(cid,'ACCOUNTING_ADMIN') or request_id is null then raise exception 'Accounting Admin and request required' using errcode='42501';end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'business',business,'terms',terms,'reason',btrim(reason),'evidence',btrim(evidence))::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into prior from private.subcontract_creation_receipts where company_id=cid and request_key=request_id;
 if found then if prior.request_hash<>h then raise exception 'Changed creation intent' using errcode='22023';end if;return prior.receipt||jsonb_build_object('replayed',true);end if;
 if terms->>'mode'='UNIT_RATE_UNCAPPED' then business:=jsonb_set(jsonb_set(business,'{original_contract_value_minor}','"0"'),'{approved_variations_minor}','"0"');end if;
 if business->>'status' is not null and business->>'status'<>'ACTIVE' then raise exception 'New operational contract must be Active' using errcode='23514';end if;
 sid:=public.create_subcontract(cid,business);
 r:=public.amend_operational_subcontract(cid,sid,0,request_id,terms,reason,evidence);
 insert into private.subcontract_creation_receipts values(cid,request_id,h,r);return r;
 end;$$;
create function public.prepare_measured_certificate(cid uuid,sid uuid,request_id uuid,input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
 declare actor uuid;s public.subcontracts;e public.subcontract_term_events;m public.subcontract_measurements;x jsonb;b jsonb;q numeric;total numeric:=0;line_amount numeric;quantities jsonb:='[]';v jsonb:=input;h text;r record;k text;
 begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if request_id is null or jsonb_typeof(v) is distinct from 'object' then raise exception 'Measurement input required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop if k<>all(array['terms_id','quantities','certificate_date','certificate_number','evidence','tax_basis','vat_minor','invoice_number','invoice_date','advance_recovery_minor']) then raise exception 'Unsupported measurement input' using errcode='22023';end if;end loop;
 foreach k in array array['certificate_number','evidence','tax_basis'] loop if coalesce(length(btrim(v->>k)),0) not between 1 and 2000 then raise exception 'Signed measurement and tax evidence required' using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end loop;
 if (v->>'certificate_date')::date>current_date or (v->>'certificate_date')::date<'2000-01-01' or v->>'certificate_date' is null then raise exception 'Nonfuture measurement date required' using errcode='22023';end if;
 if coalesce(v->>'vat_minor','')!~'^[0-9]+$' or coalesce(v->>'advance_recovery_minor','')!~'^[0-9]+$' or (v->>'vat_minor')::numeric>9000000000000000 or (v->>'advance_recovery_minor')::numeric>9000000000000000 then raise exception 'Exact evidenced VAT and recovery required' using errcode='22023';end if;
 if (v->>'vat_minor')::numeric>0 and (coalesce(length(btrim(v->>'invoice_number')),0)=0 or nullif(v->>'invoice_date','') is null) then raise exception 'Recoverable VAT needs actual invoice evidence' using errcode='23514';end if;
 if jsonb_typeof(v->'quantities') is distinct from 'array' or jsonb_array_length(v->'quantities') not between 1 and 100 then raise exception 'Cumulative measured quantities required' using errcode='22023';end if;
 for x in select value from jsonb_array_elements(v->'quantities') loop
 if coalesce(x->>'quantity_micros','')!~'^[0-9]+$' or (x->>'quantity_micros')::numeric>9000000000000000 or coalesce(length(btrim(x->>'code')),0)=0 then raise exception 'Exact nonnegative measured quantity required' using errcode='22023';end if;
 if exists(select 1 from jsonb_array_elements(quantities) z where z->>'code'=btrim(x->>'code')) then raise exception 'Duplicate measured item' using errcode='23505';end if;
 quantities:=quantities||jsonb_build_array(jsonb_build_object('code',btrim(x->>'code'),'quantity_micros',((x->>'quantity_micros')::bigint)::text));end loop;
 v:=jsonb_set(v,'{quantities}',(select jsonb_agg(z order by z->>'code') from jsonb_array_elements(quantities) z));
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'contract',sid,'input',v)::text,'UTF8'),'sha256'),'hex');
 select * into s from public.subcontracts where company_id=cid and id=sid for update;
 if not found then raise exception 'Same-Company contract required' using errcode='42501';end if;
 perform private.serialize_operational_finance(cid,'OPERATIONS');
 select * into m from public.subcontract_measurements where company_id=cid and request_key=request_id;
 if found then if m.request_hash<>h then raise exception 'Changed measurement intent' using errcode='22023';end if;return jsonb_build_object('id',m.id,'certificate_id',m.certificate_id,'replayed',true);end if;
 select * into e from public.subcontract_term_events where company_id=cid and subcontract_id=sid order by version desc limit 1;
 if e.id is distinct from (v->>'terms_id')::uuid or e.terms->>'mode'<>'UNIT_RATE_UNCAPPED' or s.status<>'ACTIVE' or not exists(select 1 from public.projects where company_id=cid and id=s.project_id and status='ACTIVE') then raise exception 'Current active unit-rate agreement required' using errcode='40001';end if;
 if not exists(select 1 from public.parties where company_id=cid and id=s.subcontractor_id and type='SUBCONTRACTOR' and status='ACTIVE') then raise exception 'Active Subcontractor required for new measurement' using errcode='23514';end if;
 if jsonb_array_length(e.terms->'boq')<>jsonb_array_length(quantities) then raise exception 'All BOQ positions required' using errcode='23514';end if;
 for b in select value from jsonb_array_elements(e.terms->'boq') loop
 select (z->>'quantity_micros')::numeric into q from jsonb_array_elements(quantities) z where z->>'code'=b->>'code';
 if q is null then raise exception 'Unknown/missing measured position' using errcode='23514';end if;
 if exists(select 1 from public.subcontract_measurements mm join public.subcontractor_certificates c on c.company_id=mm.company_id and c.id=mm.certificate_id cross join lateral jsonb_array_elements(mm.quantities) z where mm.company_id=cid and mm.subcontract_id=sid and c.status='POSTED' and ((z->>'code'=b->>'code' and (z->>'quantity_micros')::numeric>q) or c.certificate_date>(v->>'certificate_date')::date)) then raise exception 'Cumulative measurement/date cannot precede posted history' using errcode='23514';end if;
 line_amount:=round(q*(b->>'rate_minor')::numeric/1000000);total:=total+line_amount;
 end loop;
 if total not between 1 and 9000000000000000 then raise exception 'Positive measured work within exact money bounds required' using errcode='23514';end if;
 select * into r from public.create_subcontractor_certificate_draft(cid,(v->>'certificate_date')::date,sid,v->>'certificate_number',total::bigint,0,(v->>'advance_recovery_minor')::bigint,case when (v->>'vat_minor')::bigint=0 then 'ZERO'::public.expense_vat_mode else 'MANUAL'::public.expense_vat_mode end,(v->>'vat_minor')::bigint,(v->>'vat_minor')::bigint>0,nullif(v->>'invoice_number',''),nullif(v->>'invoice_date','')::date,'[]'::jsonb,'Signed measured certificate: measurement and tax evidence retained in contract register');
 insert into public.subcontract_measurements(company_id,subcontract_id,terms_id,certificate_id,request_key,request_hash,quantities,total_minor,evidence_reference,tax_basis_reference,created_by) values(cid,sid,e.id,r.subcontractor_certificate_id,request_id,h,quantities,total::bigint,v->>'evidence',v->>'tax_basis',actor) returning * into m;
 return jsonb_build_object('id',m.id,'certificate_id',m.certificate_id,'replayed',false);
 end;$$;
create function private.validate_measured_certificate(cid uuid,sid uuid,certificate uuid) returns boolean language plpgsql security definer set search_path='' as $$
 declare e public.subcontract_term_events;m public.subcontract_measurements;x jsonb;prior numeric;begin
 if exists(select 1 from public.subcontract_certificate_withdrawals where company_id=cid and certificate_id=certificate) then raise exception 'Withdrawn draft cannot be posted' using errcode='23514';end if;
 select * into e from public.subcontract_term_events where company_id=cid and subcontract_id=sid order by version desc limit 1;
 if not found or e.terms->>'mode'='FIXED_PRICE' then return false;end if;
 select * into m from public.subcontract_measurements where company_id=cid and subcontract_id=sid and certificate_id=certificate;
 if not found or m.terms_id<>e.id then raise exception 'Fresh signed measured certificate required for uncapped agreement' using errcode='23514';end if;
 for x in select value from jsonb_array_elements(m.quantities) loop
 select coalesce(max((z->>'quantity_micros')::numeric),0) into prior from public.subcontract_measurements mm join public.subcontractor_certificates c on c.company_id=mm.company_id and c.id=mm.certificate_id cross join lateral jsonb_array_elements(mm.quantities) z where mm.company_id=cid and mm.subcontract_id=sid and c.status='POSTED' and z->>'code'=x->>'code';
 if (x->>'quantity_micros')::numeric<prior then raise exception 'Measured quantity is below posted cumulative history' using errcode='23514';end if;end loop;
 return true;
 end;$$;
revoke all on function private.validate_measured_certificate(uuid,uuid,uuid) from public,anon,authenticated,service_role;
revoke all on function public.amend_operational_subcontract(uuid,uuid,integer,uuid,jsonb,text,text),public.create_operational_subcontract(uuid,uuid,jsonb,jsonb,text,text),public.prepare_measured_certificate(uuid,uuid,uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.amend_operational_subcontract(uuid,uuid,integer,uuid,jsonb,text,text),public.create_operational_subcontract(uuid,uuid,jsonb,jsonb,text,text),public.prepare_measured_certificate(uuid,uuid,uuid,jsonb) to authenticated;

-- Forward extension: fixed-value caps unchanged; only signed measured uncapped contracts bypass that cap.
create or replace function public.approve_post_subcontractor_certificate(
  target_company_id uuid, target_subcontractor_certificate_id uuid, target_idempotency_key uuid
)
returns table (subcontractor_certificate_id uuid, certificate_reference text, journal_entry_id uuid, replayed boolean)
language plpgsql security definer set search_path = '' as $$
declare
  actor_id uuid:=auth.uid(); cert public.subcontractor_certificates; subcontract_row public.subcontracts;
  project_status public.project_status; previous_work numeric; current_work numeric; gross numeric;
  retention numeric; recovery numeric; deduction_total numeric; net_before_vat numeric; vat numeric; payable numeric;
  revised_value numeric; live_certified numeric; available_advance numeric; project_cost_account uuid;
  vat_account uuid; retention_account uuid; advance_account uuid; payable_account uuid;
  deduction_row public.subcontractor_certificate_deductions; lines jsonb := '[]'::jsonb;
  request_hash text; request_row private.financial_command_requests; new_journal_id uuid;
begin
  if actor_id is null or not public.has_permission(target_company_id,'certificate.approve_post') then
    raise exception 'Not authorized to approve/post Subcontractor Certificates' using errcode='42501';
  end if;
  if target_company_id is null or target_subcontractor_certificate_id is null or target_idempotency_key is null then
    raise exception 'Required Certificate approval input is missing' using errcode='22023';
  end if;
  request_hash:=encode(extensions.digest(convert_to(jsonb_build_object('company_id',target_company_id,
    'certificate_id',target_subcontractor_certificate_id)::text,'UTF8'),'sha256'),'hex');
  request_row:=private.reserve_financial_command(target_company_id,'APPROVE_SUBCONTRACTOR_CERTIFICATE',
    target_idempotency_key,request_hash,actor_id);
  if request_row.status='COMPLETED' then
    return query select c.id,c.certificate_reference,c.posted_journal_entry_id,true
    from public.subcontractor_certificates c where c.company_id=target_company_id
      and c.posted_journal_entry_id=request_row.resulting_journal_entry_id;
    return;
  end if;
  select c.* into cert from public.subcontractor_certificates c
  where c.company_id=target_company_id and c.id=target_subcontractor_certificate_id for update;
  if not found then raise exception 'Certificate not found in company' using errcode='23503'; end if;
  if cert.status<>'DRAFT' then raise exception 'Only a DRAFT Certificate can be approved' using errcode='23514'; end if;
  perform private.validate_measured_certificate(target_company_id,cert.subcontract_id,cert.id);
  select s.* into subcontract_row from public.subcontracts s
  where s.company_id=target_company_id and s.id=cert.subcontract_id for update;
  if not found then raise exception 'Subcontract not found in company' using errcode='23503'; end if;
  if subcontract_row.status='CLOSED' then raise exception 'CLOSED Subcontract cannot receive a new Certificate' using errcode='23514'; end if;
  select p.status into project_status from public.projects p
  where p.company_id=target_company_id and p.id=subcontract_row.project_id;
  if project_status='CLOSED' then raise exception 'CLOSED Project cannot receive a new Certificate' using errcode='23514'; end if;
  perform 1 from public.parties p where p.company_id=target_company_id
    and p.id=subcontract_row.subcontractor_id and p.type='SUBCONTRACTOR';
  if not found then raise exception 'Certificate Subcontractor identity is invalid' using errcode='23514'; end if;
  select coalesce(max(c.work_value_to_date_minor),0),coalesce(sum(c.gross_certified_minor),0)
    into previous_work,live_certified from public.subcontractor_certificates c
    where c.company_id=target_company_id and c.subcontract_id=cert.subcontract_id and c.status='POSTED';
  current_work:=cert.work_value_to_date_minor::numeric-previous_work;
  gross:=current_work+cert.current_variation_amount_minor::numeric;
  revised_value:=subcontract_row.original_contract_value_minor::numeric+subcontract_row.approved_variations_minor::numeric;
  if current_work<0 then raise exception 'Work value to date cannot be below authoritative previous certification' using errcode='23514'; end if;
  if gross<=0 or gross>9000000000000000 then raise exception 'Current gross certified amount must be positive and within bounds' using errcode='23514'; end if;
  if not private.validate_measured_certificate(target_company_id,cert.subcontract_id,cert.id) and live_certified+gross>revised_value then raise exception 'Cumulative certified work exceeds revised Subcontract value' using errcode='23514'; end if;
  retention:=round(gross*subcontract_row.retention_bps::numeric/10000);
  recovery:=cert.requested_advance_recovery_minor;
  available_advance:=private.subcontractor_advance_balance_minor(target_company_id,cert.subcontract_id);
  if recovery>available_advance then raise exception 'Advance recovery exceeds available same-contract Advance' using errcode='23514'; end if;
  select coalesce(sum(d.amount_minor),0) into deduction_total from public.subcontractor_certificate_deductions d
  where d.company_id=target_company_id and d.certificate_id=cert.id;
  net_before_vat:=gross-retention-recovery-deduction_total;
  if net_before_vat<0 then raise exception 'Certificate deductions, retention and recovery exceed gross certified amount' using errcode='23514'; end if;
  vat:=case cert.vat_mode when 'ZERO' then 0 when 'AUTO_5' then round(net_before_vat*5/100)
    when 'MANUAL' then cert.manual_vat_amount_minor::numeric end;
  if vat>0 and (not cert.tax_invoice_received or cert.tax_invoice_number is null or cert.tax_invoice_date is null) then
    raise exception 'Recoverable VAT requires tax invoice evidence' using errcode='23514';
  end if;
  payable:=net_before_vat+vat;
  select a.id into project_cost_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='PROJECT_COST_SUBCONTRACTORS' and a.status='ACTIVE' and a.account_type='EXPENSE';
  select a.id into vat_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='INPUT_VAT' and a.status='ACTIVE' and a.account_type='ASSET';
  select a.id into retention_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_RETENTION_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  select a.id into advance_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_ADVANCE' and a.status='ACTIVE' and a.account_type='ASSET';
  select a.id into payable_account from public.accounts a where a.company_id=target_company_id
    and a.system_key='SUBCONTRACTOR_PAYABLE' and a.status='ACTIVE' and a.account_type='LIABILITY';
  if project_cost_account is null or (vat>0 and vat_account is null) or (retention>0 and retention_account is null)
     or (recovery>0 and advance_account is null) or (payable>0 and payable_account is null) then
    raise exception 'Required Certificate system account is unavailable' using errcode='23514';
  end if;
  lines:=lines||jsonb_build_array(jsonb_build_object('account_id',project_cost_account,'debit_minor',gross::bigint,
    'credit_minor',0,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract work certified'));
  if vat>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat_account,'debit_minor',vat::bigint,
    'credit_minor',0,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Recoverable Certificate VAT')); end if;
  if retention>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',retention_account,'debit_minor',0,
    'credit_minor',retention::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract retention withheld')); end if;
  if recovery>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',advance_account,'debit_minor',0,
    'credit_minor',recovery::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontract Advance recovered')); end if;
  for deduction_row in select d.* from public.subcontractor_certificate_deductions d
    where d.company_id=target_company_id and d.certificate_id=cert.id order by d.line_number loop
    perform 1 from public.accounts a where a.company_id=target_company_id and a.id=deduction_row.account_id
      and a.status='ACTIVE' and a.account_type='REVENUE';
    if not found then raise exception 'Certificate deduction account is unavailable' using errcode='23514'; end if;
    lines:=lines||jsonb_build_array(jsonb_build_object('account_id',deduction_row.account_id,'debit_minor',0,
      'credit_minor',deduction_row.amount_minor,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
      'subcontract_id',cert.subcontract_id,'memo',deduction_row.description));
  end loop;
  if payable>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',payable_account,'debit_minor',0,
    'credit_minor',payable::bigint,'project_id',cert.project_id,'party_id',cert.subcontractor_id,
    'subcontract_id',cert.subcontract_id,'memo','Subcontractor payable recognized')); end if;
  new_journal_id:=private.create_journal(target_company_id,cert.certificate_date,
    'Subcontractor Certificate '||cert.certificate_reference,'SUBCONTRACTOR_CERTIFICATE',cert.id,
    'ORIGINAL',lines,actor_id,null);
  update public.subcontractor_certificates set status='POSTED',previous_certified_work_minor=previous_work::bigint,
    current_work_amount_minor=current_work::bigint,gross_certified_minor=gross::bigint,
    retention_bps=subcontract_row.retention_bps,retention_amount_minor=retention::bigint,
    advance_recovery_minor=recovery::bigint,deductions_total_minor=deduction_total::bigint,
    net_before_vat_minor=net_before_vat::bigint,vat_amount_minor=vat::bigint,payable_amount_minor=payable::bigint,
    posted_journal_entry_id=new_journal_id,approved_at=now(),approved_by=actor_id where id=cert.id;
  perform private.complete_financial_command(request_row.id,new_journal_id);
  return query select cert.id,cert.certificate_reference,new_journal_id,false;
end;
$$;


create view public.subcontract_operating_summary with(security_invoker=true) as
 select s.id,s.company_id,s.project_id,s.subcontractor_id,s.contract_number,s.status,
 coalesce(e.terms->>'mode','FIXED_PRICE') mode,
 case when e.terms->>'mode'='UNIT_RATE_UNCAPPED' then null else (s.original_contract_value_minor::numeric+s.approved_variations_minor)::text end contract_value_minor,
 coalesce(c.work,0)::text certified_work_minor,coalesce(c.vat,0)::text vat_minor,coalesce(c.retention,0)::text retention_applied_minor,
 coalesce(c.payable,0)::text payable_created_minor,coalesce(p.paid,0)::text actual_payment_minor,
 (coalesce(c.payable,0)-coalesce(p.paid,0))::text certificate_outstanding_minor,
 (coalesce(c.retention,0)-coalesce(r.released,0))::text retention_held_minor,
 (coalesce(r.released,0)-coalesce(rp.paid,0))::text released_retention_outstanding_minor,
 coalesce(rp.paid,0)::text retention_payment_minor,
 (coalesce(a.funded,0)-coalesce(c.recovered,0))::text advance_outstanding_minor
 from public.subcontracts s
 left join lateral(select terms from public.subcontract_term_events e where e.company_id=s.company_id and e.subcontract_id=s.id order by version desc limit 1) e on true
 left join lateral(select sum(gross_certified_minor) work,sum(vat_amount_minor) vat,sum(retention_amount_minor) retention,sum(payable_amount_minor) payable,sum(advance_recovery_minor) recovered from public.subcontractor_certificates c where c.company_id=s.company_id and c.subcontract_id=s.id and c.status='POSTED') c on true
 left join lateral(select sum(total_amount_minor) paid from public.subcontractor_payments p where p.company_id=s.company_id and p.subcontract_id=s.id and p.status='POSTED') p on true
 left join lateral(select sum(total_amount_minor) released from public.subcontractor_retention_releases r where r.company_id=s.company_id and r.subcontract_id=s.id and r.status='POSTED') r on true
 left join lateral(select sum(total_amount_minor) paid from public.subcontractor_retention_payments rp where rp.company_id=s.company_id and rp.subcontract_id=s.id and rp.status='POSTED') rp on true
 left join lateral(select sum(amount_minor) funded from public.subcontractor_advances a where a.company_id=s.company_id and a.subcontract_id=s.id and a.status='POSTED') a on true
 where public.has_company_role(s.company_id,'ACCOUNTING_ADMIN') or public.has_company_role(s.company_id,'ACCOUNTANT') or public.has_company_role(s.company_id,'MANAGEMENT_VIEWER');
revoke all on public.subcontract_operating_summary from public,anon,authenticated,service_role;
grant select on public.subcontract_operating_summary to authenticated;

create function public.withdraw_subcontract_certificate(cid uuid,certificate uuid,reason text) returns jsonb language plpgsql security definer set search_path='' as $$
 declare actor uuid;c public.subcontractor_certificates;r public.subcontract_certificate_withdrawals;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');
 if coalesce(length(btrim(reason)),0) not between 1 and 1000 then raise exception 'Withdrawal reason required' using errcode='22023';end if;
 select * into c from public.subcontractor_certificates where company_id=cid and id=certificate for update;
 if not found then raise exception 'Same-Company draft required' using errcode='42501';end if;
 if c.status<>'DRAFT' then raise exception 'Posted certificate requires financial reversal, never withdrawal' using errcode='23514';end if;
 perform 1 from public.subcontracts where company_id=cid and id=c.subcontract_id for update;
 select * into r from public.subcontract_certificate_withdrawals where company_id=cid and certificate_id=certificate;
 if found then if r.created_by<>actor or r.reason<>btrim(reason) then raise exception 'Changed withdrawal intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'replayed',true);end if;
 insert into public.subcontract_certificate_withdrawals(company_id,certificate_id,reason,created_by) values(cid,certificate,btrim(reason),actor) returning * into r;
 return jsonb_build_object('id',r.id,'replayed',false);
 end;$$;
revoke all on function public.withdraw_subcontract_certificate(uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.withdraw_subcontract_certificate(uuid,uuid,text) to authenticated;

-- Withdrawn unposted evidence is not an outstanding Project commitment.
create or replace function private.project_lifecycle_dependencies(cid uuid,pid uuid) returns jsonb language sql stable set search_path='' as $$
 select jsonb_build_object(
 'pending_sources',(select count(*) from public.historical_source_records r left join public.source_expense_allocation_events a on a.company_id=r.company_id and a.id=r.expense_allocation_id
 where r.company_id=cid and r.review_status<>'CANCELLED' and r.record_type='GENERAL' and r.expense_id is null and not exists(select 1 from private.financial_command_requests q where q.company_id=cid and q.idempotency_key=r.id and q.command_type='POST_EXPENSE' and q.status='COMPLETED') and
 (r.assigned_project_id=pid or (r.allocation_scope is null and r.expense_allocation_id is null and r.completion->>'project_id'=pid::text) or exists(select 1 from jsonb_array_elements(coalesce(a.plan->'destinations','[]'::jsonb)) d where d->>'project_id'=pid::text))),
 'open_subcontracts',(select count(*) from public.subcontracts s where s.company_id=cid and s.project_id=pid and s.status<>'CLOSED'),
 'draft_certificates',(select count(*) from public.subcontractor_certificates c where c.company_id=cid and c.project_id=pid and c.status='DRAFT' and not exists(select 1 from public.subcontract_certificate_withdrawals w where w.company_id=cid and w.certificate_id=c.id)),
 'pending_corrections',(select count(*) from public.expense_correction_reviews r
 where r.company_id=cid and (r.original_project_id=pid or r.proposed_project_id=pid or exists(select 1 from public.expenses e, lateral jsonb_array_elements(coalesce(e.allocation_plan->'destinations','[]'::jsonb)) d where e.company_id=cid and e.id=r.expense_id and d->>'project_id'=pid::text))
 and not exists(select 1 from public.expense_correction_reviews n where n.company_id=cid and n.previous_review_id=r.id)
 and not exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.review_id=r.id)),
 'posted_split_expenses',(select count(*) from public.expenses e where e.company_id=cid and e.allocation_plan is not null and exists(select 1 from jsonb_array_elements(e.allocation_plan->'destinations') d where d->>'project_id'=pid::text)),
 'cost_debit_minor',(select coalesce(sum(l.debit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'),
 'cost_credit_minor',(select coalesce(sum(l.credit_minor::numeric),0)::text from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.project_id=pid and a.account_type='EXPENSE'),
 -- Separate actual GL dimensions; never net assets, liabilities or contracts together.
 'obligations',coalesce((select jsonb_agg(to_jsonb(b) order by account_code,subcontract_id,party_id) from
 (select a.code account_code,a.name account_name,a.system_key::text category,l.subcontract_id,l.party_id,s.contract_number,
 sum(l.debit_minor::numeric-l.credit_minor::numeric)::text balance_minor
 from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id
 left join public.subcontracts s on s.company_id=l.company_id and s.id=l.subcontract_id
 where l.company_id=cid and l.project_id=pid and a.requires_party and a.account_type in ('ASSET','LIABILITY','EQUITY')
 group by a.id,a.code,a.name,a.system_key,l.subcontract_id,l.party_id,s.contract_number
 having sum(l.debit_minor::numeric-l.credit_minor::numeric)<>0) b),'[]'::jsonb),
 'coverage','PROJECT_JOURNAL_DIMENSIONS_ONLY','closure','POLICY_UNAVAILABLE');
$$;
