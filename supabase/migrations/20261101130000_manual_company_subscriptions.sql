-- Manual service subscriptions only. No historical backfill, memberships or accounting updates.
create table private.company_subscriptions (
 company_id uuid primary key references public.companies(id) on delete restrict,
 plan_key text not null check(plan_key in ('TRIAL','STANDARD')),
 state text not null check(state in ('TRIAL','ACTIVE','EXPIRED','CANCELLED')),
 starts_on date not null, ends_on date not null,
 billing_method text not null check(billing_method in ('NONE','MANUAL_CASH','MANUAL_BANK_TRANSFER','MANUAL_OTHER')),
 payment_status text not null check(payment_status in ('NOT_REQUIRED','UNPAID','PAID','WAIVED')),
 payment_reference text check(payment_reference is null or length(payment_reference) between 1 and 200),
 version integer not null default 1 check(version>0),
 updated_by uuid not null references auth.users(id) on delete restrict,
 updated_at timestamptz not null default clock_timestamp(),
 check(ends_on>=starts_on and starts_on>='2000-01-01' and ends_on<='9999-12-30'),
 check(state<>'TRIAL' or plan_key='TRIAL'),
 check(state<>'ACTIVE' or plan_key='STANDARD'),
 check(payment_status<>'PAID' or (billing_method<>'NONE' and payment_reference is not null))
);
alter table private.company_subscriptions enable row level security;
alter table private.company_subscriptions force row level security;
revoke all on private.company_subscriptions from public,anon,authenticated,service_role;

create function private.subscription_effective_state(s private.company_subscriptions, today date)
returns text language sql immutable set search_path='' as $$
 select case when s.company_id is null then 'UNMANAGED' when s.state='CANCELLED' then 'CANCELLED'
  when s.state='EXPIRED' or today>s.ends_on then 'EXPIRED' when today<s.starts_on then 'SCHEDULED' else s.state end
$$;
revoke all on function private.subscription_effective_state(private.company_subscriptions,date) from public,anon,authenticated,service_role;

create function public.set_company_subscription(request_id uuid,business_input jsonb)
returns jsonb language plpgsql security definer set search_path='' as $$
declare actor uuid; p jsonb:='{}'; k text; v jsonb; cid uuid; expected integer;
 digest bytea; prior private.platform_requests; old private.company_subscriptions;
 next_row private.company_subscriptions; result jsonb; reason text;
begin
 perform private.lock_platform_authorization(); actor:=private.platform_actor();
 if request_id is null or jsonb_typeof(business_input) is distinct from 'object' or octet_length(business_input::text)>6000 then raise exception 'Invalid request' using errcode='22023'; end if;
 for k,v in select * from jsonb_each(business_input) loop
  if k<>all(array['id','version','plan_key','subscription_state','starts_on','ends_on','billing_method','payment_status','payment_reference','reason']) or jsonb_typeof(v) not in ('string','null') then raise exception 'Unsupported field' using errcode='22023'; end if;
  if v<>'null'::jsonb and nullif(btrim(v#>>'{}'),'') is not null then p:=p||jsonb_build_object(k,btrim(v#>>'{}')); end if;
 end loop;
 cid:=(p->>'id')::uuid; expected:=(p->>'version')::integer;reason:=private.platform_text(p,'reason',500);
 if cid is null or expected is null or expected<0 or coalesce(p->>'starts_on','')!~'^\d{4}-\d{2}-\d{2}$' or coalesce(p->>'ends_on','')!~'^\d{4}-\d{2}-\d{2}$' then raise exception 'Company, version and ISO dates required' using errcode='22023'; end if;
 p:=p||jsonb_build_object('id',cid::text,'version',expected::text,'starts_on',((p->>'starts_on')::date)::text,'ends_on',((p->>'ends_on')::date)::text);
 digest:=sha256(convert_to('set_subscription:'||p::text,'UTF8'));
 insert into private.platform_requests(actor_id,request_id,command_name,request_hash) values(actor,request_id,'set_subscription',digest) on conflict do nothing;
 select * into prior from private.platform_requests r where r.actor_id=actor and r.request_id=set_company_subscription.request_id for update;
 if prior.command_name<>'set_subscription' or prior.request_hash<>digest then raise exception 'Idempotency mismatch' using errcode='22023'; end if;
 perform 1 from public.companies where id=cid for update;
 if not found then raise exception 'Company unavailable' using errcode='22023'; end if;
 if prior.receipt is not null then return prior.receipt; end if;
 select * into old from private.company_subscriptions where company_id=cid for update;
 if coalesce(old.version,0)<>expected then raise exception 'Stale subscription' using errcode='40001'; end if;
 insert into private.company_subscriptions(company_id,plan_key,state,starts_on,ends_on,billing_method,payment_status,payment_reference,updated_by)
 values(cid,private.platform_text(p,'plan_key',20),private.platform_text(p,'subscription_state',20),(p->>'starts_on')::date,(p->>'ends_on')::date,private.platform_text(p,'billing_method',30),private.platform_text(p,'payment_status',20),private.platform_text(p,'payment_reference',200,false),actor)
 on conflict(company_id) do update set plan_key=excluded.plan_key,state=excluded.state,starts_on=excluded.starts_on,ends_on=excluded.ends_on,billing_method=excluded.billing_method,payment_status=excluded.payment_status,payment_reference=excluded.payment_reference,version=company_subscriptions.version+1,updated_by=actor,updated_at=clock_timestamp()
 returning * into next_row;
 -- Preserve existing plan metadata for compatibility, without adopting legacy accounting entities.
 update private.platform_entities set plan_key=next_row.plan_key,version=version+1 where company_id=cid;
 insert into private.platform_events(actor_id,action,target_id,request_id,metadata)
 values(actor,'set_subscription',cid,request_id,jsonb_build_object('reason',reason,'before',case when old.company_id is null then null else to_jsonb(old) end,'after',to_jsonb(next_row)));
 result:=jsonb_build_object('id',cid,'request_id',request_id,'command','set_subscription','status','CONFIRMED');
 update private.platform_requests r set receipt=result where r.actor_id=actor and r.request_id=set_company_subscription.request_id;
 return result;
end $$;
revoke all on function public.set_company_subscription(uuid,jsonb) from public,anon,authenticated,service_role;
grant execute on function public.set_company_subscription(uuid,jsonb) to authenticated;

-- Old entity metadata editing cannot contradict a managed subscription's authoritative plan.
create function private.guard_subscription_plan_metadata() returns trigger
language plpgsql security definer set search_path='' as $$
begin
 if exists(select 1 from private.company_subscriptions s where s.company_id=new.company_id and s.plan_key<>new.plan_key) then raise exception 'Use subscription management to change managed plan' using errcode='23514';end if;
 return new;
end $$;
revoke all on function private.guard_subscription_plan_metadata() from public,anon,authenticated,service_role;
create trigger subscription_plan_metadata_guard before update of plan_key on private.platform_entities for each row execute function private.guard_subscription_plan_metadata();

create function public.list_company_subscriptions(page_offset integer default 0,page_size integer default 25,search text default '')
returns jsonb language plpgsql security definer set search_path='' as $$
declare result jsonb;today date:=(statement_timestamp() at time zone 'Asia/Dubai')::date;
begin
 perform private.platform_read_actor();
 if page_offset is null or page_size is null or search is null or page_offset<0 or page_offset>100000 or page_size not between 1 and 100 or length(search)>100 then raise exception 'Invalid page' using errcode='22023';end if;
 select coalesce(jsonb_agg(to_jsonb(q)),'[]') into result from (
 select c.id,c.code,c.name,c.status company_status,coalesce(s.plan_key,'UNASSIGNED') plan_key,
 coalesce(s.state,'UNMANAGED') subscription_state,private.subscription_effective_state(s,today) effective_state,
 s.starts_on,s.ends_on,case when s.company_id is not null then s.ends_on+1 end renewal_due_on,
 s.billing_method,s.payment_status,s.payment_reference,coalesce(s.version,0) version,
 case when s.company_id is null or private.subscription_effective_state(s,today) in ('TRIAL','ACTIVE') then 'FULL' else 'LIMITED' end subscription_access
 from public.companies c left join private.company_subscriptions s on s.company_id=c.id
 where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search order by c.id limit page_size offset page_offset
 )q;
 return jsonb_build_object('items',result,'has_more',exists(select 1 from public.companies c where c.name ilike '%'||search||'%' or c.code ilike '%'||search||'%' or c.id::text=search offset page_offset+page_size));
end $$;
revoke all on function public.list_company_subscriptions(integer,integer,text) from public,anon,authenticated,service_role;
grant execute on function public.list_company_subscriptions(integer,integer,text) to authenticated;

create function public.get_my_company_subscription(target_company_id uuid)
returns jsonb language plpgsql security definer set search_path='' as $$
declare s private.company_subscriptions;today date:=(statement_timestamp() at time zone 'Asia/Dubai')::date;effective text;
begin
 if not public.is_company_member(target_company_id) then raise exception 'Denied' using errcode='42501';end if;
 select * into s from private.company_subscriptions where company_id=target_company_id;effective:=private.subscription_effective_state(s,today);
 return jsonb_build_object('company_id',target_company_id,'plan_key',coalesce(s.plan_key,'UNASSIGNED'),'state',effective,'starts_on',s.starts_on,'ends_on',s.ends_on,'renewal_due_on',s.ends_on+1,'payment_status',s.payment_status,'access',case when effective in ('UNMANAGED','TRIAL','ACTIVE') then 'FULL' else 'LIMITED' end);
end $$;
revoke all on function public.get_my_company_subscription(uuid) from public,anon,authenticated,service_role;
grant execute on function public.get_my_company_subscription(uuid) to authenticated;

-- Preserve reads, memberships, master maintenance, existing settlements and reversals.
-- Deny creation of new business/masters and edits to draft detail rows.
-- Period-header updates remain available: reverse_payroll must unlock attendance and invalidate review.
create function private.guard_subscription_new_business() returns trigger
language plpgsql security definer set search_path='' as $$
declare cid uuid; s private.company_subscriptions;effective text;
begin
 if tg_op='DELETE' then cid:=old.company_id;else cid:=new.company_id;end if;
 perform 1 from public.companies where id=cid for share;
 select * into s from private.company_subscriptions where company_id=cid for share;
 effective:=private.subscription_effective_state(s,(statement_timestamp() at time zone 'Asia/Dubai')::date);
 if effective not in ('UNMANAGED','TRIAL','ACTIVE') then raise exception 'SUBSCRIPTION_LIMITED: read, existing settlement and reversal access remains available' using errcode='42501';end if;
 if tg_op='DELETE' then return old;end if;return new;
end $$;
revoke all on function private.guard_subscription_new_business() from public,anon,authenticated,service_role;
do $$declare t text;begin
 foreach t in array array['projects','parties','party_person_roles','expense_categories','accounts','treasury_accounts','subcontracts','expenses','custody_advances','subcontractor_advances','subcontractor_certificates','payroll_postings','historical_source_records','payroll_draft_periods','attendance_periods'] loop
 execute format('create trigger subscription_new_business_guard before insert on public.%I for each row execute function private.guard_subscription_new_business()',t);
 end loop;
 foreach t in array array['payroll_draft_rows','payroll_draft_adjustments','payroll_draft_accounting','attendance_exceptions','employee_site_assignments'] loop
 execute format('create trigger subscription_operational_draft_guard before insert or update or delete on public.%I for each row execute function private.guard_subscription_new_business()',t);
 end loop;
end $$;
