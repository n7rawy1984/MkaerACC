import assert from 'node:assert/strict';import {randomUUID} from 'node:crypto';import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';import {makerOperationalFixture} from './maker-operational-fixture.mjs';
const out='/tmp/narvo-accounting-ux';mkdirSync(out,{recursive:true});const checks=[],f=await makerOperationalFixture({seed:false});
const check=(v,label)=>{assert(v,label);checks.push(label);console.log('PASS',label);};
const call=async(actor,name,args)=>(await f.as(actor,'select public.'+name+'('+args.map((_,i)=>'$'+(i+1)).join(',')+')r',args))[0].r;
try{
 for(const file of ['20261111120000_custody_funding_drafts.sql','20261111140000_custody_funded_source_settlements.sql','20261112120000_accounting_dashboard_reads.sql'])await f.db.exec(readFileSync('supabase/migrations/'+file,'utf8'));
 const preserve=async()=>JSON.stringify((await f.db.query("select (select jsonb_agg(t)from public.journal_entries t)journals,(select jsonb_agg(t)from public.journal_lines t)lines,(select jsonb_agg(t)from public.historical_source_records t)sources,(select jsonb_agg(t)from public.expense_draft_events t)drafts,(select jsonb_agg(t)from public.parties t)parties,(select jsonb_agg(t)from public.company_memberships t)members,(select jsonb_agg(t)from auth.users t)users")).rows);
 const before=await preserve();await f.db.exec(readFileSync('supabase/migrations/20261113120000_payment_workflow_preferences.sql','utf8'));check(before===await preserve(),'Additive activation preserves all synthetic journals, balances, sources, drafts, parties, memberships and identities');
 const defaults={kind:'DEFAULT',mode:'TREASURY',treasury_id:f.bank,approval_reference:'Synthetic approved future account suggestion'};
 const configure=(input,version=0,key=randomUUID(),actor=f.admin,cid=f.company)=>call(actor,'configure_payment_preferences',[cid,key,version,input]);
 const key=randomUUID(),saved=await configure(defaults,0,key);check(saved.treasury_id===f.bank,'Future default uses an existing active same-Company Treasury');check((await configure(defaults,0,key)).id===saved.id,'Identical retry returns one immutable preference event');
 async function rejects(fn,label){let error;try{await fn();}catch(e){error=e;}check(!!error,label);}
 await rejects(()=>configure({...defaults,approval_reference:'Changed request payload'},0,key),'Changed payload cannot reuse a request key');
 await rejects(()=>configure(defaults,0),'Stale concurrent version cannot overwrite a default');
 const ids=await f.db.query('select user_id from public.company_memberships where company_id=$1 and role=$2',[f.company,'MANAGEMENT_VIEWER']);const viewer=ids.rows[0]?.user_id;
 if(!viewer)throw Error('Required local Viewer fixture missing');
 await rejects(()=>configure(defaults,1,randomUUID(),viewer),'Management Viewer cannot configure payment defaults');
 await rejects(()=>call(viewer,'read_payment_preferences',[f.company]),'Management Viewer cannot read confidential payer-policy metadata');
 await rejects(()=>configure(defaults,1,randomUUID(),f.admin,randomUUID()),'Cross-tenant configuration is denied');
 await rejects(()=>configure({...defaults,treasury_id:randomUUID()},1),'Unknown or other-Company Treasury cannot be configured');
 const src=await f.source('EXPENSE'),policy={kind:'SOURCE_SET',mode:'CUSTODIAN',party_id:f.custodian,source_file:'synthetic.xlsx',source_hash:'b'.repeat(64),month_from:'2026-08',month_through:'2026-11',approval_reference:'Owner confirms actual Company outgoings paid by this Custodian; exact synthetic source set'};
 const policyBefore=await preserve();const p=await configure(policy);check(p.kind==='SOURCE_SET','Audited exact file/hash/month source-set payer policy saved');
 const matched=await call(f.admin,'read_source_payment_policies',[f.company,[src]]);check(matched.length===1&&!matched[0].contradicted&&matched[0].party_id===f.custodian,'Covered genuine outgoing reuses confirmed Custody payer without per-record funding edits');
 await rejects(()=>configure({...policy,source_hash:'c'.repeat(64)}),'Policy cannot invent an unknown import fingerprint');
 await rejects(()=>configure({...policy,month_from:'2026-09'}),'Conflicting overlapping source scopes are rejected');
 await f.db.query("update public.historical_source_records set completion=completion||'{\"funding_contradiction\":\"true\"}'where id=$1",[src]);
 check((await call(f.admin,'read_source_payment_policies',[f.company,[src]]))[0].contradicted,'Contradictory source evidence stays explicitly unresolved');
 const foreign=await call(f.admin,'read_source_payment_policies',[f.company,[randomUUID()]]);check(!foreign.length,'Policy reader cannot return unrelated source identities');
 await rejects(()=>call(f.admin,'read_source_payment_policies',[randomUUID(),[src]]),'Policy reader denies another Company');
 await rejects(()=>call(f.admin,'read_source_payment_policies',[f.company,Array.from({length:501},randomUUID)]),'Policy reader enforces bounded pagination');
 const outside=await f.source('EXPENSE');await f.db.query("update public.historical_source_records set source_hash=repeat('d',64)where id=$1",[outside]);check(!(await call(f.admin,'read_source_payment_policies',[f.company,[outside]])).length,'Unrelated import is never assigned the historical Custodian');
 const reverse=await configure({...defaults,mode:'NONE',treasury_id:null},1);check(reverse.mode==='NONE','Default can be disabled by a new audited version');
 const perms=(await f.db.query("select has_table_privilege('authenticated','public.payment_workflow_preferences','INSERT')i,has_table_privilege('authenticated','public.payment_workflow_preferences','UPDATE')u,has_table_privilege('authenticated','public.payment_workflow_preferences','DELETE')d")).rows[0];check(!perms.i&&!perms.u&&!perms.d,'No authenticated direct-write bypass to policy history');
 const journalAfter=(await f.db.query('select count(*)n from public.journal_entries')).rows[0].n;check(journalAfter>0,'Existing canonical synthetic financial history remains present');
 // Only scoped synthetic contradiction/hash fixtures above changed source metadata; config itself did not.
 check(policyBefore===await preserve().then(s=>{const a=JSON.parse(s),b=JSON.parse(policyBefore);a[0].sources=b[0].sources;return JSON.stringify(a);}),'All preference configuration leaves financial journals, GL lines, drafts and identities unchanged');
 writeFileSync(out+'/preferences.json',JSON.stringify({status:'PASS',checks,hosted:false,financialCommandsChanged:false},null,2));
}catch(e){console.error(e);process.exitCode=1;}finally{await f.db.close();}
