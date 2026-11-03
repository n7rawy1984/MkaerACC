-- Scoped current-period Project reclassification. No source/cash/settlement rewrite.
create table public.project_correction_period_events (
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id) on delete restrict,
 month date not null check(month=date_trunc('month',month)::date),state text not null check(state in ('OPEN','CLOSED')),
 request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,reason text not null check(length(reason) between 1 and 500),input_hash text not null,
 created_at timestamptz not null default clock_timestamp(),unique(company_id,request_id),unique(company_id,month,state)
);
create table public.project_cost_corrections (
 id uuid primary key,company_id uuid not null,expense_id uuid not null,review_id uuid not null,correction_reference text not null,
 request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,
 correction_date date not null,month date not null,original_project_id uuid,corrected_project_id uuid,
 source_account_id uuid not null,destination_account_id uuid not null,amount_minor bigint not null check(amount_minor>0),
 original_journal_entry_id uuid not null,journal_entry_id uuid not null,reason text not null,evidence_reference text not null check(length(evidence_reference) between 1 and 500),
 unreconciled_attested boolean not null check(unreconciled_attested),input_hash text not null,created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,correction_reference),unique(company_id,request_id),unique(review_id),unique(journal_entry_id),
 foreign key(company_id,expense_id) references public.expenses(company_id,id) on delete restrict,
 foreign key(company_id,expense_id,review_id) references public.expense_correction_reviews(company_id,expense_id,id) on delete restrict,
 foreign key(company_id,original_project_id) references public.projects(company_id,id) on delete restrict,
 foreign key(company_id,corrected_project_id) references public.projects(company_id,id) on delete restrict,
 foreign key(company_id,source_account_id) references public.accounts(company_id,id) on delete restrict,
 foreign key(company_id,destination_account_id) references public.accounts(company_id,id) on delete restrict,
 foreign key(company_id,original_journal_entry_id) references public.journal_entries(company_id,id) on delete restrict,
 foreign key(company_id,journal_entry_id) references public.journal_entries(company_id,id) on delete restrict
);
create table public.project_cost_correction_reversals (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,correction_id uuid not null unique,
 request_id uuid not null,actor_id uuid not null references auth.users(id) on delete restrict,
 reversal_date date not null,journal_entry_id uuid not null unique,reason text not null check(length(reason) between 1 and 500),input_hash text not null,
 created_at timestamptz not null default clock_timestamp(),unique(company_id,request_id),
 foreign key(company_id,correction_id) references public.project_cost_corrections(company_id,id) on delete restrict,
 foreign key(company_id,journal_entry_id) references public.journal_entries(company_id,id) on delete restrict
);
-- Audit records never mutate; period state derives from immutable OPEN/CLOSED events.
create function private.protect_project_cost_correction() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Correction evidence is immutable' using errcode='23514';end;$$;
revoke all on function private.protect_project_cost_correction() from public,anon,authenticated,service_role;
alter table public.project_correction_period_events enable row level security;
alter table public.project_correction_period_events force row level security;
alter table public.project_cost_corrections enable row level security;
alter table public.project_cost_corrections force row level security;
alter table public.project_cost_correction_reversals enable row level security;
alter table public.project_cost_correction_reversals force row level security;
revoke all on public.project_correction_period_events,public.project_cost_corrections,public.project_cost_correction_reversals from public,anon,authenticated,service_role;
grant select on public.project_correction_period_events,public.project_cost_corrections,public.project_cost_correction_reversals to authenticated;
create policy correction_period_read on public.project_correction_period_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy project_cost_correction_read on public.project_cost_corrections for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy project_cost_correction_reversal_read on public.project_cost_correction_reversals for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create trigger correction_period_immutable before update or delete on public.project_correction_period_events for each row execute function private.protect_project_cost_correction();
create trigger cost_correction_immutable before update or delete on public.project_cost_corrections for each row execute function private.protect_project_cost_correction();
create trigger cost_correction_reversal_immutable before update or delete on public.project_cost_correction_reversals for each row execute function private.protect_project_cost_correction();

create function private.correction_text(value text) returns text language sql immutable set search_path='' as $$
 select nullif(btrim(value,E' \t\n\r\f'||chr(11)||chr(160)||chr(5760)||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279)),'')
$$;
revoke all on function private.correction_text(text) from public,anon,authenticated,service_role;
create function private.correction_authority(cid uuid) returns uuid language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();begin
 if actor is null then raise exception 'Denied' using errcode='42501';end if;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=cid and user_id=actor for share;
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN') or not public.has_permission(cid,'accounting.post') then raise exception 'Correction denied' using errcode='42501';end if;
 return actor;
end;$$;
revoke all on function private.correction_authority(uuid) from public,anon,authenticated,service_role;
create function public.set_project_correction_period(target_company_id uuid,request_id uuid,state text,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;m date:=date_trunc('month',statement_timestamp() at time zone 'UTC')::date;digest text;prior public.project_correction_period_events;event_id uuid;why text:=private.correction_text(reason);begin
 perform 1 from public.companies where id=target_company_id for update;actor:=private.correction_authority(target_company_id);
 if request_id is null or state is null or state not in ('OPEN','CLOSED') or why is null or length(why)>500 then raise exception 'Invalid period request' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'state',state,'reason',why)::text,'sha256'),'hex');
 select * into prior from public.project_correction_period_events e where e.company_id=target_company_id and e.request_id=set_project_correction_period.request_id;
 if found then if prior.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return to_jsonb(prior)-'input_hash';end if;
 if exists(select 1 from public.project_correction_period_events e where e.company_id=target_company_id and e.month=m and (e.state='CLOSED' or e.state=set_project_correction_period.state)) then raise exception 'Correction period already closed or unchanged' using errcode='23514';end if;
 if state='CLOSED' and not exists(select 1 from public.project_correction_period_events e where e.company_id=target_company_id and e.month=m and e.state='OPEN') then raise exception 'Correction period is not open' using errcode='23514';end if;
 insert into public.project_correction_period_events(company_id,month,state,request_id,actor_id,reason,input_hash) values(target_company_id,m,state,request_id,actor,why,digest) returning id into event_id;
 return (select to_jsonb(e)-'input_hash' from public.project_correction_period_events e where id=event_id);
end;$$;

-- Private eligibility computation is also re-run under execution locks.
create function private.project_correction_check(cid uuid,rid uuid) returns jsonb language plpgsql security definer set search_path='' as $$
declare r public.expense_correction_reviews;e public.expenses;t public.treasury_accounts;today date:=(statement_timestamp() at time zone 'UTC')::date;m date:=date_trunc('month',today)::date;source_account uuid;destination_account uuid;why text;begin
 select * into r from public.expense_correction_reviews where company_id=cid and id=rid;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 select * into e from public.expenses where company_id=cid and id=r.expense_id;
 if r.kind<>'PROJECT' then why:='ALLOCATION_ONLY';
 elsif exists(select 1 from public.expense_correction_reviews next where next.previous_review_id=r.id) then why:='STALE_REVIEW';
 elsif e.status<>'POSTED' or e.updated_at<>r.expense_updated_at or e.project_id is distinct from r.original_project_id then why:='SOURCE_CHANGED';
 elsif e.expense_date<m or e.expense_date>today or r.requested_effective_date<>today then why:='CURRENT_PERIOD_TODAY_ONLY';
 elsif exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='CLOSED') then why:='PERIOD_CLOSED';
 elsif not exists(select 1 from public.project_correction_period_events p where p.company_id=cid and p.month=m and p.state='OPEN') then why:='PERIOD_NOT_OPEN';
 elsif (public.get_my_company_subscription(cid)->>'access') is distinct from 'FULL' then why:='COMMERCIAL_ACCESS_REQUIRED';
 elsif e.funding_mode<>'TREASURY' or e.payment_method<>'CASH' or e.supplier_id is not null or e.paid_by_party_id is not null or e.vat_amount_minor<>0 or e.gross_amount_minor<>e.net_amount_minor then why:='UNSUPPORTED_SOURCE';
 elsif r.proposed_project_id is not distinct from e.project_id then why:='UNCHANGED_ALLOCATION';
 elsif exists(select 1 from public.project_cost_corrections c where c.company_id=cid and c.expense_id=e.id and not exists(select 1 from public.project_cost_correction_reversals v where v.correction_id=c.id)) then why:='LIVE_CORRECTION';
 elsif exists(select 1 from public.supplier_payment_allocations a where a.company_id=cid and a.expense_id=e.id) or exists(select 1 from public.custody_settlement_items i where i.company_id=cid and i.expense_id=e.id) then why:='SETTLEMENT_DEPENDENCY';end if;
 select * into t from public.treasury_accounts where company_id=cid and id=e.treasury_account_id;
 if why is null and (t.id is null or t.type<>'CASH' or t.project_id is not null) then why:='BANK_OR_SCOPED_TREASURY';end if;
 if why is null and exists(select 1 from public.projects p where p.company_id=cid and p.id in (e.project_id,r.proposed_project_id) and p.status<>'ACTIVE') then why:='PROJECT_NOT_ACTIVE';end if;
 select id into source_account from public.accounts where company_id=cid and system_key=case when e.project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 select id into destination_account from public.accounts where company_id=cid and system_key=case when r.proposed_project_id is null then 'COMPANY_EXPENSE'::public.system_account_key else 'PROJECT_COST'::public.system_account_key end and account_type='EXPENSE' and status='ACTIVE';
 if why is null and (source_account is null or destination_account is null) then why:='COST_MAPPING_UNAVAILABLE';end if;
 if why is null and (not exists(select 1 from public.journal_entries j where j.company_id=cid and j.id=e.posted_journal_entry_id and j.source_type='EXPENSE' and j.source_id=e.id and j.posting_purpose='ORIGINAL' and j.reversal_of_journal_entry_id is null)
 or (select count(*) from public.journal_lines where company_id=cid and journal_entry_id=e.posted_journal_entry_id)<>2
 or not exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=source_account and l.debit_minor=e.net_amount_minor and l.credit_minor=0 and l.project_id is not distinct from e.project_id and l.treasury_account_id is null and l.party_id is null and l.subcontract_id is null)
 or not exists(select 1 from public.journal_lines l where l.company_id=cid and l.journal_entry_id=e.posted_journal_entry_id and l.account_id=t.gl_account_id and l.credit_minor=e.net_amount_minor and l.debit_minor=0 and l.treasury_account_id=t.id and l.party_id is null and l.subcontract_id is null)) then why:='NONSTANDARD_SOURCE_JOURNAL';end if;
 return jsonb_build_object('eligible',why is null,'blocker',why,'review_id',r.id,'expense_id',e.id,'expense_reference',e.expense_reference,'original_project_id',e.project_id,'corrected_project_id',r.proposed_project_id,'amount_minor',e.net_amount_minor::text,'effective_date',today,'source_account_id',source_account,'destination_account_id',destination_account,'reason',r.reason,'requires_unreconciled_evidence',true);
end;$$;
revoke all on function private.project_correction_check(uuid,uuid) from public,anon,authenticated,service_role;
create function public.get_project_correction_eligibility(target_company_id uuid,target_review_id uuid) returns jsonb language plpgsql security definer set search_path='' as $$
begin perform 1 from public.companies where id=target_company_id for share;perform private.correction_authority(target_company_id);return private.project_correction_check(target_company_id,target_review_id);end;$$;

create function public.execute_project_cost_correction(target_company_id uuid,target_review_id uuid,request_id uuid,unreconciled_confirmed boolean,evidence_reference text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;r public.expense_correction_reviews;e public.expenses;c public.project_cost_corrections;effect jsonb;digest text;cid uuid:=gen_random_uuid();jid uuid;today date:=(statement_timestamp() at time zone 'UTC')::date;ev text:=private.correction_text(evidence_reference);begin
 perform 1 from public.companies where id=target_company_id for share;actor:=private.correction_authority(target_company_id);
 if request_id is null or target_review_id is null or unreconciled_confirmed is distinct from true or ev is null or length(ev)>500 then raise exception 'Unreconciled cash evidence required' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'review',target_review_id,'evidence',ev,'unreconciled',true)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('project-cost-correction:'||target_company_id::text||':'||request_id::text,0));
 select * into c from public.project_cost_corrections x where x.company_id=target_company_id and x.request_id=execute_project_cost_correction.request_id;
 if found then if c.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return (to_jsonb(c)-'input_hash')||jsonb_build_object('amount_minor',c.amount_minor::text);end if;
 select * into r from public.expense_correction_reviews where company_id=target_company_id and id=target_review_id;
 if not found then raise exception 'Review unavailable' using errcode='42501';end if;
 perform 1 from public.projects where company_id=target_company_id and id in(r.original_project_id,r.proposed_project_id) order by id for share;
 select * into e from public.expenses where company_id=target_company_id and id=r.expense_id for update;
 -- The latest review cannot be superseded while holding this shared Expense lock.
 if exists(select 1 from public.project_cost_corrections x where x.review_id=r.id) then raise exception 'Review already executed' using errcode='23514';end if;
 effect:=private.project_correction_check(target_company_id,target_review_id);
 if not (effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 perform 1 from public.treasury_accounts where company_id=target_company_id and id=e.treasury_account_id for share;
 perform 1 from public.accounts where company_id=target_company_id and id in((effect->>'source_account_id')::uuid,(effect->>'destination_account_id')::uuid) order by id for share;
 -- Revalidate mappings/lifecycle after any awaited locks.
 effect:=private.project_correction_check(target_company_id,target_review_id);
 if not (effect->>'eligible')::boolean then raise exception 'Correction blocked: %',effect->>'blocker' using errcode='23514';end if;
 jid:=private.create_journal(target_company_id,today,'Project allocation correction: '||e.expense_reference,'PROJECT_COST_CORRECTION',cid,'POST',jsonb_build_array(
 jsonb_build_object('account_id',effect->>'destination_account_id','debit_minor',e.net_amount_minor::text,'credit_minor','0','project_id',r.proposed_project_id,'memo',r.reason),
 jsonb_build_object('account_id',effect->>'source_account_id','debit_minor','0','credit_minor',e.net_amount_minor::text,'project_id',e.project_id,'memo',r.reason)),actor);
 insert into public.project_cost_corrections(id,company_id,expense_id,review_id,correction_reference,request_id,actor_id,correction_date,month,original_project_id,corrected_project_id,source_account_id,destination_account_id,amount_minor,original_journal_entry_id,journal_entry_id,reason,evidence_reference,unreconciled_attested,input_hash)
 values(cid,target_company_id,e.id,r.id,private.allocate_reference(target_company_id,'PCC',extract(year from today)::integer),request_id,actor,today,date_trunc('month',today)::date,e.project_id,r.proposed_project_id,(effect->>'source_account_id')::uuid,(effect->>'destination_account_id')::uuid,e.net_amount_minor,e.posted_journal_entry_id,jid,r.reason,ev,true,digest);
 return (select (to_jsonb(x)-'input_hash')||jsonb_build_object('amount_minor',x.amount_minor::text) from public.project_cost_corrections x where id=cid);
end;$$;

create function public.reverse_project_cost_correction(target_company_id uuid,target_correction_id uuid,request_id uuid,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid;c public.project_cost_corrections;v public.project_cost_correction_reversals;digest text;jid uuid;vid uuid;today date:=(statement_timestamp() at time zone 'UTC')::date;why text:=private.correction_text(reason);begin
 perform 1 from public.companies where id=target_company_id for share;actor:=private.correction_authority(target_company_id);
 if request_id is null or why is null or length(why)>500 then raise exception 'Reason required' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'correction',target_correction_id,'reason',why)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('project-cost-correction-reversal:'||target_company_id::text||':'||request_id::text,0));
 select * into v from public.project_cost_correction_reversals x where x.company_id=target_company_id and x.request_id=reverse_project_cost_correction.request_id;
 if found then if v.input_hash<>digest then raise exception 'Request changed' using errcode='22023';end if;return to_jsonb(v)-'input_hash';end if;
 select * into c from public.project_cost_corrections where company_id=target_company_id and id=target_correction_id;
 if not found then raise exception 'Correction unavailable' using errcode='42501';end if;
 perform 1 from public.expenses where company_id=target_company_id and id=c.expense_id for update;
 if c.month<>date_trunc('month',today)::date or not exists(select 1 from public.project_correction_period_events p where p.company_id=target_company_id and p.month=c.month and p.state='OPEN') or exists(select 1 from public.project_correction_period_events p where p.company_id=target_company_id and p.month=c.month and p.state='CLOSED') then raise exception 'Open current correction period required' using errcode='23514';end if;
 if exists(select 1 from public.project_cost_correction_reversals x where x.correction_id=c.id) then raise exception 'Correction already reversed' using errcode='23514';end if;
 jid:=private.reverse_journal(c.journal_entry_id,today,'Reverse Project correction: '||why,actor);
 insert into public.project_cost_correction_reversals(company_id,correction_id,request_id,actor_id,reversal_date,journal_entry_id,reason,input_hash) values(target_company_id,c.id,request_id,actor,today,jid,why,digest) returning id into vid;
 return (select to_jsonb(x)-'input_hash' from public.project_cost_correction_reversals x where id=vid);
end;$$;
-- Source cancellation must reverse its allocation adjustment first, atomically.
create function private.guard_corrected_expense_reversal() returns trigger language plpgsql security definer set search_path='' as $$
begin if old.status='POSTED' and new.status='REVERSED' and exists(select 1 from public.project_cost_corrections c where c.company_id=old.company_id and c.expense_id=old.id and not exists(select 1 from public.project_cost_correction_reversals v where v.correction_id=c.id)) then raise exception 'Reverse the live Project allocation correction before reversing this Expense' using errcode='23514';end if;return new;end;$$;
revoke all on function private.guard_corrected_expense_reversal() from public,anon,authenticated,service_role;
create trigger expense_project_correction_dependency before update on public.expenses for each row execute function private.guard_corrected_expense_reversal();
revoke all on function public.set_project_correction_period(uuid,uuid,text,text),public.get_project_correction_eligibility(uuid,uuid),public.execute_project_cost_correction(uuid,uuid,uuid,boolean,text),public.reverse_project_cost_correction(uuid,uuid,uuid,text) from public,anon,authenticated,service_role;
grant execute on function public.set_project_correction_period(uuid,uuid,text,text),public.get_project_correction_eligibility(uuid,uuid),public.execute_project_cost_correction(uuid,uuid,uuid,boolean,text),public.reverse_project_cost_correction(uuid,uuid,uuid,text) to authenticated;
