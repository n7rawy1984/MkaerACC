-- Nonposting correction evidence only. No adjustment/reversal authority granted.
create table public.expense_correction_reviews (
 id uuid primary key default gen_random_uuid(),company_id uuid not null,
 expense_id uuid not null,request_id uuid not null,previous_review_id uuid,
 actor_id uuid not null references auth.users(id) on delete restrict,
 kind text not null check(kind in ('PROJECT','CLASSIFICATION','REVERSAL')),
 reason text not null check(length(reason) between 1 and 500),
 requested_effective_date date not null,
 original_project_id uuid,proposed_project_id uuid,
 original_journal_entry_id uuid not null,
 expense_updated_at timestamptz not null,input_hash text not null,
 snapshot jsonb not null check(jsonb_typeof(snapshot)='object'),
 status text not null default 'REVIEW_REQUIRED' check(status='REVIEW_REQUIRED'),
 created_at timestamptz not null default clock_timestamp(),
 unique(company_id,request_id),unique(company_id,expense_id,id),unique(previous_review_id),
 foreign key(company_id,expense_id) references public.expenses(company_id,id) on delete restrict,
 foreign key(company_id,original_project_id) references public.projects(company_id,id) on delete restrict,
 foreign key(company_id,proposed_project_id) references public.projects(company_id,id) on delete restrict,
 foreign key(company_id,original_journal_entry_id) references public.journal_entries(company_id,id) on delete restrict,
 foreign key(company_id,expense_id,previous_review_id) references public.expense_correction_reviews(company_id,expense_id,id) on delete restrict
);
create unique index expense_correction_review_root on public.expense_correction_reviews(company_id,expense_id) where previous_review_id is null;
alter table public.expense_correction_reviews enable row level security;
alter table public.expense_correction_reviews force row level security;
revoke all on public.expense_correction_reviews from public,anon,authenticated,service_role;
grant select on public.expense_correction_reviews to authenticated;
create policy expense_correction_review_read on public.expense_correction_reviews for select to authenticated
 using(public.has_company_role(company_id,'ACCOUNTING_ADMIN') or public.has_company_role(company_id,'ACCOUNTANT') or public.has_company_role(company_id,'MANAGEMENT_VIEWER'));
create function private.protect_expense_correction_review() returns trigger language plpgsql set search_path='' as $$
begin raise exception 'Correction review evidence is immutable' using errcode='23514';end;$$;
revoke all on function private.protect_expense_correction_review() from public,anon,authenticated,service_role;
create trigger expense_correction_review_immutable before update or delete on public.expense_correction_reviews
 for each row execute function private.protect_expense_correction_review();

create function public.record_expense_correction_review(target_company_id uuid,target_expense_id uuid,
 expected_updated_at timestamptz,expected_latest_review_id uuid,request_id uuid,kind text,
 proposed_project_id uuid,requested_effective_date date,reason text)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid:=auth.uid();e public.expenses;prior public.expense_correction_reviews;latest uuid;
 review_id uuid;digest text;evidence jsonb;normalized_reason text;
 trim_chars text:=E' \t\n\r\f'||chr(11)||chr(160)||chr(5760)||chr(8192)||chr(8193)||chr(8194)||chr(8195)||chr(8196)||chr(8197)||chr(8198)||chr(8199)||chr(8200)||chr(8201)||chr(8202)||chr(8232)||chr(8233)||chr(8239)||chr(8287)||chr(12288)||chr(65279);
begin
 if actor is null then raise exception 'Denied' using errcode='42501';end if;
 perform 1 from public.companies where id=target_company_id for share;
 perform 1 from public.profiles where user_id=actor for share;
 perform 1 from public.company_memberships where company_id=target_company_id and user_id=actor for share;
 if not public.has_company_role(target_company_id,'ACCOUNTING_ADMIN') then raise exception 'Review denied' using errcode='42501';end if;
 normalized_reason:=nullif(btrim(reason,trim_chars),'');
 if target_expense_id is null or expected_updated_at is null or request_id is null or kind is null or kind not in ('PROJECT','CLASSIFICATION','REVERSAL')
 or requested_effective_date is null or normalized_reason is null or length(normalized_reason)>500
 or (kind<>'PROJECT' and proposed_project_id is not null) then raise exception 'Invalid review' using errcode='22023';end if;
 digest:=encode(extensions.digest(jsonb_build_object('actor',actor,'company',target_company_id,'expense',target_expense_id,
 'expected_epoch',extract(epoch from expected_updated_at),'previous',expected_latest_review_id,'kind',kind,
 'project',proposed_project_id,'date',requested_effective_date,'reason',normalized_reason)::text,'sha256'),'hex');
 perform pg_advisory_xact_lock(hashtextextended('expense-correction-review:'||target_company_id::text||':'||request_id::text,0));
 select * into prior from public.expense_correction_reviews r where r.company_id=target_company_id and r.request_id=record_expense_correction_review.request_id;
 if found then
  if prior.input_hash<>digest or prior.actor_id<>actor then raise exception 'Request changed' using errcode='22023';end if;
  return jsonb_build_object('id',prior.id,'company_id',prior.company_id,'expense_id',prior.expense_id,'request_id',prior.request_id,'status',prior.status);
 end if;
 if proposed_project_id is not null then
  perform 1 from public.projects p where p.company_id=target_company_id and p.id=proposed_project_id for share;
  if not found then raise exception 'Project unavailable' using errcode='42501';end if;
 end if;
 select * into e from public.expenses where company_id=target_company_id and id=target_expense_id for update;
 if not found then raise exception 'Expense unavailable' using errcode='42501';end if;
 if e.updated_at<>expected_updated_at then raise exception 'Expense changed; refresh' using errcode='40001';end if;
 if e.status not in ('POSTED','REVERSED') or e.posted_journal_entry_id is null then raise exception 'Posted expense required' using errcode='23514';end if;
 if requested_effective_date<e.expense_date then raise exception 'Requested date precedes original' using errcode='22023';end if;
 if kind='PROJECT' and proposed_project_id is not distinct from e.project_id then raise exception 'Project unchanged' using errcode='22023';end if;
 select r.id into latest from public.expense_correction_reviews r where r.company_id=target_company_id and r.expense_id=target_expense_id
 and not exists(select 1 from public.expense_correction_reviews successor where successor.previous_review_id=r.id);
 if latest is distinct from expected_latest_review_id then raise exception 'Review changed; refresh' using errcode='40001';end if;
 evidence:=jsonb_build_object('expense_reference',e.expense_reference,'expense_status',e.status,'expense_date',e.expense_date,
  'funding_mode',e.funding_mode,'net_amount_minor',e.net_amount_minor::text,'gross_amount_minor',e.gross_amount_minor::text,
  'reversal_journal_entry_id',e.reversal_journal_entry_id,
  'live_supplier_payment_count',(select count(distinct p.id) from public.supplier_payment_allocations a join public.supplier_payments p on p.company_id=a.company_id and p.id=a.supplier_payment_id where a.company_id=target_company_id and a.expense_id=e.id and p.status='POSTED'),
  'live_custody_settlement_count',(select count(distinct s.id) from public.custody_settlement_items i join public.custody_settlements s on s.company_id=i.company_id and s.id=i.settlement_id where i.company_id=target_company_id and i.expense_id=e.id and s.status='FINALIZED'),
  'period_control','NOT_IMPLEMENTED','reconciliation_status','UNVERIFIED','financial_execution','NOT_AUTHORIZED_BY_REVIEW',
  'policy_decision',case kind when 'PROJECT' then 'DIMENSION_CORRECTION_METHOD_AND_DEPENDENCIES' when 'CLASSIFICATION' then 'CLASSIFICATION_SUBSTANCE_AND_CORRECTION_METHOD' else 'REVERSAL_DEPENDENCIES_AND_EFFECTIVE_PERIOD' end);
 insert into public.expense_correction_reviews(company_id,expense_id,request_id,previous_review_id,actor_id,kind,reason,
  requested_effective_date,original_project_id,proposed_project_id,original_journal_entry_id,expense_updated_at,input_hash,snapshot)
 values(target_company_id,target_expense_id,request_id,latest,actor,kind,normalized_reason,requested_effective_date,e.project_id,
  proposed_project_id,e.posted_journal_entry_id,e.updated_at,digest,evidence) returning id into review_id;
 return jsonb_build_object('id',review_id,'company_id',target_company_id,'expense_id',target_expense_id,'request_id',request_id,'status','REVIEW_REQUIRED');
end;$$;
revoke all on function public.record_expense_correction_review(uuid,uuid,timestamptz,uuid,uuid,text,uuid,date,text) from public,anon,authenticated,service_role;
grant execute on function public.record_expense_correction_review(uuid,uuid,timestamptz,uuid,uuid,text,uuid,date,text) to authenticated;
