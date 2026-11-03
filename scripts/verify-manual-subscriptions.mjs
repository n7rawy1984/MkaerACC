// Isolated embedded PostgreSQL; synthetic identities/data only, no hosted connections.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {platformTestDatabase} from './verify-platform-database.mjs';
const {db}=await platformTestDatabase(undefined,{through:'20261101120000'});
let checks=0;
const q=async(s,a=[])=>(await db.query(s,a)).rows;
const check=(v,label)=>{assert(v,label);checks++;};
const reject=async(fn,code,label)=>{await assert.rejects(fn,e=>e.code===code,label);checks++;};
const roles=['owner','admin','foreign','system'];
const users=Object.fromEntries(roles.map(r=>[r,randomUUID()]));
const sessions=Object.fromEntries(roles.map(r=>[r,randomUUID()]));
const as=(role,sql,args=[],patch={})=>db.transaction(async tx=>{
 await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:users[role],session_id:sessions[role],aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}],...patch})]);
 await tx.exec('set local role authenticated');return(await tx.query(sql,args)).rows;
});
const cmd=(name,p)=>as('owner','select public.platform_admin_command($1,$2,$3) r',[name,randomUUID(),JSON.stringify(p)]).then(r=>r[0].r);
const assign=(p,key=randomUUID(),role='owner',patch={})=>as(role,'select public.set_company_subscription($1,$2) r',[key,JSON.stringify(p)],patch).then(r=>r[0].r);
const status=(cid,role='admin')=>as(role,'select public.get_my_company_subscription($1) r',[cid]).then(r=>r[0].r);
const snapshot=async(ids)=>JSON.stringify(await q(`select c.id,to_jsonb(c) company,
 (select jsonb_agg(to_jsonb(a) order by a.id) from public.accounts a where a.company_id=c.id) accounts,
 (select jsonb_agg(to_jsonb(j) order by j.id) from public.journal_entries j where j.company_id=c.id) journals,
 (select jsonb_agg(to_jsonb(l) order by l.id) from public.journal_lines l where l.company_id=c.id) lines,
 (select jsonb_agg(to_jsonb(m) order by m.id) from public.company_memberships m where m.company_id=c.id) memberships
 from public.companies c where c.id=any($1) order by c.id`,[ids]));
try{
 for(const role of roles){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[users[role],`${role}@example.invalid`]);await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[sessions[role],users[role]]);}
 await db.query('insert into private.system_administrators(user_id) values($1)',[users.owner]);
 await db.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[users.owner]);
 await db.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1) where user_id=$1',[users.owner]);
 const historical=[];
 for(let i=0;i<17;i++){
  const cid=randomUUID(),a=randomUUID(),b=randomUUID(),j=randomUUID();historical.push(cid);
  await db.query('insert into public.companies(id,code,name) values($1,$2,$2)',[cid,`HISTORY-${i}`]);
  await db.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[cid,users.admin]);
  await db.query("insert into public.accounts(id,company_id,code,name,account_type) values($1,$3,'A','Asset','ASSET'),($2,$3,'E','Expense','EXPENSE')",[a,b,cid]);
  await db.transaction(async tx=>{
   await tx.query("insert into public.journal_entries(id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose) values($1,$2,'H-1',current_date,'Synthetic history','TEST',$3,'POST')",[j,cid,randomUUID()]);
   await tx.query('insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,debit_minor,credit_minor) values($1,$2,1,$3,100,0),($1,$2,2,$4,0,100)',[cid,j,b,a]);
  });
 }
 const history=await snapshot(historical);
 await db.exec(readFileSync('supabase/migrations/20261101130000_manual_company_subscriptions.sql','utf8'));
 check(await snapshot(historical)===history,'migration preserves all 17 historical Companies and posted accounting');
 check((await q('select count(*)::int n from private.company_subscriptions'))[0].n===0,'no automatic subscription backfill');
 check((await status(historical[0])).state==='UNMANAGED','historical Company retains explicit unmanaged access');
 const c=await cmd('create_entity',{code:'SUBS-LOCAL',name:'Synthetic subscription Company',tenant_slug:'subs-local',locale:'en',entity_kind:'BUSINESS',initial_admin_id:users.admin});
 await cmd('set_lifecycle',{id:c.id,version:'1',state:'ACTIVE',reason:'Synthetic activation'});
 await as('owner','select public.provision_company_accounting($1,$2)',[randomUUID(),JSON.stringify({id:c.id,code:'SUBS-LOCAL',version:'2',treasury_name:'Synthetic cash',treasury_type:'CASH',reason:'Synthetic foundation'})]);
 await db.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'SYSTEM_ADMIN')",[c.id,users.system]);
 const before=await snapshot([c.id]);
 const dates=(await q("select ((statement_timestamp() at time zone 'Asia/Dubai')::date)::text today,(((statement_timestamp() at time zone 'Asia/Dubai')::date)-1)::text yesterday,(((statement_timestamp() at time zone 'Asia/Dubai')::date)+1)::text tomorrow"))[0];
 const input={id:c.id,version:'0',plan_key:'TRIAL',subscription_state:'TRIAL',starts_on:dates.today,ends_on:dates.today,billing_method:'NONE',payment_status:'NOT_REQUIRED',reason:'Synthetic reviewed trial'};
 for(const role of ['admin','foreign','system'])await reject(()=>assign(input,randomUUID(),role),'42501',`${role} cannot manage subscriptions`);
 await reject(()=>assign(input,randomUUID(),'owner',{aal:'aal1'}),'42501','owner AAL1 denied');
 await reject(()=>assign(input,randomUUID(),'owner',{amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)-601}]}),'42501','stale owner MFA denied');
 await reject(()=>assign(input,randomUUID(),'owner',{session_id:randomUUID()}),'42501','unknown session denied');
 await reject(()=>assign({...input,unknown:'field'}),'22023','closed field set enforced');
 await reject(()=>assign({...input,reason:''}),'22023','audit reason mandatory');
 await reject(()=>assign({...input,ends_on:dates.yesterday}),'23514','inverted dates denied');
 await reject(()=>assign({...input,payment_status:'PAID'}),'23514','paid requires manual method and reference');
 const key=randomUUID();
 await db.exec("create function public.fail_subscription_audit() returns trigger language plpgsql as $$begin if new.action='set_subscription' then raise exception 'Synthetic late audit failure' using errcode='23514';end if;return new;end$$; create trigger synthetic_subscription_audit_failure before insert on private.platform_events for each row execute function public.fail_subscription_audit();");
 await reject(()=>assign(input,key),'23514','late audit failure rolls back subscription, metadata and receipt');
 check((await q('select count(*)::int n from private.company_subscriptions where company_id=$1',[c.id]))[0].n===0&&(await q('select count(*)::int n from private.platform_requests where request_id=$1',[key]))[0].n===0,'late failure leaves no row or request');
 await db.exec('drop trigger synthetic_subscription_audit_failure on private.platform_events;drop function public.fail_subscription_audit()');
 const receipt=await assign(input,key);
 check(receipt.command==='set_subscription'&&receipt.status==='CONFIRMED','trial assignment succeeds');
 check(JSON.stringify(await assign({...input,reason:` ${input.reason} `},key))===JSON.stringify(receipt),'normalized replay recovers exact receipt');
 await reject(()=>assign({...input,ends_on:dates.tomorrow},key),'22023','same key changed intent denied');
 await reject(()=>assign(input),'40001','new key stale version cannot create conflicting active subscription');
 check((await q('select count(*)::int n from private.company_subscriptions where company_id=$1',[c.id]))[0].n===1,'one authoritative current subscription');
 check(await snapshot([c.id])===before,'subscription assignment and retries preserve Company, memberships, chart and financial records');
 check((await status(c.id)).state==='TRIAL'&&(await status(c.id)).access==='FULL','inclusive end date trial remains available');
 check((await q("select private.subscription_effective_state(s,s.ends_on+1) state from private.company_subscriptions s where company_id=$1",[c.id]))[0].state==='EXPIRED','automatic expiry after inclusive final date');
 await reject(()=>as('foreign','select public.get_my_company_subscription($1)',[c.id]),'42501','unrelated tenant status denied');
 await reject(()=>status(c.id,'owner'),'42501','owner is not a financial Company member');
 await reject(()=>as('admin','select public.list_company_subscriptions()'),'42501','owner directory unavailable to Company admin');
 await reject(()=>as('admin','select * from private.company_subscriptions'),'42501','private subscription rows inaccessible');
 const ownerList=(await as('owner','select public.list_company_subscriptions(0,25,$1) r',['SUBS-LOCAL']))[0].r;
 check(ownerList.items.length===1&&ownerList.items[0].renewal_due_on===dates.tomorrow,'owner sees real renewal due date');
 const member=await status(c.id);check(!('payment_reference' in member)&&!('updated_by' in member),'member projection omits private manual reference and actor');
 await reject(()=>cmd('update_entity',{id:c.id,version:'4',name:'Synthetic subscription Company',entity_kind:'BUSINESS',plan_key:'STANDARD'}),'23514','old metadata editor cannot bypass plan authority');
 let version=1;
 const change=async(p)=>assign({...input,version:String(version++),...p});
 await change({subscription_state:'ACTIVE',plan_key:'STANDARD',billing_method:'MANUAL_BANK_TRANSFER',payment_status:'PAID',payment_reference:'LOCAL-RECEIPT'});
 check((await status(c.id)).state==='ACTIVE','paid active state recorded manually');
 // Existing real posting commands before expiry; all fixtures stay inside this disposable engine.
 const supplier=randomUUID(),category=randomUUID();
 await db.query("insert into public.parties(id,company_id,type,name) values($1,$2,'SUPPLIER','Synthetic supplier')",[supplier,c.id]);
 await db.query("insert into public.expense_categories(id,company_id,code,name) values($1,$2,'LOCAL','Synthetic expense')",[category,c.id]);
 const post=()=>as('admin',"select * from public.post_expense($1,current_date,null,$2,'Synthetic subscription proof',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,$3,'OTHER',false,null,null,$4)",[c.id,category,supplier,randomUUID()]).then(r=>r[0]);
 const existing=await post(),toReverse=await post();check(!!existing.journal_entry_id,'active plan permits existing accounting posting engine');
 await change({subscription_state:'ACTIVE',plan_key:'STANDARD',starts_on:dates.yesterday,ends_on:dates.yesterday});
 check((await status(c.id)).state==='EXPIRED'&&(await status(c.id)).access==='LIMITED','date expiry limits access without scheduled task');
 const prior=await snapshot([c.id]);
 await reject(()=>post(),'42501','expired new expense rejected atomically');
 check(await snapshot([c.id])===prior,'failed expired posting leaves accounting unchanged');
 check((await as('admin','select count(*)::int n from public.accounts where company_id=$1',[c.id]))[0].n===11,'expired Company can read accounting history');
 for(const table of ['accounts','projects','expenses','payroll_postings','custody_advances','subcontractor_certificates','historical_source_records'])check((await q("select count(*)::int n from pg_trigger where tgrelid=$1::regclass and tgname='subscription_new_business_guard'",[`public.${table}`]))[0].n===1,`${table} creation guarded`);
 await reject(()=>db.query("insert into public.expense_categories(company_id,code,name) values($1,'DENIED','Expired new category')",[c.id]),'42501','new master denied even through privileged caller');
 await db.query("update public.expense_categories set name='Maintained existing category' where id=$1",[category]);checks++;
 const treasury=(await q('select id from public.treasury_accounts where company_id=$1',[c.id]))[0].id;
 const paid=(await as('admin',"select * from public.post_supplier_payment($1,current_date,$2,$3,10000,'CASH',null,'Synthetic existing payable settlement',$4,$5)",[c.id,supplier,treasury,JSON.stringify([{expense_id:existing.expense_id,amount_minor:10000}]),randomUUID()]))[0];
 check(!!paid.supplier_payment_id,'expired subscription does not trap existing supplier payable');
 const reversed=(await as('admin',"select * from public.reverse_expense($1,$2,current_date,'Synthetic existing correction',$3)",[c.id,toReverse.expense_id,randomUUID()]))[0];
 check(!!reversed.reversal_journal_entry_id,'expired subscription permits legitimate existing reversal');
 // Payroll reversal updates these headers: never block its unlock/invalidation writes.
 for(const table of ['attendance_periods','payroll_draft_periods'])check((await q("select (tgtype & 16)=0 no_update_guard from pg_trigger where tgrelid=$1::regclass and tgname='subscription_new_business_guard'",[`public.${table}`]))[0].no_update_guard,`${table} reversal header updates preserved`);
 await change({subscription_state:'EXPIRED'});check((await status(c.id)).state==='EXPIRED','explicit Expired state supported independently of dates');
 await change({subscription_state:'CANCELLED'});check((await status(c.id)).state==='CANCELLED','cancellation is explicit and immediate');
 await reject(()=>post(),'42501','cancelled new financial business denied');
 await change({subscription_state:'TRIAL',starts_on:dates.tomorrow,ends_on:dates.tomorrow});check((await status(c.id)).state==='SCHEDULED','future start cannot grant early access');
 await reject(()=>post(),'42501','scheduled access limited until starts_on');
 await change({subscription_state:'ACTIVE',plan_key:'STANDARD',ends_on:dates.tomorrow,payment_status:'UNPAID',billing_method:'MANUAL_OTHER'});
 check((await status(c.id)).access==='FULL','explicit owner renewal restores new business; payment status independent');
 check(!!(await post()).expense_id,'renewed subscription uses unchanged posting engine');
 check((await q('select count(*)::int n from private.company_subscriptions where company_id=$1',[c.id]))[0].n===1,'renewal updates same subscription, no overlap');
 check((await q("select count(*)::int n from private.platform_events where target_id=$1 and action='set_subscription'",[c.id]))[0].n===version,'every effective administrative change audited once');
 const companyAfter=await snapshot([c.id]);
 check(JSON.parse(before)[0].company.status===JSON.parse(companyAfter)[0].company.status&&JSON.stringify(JSON.parse(before)[0].memberships)===JSON.stringify(JSON.parse(companyAfter)[0].memberships),'subscription lifecycle independent of Company status and memberships');
 check(await snapshot(historical)===history,'all 17 historical Companies and immutable accounting remain byte-identical');
 for(const role of ['anon','service_role'])check((await q("select has_function_privilege($1,'public.set_company_subscription(uuid,jsonb)','execute') allowed",[role]))[0].allowed===false,`${role} management RPC denied`);
 check((await q("select relrowsecurity and relforcerowsecurity enabled from pg_class where oid='private.company_subscriptions'::regclass"))[0].enabled,'forced RLS enabled on private subscription table');
 console.log(`PASS: ${checks} focused manual-subscription checks; isolated PostgreSQL, zero hosted writes.`);
}finally{await db.close();}
