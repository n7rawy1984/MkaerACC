-- 102 / CR-04. Additive purchase-return integration; no seeds or financial backfill.
-- Physical return clears moving-average stock into GRNI. Supplier credit clears GRNI,
-- with invoice-price/carrying-value differences in the existing valuation variance control.
create unique index supplier_return_dispatch_once on public.inventory_events(company_id,(snapshot->>'supplier_id'),lower(btrim(snapshot->>'reference')))where state='POSTED'and snapshot->>'kind'='PURCHASE_RETURN';
create table public.supplier_return_credits(
 company_id uuid not null,return_event_id uuid not null,credit_note_id uuid not null,
 primary key(company_id,return_event_id),unique(company_id,credit_note_id),
 foreign key(company_id,return_event_id)references public.inventory_events(company_id,id),
 foreign key(company_id,credit_note_id)references public.supplier_ap_documents(company_id,id));
create table public.supplier_credit_refunds(
 id uuid primary key default gen_random_uuid(),company_id uuid not null,credit_note_id uuid not null,treasury_id uuid not null,
 date date not null,amount_minor bigint not null check(amount_minor between 1 and 9000000000000000),
 reference text not null check(length(btrim(reference))between 1 and 200),evidence text not null,
 journal_id uuid not null,original_id uuid,created_by uuid not null references auth.users(id),created_at timestamptz not null default clock_timestamp(),
 unique(company_id,id),unique(company_id,journal_id),unique(company_id,original_id),
 foreign key(company_id,credit_note_id)references public.supplier_ap_documents(company_id,id),
 foreign key(company_id,treasury_id)references public.treasury_accounts(company_id,id),
 foreign key(company_id,journal_id)references public.journal_entries(company_id,id),
 foreign key(company_id,original_id)references public.supplier_credit_refunds(company_id,id));
create unique index supplier_refund_reference on public.supplier_credit_refunds(company_id,treasury_id,lower(btrim(reference)))where original_id is null;
do $$declare t text;begin foreach t in array array['supplier_return_credits','supplier_credit_refunds']loop
 execute format('alter table public.%I enable row level security',t);execute format('alter table public.%I force row level security',t);
 execute format('revoke all on public.%I from public,anon,authenticated,service_role',t);execute format('grant select on public.%I to authenticated',t);
 execute format('create policy supplier_return_read on public.%I for select to authenticated using(public.has_company_role(company_id,''ACCOUNTING_ADMIN'')or public.has_company_role(company_id,''ACCOUNTANT'')or public.has_company_role(company_id,''MANAGEMENT_VIEWER''))',t);
 execute format('create trigger immutable_return_evidence before update or delete on public.%I for each row execute function private.financial_evidence_immutable()',t);
end loop;end$$;

-- Include cash refunds in the existing invoice-side credit balance; preserve as-of behavior.
alter function private.supplier_ap_used(uuid,uuid,date)rename to supplier_ap_used_pre102;
create function private.supplier_refunded(cid uuid,credit uuid,cutoff date default 'infinity')returns numeric language sql stable set search_path=''as $$
 select coalesce(sum(case when r.original_id is null then r.amount_minor else -r.amount_minor end),0)
 from public.supplier_credit_refunds r where r.company_id=cid and r.credit_note_id=credit and r.date<=cutoff $$;
create function private.supplier_ap_used(cid uuid,eid uuid,cutoff date default 'infinity')returns numeric language sql stable set search_path=''as $$
 select private.supplier_ap_used_pre102(cid,eid,cutoff)-coalesce((select sum(private.supplier_refunded(cid,c.id,cutoff))from public.supplier_ap_documents c where c.company_id=cid and c.expense_id=eid and c.kind='CREDIT_NOTE'),0) $$;
alter function private.supplier_adjustment_plan(uuid,text,jsonb)rename to supplier_adjustment_plan_pre102;
create function private.supplier_adjustment_plan(cid uuid,kind text,v jsonb)returns jsonb language plpgsql set search_path=''as $$
declare c public.supplier_ap_documents;n numeric;begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if kind='CREDIT_ALLOCATION'then
 select *into c from public.supplier_ap_documents where company_id=cid and id=(v->>'credit_note_id')::uuid for update;
 select coalesce(sum(amount_minor),0)into n from public.supplier_ap_documents where company_id=cid and credit_note_id=c.id and status='POSTED';
 if(v->>'net_minor')::numeric>c.amount_minor-n-private.supplier_refunded(cid,c.id)then raise exception 'Credit already allocated or refunded'using errcode='23514';end if;
 end if;return private.supplier_adjustment_plan_pre102(cid,kind,v);end$$;
create function private.guard_supplier_refund_dependency()returns trigger language plpgsql security definer set search_path=''as $$begin
 if old.status='POSTED'and new.status='REVERSED'and private.supplier_refunded(old.company_id,old.id)>0 then raise exception 'Reverse actual Supplier refunds before credit note'using errcode='23514';end if;return new;end$$;
create trigger supplier_refund_dependency before update on public.supplier_ap_documents for each row execute function private.guard_supplier_refund_dependency();

create function private.supplier_return_plan(cid uuid,action text,v jsonb)returns jsonb language plpgsql set search_path=''as $$
#variable_conflict use_variable
declare cfg public.inventory_configuration;r public.inventory_events;e public.inventory_events;ex public.expenses;c public.supplier_ap_documents;t public.treasury_accounts;
 original_journal uuid; b jsonb;q bigint;n bigint;tax bigint;carrying bigint;origq bigint;returned numeric;priornet numeric;priortax numeric;used numeric;ap uuid;vat uuid;diff bigint;lines jsonb:='[]';link record;
begin
 perform private.operational_finance_actor(cid,'accounting.post');perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if v is null or jsonb_typeof(v)<>'object'or octet_length(v::text)>16000 or v-array['id','version','receipt_id','expense_id','qty_micros','date','evidence','reference','credit_note_id','treasury_id','amount_minor','vat_minor','tax_credit_confirmed']<>'{}'::jsonb or coalesce(length(btrim(v->>'evidence')),0)not between 5 and 2000 or coalesce(v->>'date','')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Bounded return business inputs, actual date and evidence required'using errcode='22023';end if;
 if(v->>'date')::date>current_date then raise exception 'Future financial date not supported'using errcode='23514';end if;perform private.opening_period(cid,(v->>'date')::date);
 select *into cfg from public.inventory_configuration where company_id=cid;if cfg.company_id is null and action in('RETURN','CREDIT')then raise exception 'Inventory configuration required'using errcode='23514';end if;
 select id into ap from public.accounts where company_id=cid and system_key='SUPPLIER_PAYABLE'and status='ACTIVE'and account_type='LIABILITY'and requires_party;
 if ap is null then raise exception 'Supplier Payable control required'using errcode='23514';end if;
 if action in('REVERSE_RETURN','REVERSE_REFUND')then
 perform private.operational_finance_actor(cid,'accounting.reverse');if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin reversal required'using errcode='42501';end if;
 if action='REVERSE_RETURN'then e:=private.inventory_current(cid,(v->>'id')::uuid);if e.state is distinct from 'POSTED'or e.snapshot->>'kind'is distinct from 'PURCHASE_RETURN'then raise exception 'Live physical return required'using errcode='23514';end if;original_journal:=e.journal_id;
 else select f.journal_id into original_journal from public.supplier_credit_refunds f where f.company_id=cid and f.id=(v->>'id')::uuid and f.original_id is null and not exists(select 1 from public.supplier_credit_refunds z where z.company_id=cid and z.original_id=f.id);if original_journal is null then raise exception 'Live actual refund required'using errcode='23514';end if;end if;
 select coalesce(jsonb_agg(jsonb_build_object('account_id',l.account_id,'debit_minor',l.credit_minor::text,'credit_minor',l.debit_minor::text)order by l.line_number),'[]')into lines from public.journal_lines l where l.company_id=cid and l.journal_entry_id=original_journal;
 return v||jsonb_build_object('lines',lines);
 elsif action='RETURN'then
 if coalesce(length(btrim(v->>'reference')),0)not between 1 and 100 then raise exception 'Actual unique Supplier return dispatch reference required'using errcode='23514';end if;
 r:=private.inventory_current(cid,(v->>'receipt_id')::uuid);
 select *into ex from public.expenses where company_id=cid and id=(v->>'expense_id')::uuid for update;
 if r.id is null or r.state<>'POSTED'or r.snapshot->>'kind'<>'RECEIPT'or r.snapshot->>'recognition'not in('GRNI','EXISTING_EXPENSE')or ex.id is null or ex.status<>'POSTED'or ex.supplier_id is null or not exists(select 1 from public.parties where company_id=cid and id=ex.supplier_id and type='SUPPLIER')or(r.snapshot->>'recognition'='GRNI'and ex.supplier_id::text is distinct from r.snapshot->>'supplier_id')or(r.snapshot->>'recognition'='EXISTING_EXPENSE'and ex.id::text is distinct from r.snapshot->>'expense_id')or(v->>'date')::date<greatest(ex.expense_date,(r.snapshot->>'date')::date)then raise exception 'Live same-Supplier receipt and invoice required'using errcode='23514';end if;
 if r.snapshot->>'recognition'='GRNI'and not exists(select 1 from public.inventory_events m where m.company_id=cid and m.state='POSTED'and m.snapshot->>'kind'in('MATCH','INVOICE')and m.snapshot->>'origin_id'=r.document_id::text and m.snapshot->>'expense_id'=ex.id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state='REVERSED'))then raise exception 'Original receipt must be matched to this invoice'using errcode='23514';end if;
 if coalesce(v->>'qty_micros','')!~'^[0-9]{1,16}$'then raise exception 'Exact base quantity required'using errcode='22023';end if;q:=(v->>'qty_micros')::bigint;origq:=(r.snapshot->'computed'->>'qty')::bigint;
 select coalesce(sum((x.snapshot->>'qty_micros')::numeric),0)into returned from public.inventory_events x where x.company_id=cid and x.state='POSTED'and x.snapshot->>'kind'='PURCHASE_RETURN'and x.snapshot->>'origin_id'=r.document_id::text and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=x.document_id and z.state='REVERSED');
 b:=private.inventory_balance(cid,(r.snapshot->>'material_id')::uuid,(r.snapshot->>'location_id')::uuid);
 if q<1 or q+returned>origq or q>(b->>'qty')::numeric then raise exception 'Return exceeds eligible receipt quantity or available stock; recover issued/transferred stock first'using errcode='23514';end if;
 if(b->>'last_date')::date>(v->>'date')::date then raise exception 'Backdated return would restate moving-average valuation'using errcode='23514';end if;
 carrying:=case when q=(b->>'qty')::numeric then(b->>'value')::bigint else round((b->>'value')::numeric*q/(b->>'qty')::numeric)::bigint end;
 if carrying>0 then lines:=jsonb_build_array(jsonb_build_object('account_id',cfg.grni_account_id,'party_id',ex.supplier_id,'debit_minor',carrying::text,'credit_minor','0'),jsonb_build_object('account_id',cfg.inventory_account_id,'debit_minor','0','credit_minor',carrying::text));end if;
 return v||jsonb_build_object('kind','PURCHASE_RETURN','origin_id',r.document_id,'supplier_id',ex.supplier_id,'material_id',r.snapshot->>'material_id','location_id',r.snapshot->>'location_id','unit',r.snapshot->>'unit','computed',jsonb_build_object('qty',q::text,'value',carrying::text,'balance',b),'lines',lines);
 elsif action='CREDIT'then
 e:=private.inventory_current(cid,(v->>'id')::uuid);
 if e.id is null or e.state<>'POSTED'or e.snapshot->>'kind'<>'PURCHASE_RETURN'or exists(select 1 from public.supplier_return_credits k join public.supplier_ap_documents a on a.company_id=k.company_id and a.id=k.credit_note_id where k.company_id=cid and k.return_event_id=e.id and a.status='POSTED')then raise exception 'Uncredited physical return required'using errcode='23514';end if;
 -- A reversed credit may be replaced through a new physical event only; immutable link prevents accidental reuse.
 if exists(select 1 from public.supplier_return_credits where company_id=cid and return_event_id=e.id)then raise exception 'Reverse physical return and prepare corrected return after reversed credit'using errcode='23514';end if;
 r:=private.inventory_current(cid,(e.snapshot->>'origin_id')::uuid);select *into ex from public.expenses where company_id=cid and id=(e.snapshot->>'expense_id')::uuid for update;
 if ex.id is null or ex.status<>'POSTED'or(v->>'date')::date<(e.snapshot->>'date')::date or coalesce(length(btrim(v->>'reference')),0)not between 1 and 100 then raise exception 'Live invoice, actual credit note number and non-earlier date required'using errcode='23514';end if;
 origq:=(r.snapshot->'computed'->>'qty')::bigint;q:=(e.snapshot->>'qty_micros')::bigint;carrying:=(e.snapshot->'computed'->>'value')::bigint;
 select coalesce(sum(d.net_minor),0),coalesce(sum(d.vat_minor),0),coalesce(sum((p.snapshot->>'qty_micros')::numeric),0)into priornet,priortax,returned from public.supplier_return_credits k join public.inventory_events p on p.company_id=k.company_id and p.id=k.return_event_id join public.supplier_ap_documents d on d.company_id=k.company_id and d.id=k.credit_note_id where k.company_id=cid and p.snapshot->>'origin_id'=r.document_id::text and d.status='POSTED';
 n:=round(ex.net_amount_minor::numeric*(returned+q)/origq)-priornet;
 if coalesce(v->>'vat_minor','0')!~'^[0-9]{1,16}$'then raise exception 'Actual credit-note VAT required'using errcode='22023';end if;tax:=coalesce(v->>'vat_minor','0')::bigint;
 if n<1 or priornet+n>ex.net_amount_minor or priortax+tax>ex.vat_amount_minor or (ex.vat_amount_minor>0 and(v->>'tax_credit_confirmed'is distinct from 'true'or tax<>round(ex.vat_amount_minor::numeric*(returned+q)/origq)-priortax))or(ex.vat_amount_minor=0 and tax<>0)then raise exception 'Documented original proportional credit/VAT required; missing tax evidence cannot be guessed'using errcode='23514';end if;
 lines:=jsonb_build_array(jsonb_build_object('account_id',ap,'party_id',ex.supplier_id,'project_id',ex.project_id,'debit_minor',(n+tax)::text,'credit_minor','0'));
 if carrying>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cfg.grni_account_id,'party_id',ex.supplier_id,'debit_minor','0','credit_minor',carrying::text));end if;
 diff:=n-carrying;if diff<>0 then lines:=lines||jsonb_build_array(jsonb_build_object('account_id',cfg.variance_account_id,'debit_minor',greatest(-diff,0)::text,'credit_minor',greatest(diff,0)::text));end if;
 if tax>0 then select account_id into vat from public.journal_lines l join public.accounts a on a.company_id=l.company_id and a.id=l.account_id where l.company_id=cid and l.journal_entry_id=ex.posted_journal_entry_id and a.system_key='INPUT_VAT'and l.debit_minor=ex.vat_amount_minor;
 if vat is null then raise exception 'Original recoverable VAT entry required'using errcode='23514';end if;lines:=lines||jsonb_build_array(jsonb_build_object('account_id',vat,'debit_minor','0','credit_minor',tax::text));end if;
 return v||jsonb_build_object('return_event_id',e.id,'supplier_id',ex.supplier_id,'expense_id',ex.id,'project_id',ex.project_id,'net_minor',n::text,'vat_minor',tax::text,'gross_minor',(n+tax)::text,'lines',lines);
 elsif action='REFUND'then
 select *into c from public.supplier_ap_documents where company_id=cid and id=(v->>'credit_note_id')::uuid for update;
 if c.id is null or c.kind<>'CREDIT_NOTE'or c.status<>'POSTED'or(v->>'date')::date<c.posting_date or coalesce(length(btrim(v->>'reference')),0)not between 1 and 200 or coalesce(v->>'amount_minor','')!~'^[0-9]{1,16}$'then raise exception 'Available credit note, actual refund amount/reference/date required'using errcode='23514';end if;
 select *into ex from public.expenses where company_id=cid and id=c.expense_id for update;
 select coalesce(sum(amount_minor),0)into used from public.supplier_ap_documents where company_id=cid and credit_note_id=c.id and status='POSTED';n:=(v->>'amount_minor')::bigint;
 if n<1 or n>c.amount_minor-used-private.supplier_refunded(cid,c.id)or n>private.supplier_ap_used(cid,ex.id,(v->>'date')::date)-ex.gross_amount_minor then raise exception 'Refund exceeds actual Supplier credit after invoice obligations and allocations'using errcode='23514';end if;
 select *into t from public.treasury_accounts where company_id=cid and id=(v->>'treasury_id')::uuid and status='ACTIVE';
 if t.id is null or(t.project_id is not null and t.project_id is distinct from c.project_id)or not exists(select 1 from public.accounts where company_id=cid and id=t.gl_account_id and status='ACTIVE'and account_type='ASSET')then raise exception 'Actual active same-Company Treasury and consistent Project required'using errcode='23514';end if;
 lines:=jsonb_build_array(jsonb_build_object('account_id',t.gl_account_id,'treasury_account_id',t.id,'project_id',t.project_id,'debit_minor',n::text,'credit_minor','0'),jsonb_build_object('account_id',ap,'party_id',c.supplier_id,'project_id',c.project_id,'debit_minor','0','credit_minor',n::text));
 return v||jsonb_build_object('supplier_id',c.supplier_id,'gross_minor',n::text,'lines',lines);
 else raise exception 'Unsupported purchase return action'using errcode='22023';end if;
end$$;
create function public.preview_supplier_return(cid uuid,action text,input jsonb)returns jsonb language sql security definer set search_path=''as $$select jsonb_build_object('company_id',cid)||private.supplier_return_plan(cid,action,input)$$;
create function public.command_supplier_return(cid uuid,request_id uuid,action text,input jsonb)returns jsonb language plpgsql security definer set search_path=''as $$
#variable_conflict use_variable
declare req private.financial_command_requests;actor uuid;h text;old public.inventory_events;e public.inventory_events;r public.inventory_events;p jsonb;v jsonb;did uuid;j uuid;ref text;state text;ver integer;credit uuid;f public.supplier_credit_refunds;b jsonb;row record;k text;val jsonb;norm jsonb:='{}';begin
 actor:=private.operational_finance_actor(cid,case when action like 'REVERSE_%'then 'accounting.reverse'else 'accounting.post'end);perform private.attendance_company_lock(cid);perform private.serialize_operational_finance(cid,'OPERATIONS');
 if request_id is null or input is null or jsonb_typeof(input)<>'object'or octet_length(input::text)>16000 or input-array['id','version','receipt_id','expense_id','qty_micros','date','evidence','reference','credit_note_id','treasury_id','amount_minor','vat_minor','tax_credit_confirmed']<>'{}'::jsonb then raise exception 'Bounded request required'using errcode='22023';end if;
 for k,val in select *from jsonb_each(input)loop
 if jsonb_typeof(val)not in('string','number','boolean','null')then raise exception 'Business scalars only'using errcode='22023';end if;
 if jsonb_typeof(val)='string'then val:=to_jsonb(btrim(val#>>'{}'));end if;
 if k in('version','qty_micros','amount_minor','vat_minor')and val<>'null'::jsonb and(val#>>'{}')<>''then val:=to_jsonb(((val#>>'{}')::bigint)::text);end if;
 if val<>'null'::jsonb and(val#>>'{}')<>''and(k='id'or k like '%_id')then val:=to_jsonb(((val#>>'{}')::uuid)::text);end if;
 if k='date'and val<>'null'::jsonb then if(val#>>'{}')!~'^[0-9]{4}-[0-9]{2}-[0-9]{2}$'then raise exception 'Unambiguous ISO date required'using errcode='22023';end if;val:=to_jsonb(((val#>>'{}')::date)::text);end if;
 if k='tax_credit_confirmed'and val<>'null'::jsonb then if(val#>>'{}')not in('true','false')then raise exception 'Explicit tax evidence boolean required'using errcode='22023';end if;val:=to_jsonb((val#>>'{}')::boolean);end if;
 norm:=norm||jsonb_build_object(k,val);end loop;input:=norm;
 h:=encode(extensions.digest(jsonb_build_array(actor,cid,action,input)::text,'sha256'),'hex');
 if action in('CREDIT','REFUND','REVERSE_REFUND')then
 req:=private.reserve_financial_command(cid,'SUPPLIER_RETURN_'||action,request_id,h,actor);
 if req.status='COMPLETED'then
 select source_id into did from public.journal_entries where company_id=cid and id=req.resulting_journal_entry_id;if action in('REFUND','REVERSE_REFUND')then select id into did from public.supplier_credit_refunds where company_id=cid and journal_id=req.resulting_journal_entry_id;end if;p:=input;
 if action='CREDIT'then select input||jsonb_build_object('credit_note_id',c.id,'supplier_id',c.supplier_id,'net_minor',c.net_minor::text,'vat_minor',c.vat_minor::text,'gross_minor',c.amount_minor::text)into p from public.supplier_ap_documents c where c.company_id=cid and c.id=did;end if;
 return jsonb_build_object('id',req.resulting_journal_entry_id,'document_id',did,'company_id',cid,'version',1,'state','RECORDED','snapshot',p||jsonb_build_object('kind','SUPPLIER_RETURN_'||action),'journal_id',req.resulting_journal_entry_id,'replayed',true);end if;
 end if;
 select *into old from public.inventory_events z where z.company_id=cid and z.request_id=command_supplier_return.request_id;
 if old.id is not null then if old.request_hash<>h then raise exception 'Changed purchase return retry intent'using errcode='22023';end if;return to_jsonb(old)||jsonb_build_object('replayed',true);end if;
 did:=coalesce(nullif(input->>'id','')::uuid,gen_random_uuid());e:=private.inventory_current(cid,did);ver:=coalesce(e.version,0)+1;
 if action in('SAVE','REVIEW','POST','REVERSE_RETURN')then
 if action='SAVE'then
 if e.id is not null and(e.state not in('DRAFT','REVIEWED')or e.snapshot->>'kind'<>'PURCHASE_RETURN')then raise exception 'Editable purchase return draft required'using errcode='23514';end if;
 if coalesce((input->>'version')::integer,0)<>coalesce(e.version,0)then raise exception 'Return document changed; refresh'using errcode='40001';end if;
 p:=private.supplier_return_plan(cid,'RETURN',input);state:='DRAFT';
 elsif action in('REVIEW','POST')then
 if e.id is null or e.snapshot->>'kind'<>'PURCHASE_RETURN'or e.version is distinct from(input->>'version')::integer or e.state<>(case when action='REVIEW'then 'DRAFT'else 'REVIEWED'end) then raise exception 'Fresh draft/reviewed purchase return required'using errcode='40001';end if;
 p:=private.supplier_return_plan(cid,'RETURN',e.snapshot-array['kind','origin_id','supplier_id','material_id','location_id','unit','computed','lines']);
 if action='POST'and p is distinct from e.snapshot then raise exception 'Stock/valuation changed; save and review a fresh return'using errcode='40001';end if;state:=case when action='REVIEW'then 'REVIEWED'else 'POSTED'end;
 else
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')then raise exception 'Accounting Admin reversal required'using errcode='42501';end if;
 if e.id is null or e.state<>'POSTED'or e.snapshot->>'kind'<>'PURCHASE_RETURN'or e.version is distinct from(input->>'version')::integer or coalesce(length(btrim(input->>'evidence')),0)<5 then raise exception 'Live return and audited reason required'using errcode='23514';end if;
 if exists(select 1 from public.supplier_return_credits k join public.supplier_ap_documents c on c.company_id=k.company_id and c.id=k.credit_note_id where k.company_id=cid and k.return_event_id=e.id and c.status='POSTED')then raise exception 'Reverse dependent Supplier credit and refunds first'using errcode='23514';end if;
 perform private.opening_period(cid,(input->>'date')::date);if(input->>'date')::date<(e.snapshot->>'date')::date or(input->>'date')::date>current_date then raise exception 'Valid non-earlier reversal date required'using errcode='23514';end if;
 b:=private.inventory_balance(cid,(e.snapshot->>'material_id')::uuid,(e.snapshot->>'location_id')::uuid);
 if(b->>'revision')::bigint<>(e.snapshot->'computed'->'balance'->>'revision')::bigint+1 then raise exception 'Later stock movements require dependency recovery before reversal'using errcode='23514';end if;
 p:=e.snapshot||jsonb_build_object('reversal_date',input->>'date','reversal_evidence',input->>'evidence');state:='REVERSED';if e.journal_id is not null then j:=private.reverse_journal(e.journal_id,(input->>'date')::date,btrim(input->>'evidence'),actor);end if;
 end if;
 if action='POST'and jsonb_array_length(p->'lines')>0 then j:=private.create_journal(cid,(p->>'date')::date,'Physical Supplier return','SUPPLIER_PHYSICAL_RETURN',did,'POST',p->'lines',actor);end if;
 ref:=coalesce(e.reference,private.allocate_reference(cid,'SRET',extract(year from(p->>'date')::date)::integer));
 else
 if action not in('CREDIT','REFUND','REVERSE_REFUND')then raise exception 'Supported purchase return command required'using errcode='22023';end if;
 did:=gen_random_uuid();ver:=1;state:='RECORDED';ref:=private.allocate_reference(cid,'SRET',extract(year from(input->>'date')::date)::integer);
 if action='REVERSE_REFUND'then
 if not public.has_company_role(cid,'ACCOUNTING_ADMIN')or coalesce(length(btrim(input->>'evidence')),0)<5 then raise exception 'Accounting Admin audited refund reversal required'using errcode='42501';end if;
 select *into f from public.supplier_credit_refunds where company_id=cid and id=(input->>'id')::uuid and original_id is null for update;
 if f.id is null or exists(select 1 from public.supplier_credit_refunds where company_id=cid and original_id=f.id)or(input->>'date')::date<f.date or(input->>'date')::date>current_date then raise exception 'Unreversed refund and non-earlier reversal date required'using errcode='23514';end if;
 -- Canonical reversal enforces open fiscal/annual period and finalized-bank dependencies.
 perform private.settlement_funding(cid,f.treasury_id,null,(input->>'date')::date,f.amount_minor,(select project_id from public.treasury_accounts where company_id=cid and id=f.treasury_id));
 j:=private.reverse_journal(f.journal_id,(input->>'date')::date,btrim(input->>'evidence'),actor);
 insert into public.supplier_credit_refunds(id,company_id,credit_note_id,treasury_id,date,amount_minor,reference,evidence,journal_id,original_id,created_by)values(did,cid,f.credit_note_id,f.treasury_id,(input->>'date')::date,f.amount_minor,ref,input->>'evidence',j,f.id,actor);p:=input;
 else
 p:=private.supplier_return_plan(cid,action,input);j:=private.create_journal(cid,(p->>'date')::date,ref||' '||(p->>'evidence'),'SUPPLIER_'||case when action='CREDIT'then 'CREDIT_NOTE'else 'REFUND'end,did,'POST',p->'lines',actor);
 if action='CREDIT'then
 credit:=did;insert into public.supplier_ap_documents(id,company_id,kind,reference,external_reference,supplier_id,project_id,expense_id,posting_date,net_minor,vat_minor,amount_minor,evidence,posted_journal_entry_id,created_by)values(credit,cid,'CREDIT_NOTE',ref,p->>'reference',(p->>'supplier_id')::uuid,(p->>'project_id')::uuid,(p->>'expense_id')::uuid,(p->>'date')::date,(p->>'net_minor')::bigint,(p->>'vat_minor')::bigint,(p->>'gross_minor')::bigint,p->>'evidence',j,actor);
 insert into public.supplier_return_credits values(cid,(p->>'return_event_id')::uuid,credit);p:=p||jsonb_build_object('credit_note_id',credit);
 else
 insert into public.supplier_credit_refunds(id,company_id,credit_note_id,treasury_id,date,amount_minor,reference,evidence,journal_id,created_by)values(did,cid,(p->>'credit_note_id')::uuid,(p->>'treasury_id')::uuid,(p->>'date')::date,(p->>'amount_minor')::bigint,p->>'reference',p->>'evidence',j,actor);
 end if;end if;p:=p||jsonb_build_object('kind','SUPPLIER_RETURN_'||action);
 end if;
 if action in('CREDIT','REFUND','REVERSE_REFUND')then
 perform private.complete_financial_command(req.id,j);return jsonb_build_object('id',j,'document_id',did,'version',1,'company_id',cid,'state','RECORDED','snapshot',p,'reference',ref,'journal_id',j,'replayed',false);end if;
 insert into public.inventory_events(company_id,document_id,version,request_id,request_hash,action,state,snapshot,reference,journal_id,created_by)values(cid,did,ver,request_id,h,'SUPPLIER_'||action,state,p,ref,j,actor)returning *into r;
 if action='POST'then
 insert into public.inventory_movements(company_id,event_id,material_id,location_id,quantity_micros,value_minor,movement_date)values(cid,r.id,(p->>'material_id')::uuid,(p->>'location_id')::uuid,-(p->>'qty_micros')::bigint,-(p->'computed'->>'value')::bigint,(p->>'date')::date);
 elsif action='REVERSE_RETURN'then
 insert into public.inventory_movements(company_id,event_id,material_id,location_id,quantity_micros,value_minor,movement_date)select cid,r.id,material_id,location_id,-quantity_micros,-value_minor,(input->>'date')::date from public.inventory_movements where company_id=cid and event_id=e.id;
 end if;
 if action in('POST','REVERSE_RETURN')and(select coalesce(sum(value_minor::numeric),0)from public.inventory_movements where company_id=cid)is distinct from(select coalesce(sum(l.debit_minor::numeric-l.credit_minor::numeric),0)from public.journal_lines l where l.company_id=cid and l.account_id=(select inventory_account_id from public.inventory_configuration where company_id=cid))then raise exception 'Inventory quantity/value ledger must reconcile with canonical GL'using errcode='23514';end if;
 return to_jsonb(r)||jsonb_build_object('replayed',false);
end$$;

-- Existing generic stock reversal must not bypass Supplier-return dependencies.
create function private.guard_supplier_return_origin()returns trigger language plpgsql security definer set search_path=''as $$begin
 if(new.snapshot->>'kind'='PURCHASE_RETURN'or new.snapshot->>'kind'like 'SUPPLIER_RETURN_%')and new.action not like 'SUPPLIER_%'then raise exception 'Use controlled Supplier purchase return workflow'using errcode='23514';end if;
 if new.state='REVERSED'and new.snapshot->>'kind'in('RECEIPT','MATCH','INVOICE')and exists(select 1 from public.inventory_events e where e.company_id=new.company_id and e.state='POSTED'and e.snapshot->>'kind'='PURCHASE_RETURN'and(e.snapshot->>'origin_id'=new.document_id::text or e.snapshot->>'expense_id'=new.snapshot->>'expense_id')and not exists(select 1 from public.inventory_events r where r.company_id=e.company_id and r.document_id=e.document_id and r.state='REVERSED'))then raise exception 'Reverse dependent physical Supplier return first'using errcode='23514';end if;return new;end$$;
create trigger supplier_return_origin_dependency before insert on public.inventory_events for each row execute function private.guard_supplier_return_origin();
create function public.read_supplier_returns(cid uuid)returns jsonb language plpgsql stable security definer set search_path=''as $$begin
 if auth.uid()is null or not(public.has_company_role(cid,'ACCOUNTING_ADMIN')or public.has_company_role(cid,'ACCOUNTANT')or public.has_company_role(cid,'MANAGEMENT_VIEWER'))then raise exception 'Company accounting reader required'using errcode='42501';end if;
 return jsonb_build_object('company_id',cid,'today',current_date,
 'receipts',(select coalesce(jsonb_agg(jsonb_build_object('receipt_id',e.document_id,'reference',e.reference,'supplier_id',x.supplier_id,'material_id',e.snapshot->>'material_id','location_id',e.snapshot->>'location_id','qty_micros',e.snapshot->'computed'->>'qty','expense_id',x.id,'balance',private.inventory_balance(cid,(e.snapshot->>'material_id')::uuid,(e.snapshot->>'location_id')::uuid))),'[]')
 from public.inventory_events e left join lateral(select m.*from public.inventory_events m where m.company_id=e.company_id and m.snapshot->>'origin_id'=e.document_id::text and m.snapshot->>'kind'in('MATCH','INVOICE')and m.state='POSTED'and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.document_id=m.document_id and z.state='REVERSED')order by m.created_at limit 1)m on true
 join public.expenses x on x.company_id=e.company_id and x.id=(case when e.snapshot->>'recognition'='EXISTING_EXPENSE'then e.snapshot->>'expense_id'else m.snapshot->>'expense_id'end)::uuid and x.status='POSTED'and x.supplier_id is not null
 where e.company_id=cid and e.state='POSTED'and e.snapshot->>'kind'='RECEIPT'and e.snapshot->>'recognition'in('GRNI','EXISTING_EXPENSE')and not exists(select 1 from public.inventory_events z where z.company_id=cid and z.state='REVERSED'and z.document_id=e.document_id)),
 'documents',(select coalesce(jsonb_agg(row order by row->>'created_at'),'[]')from(
 select to_jsonb(x)row from(select distinct on(document_id)*from public.inventory_events where company_id=cid and snapshot->>'kind'='PURCHASE_RETURN'order by document_id,version desc)x
 union all select jsonb_build_object('id',c.id,'company_id',cid,'document_id',c.id,'version',1,'state',c.status,'reference',c.reference,'journal_id',c.posted_journal_entry_id,'created_at',c.created_at,'snapshot',jsonb_build_object('kind','SUPPLIER_RETURN_CREDIT','supplier_id',c.supplier_id,'expense_id',c.expense_id,'credit_note_id',c.id,'date',c.posting_date,'net_minor',c.net_minor::text,'vat_minor',c.vat_minor::text,'gross_minor',c.amount_minor::text))from public.supplier_return_credits k join public.supplier_ap_documents c on c.company_id=k.company_id and c.id=k.credit_note_id where k.company_id=cid)rows),
 'credits',(select coalesce(jsonb_agg(to_jsonb(k)),'[]')from public.supplier_return_credits k where company_id=cid),
 'refunds',(select coalesce(jsonb_agg(to_jsonb(f)||jsonb_build_object('amount_minor',f.amount_minor::text)),'[]')from public.supplier_credit_refunds f where company_id=cid));end$$;
alter function public.read_supplier_accounts(uuid,date)rename to read_supplier_accounts_pre102;
revoke all on function public.read_supplier_accounts_pre102(uuid,date)from public,anon,authenticated,service_role;
create function public.read_supplier_accounts(cid uuid,as_of date default current_date)returns jsonb language sql stable security definer set search_path=''as $$
 select public.read_supplier_accounts_pre102(cid,as_of)||jsonb_build_object('refunds',(select coalesce(jsonb_agg(to_jsonb(f)||jsonb_build_object('amount_minor',f.amount_minor::text,'supplier_id',c.supplier_id)),'[]')from public.supplier_credit_refunds f join public.supplier_ap_documents c on c.company_id=f.company_id and c.id=f.credit_note_id where f.company_id=cid and f.date<=as_of)) $$;
revoke all on function private.supplier_ap_used_pre102(uuid,uuid,date),private.supplier_refunded(uuid,uuid,date),private.supplier_ap_used(uuid,uuid,date),private.supplier_adjustment_plan_pre102(uuid,text,jsonb),private.supplier_adjustment_plan(uuid,text,jsonb),private.guard_supplier_refund_dependency(),private.guard_supplier_return_origin(),private.supplier_return_plan(uuid,text,jsonb),public.preview_supplier_return(uuid,text,jsonb),public.command_supplier_return(uuid,uuid,text,jsonb),public.read_supplier_returns(uuid),public.read_supplier_accounts(uuid,date)from public,anon,authenticated,service_role;
grant execute on function public.preview_supplier_return(uuid,text,jsonb),public.command_supplier_return(uuid,uuid,text,jsonb),public.read_supplier_returns(uuid),public.read_supplier_accounts(uuid,date)to authenticated;
