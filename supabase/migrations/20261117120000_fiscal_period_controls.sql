-- 95: Opt-in fiscal years/periods. Activation creates no Company policy or financial data.
-- All journal-producing commands share the gate. Existing Companies remain unchanged
-- until an Accounting Admin explicitly configures a fiscal year through the command.
create table public.accounting_fiscal_years(
 id uuid primary key default gen_random_uuid(), company_id uuid not null references public.companies(id) on delete restrict,
 label text not null check(length(btrim(label))between 1 and 100),from_date date not null,through_date date not null,
 created_by uuid not null references auth.users(id) on delete restrict,created_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,from_date),check(through_date>=from_date and through_date-from_date<=371)
);
create table public.accounting_fiscal_periods(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id)on delete restrict,
 year_id uuid not null,label text not null check(length(btrim(label))between 1 and 100),from_date date not null,through_date date not null,
 state text not null default 'OPEN'check(state in('OPEN','CLOSED')),version integer not null default 1 check(version>0),
 unique(company_id,id),foreign key(company_id,year_id)references public.accounting_fiscal_years(company_id,id)on delete restrict,
 unique(company_id,from_date),check(through_date>=from_date)
);
create table public.accounting_fiscal_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id)on delete restrict,
 request_id uuid not null,request_hash text not null,action text not null check(action in('CREATE_YEAR','CLOSE','REOPEN')),
 period_id uuid,reason text not null check(length(btrim(reason))between 5 and 1000),reconciliation_reference text,
 snapshot jsonb not null,result jsonb not null,created_by uuid not null references auth.users(id)on delete restrict,created_at timestamptz not null default now(),
 unique(company_id,request_id),foreign key(company_id,period_id)references public.accounting_fiscal_periods(company_id,id)on delete restrict
);
create index accounting_fiscal_period_lookup on public.accounting_fiscal_periods(company_id,from_date,through_date);
alter table public.accounting_fiscal_years enable row level security;alter table public.accounting_fiscal_years force row level security;
alter table public.accounting_fiscal_periods enable row level security;alter table public.accounting_fiscal_periods force row level security;
alter table public.accounting_fiscal_events enable row level security;alter table public.accounting_fiscal_events force row level security;
create policy fiscal_year_read on public.accounting_fiscal_years for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy fiscal_period_read on public.accounting_fiscal_periods for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy fiscal_event_read on public.accounting_fiscal_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
revoke all on public.accounting_fiscal_years,public.accounting_fiscal_periods,public.accounting_fiscal_events from public,anon,authenticated,service_role;
grant select on public.accounting_fiscal_years,public.accounting_fiscal_periods,public.accounting_fiscal_events to authenticated;
create trigger fiscal_events_immutable before update or delete on public.accounting_fiscal_events for each row execute function private.financial_evidence_immutable();

create function private.fiscal_company_lock(cid uuid)returns void language sql volatile set search_path='' as $$
 select pg_advisory_xact_lock(hashtextextended('NARVO:FISCAL:'||cid::text,0));
$$;
create function private.fiscal_journal_gate()returns trigger language plpgsql security definer set search_path='' as $$
begin
 -- Never wait behind a period transition after a financial command has taken
 -- its domain locks. Fail/retry atomically to avoid lock-order cycles.
 if not pg_try_advisory_xact_lock_shared(hashtextextended('NARVO:FISCAL:'||new.company_id::text,0))then
 raise exception 'Accounting period transition in progress; retry the same request'using errcode='40001';end if;
 if exists(select 1 from public.accounting_fiscal_years where company_id=new.company_id)and not exists(
 select 1 from public.accounting_fiscal_periods where company_id=new.company_id and state='OPEN'and new.posting_date between from_date and through_date)then
 raise exception 'Posting date has no open accounting period; ask Accounting Admin to review the period'using errcode='23514';end if;
 return new;
end;$$;
create trigger fiscal_period_posting_guard before insert on public.journal_entries for each row execute function private.fiscal_journal_gate();
revoke all on function private.fiscal_company_lock(uuid),private.fiscal_journal_gate()from public,anon,authenticated,service_role;

create function public.read_accounting_periods(cid uuid)returns jsonb language plpgsql stable security invoker set search_path='' as $$
begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Accounting period access denied'using errcode='42501';end if;
 return jsonb_build_object('company',cid,'configured',exists(select 1 from public.accounting_fiscal_years where company_id=cid),
 'years',coalesce((select jsonb_agg(to_jsonb(y)order by from_date)from public.accounting_fiscal_years y where company_id=cid),'[]'::jsonb),
 'periods',coalesce((select jsonb_agg(to_jsonb(p)order by from_date)from public.accounting_fiscal_periods p where company_id=cid),'[]'::jsonb));
end;$$;

create function public.command_accounting_period(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;v jsonb:=input;k text;prior public.accounting_fiscal_events;p public.accounting_fiscal_periods;
 h text;result jsonb;year_id uuid:=gen_random_uuid();period_id uuid;start_date date;end_date date;item jsonb;items jsonb:='[]';cursor_date date;reason text;reference text;snapshot jsonb:='{}';d numeric;c numeric;n bigint;
begin
 actor:=private.operational_finance_actor(cid,'account.manage');
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin period authority required'using errcode='42501';end if;
 if request_id is null or action is null or action not in('CREATE_YEAR','CLOSE','REOPEN')or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>20000 then raise exception 'Invalid period command'using errcode='22023';end if;
 for k in select jsonb_object_keys(input)loop
 if k<>all(case when action='CREATE_YEAR'then array['label','from','through','periods','reason']else array['id','version','reason','confirm_reconciled','reconciliation_reference']end)then raise exception 'Unsupported period input'using errcode='22023';end if;end loop;
 reason:=btrim(input->>'reason');if coalesce(length(reason),0)not between 5 and 1000 then raise exception 'Audited period reason required'using errcode='23514';end if;
 v:=jsonb_set(v,'{reason}',to_jsonb(reason));
 if action='CREATE_YEAR'then
 start_date:=(input->>'from')::date;end_date:=(input->>'through')::date;
 if start_date is null or end_date is null or end_date<start_date or end_date-start_date>371 or coalesce(length(btrim(input->>'label')),0)not between 1 and 100 or jsonb_typeof(input->'periods')is distinct from 'array'or jsonb_array_length(input->'periods')not between 1 and 53 then raise exception 'Explicit fiscal dates and contiguous periods required'using errcode='23514';end if;
 cursor_date:=start_date;
 for item in select value from jsonb_array_elements(input->'periods')order by(value->>'from')::date loop
 if jsonb_typeof(item)<>'object'or item-array['label','from','through']<>'{}'::jsonb or (item->>'from')::date is distinct from cursor_date or (item->>'through')::date is null or (item->>'through')::date<cursor_date or (item->>'through')::date>end_date or coalesce(length(btrim(item->>'label')),0)not between 1 and 100 then raise exception 'Fiscal periods must cover the year exactly without gaps or overlaps'using errcode='23514';end if;
 items:=items||jsonb_build_array(jsonb_build_object('label',btrim(item->>'label'),'from',(item->>'from')::date,'through',(item->>'through')::date));cursor_date:=(item->>'through')::date+1;
 end loop;
 if cursor_date is distinct from end_date+1 then raise exception 'Fiscal periods do not cover complete configured year'using errcode='23514';end if;
 v:=jsonb_build_object('from',start_date,'through',end_date,'label',btrim(input->>'label'),'periods',items,'reason',reason);
 else
 period_id:=(input->>'id')::uuid;
 if period_id is null or coalesce((input->>'version')::integer,0)<1 then raise exception 'Current period version required'using errcode='22023';end if;
 reference:=nullif(btrim(input->>'reconciliation_reference'),'');
 if action='CLOSE'and(input->'confirm_reconciled'is distinct from 'true'::jsonb or coalesce(length(reference),0)not between 5 and 1000 or not public.has_permission(cid,'payroll.manage'))then raise exception 'Complete ledger visibility and explicit reconciliation evidence required before closing'using errcode='23514';end if;
 v:=jsonb_build_object('id',period_id,'version',(input->>'version')::integer,'reason',reason,'confirm_reconciled',input->'confirm_reconciled','reconciliation_reference',reference);
 end if;
 h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'action',action,'input',v)::text,'UTF8'),'sha256'),'hex');
 perform private.fiscal_company_lock(cid);
 select *into prior from public.accounting_fiscal_events e where e.company_id=cid and e.request_id=command_accounting_period.request_id;
 if found then if prior.request_hash<>h then raise exception 'Period request intent changed'using errcode='22023';end if;return prior.result;end if;
 if action='CREATE_YEAR'then
 if exists(select 1 from public.accounting_fiscal_years y where y.company_id=cid and y.from_date<=end_date and y.through_date>=start_date)then raise exception 'Fiscal year overlaps existing configured dates'using errcode='23514';end if;
 insert into public.accounting_fiscal_years(id,company_id,label,from_date,through_date,created_by)values(year_id,cid,v->>'label',start_date,end_date,actor);
 for item in select value from jsonb_array_elements(items)loop insert into public.accounting_fiscal_periods(company_id,year_id,label,from_date,through_date)values(cid,year_id,item->>'label',(item->>'from')::date,(item->>'through')::date);end loop;
 result:=jsonb_build_object('company',cid,'year_id',year_id,'state','OPEN');
 else
 select *into p from public.accounting_fiscal_periods where company_id=cid and id=period_id for update;
 if not found then raise exception 'Same-Company accounting period required'using errcode='23503';end if;
 if p.version<>(v->>'version')::integer then raise exception 'Accounting period changed; refresh before retrying'using errcode='40001';end if;
 if (action='CLOSE'and p.state<>'OPEN')or(action='REOPEN'and p.state<>'CLOSED')then raise exception 'Period is already in requested state'using errcode='23514';end if;
 if action='CLOSE'then
 if exists(select 1 from public.journal_entries e left join public.journal_lines l on l.company_id=e.company_id and l.journal_entry_id=e.id where e.company_id=cid and e.posting_date between p.from_date and p.through_date group by e.id having count(l.id)<2 or coalesce(sum(l.debit_minor::numeric),0)<>coalesce(sum(l.credit_minor::numeric),0))then raise exception 'Incomplete or unbalanced posted journal prevents period close'using errcode='23514';end if;
 select count(distinct e.id),coalesce(sum(l.debit_minor::numeric),0),coalesce(sum(l.credit_minor::numeric),0)into n,d,c from public.journal_entries e join public.journal_lines l on l.company_id=e.company_id and l.journal_entry_id=e.id where e.company_id=cid and e.posting_date between p.from_date and p.through_date;
 snapshot:=jsonb_build_object('journals',n,'debit_minor',d::text,'credit_minor',c::text,'from',p.from_date,'through',p.through_date,'reconciliation_reference',reference);
 end if;
 update public.accounting_fiscal_periods set state=case when action='CLOSE'then 'CLOSED'else 'OPEN'end,version=version+1 where company_id=cid and id=period_id returning *into p;
 result:=jsonb_build_object('company',cid,'period_id',p.id,'state',p.state,'version',p.version,'snapshot',snapshot);
 end if;
 insert into public.accounting_fiscal_events(company_id,request_id,request_hash,action,period_id,reason,reconciliation_reference,snapshot,result,created_by)values(cid,request_id,h,action,period_id,reason,reference,snapshot,result,actor);
 return result;
end;$$;
revoke all on function public.read_accounting_periods(uuid),public.command_accounting_period(uuid,uuid,text,jsonb)from public,anon,authenticated,service_role;
grant execute on function public.read_accounting_periods(uuid),public.command_accounting_period(uuid,uuid,text,jsonb)to authenticated;
