import assert from 'node:assert/strict';import{randomUUID}from'node:crypto';import{writeFileSync}from'node:fs';import{foundationFixture}from'./foundation-certification-fixture.mjs';
const f=await foundationFixture(),{db,company,accounts}=f,checks=[];const check=(v,n)=>{assert(v,n);checks.push(n);console.log('PASS',n);};const reject=async(fn,code,n)=>{await assert.rejects(fn,e=>e.code===code);checks.push(n);};
try{
 check((await f.review()).failures.some(x=>x.code==='ENROLL_BUSINESS'),'unenrolled populated company receives precise enrollment blocker');
 const before=await f.fingerprint();await f.enroll();check(await f.fingerprint()===before,'canonical customer association preserves accounts, journals, Treasury and memberships');
 check((await f.review()).eligible,'valid populated company passes structural foundation validation');
 await reject(()=>f.certify(randomUUID(),{},f.admin),'42501','Accounting Admin cannot certify Platform foundation');
 await reject(()=>f.certify(randomUUID(),{},f.foreign),'42501','other tenant accountant cannot certify or inspect foundation');
 await reject(()=>f.as(f.foreign,'select public.review_existing_company_foundation($1)',[company]),'42501','review is restricted to Platform Owner');
 await reject(()=>f.certify(randomUUID(),{},f.owner,{aal:'aal1'}),'42501','certification enforces genuine live-session MFA gate');
 await reject(()=>f.certify(randomUUID(),{},f.owner,{amr:[{method:'totp',timestamp:1}]}),'42501','stale MFA cannot certify');
 const failed=async(sql,args,code)=>{try{await db.transaction(async tx=>{for(const statement of sql.split(';').filter(Boolean))await tx.query(statement,statement.includes('$')?args:[]);const r=(await tx.query('select private.existing_foundation_validation($1)r',[company])).rows[0].r;check(!r.eligible&&r.failures.some(x=>x.code===code),code+' blocks certification');throw Error('rollback fixture');});}catch(e){if(e.message!=='rollback fixture')throw e;}};
 await failed("update public.accounts set status='INACTIVE'where id=$1",[accounts.SUPPLIER_PAYABLE],'CONTROL_MAPPING');
 await failed("update public.treasury_accounts set type='BANK',bank_name=null where id=$1",[f.treasury],'TREASURY_MAPPING');
 await failed("update public.treasury_accounts set status='INACTIVE'where id=$1",[f.treasury],'TREASURY_REQUIRED');
 await failed("alter table public.journal_lines disable trigger all; update public.journal_lines set credit_minor=50000 where company_id=$1 and credit_minor>0 and treasury_account_id is not null",[company],'TREASURY_BALANCE');
 await failed("alter table public.journal_entries disable trigger journal_entries_immutable",[],'IMMUTABILITY');
 // Deliberate corruption is possible only as trusted fixture operator with protections disabled.
 await failed("alter table public.journal_lines disable trigger all; update public.journal_lines set debit_minor=10001 where company_id=$1 and debit_minor>0",[company],'JOURNAL_BALANCE');
 await failed("insert into public.accounting_fiscal_years(company_id,label,from_date,through_date,created_by)values($1,'Old year','2020-01-01','2020-12-31',$2)",[company,f.admin],'PERIOD_COVERAGE');
 await failed("alter table public.journal_lines disable trigger all; update public.journal_lines set account_id=$2 where company_id=$1 and debit_minor>0",[company,accounts.CUSTODY_ADVANCE],'LINE_DIMENSIONS');
 await failed("with d as(insert into public.opening_balance_drafts(company_id,request_key,request_hash,opening_date,period_month,source_reference,reason,evidence_reference,period_reference,positions,created_by)values($1,$4,'fixture',current_date,date_trunc('month',current_date)::date,'Local corrupt opening','Fixture only','Fixture only','Fixture only',jsonb_build_array(jsonb_build_object('account_id',$3::text,'target_minor','999999')),$2)returning id)insert into public.opening_balance_postings(company_id,draft_id,approval_reference,created_by)select $1,id,'Fixture only',$2 from d",[company,f.admin,accounts.CASH,randomUUID()],'OPENING_POSITION');
 check(await f.fingerprint()===before,'all rejection fixtures roll back without changing existing books');
 const key=randomUUID(),v=await f.version(),receipt=await f.certify(key);check(receipt.status==='CONFIRMED','actual canonical certification succeeds');
 const replay=await f.certify(key,{version:v});check(JSON.stringify(receipt)===JSON.stringify(replay),'same request replay returns identical receipt');
 await reject(()=>f.certify(key,{version:v,reason:'Changed certification intent'}),'22023','changed request intent is rejected');
 await f.certify();check((await db.query('select count(*)::int n from private.company_foundation_certifications where company_id=$1',[company])).rows[0].n===1,'new request does not duplicate certification');
 check((await db.query("select status from public.companies where id=$1",[company])).rows[0].status==='ACTIVE','active company lifecycle preserved');
 const readiness=async()=>(await db.query('select private.company_commercial_readiness($1)r',[company])).rows[0].r;
 check((await readiness()).foundation&&!(await readiness()).ready,'certificate completes foundation without inventing a subscription');
 const today=new Date().toISOString().slice(0,10),sub={id:company,version:'0',plan_key:'TRIAL',subscription_state:'TRIAL',starts_on:today,ends_on:today,billing_method:'NONE',payment_status:'NOT_REQUIRED',reason:'Isolated explicitly selected trial dates'};
 await reject(()=>f.as(f.owner,'select public.set_company_subscription($1,$2)',[randomUUID(),{...sub,ends_on:'2000-01-01'}]),'23514','invalid trial dates are rejected');
 await f.as(f.owner,'select public.set_company_subscription($1,$2)',[randomUUID(),sub]);check((await readiness()).ready,'existing customer, admin, certificate and valid trial transition to commercial ready');
 check(await f.fingerprint()===before,'certification and trial preserve exact existing financial books and memberships');
 await reject(()=>db.query("update private.company_foundation_certifications set reason='tamper'where company_id=$1",[company]),'42501','certification evidence is immutable');
 check((await db.query("select has_table_privilege('authenticated','private.company_foundation_certifications','INSERT')p")).rows[0].p===false,'authenticated direct certificate write is denied');
 writeFileSync('docs/foundation-certification-verification.json',JSON.stringify({status:'PASS',checks,count:checks.length,environment:'Disposable local PostgreSQL; synthetic Auth fixture, no hosted writes',preservedBooks:true},null,2)+'\n');
}finally{await db.close();}
