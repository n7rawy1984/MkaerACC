-- 98: Audited annual profit transfer and final year lock. No activation-time journals/configuration.
create table public.accounting_year_closures(
 company_id uuid not null,year_id uuid not null,state text not null check(state in('OPEN','FINAL')),
 journal_id uuid,version integer not null default 1,primary key(company_id,year_id),
 foreign key(company_id,year_id)references public.accounting_fiscal_years(company_id,id)on delete restrict,
 foreign key(company_id,journal_id)references public.journal_entries(company_id,id)on delete restrict
);
create table public.accounting_year_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,year_id uuid not null,request_id uuid not null,
 action text not null check(action in('FINALIZE','REOPEN')),request_hash text not null,reason text not null,
 reconciliation_reference text not null,journal_id uuid,result jsonb not null,actor uuid not null references auth.users(id),created_at timestamptz not null default now(),unique(company_id,request_id),
 foreign key(company_id,year_id)references public.accounting_fiscal_years(company_id,id)on delete restrict,
 foreign key(company_id,journal_id)references public.journal_entries(company_id,id)on delete restrict
);
alter table public.accounting_year_closures enable row level security;alter table public.accounting_year_closures force row level security;
alter table public.accounting_year_events enable row level security;alter table public.accounting_year_events force row level security;
create policy year_closure_read on public.accounting_year_closures for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy year_event_read on public.accounting_year_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
revoke all on public.accounting_year_closures,public.accounting_year_events from public,anon,authenticated,service_role;
grant select on public.accounting_year_closures,public.accounting_year_events to authenticated;
create trigger year_events_immutable before update or delete on public.accounting_year_events for each row execute function private.financial_evidence_immutable();
create or replace function private.commercial_control_type(k text)returns text language sql immutable set search_path='' as $$
 select case when k in('AR','ASSET_COST','ACCUMULATED_DEPRECIATION','PREPAYMENT')then 'ASSET'
 when k in('CUSTOMER_ADVANCE','OUTPUT_VAT','ACCRUED_LIABILITY')then 'LIABILITY'
 when k in('REVENUE','DISPOSAL_GAIN')then 'REVENUE'
 when k in('DEPRECIATION_EXPENSE','DISPOSAL_LOSS','ACCRUAL_EXPENSE')then 'EXPENSE'when k='RETAINED_EARNINGS'then 'EQUITY'end;
$$;
create function private.final_year_period_guard()returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.accounting_year_closures where company_id=old.company_id and year_id=old.year_id and state='FINAL')then raise exception 'Final year locked; Accounting Admin must use audited annual reopening first'using errcode='23514';end if;return new;end;$$;
create trigger final_year_period_guard before update on public.accounting_fiscal_periods for each row execute function private.final_year_period_guard();
create function private.final_year_journal_guard()returns trigger language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from public.accounting_year_closures c join public.accounting_fiscal_years y on y.company_id=c.company_id and y.id=c.year_id where c.company_id=new.company_id and c.state='FINAL'and new.posting_date between y.from_date and y.through_date)then raise exception 'Final fiscal year locked'using errcode='23514';end if;return new;end;$$;
create trigger final_year_journal_guard before insert on public.journal_entries for each row execute function private.final_year_journal_guard();
create function private.annual_close_plan(cid uuid,year_id uuid)returns jsonb language plpgsql stable set search_path='' as $$
#variable_conflict use_variable
declare y public.accounting_fiscal_years;r record;lines jsonb:='[]';retained uuid;net numeric:=0;n bigint;begin
 select *into y from public.accounting_fiscal_years where company_id=cid and id=year_id;
 if y.id is null then raise exception 'Company fiscal year required'using errcode='23514';end if;
 retained:=private.commercial_account(cid,'RETAINED_EARNINGS');
 for r in select l.account_id,l.party_id,l.project_id,l.treasury_account_id,l.subcontract_id,sum(l.debit_minor-l.credit_minor)::bigint balance from public.journal_lines l join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and e.posting_date between y.from_date and y.through_date and a.account_type::text in('REVENUE','EXPENSE')group by l.account_id,l.party_id,l.project_id,l.treasury_account_id,l.subcontract_id having sum(l.debit_minor-l.credit_minor)<>0 loop
 n:=r.balance;net:=net+n;lines:=lines||jsonb_build_array(private.commercial_line(r.account_id,abs(n),n>0,r.party_id,r.project_id,r.treasury_account_id)||jsonb_build_object('subcontract_id',r.subcontract_id));end loop;
 if net<>0 then lines:=lines||jsonb_build_array(private.commercial_line(retained,abs(net)::bigint,net<0));end if;
 return lines;end;$$;
create function public.command_annual_closing(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;prior public.accounting_year_events;y public.accounting_fiscal_years;c public.accounting_year_closures;p public.accounting_fiscal_periods;
 r record;lines jsonb:='[]';net numeric:=0;n bigint;j uuid;did uuid:=gen_random_uuid();retained uuid;result jsonb;begin
 actor:=private.operational_finance_actor(cid,'account.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or not public.has_permission(cid,'payroll.manage')then raise exception 'Accounting Admin with full ledger access required'using errcode='42501';end if;
 if action='REOPEN'then perform private.operational_finance_actor(cid,'accounting.reverse');end if;
 if request_id is null or action is null or action not in('FINALIZE','REOPEN')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>10000 or exists(select 1 from jsonb_object_keys(input)x where x not in('year_id','version','reason','reconciliation_reference','confirm_reconciled'))or coalesce(length(btrim(input->>'reason')),0)not between 5 and 1000 or coalesce(length(btrim(input->>'reconciliation_reference')),0)not between 5 and 1000 or (input->>'confirm_reconciled')::boolean is distinct from true then raise exception 'Audited year action and full reconciliation evidence required'using errcode='23514';end if;
 perform private.fiscal_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.accounting_year_events where company_id=cid and accounting_year_events.request_id=command_annual_closing.request_id;
 if prior.id is not null then if prior.request_hash<>h then raise exception 'Changed annual request'using errcode='23505';end if;return prior.result;end if;
 select *into y from public.accounting_fiscal_years where company_id=cid and id=(input->>'year_id')::uuid for update;
 if y.id is null or y.through_date>current_date then raise exception 'Completed configured fiscal year required'using errcode='23514';end if;
 select *into c from public.accounting_year_closures where company_id=cid and year_id=y.id for update;
 if coalesce(c.version,0)is distinct from(input->>'version')::integer then raise exception 'Year version changed; refresh'using errcode='40001';end if;
 select *into p from public.accounting_fiscal_periods where company_id=cid and year_id=y.id and through_date=y.through_date for update;
 if p.id is null then raise exception 'Final period missing'using errcode='23514';end if;
 if action='FINALIZE'then
 if c.state='FINAL'or exists(select 1 from public.accounting_fiscal_periods where company_id=cid and year_id=y.id and state<>'CLOSED')then raise exception 'Reconcile and close all periods before finalizing the year'using errcode='23514';end if;
 if exists(select 1 from public.journal_lines l join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and e.posting_date<y.from_date and a.account_type::text in('REVENUE','EXPENSE')group by l.account_id having sum(l.debit_minor-l.credit_minor)<>0)then raise exception 'Close prior unclosed results before this fiscal year'using errcode='23514';end if;
 if exists(select 1 from public.accounting_fiscal_years yy join public.accounting_year_closures cc on cc.company_id=yy.company_id and cc.year_id=yy.id where yy.company_id=cid and yy.from_date>y.through_date and cc.state='FINAL')then raise exception 'Later year already final; reopen later years first'using errcode='23514';end if;
 lines:=private.annual_close_plan(cid,y.id);
 -- A zero-turnover year has no invented zero journal; the audited lock still applies.
 if jsonb_array_length(lines)>0 then
 update public.accounting_fiscal_periods set state='OPEN'where company_id=cid and id=p.id;
 j:=private.create_journal(cid,y.through_date,'Annual closing — '||y.label,'ANNUAL_CLOSE',did,'CLOSING',lines,actor);
 update public.accounting_fiscal_periods set state='CLOSED'where company_id=cid and id=p.id;end if;
 insert into public.accounting_year_closures(company_id,year_id,state,journal_id,version)values(cid,y.id,'FINAL',j,1)on conflict(company_id,year_id)do update set state='FINAL',journal_id=excluded.journal_id,version=accounting_year_closures.version+1;
 else
 if c.state is distinct from 'FINAL'then raise exception 'Year is not final'using errcode='23514';end if;
 -- Reopening prior balances after later-year posting is deliberately not implicit.
 if exists(select 1 from public.journal_entries where company_id=cid and posting_date>y.through_date)then raise exception 'Later-year financial activity exists; controlled subsequent-year correction required'using errcode='23514';end if;
 update public.accounting_year_closures set state='OPEN',version=version+1 where company_id=cid and year_id=y.id;
 update public.accounting_fiscal_periods set state='OPEN',version=version+1 where company_id=cid and id=p.id;
 if c.journal_id is not null then j:=private.reverse_journal(c.journal_id,y.through_date,btrim(input->>'reason'),actor);end if;
 end if;
 result:=jsonb_build_object('year_id',y.id,'state',case when action='FINALIZE'then 'FINAL'else 'OPEN'end,'journal_id',j,'version',coalesce(c.version,0)+1);
 insert into public.accounting_year_events(id,company_id,year_id,request_id,action,request_hash,reason,reconciliation_reference,journal_id,result,actor)values(did,cid,y.id,request_id,action,h,btrim(input->>'reason'),btrim(input->>'reconciliation_reference'),j,result,actor);return result;
end;$$;
revoke all on function private.final_year_period_guard(),private.final_year_journal_guard(),public.command_annual_closing(uuid,uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.command_annual_closing(uuid,uuid,text,jsonb)to authenticated;

revoke all on function private.annual_close_plan(uuid,uuid)from public,anon,authenticated,service_role;

-- Annual transfers contain full-ledger, potentially confidential Payroll-derived totals.
-- Additive restrictive policies protect the closing journal and its exact reversals.
-- Existing non-closing journal visibility is unchanged; the boolean helper never exposes values.
create function public.can_read_annual_journal(cid uuid,jid uuid)returns boolean language sql stable security definer set search_path='' as $$
 select auth.uid()is not null and public.is_company_member(cid)and(public.has_permission(cid,'payroll.manage')or not exists(
 select 1 from public.journal_entries j left join public.journal_entries original on original.company_id=j.company_id and original.id=j.reversal_of_journal_entry_id
 where j.company_id=cid and j.id=jid and(j.source_type='ANNUAL_CLOSE'or original.source_type='ANNUAL_CLOSE')));
$$;
revoke all on function public.can_read_annual_journal(uuid,uuid)from public,anon,authenticated,service_role;
grant execute on function public.can_read_annual_journal(uuid,uuid)to authenticated;
create policy annual_journal_privacy on public.journal_entries as restrictive for select to authenticated using(public.can_read_annual_journal(company_id,id));
create policy annual_journal_line_privacy on public.journal_lines as restrictive for select to authenticated using(public.can_read_annual_journal(company_id,journal_entry_id));
