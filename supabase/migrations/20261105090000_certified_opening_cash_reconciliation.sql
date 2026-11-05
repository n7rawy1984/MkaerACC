-- Certified business opening positions and physical counts; no hosted backfill.
-- Desired positions are not arbitrary journals. The server derives reconciliation
-- deltas against posted history; both certified positions and deltas must balance.
create table public.opening_balance_drafts (
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id),
 request_key uuid not null, request_hash text not null, opening_date date not null, period_month date not null,
 source_reference text not null check(length(source_reference) between 1 and 200),
 reason text not null check(length(reason) between 1 and 1000), evidence_reference text not null check(length(evidence_reference) between 1 and 2000),
 period_reference text not null check(length(period_reference) between 1 and 1000), positions jsonb not null check(jsonb_typeof(positions)='array'),
 created_by uuid not null references auth.users(id), created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id), unique(company_id,request_key), unique(company_id,source_reference),
 check(period_month=date_trunc('month',opening_date)::date)
);
create table public.opening_balance_postings (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),draft_id uuid not null,
 approval_reference text not null check(length(approval_reference) between 1 and 1000),
 journal_id uuid unique,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 foreign key(company_id,draft_id) references public.opening_balance_drafts(company_id,id),
 foreign key(company_id,journal_id) references public.journal_entries(company_id,id), unique(company_id,id),unique(company_id,draft_id)
);
create table public.opening_balance_reversals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),posting_id uuid not null,
 reason text not null check(length(reason) between 1 and 1000), journal_id uuid unique,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,posting_id),
 foreign key(company_id,posting_id) references public.opening_balance_postings(company_id,id),
 foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.cash_reconciliation_counts (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),request_key uuid not null,request_hash text not null,
 scope text not null check(scope in ('TREASURY','CUSTODY')),account_id uuid not null,treasury_id uuid,holder_id uuid,
 counted_at timestamptz not null,as_of_date date not null,counted_minor bigint not null check(counted_minor between 0 and 9000000000000000),
 gl_minor bigint not null,snapshot_hash text not null,location text not null check(length(location) between 1 and 200),
 responsible_id uuid not null,source_reference text not null check(length(source_reference) between 1 and 200),
 explanation text not null check(length(explanation) between 1 and 1000),evidence_reference text not null check(length(evidence_reference) between 1 and 2000),
 unposted_reference text not null check(length(unposted_reference)<=2000),
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),
 foreign key(company_id,account_id) references public.accounts(company_id,id),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id),
 foreign key(company_id,holder_id) references public.parties(company_id,id),
 foreign key(company_id,responsible_id) references public.parties(company_id,id),
 check((scope='TREASURY' and treasury_id is not null and holder_id is null) or (scope='CUSTODY' and treasury_id is null and holder_id is not null))
);
create table public.cash_reconciliation_reviews (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),count_id uuid not null,
 request_key uuid not null,request_hash text not null,decision text not null check(decision in ('MATCH_APPROVED','DIFFERENCE_REVIEWED','NEEDS_INFORMATION')),
 reason text not null check(length(reason) between 1 and 1000),created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),foreign key(company_id,count_id) references public.cash_reconciliation_counts(company_id,id)
);
-- Same financial roles as existing reports. Complete mixed opening schedules and
-- Treasury counts require existing Payroll visibility; do not leak hidden GL.
do $$ declare t text;begin
 foreach t in array array['opening_balance_drafts','opening_balance_postings','opening_balance_reversals','cash_reconciliation_counts','cash_reconciliation_reviews'] loop
  execute format('alter table public.%I enable row level security',t);
  execute format('alter table public.%I force row level security',t);
  execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);
  execute format('grant select on public.%I to authenticated',t);
  execute format('create trigger immutable_evidence before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
 end loop;
end;$$;
create function public.can_read_opening_reconciliation(cid uuid) returns boolean language sql stable security definer set search_path='' as $$
 select public.has_company_role(cid,'ACCOUNTING_ADMIN') or public.has_company_role(cid,'ACCOUNTANT') or public.has_company_role(cid,'MANAGEMENT_VIEWER');$$;
create policy opening_draft_read on public.opening_balance_drafts for select to authenticated using(public.can_read_opening_reconciliation(company_id) and public.has_permission(company_id,'payroll.manage'));
create policy opening_posting_read on public.opening_balance_postings for select to authenticated using(public.can_read_opening_reconciliation(company_id) and public.has_permission(company_id,'payroll.manage'));
create policy opening_reversal_read on public.opening_balance_reversals for select to authenticated using(public.can_read_opening_reconciliation(company_id) and public.has_permission(company_id,'payroll.manage'));
create policy cash_count_read on public.cash_reconciliation_counts for select to authenticated using(public.can_read_opening_reconciliation(company_id) and (scope='CUSTODY' or public.has_permission(company_id,'payroll.manage')));
create policy cash_review_read on public.cash_reconciliation_reviews for select to authenticated using(exists(select 1 from public.cash_reconciliation_counts c where c.company_id=cash_reconciliation_reviews.company_id and c.id=cash_reconciliation_reviews.count_id));
revoke all on function public.can_read_opening_reconciliation(uuid) from public,anon,authenticated,service_role;
-- RLS expressions use a public boolean-only helper; private schema USAGE is not broadened.
grant execute on function public.can_read_opening_reconciliation(uuid) to authenticated;
create function private.opening_snapshot(cid uuid,aid uuid,pid uuid,d date) returns jsonb language sql stable security definer set search_path='' as $$
 select jsonb_build_object('balance',coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)::text,
 'hash',encode(sha256(convert_to(coalesce(string_agg(to_jsonb(l)::text,E'\n' order by l.id),''),'UTF8')),'hex'))
 from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id
 where l.company_id=cid and l.account_id=aid and (exists(select 1 from public.accounts a where a.company_id=cid and a.id=aid and not a.requires_party) or l.party_id is not distinct from pid) and j.posting_date<=d;$$;
create function private.opening_period(cid uuid,d date) returns void language plpgsql set search_path='' as $$
 begin
 if d is null or d>(clock_timestamp() at time zone 'Asia/Dubai')::date or d<'2000-01-01' then raise exception 'Nonfuture evidenced opening date required' using errcode='23514';end if;
 if exists(select 1 from public.project_correction_period_events where company_id=cid and month=date_trunc('month',d)::date and state='CLOSED') then raise exception 'Existing closed financial correction period cannot be bypassed' using errcode='23514';end if;
 end;$$;
create function public.prepare_certified_opening(target_company_id uuid,target_request_key uuid,business_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
 declare actor uuid;v jsonb:=business_input;row_data jsonb;item jsonb;positions jsonb:='[]';normalized_positions jsonb:='[]';a public.accounts;t public.treasury_accounts;
 aid uuid;pid uuid;tid uuid;kind text;amount bigint;signed_amount numeric;total numeric:=0;delta_total numeric:=0;snap jsonb;d date;hash text;r public.opening_balance_drafts;k text;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Complete opening GL visibility required' using errcode='42501';end if;
 if target_request_key is null or jsonb_typeof(v) is distinct from 'object' then raise exception 'Opening business input required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop if k<>all(array['opening_date','period_month','source_reference','reason','evidence_reference','period_reference','positions']) then raise exception 'Unsupported opening input' using errcode='22023';end if;end loop;
 d:=(v->>'opening_date')::date;perform private.opening_period(target_company_id,d);
 if (v->>'period_month')::date is distinct from date_trunc('month',d)::date then raise exception 'Explicit opening accounting month required' using errcode='22023';end if;
 foreach k in array array['source_reference','reason','evidence_reference','period_reference'] loop
 if coalesce(length(btrim(v->>k)),0)<1 then raise exception 'Complete source, evidence, reason and period authorization required' using errcode='22023';end if;
 v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end loop;
 if jsonb_typeof(v->'positions') is distinct from 'array' or jsonb_array_length(v->'positions') not between 2 and 100 then raise exception 'Balanced supported opening positions required' using errcode='22023';end if;
 -- Normalize business fields before replay; authoritative snapshots are not caller input.
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 for item in select value from jsonb_array_elements(v->'positions') loop
  if jsonb_typeof(item)<>'object' then raise exception 'Opening position object required' using errcode='22023';end if;
  for k in select jsonb_object_keys(item) loop if k<>all(array['kind','account_id','party_id','treasury_id','amount_minor','side']) then raise exception 'Unsupported opening position' using errcode='22023';end if;end loop;
  if coalesce(btrim(item->>'amount_minor'),'')!~'^[0-9]+$' then raise exception 'Exact opening minor units required' using errcode='22023';end if;
  normalized_positions:=normalized_positions||jsonb_build_array(jsonb_build_object('kind',upper(btrim(item->>'kind')),'side',upper(btrim(item->>'side')),'amount_minor',((btrim(item->>'amount_minor'))::bigint)::text,'account_id',nullif(btrim(item->>'account_id'),'')::uuid,'party_id',nullif(btrim(item->>'party_id'),'')::uuid,'treasury_id',nullif(btrim(item->>'treasury_id'),'')::uuid));
 end loop;
 v:=jsonb_set(v,'{positions}',(select jsonb_agg(x order by x::text) from jsonb_array_elements(normalized_positions) x));
 v:=jsonb_set(jsonb_set(v,'{opening_date}',to_jsonb(d)),'{period_month}',to_jsonb(date_trunc('month',d)::date));
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('input',v,'actor',actor)::text,'UTF8'),'sha256'),'hex');
 select * into r from public.opening_balance_drafts where company_id=target_company_id and request_key=target_request_key;
 if found then if r.request_hash<>hash then raise exception 'Changed opening request' using errcode='22023';end if;return jsonb_build_object('id',r.id,'replayed',true);end if;
 if exists(select 1 from public.opening_balance_postings p join public.opening_balance_drafts b on b.company_id=p.company_id and b.id=p.draft_id where p.company_id=target_company_id and b.opening_date<>d) then raise exception 'Company cutover already established; no conflicting opening date' using errcode='23514';end if;
 for item in select value from jsonb_array_elements(v->'positions') loop
  for k in select jsonb_object_keys(item) loop if k<>all(array['kind','account_id','party_id','treasury_id','amount_minor','side']) then raise exception 'Unsupported opening position' using errcode='22023';end if;end loop;
  kind:=item->>'kind';pid:=nullif(item->>'party_id','')::uuid;tid:=nullif(item->>'treasury_id','')::uuid;
  if coalesce(item->>'amount_minor','')!~'^[0-9]+$' or item->>'side' is null or item->>'side' not in ('DEBIT','CREDIT') then raise exception 'Exact signed opening position required' using errcode='22023';end if;
  amount:=(item->>'amount_minor')::bigint;if amount not between 0 and 9000000000000000 then raise exception 'Opening amount outside safe range' using errcode='22023';end if;
  if kind='TREASURY' then
   select * into t from public.treasury_accounts where company_id=target_company_id and id=tid and type in ('CASH','BANK') and status='ACTIVE' for share;
   if not found or pid is not null or item->>'account_id' is not null or item->>'side'<>'DEBIT' then raise exception 'Supported real Cash/Bank opening required' using errcode='23514';end if;aid:=t.gl_account_id;
  elsif kind='CUSTODY' then
   if tid is not null or item->>'account_id' is not null or not private.party_has_person_role(target_company_id,pid,'CUSTODIAN') or item->>'side'<>'DEBIT' then raise exception 'Positive holder opening with authoritative Custody control required' using errcode='23514';end if;
   select id into aid from public.accounts where company_id=target_company_id and system_key='CUSTODY_ADVANCE';
  elsif kind in ('PARTNER_CURRENT','PARTNER_LOAN','PARTNER_CAPITAL','PARTNER_ADDITIONAL_CAPITAL') then
   if tid is not null or item->>'account_id' is not null or item->>'side'<>'CREDIT' or not exists(select 1 from public.parties where company_id=target_company_id and id=pid and type='OWNER') then raise exception 'Same-Company classified credit Partner opening required' using errcode='23514';end if;
   select account_id into aid from public.operational_liability_configuration where company_id=target_company_id and classification=kind order by created_at desc,id desc limit 1;
   if kind='PARTNER_LOAN' and exists(select 1 from public.operational_liability_postings where company_id=target_company_id and account_id=aid and counterparty_id=pid) then raise exception 'Existing document-scoped loans require loan-level reconciliation, not duplicate opening debt' using errcode='23514';end if;
  elsif kind='BALANCE_SHEET' then
   aid:=(item->>'account_id')::uuid;
   if pid is not null or tid is not null or exists(select 1 from public.treasury_accounts where company_id=target_company_id and gl_account_id=aid) or exists(select 1 from public.operational_liability_configuration where company_id=target_company_id and account_id=aid) then raise exception 'Dedicated nondimensional balance-sheet position required' using errcode='23514';end if;
  else raise exception 'Unsupported opening classification' using errcode='22023';end if;
  select * into a from public.accounts where company_id=target_company_id and id=aid for share;
  if not found or a.status<>'ACTIVE' or a.account_type not in ('ASSET','LIABILITY','EQUITY') or (kind in ('TREASURY','CUSTODY') and a.account_type<>'ASSET') or a.requires_party is distinct from (pid is not null) or (kind='BALANCE_SHEET' and a.system_key is not null) then raise exception 'Supported active balance-sheet account/dimensions required' using errcode='23514';end if;
  if exists(select 1 from jsonb_array_elements(positions) x where x->>'account_id'=aid::text and x->>'party_id' is not distinct from pid::text) then raise exception 'Duplicate opening scope' using errcode='23505';end if;
  if exists(select 1 from public.journal_lines where company_id=target_company_id and account_id=aid and party_id is not distinct from pid and kind not in ('TREASURY','CUSTODY') and (subcontract_id is not null or project_id is not null)) then raise exception 'Historical analytic/subledger dimensions need dedicated reconciliation' using errcode='23514';end if;
  snap:=private.opening_snapshot(target_company_id,aid,pid,d);signed_amount:=case when item->>'side'='DEBIT' then amount::numeric else -amount::numeric end;
  total:=total+signed_amount;delta_total:=delta_total+signed_amount-(snap->>'balance')::numeric;
  if abs(signed_amount-(snap->>'balance')::numeric)>9000000000000000 then raise exception 'Opening reconciliation delta exceeds safe range' using errcode='23514';end if;
  positions:=positions||jsonb_build_array(jsonb_build_object('kind',kind,'account_id',aid,'account_code',a.code,'party_id',pid,'treasury_id',tid,'target_minor',signed_amount::text,'existing_minor',snap->>'balance','delta_minor',(signed_amount-(snap->>'balance')::numeric)::text,'history_hash',snap->>'hash'));
 end loop;
 if total<>0 or delta_total<>0 then raise exception 'Certified positions and reconciliation deltas must both balance; supply legitimate counterpart evidence, never automatic profit/loss or suspense' using errcode='23514';end if;
 insert into public.opening_balance_drafts(company_id,request_key,request_hash,opening_date,period_month,source_reference,reason,evidence_reference,period_reference,positions,created_by)
 values(target_company_id,target_request_key,hash,d,(v->>'period_month')::date,v->>'source_reference',v->>'reason',v->>'evidence_reference',v->>'period_reference',positions,actor) returning * into r;
 return jsonb_build_object('id',r.id,'replayed',false);
 end;$$;
create function public.approve_certified_opening(target_company_id uuid,target_draft_id uuid,target_approval_reference text,target_confirmed boolean) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare actor uuid;b public.opening_balance_drafts;p public.opening_balance_postings;x jsonb;snap jsonb;journal uuid;lines jsonb:='[]';amount numeric;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Accounting Admin opening approval required' using errcode='42501';end if;
 if target_confirmed is distinct from true or coalesce(length(btrim(target_approval_reference)),0) not between 1 and 1000 then raise exception 'Explicit accounting posting confirmation and approval required' using errcode='22023';end if;
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into b from public.opening_balance_drafts where company_id=target_company_id and id=target_draft_id for share;
 if not found then raise exception 'Same-Company opening draft required' using errcode='23503';end if;
 select * into p from public.opening_balance_postings where company_id=target_company_id and draft_id=b.id;
 if found then if p.created_by<>actor or p.approval_reference<>btrim(target_approval_reference) then raise exception 'Changed opening approval intent' using errcode='22023';end if;return jsonb_build_object('id',p.id,'journal',p.journal_id,'replayed',true);end if;
 if not (private.company_commercial_readiness(target_company_id)->>'ready')::boolean then raise exception 'Commercial readiness required for new opening recognition' using errcode='42501';end if;
 perform private.opening_period(target_company_id,b.opening_date);
 if exists(select 1 from public.opening_balance_postings p join public.opening_balance_drafts d on d.company_id=p.company_id and d.id=p.draft_id where p.company_id=target_company_id and d.opening_date<>b.opening_date) then raise exception 'Conflicting Company cutover' using errcode='23514';end if;
 for x in select value from jsonb_array_elements(b.positions) loop
  if exists(select 1 from public.opening_balance_postings p join public.opening_balance_drafts d on d.company_id=p.company_id and d.id=p.draft_id cross join lateral jsonb_array_elements(d.positions) y where p.company_id=target_company_id and y->>'account_id'=x->>'account_id' and y->>'party_id' is not distinct from x->>'party_id' and not exists(select 1 from public.opening_balance_reversals r where r.company_id=p.company_id and r.posting_id=p.id)) then raise exception 'Opening scope already certified; controlled reversal required' using errcode='23505';end if;
  snap:=private.opening_snapshot(target_company_id,(x->>'account_id')::uuid,(x->>'party_id')::uuid,b.opening_date);
  if snap->>'hash'<>x->>'history_hash' then raise exception 'Opening history changed; prepare a fresh evidence review' using errcode='40001';end if;
  if not exists(select 1 from public.accounts where company_id=target_company_id and id=(x->>'account_id')::uuid and status='ACTIVE') then raise exception 'Opening account no longer active' using errcode='23514';end if;
  if x->>'kind'='TREASURY' and not exists(select 1 from public.treasury_accounts where company_id=target_company_id and id=(x->>'treasury_id')::uuid and gl_account_id=(x->>'account_id')::uuid and type in ('CASH','BANK') and status='ACTIVE') then raise exception 'Opening Treasury changed or became inactive' using errcode='23514';end if;
  if x->>'party_id' is not null and not exists(select 1 from public.parties where company_id=target_company_id and id=(x->>'party_id')::uuid and status='ACTIVE') then raise exception 'Opening party no longer active' using errcode='23514';end if;
  if x->>'kind'='CUSTODY' and not private.party_has_person_role(target_company_id,(x->>'party_id')::uuid,'CUSTODIAN') then raise exception 'Custody opening role changed' using errcode='23514';end if;
  if x->>'kind' like 'PARTNER_%' and not exists(select 1 from public.operational_liability_configuration c where c.company_id=target_company_id and c.classification=x->>'kind' and c.account_id=(x->>'account_id')::uuid) then raise exception 'Approved Partner opening mapping unavailable' using errcode='23514';end if;
  if x->>'kind'='PARTNER_LOAN' and exists(select 1 from public.operational_liability_postings where company_id=target_company_id and account_id=(x->>'account_id')::uuid and counterparty_id=(x->>'party_id')::uuid) then raise exception 'Opening loan overlaps document-scoped loan history; reconcile original evidence first' using errcode='23514';end if;
  amount:=(x->>'delta_minor')::numeric;
  if amount<>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',x->>'account_id','party_id',x->>'party_id','treasury_account_id',x->>'treasury_id','debit_minor',greatest(amount,0)::bigint,'credit_minor',greatest(-amount,0)::bigint));end if;
 end loop;
 if jsonb_array_length(lines)>0 then journal:=private.create_journal(target_company_id,b.opening_date,'Certified opening reconciliation: '||b.source_reference,'CERTIFIED_OPENING',b.id,'ORIGINAL',lines,actor,null);end if;
 insert into public.opening_balance_postings(company_id,draft_id,approval_reference,journal_id,created_by) values(target_company_id,b.id,btrim(target_approval_reference),journal,actor) returning * into p;
 return jsonb_build_object('id',p.id,'journal',journal,'replayed',false);
 end;$$;
-- All existing commands participate in the same cutover serialization boundary.
-- Once certified, earlier dated writes cannot silently invalidate that position.
create function private.guard_certified_opening() returns trigger language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare j public.journal_entries;
 begin
 perform private.serialize_operational_finance(new.company_id,'OPERATIONS');
 select * into j from public.journal_entries where company_id=new.company_id and id=new.journal_entry_id;
 if exists(select 1 from public.opening_balance_postings p join public.opening_balance_drafts d on d.company_id=p.company_id and d.id=p.draft_id cross join lateral jsonb_array_elements(d.positions) x where p.company_id=new.company_id and (x->>'account_id')::uuid=new.account_id and (x->>'party_id' is null or (x->>'party_id')::uuid is not distinct from new.party_id) and j.posting_date<=d.opening_date and not exists(select 1 from public.opening_balance_reversals r where r.company_id=p.company_id and r.posting_id=p.id)
 and j.reversal_of_journal_entry_id is distinct from p.journal_id) then raise exception 'Certified opening cutover is locked; use controlled evidence/reversal workflow' using errcode='23514';end if;
 return new;
 end;$$;
create trigger certified_opening_cutover before insert on public.journal_lines for each row execute function private.guard_certified_opening();
create function public.reverse_certified_opening(target_company_id uuid,target_posting_id uuid,target_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare actor uuid;p public.opening_balance_postings;b public.opening_balance_drafts;r public.opening_balance_reversals;journal uuid;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.reverse');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') or not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Accounting Admin reversal required' using errcode='42501';end if;
 if coalesce(length(btrim(target_reason)),0) not between 1 and 1000 then raise exception 'Documented reversal reason required' using errcode='22023';end if;
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into p from public.opening_balance_postings where company_id=target_company_id and id=target_posting_id;
 if not found then raise exception 'Same-Company certified opening required' using errcode='23503';end if;
 select * into r from public.opening_balance_reversals where company_id=target_company_id and posting_id=p.id;
 if found then if r.created_by<>actor or r.reason<>btrim(target_reason) then raise exception 'Changed reversal intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'journal',r.journal_id,'replayed',true);end if;
 select * into b from public.opening_balance_drafts where company_id=target_company_id and id=p.draft_id;
 perform private.opening_period(target_company_id,b.opening_date);
 if exists(select 1 from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id cross join lateral jsonb_array_elements(b.positions) x where l.company_id=target_company_id and l.account_id=(x->>'account_id')::uuid and (x->>'party_id' is null or l.party_id is not distinct from (x->>'party_id')::uuid) and j.posting_date>b.opening_date) then raise exception 'Later scoped movements depend on this opening; reconcile dependencies before reversal' using errcode='23514';end if;
 if p.journal_id is not null then journal:=private.reverse_journal(p.journal_id,b.opening_date,btrim(target_reason),actor);end if;
 insert into public.opening_balance_reversals(company_id,posting_id,reason,journal_id,created_by) values(target_company_id,p.id,btrim(target_reason),journal,actor) returning * into r;
 return jsonb_build_object('id',r.id,'journal',journal,'replayed',false);
 end;$$;
create function public.record_cash_reconciliation(target_company_id uuid,target_request_key uuid,business_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_variable
 declare actor uuid;v jsonb:=business_input;k text;scope text;tid uuid;holder uuid;responsible uuid;aid uuid;at_time timestamptz;d date;amount bigint;snap jsonb;hash text;r public.cash_reconciliation_counts;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if target_request_key is null or jsonb_typeof(v) is distinct from 'object' then raise exception 'Cash-count business inputs required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop if k<>all(array['scope','treasury_id','holder_id','responsible_id','counted_at','counted_minor','location','source_reference','explanation','evidence_reference','unposted_reference']) then raise exception 'Unsupported cash-count field' using errcode='22023';end if;end loop;
 scope:=v->>'scope';tid:=nullif(v->>'treasury_id','')::uuid;holder:=nullif(v->>'holder_id','')::uuid;responsible:=(v->>'responsible_id')::uuid;
 if coalesce(v->>'counted_at','')!~'(Z|[+-][0-9]{2}:[0-9]{2})$' then raise exception 'Count timestamp needs explicit timezone' using errcode='22023';end if;
 at_time:=(v->>'counted_at')::timestamptz;d:=(at_time at time zone 'Asia/Dubai')::date;
 if at_time is null or at_time>clock_timestamp() or at_time<'1900-01-01' or coalesce(v->>'counted_minor','')!~'^[0-9]+$' then raise exception 'Actual nonfuture count timestamp and exact amount required' using errcode='22023';end if;
 amount:=(v->>'counted_minor')::bigint;if amount not between 0 and 9000000000000000 then raise exception 'Safe physical amount required' using errcode='22023';end if;
 if not exists(select 1 from public.parties where company_id=target_company_id and id=responsible and (private.party_has_person_role(company_id,id,'CUSTODIAN') or private.party_has_person_role(company_id,id,'EMPLOYEE'))) then raise exception 'Same-Company accountable person required' using errcode='23503';end if;
 if scope='TREASURY' then
  if not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Complete Treasury GL visibility required' using errcode='42501';end if;
  select gl_account_id into aid from public.treasury_accounts where company_id=target_company_id and id=tid and type='CASH' and status='ACTIVE';
  if not found or holder is not null then raise exception 'Actual Company Cash location required; Bank is not physical cash' using errcode='23514';end if;
 elsif scope='CUSTODY' then
  if tid is not null or holder is distinct from responsible or not private.party_has_person_role(target_company_id,holder,'CUSTODIAN') then raise exception 'Actual same-Company custody holder required' using errcode='23514';end if;
  select id into aid from public.accounts where company_id=target_company_id and system_key='CUSTODY_ADVANCE' and status='ACTIVE';
  if aid is null then raise exception 'Custody control not configured' using errcode='23514';end if;
 else raise exception 'Cash scope required' using errcode='22023';end if;
 foreach k in array array['location','source_reference','explanation','evidence_reference','unposted_reference'] loop v:=jsonb_set(v,array[k],to_jsonb(btrim(coalesce(v->>k,''))));end loop;
 v:=jsonb_build_object('scope',scope,'treasury_id',tid,'holder_id',holder,'responsible_id',responsible,'counted_at',to_char(at_time at time zone 'UTC','YYYY-MM-DD"T"HH24:MI:SS.US"Z"'),'counted_minor',amount::text,'location',v->>'location','source_reference',v->>'source_reference','explanation',v->>'explanation','evidence_reference',v->>'evidence_reference','unposted_reference',v->>'unposted_reference');
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('input',v,'actor',actor)::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into r from public.cash_reconciliation_counts where company_id=target_company_id and request_key=target_request_key;
 if found then if r.request_hash<>hash then raise exception 'Changed physical count intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'replayed',true);end if;
 snap:=private.opening_snapshot(target_company_id,aid,holder,d);
 insert into public.cash_reconciliation_counts(company_id,request_key,request_hash,scope,account_id,treasury_id,holder_id,counted_at,as_of_date,counted_minor,gl_minor,snapshot_hash,location,responsible_id,source_reference,explanation,evidence_reference,unposted_reference,created_by)
 values(target_company_id,target_request_key,hash,scope,aid,tid,holder,at_time,d,amount,(snap->>'balance')::bigint,snap->>'hash',v->>'location',responsible,v->>'source_reference',v->>'explanation',v->>'evidence_reference',v->>'unposted_reference',actor) returning * into r;
 return jsonb_build_object('id',r.id,'replayed',false);
 end;$$;
create function public.review_cash_reconciliation(target_company_id uuid,target_request_key uuid,target_count_id uuid,target_decision text,target_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare actor uuid;c public.cash_reconciliation_counts;r public.cash_reconciliation_reviews;snap jsonb;hash text;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin count approval required' using errcode='42501';end if;
 if target_request_key is null or target_decision is null or target_decision not in ('MATCH_APPROVED','DIFFERENCE_REVIEWED','NEEDS_INFORMATION') or coalesce(length(btrim(target_reason)),0) not between 1 and 1000 then raise exception 'Explicit review decision and reason required' using errcode='22023';end if;
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into c from public.cash_reconciliation_counts where company_id=target_company_id and id=target_count_id;
 if not found then raise exception 'Same-Company count required' using errcode='23503';end if;
 if c.scope='TREASURY' and not public.has_permission(target_company_id,'payroll.manage') then raise exception 'Complete Treasury GL visibility required' using errcode='42501';end if;
 hash:=encode(extensions.digest(convert_to(jsonb_build_object('count',c.id,'decision',target_decision,'reason',btrim(target_reason),'actor',actor)::text,'UTF8'),'sha256'),'hex');
 select * into r from public.cash_reconciliation_reviews where company_id=target_company_id and request_key=target_request_key;
 if found then if r.request_hash<>hash then raise exception 'Changed review intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'replayed',true);end if;
 snap:=private.opening_snapshot(target_company_id,c.account_id,c.holder_id,c.as_of_date);
 if target_decision<>'NEEDS_INFORMATION' and snap->>'hash'<>c.snapshot_hash then raise exception 'Dated GL changed; retain old evidence and record a fresh count/reconciliation' using errcode='40001';end if;
 if target_decision='MATCH_APPROVED' and (c.counted_minor<>c.gl_minor or c.unposted_reference<>'') then raise exception 'Unresolved differences/support cannot be certified as matched' using errcode='23514';end if;
 insert into public.cash_reconciliation_reviews(company_id,count_id,request_key,request_hash,decision,reason,created_by) values(target_company_id,c.id,target_request_key,hash,target_decision,btrim(target_reason),actor) returning * into r;
 return jsonb_build_object('id',r.id,'replayed',false);
 end;$$;
create function public.cash_count_snapshot_fresh(cid uuid,count_id uuid) returns boolean language plpgsql stable security definer set search_path='' as $$
#variable_conflict use_column
 declare c public.cash_reconciliation_counts;
 begin
 if not public.can_read_opening_reconciliation(cid) then return false;end if;
 select * into c from public.cash_reconciliation_counts where company_id=cid and id=count_id;
 if not found or (c.scope='TREASURY' and not public.has_permission(cid,'payroll.manage')) then return false;end if;
 return (private.opening_snapshot(cid,c.account_id,c.holder_id,c.as_of_date)->>'hash')=c.snapshot_hash;
 end;$$;
revoke all on function public.cash_count_snapshot_fresh(uuid,uuid) from public,anon,authenticated,service_role;
grant execute on function public.cash_count_snapshot_fresh(uuid,uuid) to authenticated;
-- Reads expose snapshot freshness without bypassing the existing count RLS.
create view public.cash_reconciliation_register with(security_invoker=true) as
 select c.id,c.company_id,c.scope,c.account_id,c.treasury_id,c.holder_id,c.responsible_id,c.counted_at,c.as_of_date,c.counted_minor::text,c.gl_minor::text,
 (c.counted_minor::numeric-c.gl_minor)::text difference_minor,c.location,c.source_reference,c.explanation,c.evidence_reference,c.unposted_reference,c.created_at,
 public.cash_count_snapshot_fresh(c.company_id,c.id) snapshot_fresh,r.decision,r.reason review_reason,r.id review_id
 from public.cash_reconciliation_counts c left join lateral(select id,decision,reason from public.cash_reconciliation_reviews r where r.company_id=c.company_id and r.count_id=c.id order by created_at desc,id desc limit 1) r on true;
revoke all on public.cash_reconciliation_register from public,anon,authenticated,service_role;
grant select on public.cash_reconciliation_register to authenticated;
revoke all on function private.opening_snapshot(uuid,uuid,uuid,date),private.opening_period(uuid,date),private.guard_certified_opening() from public,anon,authenticated,service_role;
revoke all on function public.prepare_certified_opening(uuid,uuid,jsonb),public.approve_certified_opening(uuid,uuid,text,boolean),public.reverse_certified_opening(uuid,uuid,text),public.record_cash_reconciliation(uuid,uuid,jsonb),public.review_cash_reconciliation(uuid,uuid,uuid,text,text) from public,anon,authenticated,service_role;
grant execute on function public.prepare_certified_opening(uuid,uuid,jsonb),public.approve_certified_opening(uuid,uuid,text,boolean),public.reverse_certified_opening(uuid,uuid,text),public.record_cash_reconciliation(uuid,uuid,jsonb),public.review_cash_reconciliation(uuid,uuid,uuid,text,text) to authenticated;

-- Opening loan principal is settled as its own evidenced obligation, not a new
-- funding receipt. It never borrows another operational loan's parent record.
create table public.opening_loan_payments (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),opening_posting_id uuid not null,
 party_id uuid not null,account_id uuid not null,treasury_id uuid not null,posting_date date not null,
 amount_minor bigint not null check(amount_minor between 1 and 9000000000000000),
 request_key uuid not null,request_hash text not null,source_reference text not null check(length(source_reference) between 1 and 200),
 evidence_reference text not null check(length(evidence_reference) between 1 and 2000),approval_reference text not null check(length(approval_reference) between 1 and 1000),
 journal_id uuid not null unique,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,request_key),unique(company_id,source_reference),
 foreign key(company_id,opening_posting_id) references public.opening_balance_postings(company_id,id),
 foreign key(company_id,party_id) references public.parties(company_id,id),foreign key(company_id,account_id) references public.accounts(company_id,id),
 foreign key(company_id,treasury_id) references public.treasury_accounts(company_id,id),foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
create table public.opening_loan_payment_reversals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),payment_id uuid not null,
 posting_date date not null,reason text not null check(length(reason) between 1 and 1000),journal_id uuid not null unique,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,payment_id),foreign key(company_id,payment_id) references public.opening_loan_payments(company_id,id),
 foreign key(company_id,journal_id) references public.journal_entries(company_id,id)
);
do $$ declare t text;begin
 foreach t in array array['opening_loan_payments','opening_loan_payment_reversals'] loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy opening_loan_read on public.%I for select to authenticated using(public.can_read_opening_reconciliation(company_id))',t);
 execute format('create trigger immutable_evidence before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
 end loop;
end;$$;
create function public.pay_opening_partner_loan(target_company_id uuid,target_request_key uuid,business_input jsonb) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare actor uuid;v jsonb:=business_input;k text;p public.opening_balance_postings;b public.opening_balance_drafts;position jsonb;t public.treasury_accounts;
 pid uuid;party uuid;tid uuid;aid uuid;pay_date date;amount bigint;paid numeric;available numeric;row_id uuid:=gen_random_uuid();journal uuid;hash text;r public.opening_loan_payments;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.post');
 if target_request_key is null or jsonb_typeof(v) is distinct from 'object' then raise exception 'Opening loan repayment inputs required' using errcode='22023';end if;
 for k in select jsonb_object_keys(v) loop if k<>all(array['opening_posting_id','party_id','treasury_id','posting_date','amount_minor','source_reference','evidence_reference','approval_reference','confirmed']) then raise exception 'Unsupported opening loan input' using errcode='22023';end if;end loop;
 if (v->>'confirmed')::boolean is distinct from true or coalesce(v->>'amount_minor','')!~'^[0-9]+$' then raise exception 'Explicit repayment confirmation and exact money required' using errcode='22023';end if;
 pid:=(v->>'opening_posting_id')::uuid;party:=(v->>'party_id')::uuid;tid:=(v->>'treasury_id')::uuid;pay_date:=(v->>'posting_date')::date;amount:=(v->>'amount_minor')::bigint;
 perform private.opening_period(target_company_id,pay_date);
 if amount not between 1 and 9000000000000000 then raise exception 'Positive principal repayment required' using errcode='22023';end if;
 foreach k in array array['source_reference','evidence_reference','approval_reference'] loop if coalesce(length(btrim(v->>k)),0)=0 then raise exception 'Original repayment evidence and approval required' using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end loop;
 v:=jsonb_build_object('opening',pid,'party',party,'treasury',tid,'date',pay_date,'amount',amount::text,'source',v->>'source_reference','evidence',v->>'evidence_reference','approval',v->>'approval_reference','actor',actor);
 hash:=encode(extensions.digest(convert_to(v::text,'UTF8'),'sha256'),'hex');
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into r from public.opening_loan_payments where company_id=target_company_id and request_key=target_request_key;
 if found then if r.request_hash<>hash then raise exception 'Changed opening loan payment intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'journal',r.journal_id,'replayed',true);end if;
 select * into p from public.opening_balance_postings where company_id=target_company_id and id=pid;
 if not found or exists(select 1 from public.opening_balance_reversals where company_id=target_company_id and posting_id=pid) then raise exception 'Active same-Company certified opening required' using errcode='23503';end if;
 select * into b from public.opening_balance_drafts where company_id=target_company_id and id=p.draft_id;
 if pay_date<=b.opening_date then raise exception 'Loan repayment must follow cutover' using errcode='23514';end if;
 select x into position from jsonb_array_elements(b.positions) x where x->>'kind'='PARTNER_LOAN' and (x->>'party_id')::uuid=party;
 if position is null or (position->>'target_minor')::numeric>=0 then raise exception 'Evidenced opening loan principal required' using errcode='23514';end if;
 aid:=(position->>'account_id')::uuid;
 if not exists(select 1 from public.operational_liability_configuration c where c.company_id=target_company_id and c.classification='PARTNER_LOAN' and c.account_id=aid and c.allow_withdrawals and not exists(select 1 from public.operational_liability_configuration n where n.previous_configuration_id=c.id)) then raise exception 'Approved loan repayment configuration required' using errcode='23514';end if;
 with events as (
 select q.posting_date d,q.amount_minor::numeric amount from public.opening_loan_payments q where q.company_id=target_company_id and q.opening_posting_id=pid and q.party_id=party
 union all select r.posting_date,-q.amount_minor::numeric from public.opening_loan_payment_reversals r join public.opening_loan_payments q on q.company_id=r.company_id and q.id=r.payment_id where q.company_id=target_company_id and q.opening_posting_id=pid and q.party_id=party
 union all select pay_date,0),daily as(select events.d,sum(events.amount) amount from events group by events.d),running as(select daily.d,sum(daily.amount) over(order by daily.d) amount from daily)
 select coalesce(max(running.amount),0) into paid from running where running.d>=pay_date;
 if paid+amount>-(position->>'target_minor')::numeric then raise exception 'Opening loan principal would be overpaid' using errcode='23514';end if;
 with movements as(select j.posting_date d,sum(l.credit_minor::numeric-l.debit_minor::numeric) delta from public.journal_lines l join public.journal_entries j on j.company_id=l.company_id and j.id=l.journal_entry_id where l.company_id=target_company_id and l.account_id=aid and l.party_id=party group by j.posting_date union all select pay_date,0),daily as(select movements.d,sum(delta) delta from movements group by movements.d),running as(select daily.d,sum(delta) over(order by daily.d) balance from daily)
 select min(balance) into available from running where running.d>=pay_date;
 if available<amount then raise exception 'Repayment exceeds dated recorded Partner loan liability' using errcode='23514';end if;
 select * into t from public.treasury_accounts where company_id=target_company_id and id=tid and status='ACTIVE';
 if not found then raise exception 'Active same-Company payment Treasury required' using errcode='23503';end if;
 journal:=private.create_journal(target_company_id,pay_date,'Opening loan principal repayment: '||(v->>'source'),'OPENING_LOAN_REPAYMENT',row_id,'ORIGINAL',jsonb_build_array(jsonb_build_object('account_id',aid,'party_id',party,'debit_minor',amount,'credit_minor',0),jsonb_build_object('account_id',t.gl_account_id,'treasury_account_id',t.id,'debit_minor',0,'credit_minor',amount)),actor,null);
 insert into public.opening_loan_payments(id,company_id,opening_posting_id,party_id,account_id,treasury_id,posting_date,amount_minor,request_key,request_hash,source_reference,evidence_reference,approval_reference,journal_id,created_by)
 values(row_id,target_company_id,pid,party,aid,tid,pay_date,amount,target_request_key,hash,v->>'source',v->>'evidence',v->>'approval',journal,actor);
 return jsonb_build_object('id',row_id,'journal',journal,'replayed',false);
 end;$$;
create function public.reverse_opening_loan_payment(target_company_id uuid,target_payment_id uuid,target_date date,target_reason text) returns jsonb language plpgsql security definer set search_path='' as $$
#variable_conflict use_column
 declare actor uuid;p public.opening_loan_payments;r public.opening_loan_payment_reversals;journal uuid;
 begin
 actor:=private.operational_finance_actor(target_company_id,'accounting.reverse');
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then raise exception 'Accounting Admin payment reversal required' using errcode='42501';end if;
 if coalesce(length(btrim(target_reason)),0) not between 1 and 1000 then raise exception 'Exact payment reversal reason required' using errcode='22023';end if;
 perform private.serialize_operational_finance(target_company_id,'OPERATIONS');
 select * into p from public.opening_loan_payments where company_id=target_company_id and id=target_payment_id;
 if not found then raise exception 'Same-Company opening loan payment required' using errcode='23503';end if;
 select * into r from public.opening_loan_payment_reversals where company_id=target_company_id and payment_id=p.id;
 if found then if r.posting_date is distinct from target_date or r.reason<>btrim(target_reason) or r.created_by<>actor then raise exception 'Changed payment reversal intent' using errcode='22023';end if;return jsonb_build_object('id',r.id,'journal',r.journal_id,'replayed',true);end if;
 perform private.opening_period(target_company_id,target_date);
 if target_date<p.posting_date then raise exception 'Reversal cannot predate payment' using errcode='23514';end if;
 journal:=private.reverse_journal(p.journal_id,target_date,btrim(target_reason),actor);
 insert into public.opening_loan_payment_reversals(company_id,payment_id,posting_date,reason,journal_id,created_by) values(target_company_id,p.id,target_date,btrim(target_reason),journal,actor) returning * into r;
 return jsonb_build_object('id',r.id,'journal',journal,'replayed',false);
 end;$$;
revoke all on function public.pay_opening_partner_loan(uuid,uuid,jsonb),public.reverse_opening_loan_payment(uuid,uuid,date,text) from public,anon,authenticated,service_role;
grant execute on function public.pay_opening_partner_loan(uuid,uuid,jsonb),public.reverse_opening_loan_payment(uuid,uuid,date,text) to authenticated;

create unique index opening_source_normalized on public.opening_balance_drafts(company_id,lower(source_reference));
create unique index cash_count_source_normalized on public.cash_reconciliation_counts(company_id,scope,account_id,(coalesce(holder_id::text,'')),lower(source_reference));
create unique index opening_payment_source_normalized on public.opening_loan_payments(company_id,lower(source_reference));
