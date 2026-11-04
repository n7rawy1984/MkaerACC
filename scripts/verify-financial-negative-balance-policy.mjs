import {createRequire} from 'node:module';
import {resolve,dirname} from 'node:path';
// Synthetic local databases only: verify legacy-negative policy without hosted writes.
import assert from 'node:assert/strict';
import {readFileSync,writeFileSync} from 'node:fs';
import {randomUUID} from 'node:crypto';
import {priorityFinancialFixture} from './priority-financial-fixture.mjs';
const require=createRequire(resolve('package.json')),ts=require('typescript'),cache=new Map();function load(path){path=resolve(path);if(cache.has(path))return cache.get(path);const mod={exports:{}};cache.set(path,mod.exports);new Function('require','module','exports',ts.transpileModule(readFileSync(path,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(n=>n.startsWith('.')?load(resolve(dirname(path),n+'.ts')):require(n),mod,mod.exports);cache.set(path,mod.exports);return mod.exports;}
const f=await priorityFinancialFixture({finance:false}),checks=[];
const check=(v,s)=>{assert(v,s);checks.push(s);console.log('PASS',checks.length,s);};
const cashGL=f.id(801),cash=f.id(802),holder=f.id(803),currentGL=f.id(804);
const run=(sql,args=[])=>f.as(f.admin,sql,args);
const balance=async(account,party=null)=>(await f.db.query('select coalesce(sum(debit_minor::numeric-credit_minor::numeric),0)::text amount from public.journal_lines where company_id=$1 and account_id=$2 and ($3::uuid is null or party_id=$3)',[f.company,account,party])).rows[0].amount;
try{
 await f.db.query("insert into public.accounts(id,company_id,code,name,account_type,requires_party) values($1,$3,'LEGACY-CASH','Synthetic legacy Cash','ASSET',false),($2,$3,'CURRENT-CONTROL','Approved current control','LIABILITY',true)",[cashGL,currentGL,f.company]);
 await f.db.query("insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id) values($1,$2,'LEGACY-CASH','Synthetic legacy Cash','CASH',$3)",[cash,f.company,cashGL]);
 await f.db.query("insert into public.parties(id,company_id,code,name,type) values($1,$2,'HOLDER-LEGACY','Synthetic holder','CUSTODIAN')",[holder,f.company]);
 const expense=async(amount,mode='TREASURY',date='2026-11-04')=>(await run("select * from public.post_expense($1,$2,$3,$4,'Supported operating cost',$5,'ZERO',null,$6,$7,$8,null,'CASH',false,null,null,$9)",[f.company,date,f.p2,f.category,amount,mode,mode==='TREASURY'?cash:null,mode==='CUSTODIAN'?holder:null,randomUUID()]))[0];
 const advance=async(amount,treasury=cash,date='2026-11-04')=>(await run("select * from public.post_custody_advance($1,$2,$3,$4,$5,$6,'CASH','Original evidence','Actual transfer',$7)",[f.company,date,holder,treasury,f.p2,amount,randomUUID()]))[0];
 const cashExpense=await expense(1000),originalAdvance=await advance(1000),custodyExpense=await expense(300,'CUSTODIAN');
 // Represent a pre-enforcement historical credit with no recorded opening. This
 // privileged balanced fixture seed is never an application posting interface.
 const cost=(await f.db.query("select id from public.accounts where company_id=$1 and system_key='PROJECT_COST'",[f.company])).rows[0].id;
 await f.db.transaction(async t=>{await t.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:f.admin})]);await t.query("select private.create_journal($1,'2026-11-04','Synthetic historical gap','LOCAL_HISTORICAL_FIXTURE',$2,'ORIGINAL',$3,$4,null)",[f.company,randomUUID(),JSON.stringify([{account_id:cost,project_id:f.p2,debit_minor:1200,credit_minor:0},{account_id:f.id(102),party_id:holder,project_id:f.p2,debit_minor:0,credit_minor:1200}]),f.admin]);});
 check(await balance(cashGL)==='-2000'&&await balance(f.id(102),holder)==='-500','Fixture reproduces actual legacy-negative Treasury and holder scopes before77');
 const before=(await f.db.query('select count(*)::int n from public.journal_entries')).rows[0].n;
 await f.db.exec(readFileSync('supabase/migrations/20261104190000_operational_liability_posting.sql','utf8'));
 check((await f.db.query('select count(*)::int n from public.journal_entries')).rows[0].n===before&&await balance(cashGL)==='-2000','Applying77 creates no corrective funding, journal or balance backfill');
 await f.rpc(f.admin,'configure_financial_operation_account',{target_company_id:f.company,target_request_key:randomUUID(),target_classification:'PARTNER_CURRENT',target_account_id:currentGL,target_allow_withdrawals:true,target_approval_reference:'Approved actual current-account policy'});
 const funding=async(amount,direct=false)=>{const e=await f.rpc(f.admin,'submit_financial_operation_evidence',{target_company_id:f.company,target_request_key:randomUUID(),business_input:{kind:'PARTNER_FUNDING',event_date:'2026-11-04',counterparty_id:f.partner,amount_minor:String(amount),classification:'CURRENT_ACCOUNT',destination:direct?'DIRECT_CUSTODY':'TREASURY',recipient_id:holder,treasury_id:direct?null:cash,project_id:f.p2,source_reference:randomUUID(),description:'Actual receipt evidence',supporting_reference:'Signed original handover'}});await f.rpc(f.admin,'review_financial_operation_evidence',{target_company_id:f.company,target_request_key:randomUUID(),target_evidence_id:e.id,target_decision:'REVIEWED',target_reason:'Original receipt verified'});return f.rpc(f.admin,'post_reviewed_financial_operation',{target_company_id:f.company,target_request_key:randomUUID(),target_evidence_id:e.id,business_input:{approved_classification:'PARTNER_CURRENT',approval_reference:'Actual classified receipt approved'}});};
 await funding(100);check(await balance(cashGL)==='-1900','Genuine Treasury receipt may improve a negative balance without first reaching zero');
 await funding(100,true);check(await balance(f.id(102),holder)==='-400'&&await balance(cashGL)==='-1900','Direct actual handover improves holder receivable without fictional Cash transit');
 await run("select * from public.reverse_expense($1,$2,'2026-11-04','Documented original correction',$3)",[f.company,cashExpense.expense_id,randomUUID()]);check(await balance(cashGL)==='-900','Exact Expense reversal can improve an existing negative Treasury while it remains negative');
 await run("select * from public.reverse_expense($1,$2,'2026-11-04','Documented custody correction',$3)",[f.company,custodyExpense.expense_id,randomUUID()]);check(await balance(f.id(102),holder)==='-100','Exact custody Expense reversal can improve a negative holder balance without forced normalization');
 const rejectedBefore=(await f.db.query('select count(*)::int n from public.journal_entries')).rows[0].n;
 await assert.rejects(()=>advance(1),e=>e.code==='23514');check(await balance(cashGL)==='-900'&&await balance(f.id(102),holder)==='-100','A transfer improving custody still rejects if its Treasury credit worsens negative Cash; both legs roll back');
 await assert.rejects(()=>expense(1,'CUSTODIAN'),e=>e.code==='23514');check((await f.db.query('select count(*)::int n from public.journal_entries')).rows[0].n===rejectedBefore,'Further spending from negative Custody rejects without another source or journal');
 await assert.rejects(()=>run("select * from public.reverse_custody_advance($1,$2,'2026-11-04','Invalid unavailable holder funds',$3)",[f.company,originalAdvance.custody_advance_id,randomUUID()]),e=>e.code==='23514');check(true,'Advance reversal cannot improve Cash by creating an unsupported negative holder receivable');
 const treasuryReport=await load('src/reports/treasuryMovements.ts').readTreasuryMovements(f.client(),f.company,cash,'2026-11-01','2026-11-30');check(treasuryReport.closing==='-900','Actual Treasury report reconciles and displays historical negative movement without triggering mutation guards');
 const custodyReport=await load('src/reports/custodyReconciliation.ts').readCustodyReconciliation(f.client(),{companyId:f.company,partyId:holder,from:'2026-11-01',through:'2026-11-30',account:'ALL',project:'ALL',transaction:'ALL'});check(custodyReport.closing==='-100','Actual holder reconciliation remains usable and retains signed negative GL evidence');
 await funding(1000,true);await expense(100,'CUSTODIAN');check(await balance(cashGL)==='-900'&&await balance(f.id(102),holder)==='800','A sufficiently funded holder can spend while an unrelated Treasury remains negative');
 await advance(1,f.bank);check(await balance(cashGL)==='-900','An independent sufficiently funded Treasury remains usable within the same Company');
 await funding(1000);await advance(50);check(await balance(cashGL)==='50','Real funding restores eligibility and subsequent outflows remain bounded');
 await assert.rejects(()=>advance(1,cash,'2026-08-01'),e=>e.code==='23514');check(true,'Later funding cannot authorize a historically unfunded backdated withdrawal');
 const reader=await f.as(f.viewer,'select count(*)::int n from public.journal_lines where company_id=$1',[f.company]);check(reader[0].n>0,'Authorized report SELECTs remain available despite historical negative balances');
 check((await f.db.query('select count(*)::int n from(select journal_entry_id from public.journal_lines group by journal_entry_id having sum(debit_minor::numeric-credit_minor::numeric)<>0) x')).rows[0].n===0,'All successful funding, corrections, spending and transfers remain balanced');
 writeFileSync('/tmp/narvo-financial-blockers/negative-policy-tests.json',JSON.stringify({status:'PASS',checks:checks.length,details:checks,hosted:false,migration77Changed:false},null,2));
}finally{await f.db.close();}
