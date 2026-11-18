-- 96: Canonical customer receivables. No tenant configuration or financial rows on activation.
-- Customer is a role of an existing Party, not a duplicate identity or a new accounting engine.
create table public.commercial_controls(
 company_id uuid not null references public.companies(id) on delete restrict,key text not null,
 account_id uuid not null, primary key(company_id,key),unique(company_id,account_id),
 foreign key(company_id,account_id) references public.accounts(company_id,id) on delete restrict
);
create table public.customer_accounts(
 company_id uuid not null references public.companies(id) on delete restrict,party_id uuid not null,
 created_by uuid not null references auth.users(id),evidence text not null,primary key(company_id,party_id),
 foreign key(company_id,party_id)references public.parties(company_id,id)on delete restrict
);
create table public.commercial_documents(
 id uuid primary key,company_id uuid not null references public.companies(id)on delete restrict,
 kind text not null,date date not null,party_id uuid,project_id uuid,treasury_id uuid,
 parent_id uuid,related_id uuid,reference text not null,amount_minor bigint not null check(amount_minor>0),
 journal_id uuid not null,ar_reduction_minor bigint not null default 0 check(ar_reduction_minor>=0),customer_credit_minor bigint not null default 0 check(customer_credit_minor>=0),input jsonb not null,request_id uuid not null,request_hash text not null,
 created_by uuid not null references auth.users(id),created_at timestamptz not null default now(),
 unique(company_id,id),unique(company_id,request_id),unique(company_id,kind,reference),
 foreign key(company_id,party_id)references public.parties(company_id,id)on delete restrict,
 foreign key(company_id,project_id)references public.projects(company_id,id)on delete restrict,
 foreign key(company_id,treasury_id)references public.treasury_accounts(company_id,id)on delete restrict,
 foreign key(company_id,parent_id)references public.commercial_documents(company_id,id)on delete restrict,
 foreign key(company_id,related_id)references public.commercial_documents(company_id,id)on delete restrict,
 foreign key(company_id,journal_id)references public.journal_entries(company_id,id)on delete restrict
);
create index commercial_parent on public.commercial_documents(company_id,parent_id);
create index commercial_related on public.commercial_documents(company_id,related_id);
create table public.commercial_setup_events(
 id uuid primary key default gen_random_uuid(),company_id uuid not null references public.companies(id),
 request_id uuid not null,request_hash text not null,input jsonb not null,result jsonb not null,
 actor uuid not null references auth.users(id),created_at timestamptz not null default now(),unique(company_id,request_id)
);
alter table public.commercial_controls enable row level security;alter table public.commercial_controls force row level security;
alter table public.customer_accounts enable row level security;alter table public.customer_accounts force row level security;
alter table public.commercial_documents enable row level security;alter table public.commercial_documents force row level security;
alter table public.commercial_setup_events enable row level security;alter table public.commercial_setup_events force row level security;
create policy commercial_control_read on public.commercial_controls for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy customer_account_read on public.customer_accounts for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy commercial_document_read on public.commercial_documents for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT')or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create policy commercial_setup_read on public.commercial_setup_events for select to authenticated using(public.has_company_role(company_id,'ACCOUNTING_ADMIN')or public.has_company_role(company_id,'ACCOUNTANT'));
revoke all on public.commercial_controls,public.customer_accounts,public.commercial_documents,public.commercial_setup_events from public,anon,authenticated,service_role;
grant select on public.commercial_controls,public.customer_accounts,public.commercial_documents,public.commercial_setup_events to authenticated;
create trigger commercial_document_immutable before update or delete on public.commercial_documents for each row execute function private.financial_evidence_immutable();
create trigger commercial_setup_immutable before update or delete on public.commercial_setup_events for each row execute function private.financial_evidence_immutable();
create trigger commercial_customer_immutable before update or delete on public.customer_accounts for each row execute function private.financial_evidence_immutable();

-- Typed normalization before request hashing; no semantic changes from JSON key order or padded money/UUIDs.
create function private.normalize_commercial_input(v jsonb)returns jsonb language plpgsql immutable set search_path='' as $$
declare k text;s text;begin
 if jsonb_typeof(v)is distinct from 'object'then raise exception 'Object input required'using errcode='22023';end if;
 for k in select jsonb_object_keys(v)loop
 if jsonb_typeof(v->k)='string'then v:=jsonb_set(v,array[k],to_jsonb(btrim(v->>k)));end if;
 if k in('amount_minor','vat_minor','residual_minor','proceeds_minor')then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::bigint::text));
 elsif k in('life_months','vat_rate_bps')then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::integer));
 elsif k in('party_id','project_id','treasury_id','parent_id','related_id')then s:=nullif(v->>k,'');if s is null then v:=v-k;else v:=jsonb_set(v,array[k],to_jsonb(s::uuid::text));end if;
 elsif k in('date','due_date','service_date')then if coalesce(v->>k,'')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Unambiguous ISO calendar date required'using errcode='22023';end if;v:=jsonb_set(v,array[k],to_jsonb((v->>k)::date::text));
 elsif k='recognition_confirmed'then v:=jsonb_set(v,array[k],to_jsonb((v->>k)::boolean));end if;end loop;return v;end;$$;
create unique index commercial_sales_reference_ci on public.commercial_documents(company_id,lower(btrim(reference)))where kind in('AR_INVOICE','AR_CASH_SALE');
create unique index commercial_reference_ci on public.commercial_documents(company_id,kind,lower(btrim(reference)));
create function private.commercial_control_type(k text)returns text language sql immutable set search_path='' as $$
 select case k when 'AR'then 'ASSET' when 'CUSTOMER_ADVANCE'then 'LIABILITY'when 'REVENUE'then 'REVENUE'when 'OUTPUT_VAT'then 'LIABILITY'end;
$$;
create function private.commercial_account(cid uuid,k text)returns uuid language plpgsql stable set search_path='' as $$
declare a public.accounts;begin
 select x.*into a from public.commercial_controls c join public.accounts x on x.company_id=c.company_id and x.id=c.account_id where c.company_id=cid and c.key=k;
 if a.id is null or a.status::text<>'ACTIVE'or a.account_type::text is distinct from private.commercial_control_type(k)then raise exception 'Active compatible Company control mapping required: %',k using errcode='23514';end if;return a.id;end;$$;
create function private.commercial_line(a uuid,n bigint,credit boolean default false,p uuid default null,project uuid default null,t uuid default null)returns jsonb language sql immutable set search_path='' as $$
 select jsonb_build_object('account_id',a,'debit_minor',case when credit then '0'else n::text end,'credit_minor',case when credit then n::text else '0'end,'party_id',p,'project_id',project,'treasury_account_id',t);
$$;
create function private.commercial_bank(cid uuid,t uuid,d date,n bigint,outflow boolean)returns uuid language plpgsql volatile set search_path='' as $$
declare a public.treasury_accounts;b numeric;future_min numeric;begin
 select *into a from public.treasury_accounts where company_id=cid and id=t for update;
 if a.id is null or a.status::text<>'ACTIVE'then raise exception 'Active Company Treasury required'using errcode='23514';end if;
 -- Actual GL money location, including historical running balance; no fabricated funding.
 if outflow then
 select coalesce(sum(l.debit_minor-l.credit_minor),0)into b from public.journal_lines l join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id where l.company_id=cid and l.treasury_account_id=t and e.posting_date<=d;
 select min(v)into future_min from(select b+sum(delta)over(order by posting_date) v from(select e.posting_date,sum(l.debit_minor-l.credit_minor)delta from public.journal_lines l join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id where l.company_id=cid and l.treasury_account_id=t and e.posting_date>d group by e.posting_date)s)q;
 if least(b,coalesce(future_min,b))<n then raise exception 'Insufficient historical Treasury funds'using errcode='23514';end if;end if;return a.gl_account_id;
end;$$;

create function public.configure_commercial_accounting(cid uuid,request_id uuid,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;h text;r public.commercial_setup_events;k text;a public.accounts;p uuid;result jsonb;begin
 actor:=private.operational_finance_actor(cid,'account.manage');if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin required'using errcode='42501';end if;
 if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>10000 or coalesce(length(btrim(input->>'evidence')),0)not between 5 and 1000 or exists(select 1 from jsonb_object_keys(input)x where x not in('controls','customer_id','evidence'))then raise exception 'Invalid audited setup'using errcode='22023';end if;
 perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into r from public.commercial_setup_events where company_id=cid and commercial_setup_events.request_id=configure_commercial_accounting.request_id;
 if r.id is not null then if r.request_hash<>h then raise exception 'Changed setup request'using errcode='23505';end if;return r.result;end if;
 if input?'controls'then
 if jsonb_typeof(input->'controls')is distinct from 'object'then raise exception 'Invalid controls'using errcode='22023';end if;
 for k in select jsonb_object_keys(input->'controls')loop
 if private.commercial_control_type(k)is null then raise exception 'Unsupported control %',k using errcode='22023';end if;
 select *into a from public.accounts where company_id=cid and id=(input->'controls'->>k)::uuid;
 if a.id is null or a.status::text<>'ACTIVE'or a.account_type::text<>private.commercial_control_type(k)or a.requires_party<>(k in('AR','CUSTOMER_ADVANCE'))then raise exception 'Invalid typed control %',k using errcode='23514';end if;
 if exists(select 1 from public.commercial_controls where company_id=cid and key=k and account_id<>a.id)then raise exception 'Control already mapped; explicit accounting migration required'using errcode='23514';end if;
 -- No adopting an unexplained historical balance into a new subledger.
 if k in('AR','CUSTOMER_ADVANCE')and not exists(select 1 from public.commercial_controls where company_id=cid and key=k)and exists(select 1 from public.journal_lines where company_id=cid and account_id=a.id)then raise exception 'Historical control requires reconciled opening workflow'using errcode='23514';end if;
 insert into public.commercial_controls values(cid,k,a.id)on conflict(company_id,key)do nothing;
 end loop;end if;
 if input?'customer_id'then p:=(input->>'customer_id')::uuid;
 if not exists(select 1 from public.parties where company_id=cid and id=p and status::text='ACTIVE'and type::text in('OTHER','SUPPLIER'))then raise exception 'Active existing customer-capable Party required; do not duplicate employees or contractors'using errcode='23514';end if;
 insert into public.customer_accounts values(cid,p,actor,input->>'evidence')on conflict do nothing;end if;
 result:=jsonb_build_object('configured',true);insert into public.commercial_setup_events(company_id,request_id,request_hash,input,result,actor)values(cid,request_id,h,input,result,actor);return result;
end;$$;

create function private.customer_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql volatile set search_path='' as $$
#variable_conflict use_variable
declare n bigint:=(v->>'amount_minor')::bigint;tax bigint:=coalesce((v->>'vat_minor')::bigint,0);d date:=(v->>'date')::date;p uuid:=nullif(v->>'party_id','')::uuid;project uuid:=nullif(v->>'project_id','')::uuid;t uuid:=nullif(v->>'treasury_id','')::uuid;
 parent public.commercial_documents;adv public.commercial_documents;used numeric;available numeric;lines jsonb;bank uuid;reduction bigint:=0;credit_balance bigint:=0;remaining_net bigint;remaining_tax bigint;expected_tax bigint;
begin
 if kind not in('AR_INVOICE','AR_CASH_SALE','AR_RECEIPT','AR_ADVANCE','AR_APPLY','AR_CREDIT','AR_REFUND')then raise exception 'Unsupported customer event'using errcode='22023';end if;
 if exists(select 1 from jsonb_object_keys(v)x where x<>all(array['economic_kind','date','party_id','project_id','treasury_id','parent_id','related_id','reference','amount_minor','vat_minor','vat_rate_bps','tax_evidence','evidence','due_date','recognition_confirmed']))or n is null or n<=0 or n>9000000000000000 or tax<0 or d is null or d>current_date or coalesce(length(btrim(v->>'reference')),0)not between 1 and 120 or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 1000 then raise exception 'Check customer amount, date, evidence and reference'using errcode='23514';end if;
 if kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE')and(v?'parent_id'or v?'related_id')or kind<>'AR_APPLY'and v?'related_id'or kind not in('AR_CASH_SALE','AR_RECEIPT','AR_ADVANCE','AR_REFUND')and v?'treasury_id'or kind not in('AR_INVOICE','AR_CASH_SALE')and(v?'economic_kind'or v?'recognition_confirmed'or v?'due_date'or v?'vat_rate_bps'or v?'tax_evidence')then raise exception 'Fields do not belong to this customer event'using errcode='22023';end if;
 if not exists(select 1 from public.customer_accounts where company_id=cid and party_id=p)then raise exception 'Company customer relationship required'using errcode='23514';end if;
 if project is not null and not exists(select 1 from public.projects where company_id=cid and id=project)then raise exception 'Company Project required'using errcode='23514';end if;
 perform private.opening_period(cid,d);
 if kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE')and not exists(select 1 from public.parties where company_id=cid and id=p and status::text='ACTIVE')then raise exception 'Active customer required for new business'using errcode='23514';end if;
 if kind in('AR_INVOICE','AR_CASH_SALE')then
 if v->>'economic_kind'is distinct from 'EARNED_SERVICE'then raise exception 'This workflow supports evidenced earned services; inventory sales/COGS and construction progress require their supported recognition workflow'using errcode='23514';end if;
 if (v->>'recognition_confirmed')::boolean is distinct from true or (v->>'due_date')::date<d or v->>'due_date'is null then raise exception 'Earned/delivered evidence and valid due date required'using errcode='23514';end if;
 if tax>0 and(coalesce(length(btrim(v->>'tax_evidence')),0)<5 or (v->>'vat_rate_bps')::integer is null or (v->>'vat_rate_bps')::integer not between 1 and 10000 or tax<>round(n::numeric*(v->>'vat_rate_bps')::integer/10000))then raise exception 'Explicit supported output tax rate and evidence required'using errcode='23514';end if;
 if kind='AR_CASH_SALE'then bank:=private.commercial_bank(cid,t,d,n+tax,false);end if;
 lines:=jsonb_build_array(case when kind='AR_CASH_SALE'then private.commercial_line(bank,n+tax,false,null,null,t)else private.commercial_line(private.commercial_account(cid,'AR'),n+tax,false,p,project)end,private.commercial_line(private.commercial_account(cid,'REVENUE'),n,true,null,project));
 if tax>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'OUTPUT_VAT'),tax,true));end if;
 elsif kind='AR_ADVANCE'then
 if tax<>0 then raise exception 'Taxable customer deposits require a supported tax-point workflow; not zero-rated by assumption'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,false);lines:=jsonb_build_array(private.commercial_line(bank,n,false,null,null,t),private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,true,p));
 elsif kind='AR_REFUND'then
 select *into adv from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if adv.id is null or adv.kind not in('AR_ADVANCE','AR_CREDIT')or adv.party_id<>p or adv.date>d or tax<>0 or project is not null then raise exception 'Same-customer refundable deposit/credit required'using errcode='23514';end if;
 available:=(case when adv.kind='AR_ADVANCE'then adv.amount_minor else adv.customer_credit_minor end)-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and(s.related_id=adv.id or s.parent_id=adv.id)),0);
 if n>available then raise exception 'Refund exceeds available customer credit'using errcode='23514';end if;
 bank:=private.commercial_bank(cid,t,d,n,true);lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,false,p),private.commercial_line(bank,n,true,null,null,t));
 else
 select *into parent from public.commercial_documents where company_id=cid and id=(v->>'parent_id')::uuid for update;
 if parent.id is null or (parent.kind<>'AR_INVOICE'and not(kind='AR_CREDIT'and parent.kind='AR_CASH_SALE'))or parent.party_id<>p or parent.date>d or project is distinct from parent.project_id then raise exception 'Same customer invoice, Project and chronological allocation required'using errcode='23514';end if;
 select coalesce(sum(ar_reduction_minor),0)into used from public.commercial_documents where company_id=cid and parent_id=parent.id;
 available:=case when parent.kind='AR_CASH_SALE'then 0 else parent.amount_minor-used end;
 if kind<>'AR_CREDIT'and n>available then raise exception 'Amount exceeds invoice outstanding; paid credits require refund/credit-liability workflow'using errcode='23514';end if;
 if kind='AR_CREDIT'then
 select (parent.input->>'amount_minor')::bigint-coalesce(sum((x.input->>'amount_minor')::bigint),0),(parent.input->>'vat_minor')::bigint-coalesce(sum((x.input->>'vat_minor')::bigint),0)into remaining_net,remaining_tax from public.commercial_documents x where x.company_id=cid and x.parent_id=parent.id and x.kind='AR_CREDIT';
 remaining_tax:=coalesce(remaining_tax,0);
 expected_tax:=case when n=remaining_net then remaining_tax when coalesce((parent.input->>'vat_minor')::bigint,0)>0 then round(n::numeric*(parent.input->>'vat_rate_bps')::integer/10000)::bigint else 0 end;
 if n>remaining_net or tax>remaining_tax or tax<>expected_tax then raise exception 'Credit exceeds original revenue/tax or does not match final rounded tax remainder'using errcode='23514';end if;
 reduction:=least(n+tax,available);credit_balance:=n+tax-reduction;
 lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'REVENUE'),n,false,null,project));
 if reduction>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'AR'),reduction,true,p,project));end if;
 if credit_balance>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),credit_balance,true,p));end if;
 if tax>0 then lines:=lines||jsonb_build_array(private.commercial_line(private.commercial_account(cid,'OUTPUT_VAT'),tax));end if;
 elsif kind='AR_RECEIPT'then
 if tax<>0 then raise exception 'Receipt cannot recreate tax'using errcode='23514';end if;
 reduction:=n;bank:=private.commercial_bank(cid,t,d,n,false);lines:=jsonb_build_array(private.commercial_line(bank,n,false,null,null,t),private.commercial_line(private.commercial_account(cid,'AR'),n,true,p,project));
 else
 if tax<>0 then raise exception 'Allocation cannot recreate tax'using errcode='23514';end if;
 select *into adv from public.commercial_documents where company_id=cid and id=(v->>'related_id')::uuid for update;
 if adv.id is null or adv.kind not in('AR_ADVANCE','AR_CREDIT')or adv.party_id<>p or adv.date>d or n>(case when adv.kind='AR_ADVANCE'then adv.amount_minor else adv.customer_credit_minor end)-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and(s.related_id=adv.id or s.parent_id=adv.id)),0)then raise exception 'Available same-customer advance required'using errcode='23514';end if;
 reduction:=n;lines:=jsonb_build_array(private.commercial_line(private.commercial_account(cid,'CUSTOMER_ADVANCE'),n,false,p),private.commercial_line(private.commercial_account(cid,'AR'),n,true,p,project));end if;end if;
 return jsonb_build_object('lines',lines,'ar_reduction',reduction,'customer_credit',credit_balance,'amount',case when kind in('AR_INVOICE','AR_CASH_SALE','AR_CREDIT')then n+tax else n end);
end;$$;

create function public.command_customer_accounting(cid uuid,request_id uuid,kind text,input jsonb)returns jsonb language plpgsql volatile security definer set search_path='' as $$
#variable_conflict use_variable
declare actor uuid;req private.financial_command_requests;h text;prior public.commercial_documents;plan jsonb;doc uuid:=gen_random_uuid();j uuid;begin
 actor:=private.operational_finance_actor(cid,'accounting.post');if request_id is null or jsonb_typeof(input)is distinct from 'object'or octet_length(input::text)>16000 then raise exception 'Invalid customer command'using errcode='22023';end if;
 input:=private.normalize_commercial_input(input);
 perform private.serialize_operational_finance(cid,'OPERATIONS');h:=encode(extensions.digest(convert_to(jsonb_build_object('actor',actor,'kind',kind,'input',input)::text,'UTF8'),'sha256'),'hex');
 select *into prior from public.commercial_documents where company_id=cid and commercial_documents.request_id=command_customer_accounting.request_id;
 if prior.id is not null then if prior.request_hash<>h then raise exception 'Changed customer request'using errcode='23505';end if;return jsonb_build_object('id',prior.id,'journal_id',prior.journal_id);end if;
 req:=private.reserve_financial_command(cid,'COMMERCIAL_'||kind,request_id,h,actor);
 plan:=private.customer_plan(cid,kind,input);
 j:=private.create_journal(cid,(input->>'date')::date,btrim(input->>'reference')||' '||btrim(input->>'evidence'),kind,doc,'ORIGINAL',plan->'lines',actor);
 insert into public.commercial_documents(id,company_id,kind,date,party_id,project_id,treasury_id,parent_id,related_id,reference,amount_minor,journal_id,ar_reduction_minor,customer_credit_minor,input,request_id,request_hash,created_by)values(doc,cid,kind,(input->>'date')::date,(input->>'party_id')::uuid,nullif(input->>'project_id','')::uuid,nullif(input->>'treasury_id','')::uuid,nullif(input->>'parent_id','')::uuid,nullif(input->>'related_id','')::uuid,btrim(input->>'reference'),(plan->>'amount')::bigint,j,(plan->>'ar_reduction')::bigint,(plan->>'customer_credit')::bigint,input,request_id,h,actor);
 perform private.complete_financial_command(req.id,j);return jsonb_build_object('id',doc,'journal_id',j);end;$$;

create function public.read_customer_accounts(cid uuid,as_of date)returns jsonb language plpgsql stable security invoker set search_path='' as $$
declare result jsonb;begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Customer access denied'using errcode='42501';end if;
 if as_of is null then raise exception 'As-of date required'using errcode='22023';end if;
 select jsonb_build_object('customers',coalesce((select jsonb_agg(jsonb_build_object('id',p.id,'name',p.name,'code',p.code))from public.customer_accounts c join public.parties p on p.company_id=c.company_id and p.id=c.party_id where c.company_id=cid),'[]'::jsonb),
 'documents',coalesce((select jsonb_agg(to_jsonb(x)||jsonb_build_object('amount_minor',x.amount_minor::text,'ar_reduction_minor',x.ar_reduction_minor::text,'customer_credit_minor',x.customer_credit_minor::text,'outstanding_minor',case when x.kind='AR_INVOICE'then(x.amount_minor-coalesce((select sum(s.ar_reduction_minor)from public.commercial_documents s where s.company_id=cid and s.parent_id=x.id and s.date<=as_of),0))::text when x.kind in('AR_ADVANCE','AR_CREDIT')then((case when x.kind='AR_ADVANCE'then x.amount_minor else x.customer_credit_minor end)-coalesce((select sum(s.amount_minor)from public.commercial_documents s where s.company_id=cid and s.date<=as_of and(s.related_id=x.id or s.parent_id=x.id)),0))::text else null end,'days_overdue',case when x.kind='AR_INVOICE'then greatest(0,as_of-(x.input->>'due_date')::date)else 0 end)order by x.date,x.id)from public.commercial_documents x where x.company_id=cid and x.kind like 'AR_%'and x.date<=as_of),'[]'::jsonb),
 'gl',coalesce((select jsonb_agg(to_jsonb(q))from(select l.party_id,c.key,sum(l.debit_minor-l.credit_minor)::text balance_minor from public.commercial_controls c join public.journal_lines l on l.company_id=c.company_id and l.account_id=c.account_id join public.journal_entries e on e.company_id=l.company_id and e.id=l.journal_entry_id where c.company_id=cid and c.key in('AR','CUSTOMER_ADVANCE')and e.posting_date<=as_of group by l.party_id,c.key)q),'[]'::jsonb),
 'configured',exists(select 1 from public.commercial_controls where company_id=cid and key='AR'))into result;return result;end;$$;
revoke all on function public.configure_commercial_accounting(uuid,uuid,jsonb),public.command_customer_accounting(uuid,uuid,text,jsonb),public.read_customer_accounts(uuid,date)from public,anon,authenticated,service_role;
grant execute on function public.configure_commercial_accounting(uuid,uuid,jsonb),public.command_customer_accounting(uuid,uuid,text,jsonb),public.read_customer_accounts(uuid,date)to authenticated;
revoke all on function private.commercial_control_type(text),private.commercial_account(uuid,text),private.commercial_line(uuid,bigint,boolean,uuid,uuid,uuid),private.commercial_bank(uuid,uuid,date,bigint,boolean),private.customer_plan(uuid,text,jsonb)from public,anon,authenticated,service_role;

revoke all on function private.normalize_commercial_input(jsonb)from public,anon,authenticated,service_role;

create trigger commercial_new_business_guard before insert on public.commercial_documents for each row when(new.kind in('AR_INVOICE','AR_CASH_SALE','AR_ADVANCE','ASSET_CAPITALIZE','PREPAY_RECOGNIZE','ACCRUAL_RECOGNIZE'))execute function private.guard_subscription_new_business();
