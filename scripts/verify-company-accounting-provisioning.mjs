// Local PostgreSQL only, synthetic records. No hosted URL or credentials accepted.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {systemAccountTypes} from './admin/provision-gl-accounts.mjs';
import {platformTestDatabase} from './verify-platform-database.mjs';
const {db,files}=await platformTestDatabase(undefined,{through:"20261101120000"}); let checks=0;
const q=async(sql,args=[]) => (await db.query(sql,args)).rows;
const check=(value,label)=>{assert(value,label);checks++;};
const reject=async(fn,code,label)=>{await assert.rejects(fn,e=>e.code===code,label);checks++;};
const users=Object.fromEntries(['owner','admin','accountant','viewer','foreign','system'].map(r=>[r,randomUUID()]));
const sessions=Object.fromEntries(Object.keys(users).map(r=>[r,randomUUID()]));
async function as(role,sql,args=[],patch={}) {
 return db.transaction(async tx=>{
  await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:users[role],session_id:sessions[role],aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}],...patch})]);
  await tx.exec('set local role authenticated');return(await tx.query(sql,args)).rows;
 });
}
const cmd=(name,input)=>as('owner','select public.platform_admin_command($1,$2,$3) r',[name,randomUUID(),JSON.stringify(input)]).then(r=>r[0].r);
const provision=(input,key=randomUUID(),role='owner',patch={})=>as(role,'select public.provision_company_accounting($1,$2) r',[key,JSON.stringify(input)],patch).then(r=>r[0].r);
let n=0;
async function company(active=true){const code=`NEW-${++n}`;const c=await cmd('create_entity',{code,name:code,tenant_slug:`new-company-${n}`,locale:'en',entity_kind:'BUSINESS',initial_admin_id:users.admin});if(active)await cmd('set_lifecycle',{id:c.id,version:'1',state:'ACTIVE',reason:'Synthetic test activation'});return {id:c.id,version:active?'2':'1',code,treasury_name:'Confirmed synthetic cash location',treasury_type:'CASH',reason:'Synthetic isolated baseline setup'};}
async function snapshot(ids){return JSON.stringify(await q(`select c.id,to_jsonb(c) company,(select jsonb_agg(to_jsonb(a) order by a.id) from public.accounts a where a.company_id=c.id) accounts,(select jsonb_agg(to_jsonb(j) order by j.id) from public.journal_entries j where j.company_id=c.id) journals,(select jsonb_agg(to_jsonb(l) order by l.id) from public.journal_lines l where l.company_id=c.id) lines,(select jsonb_agg(to_jsonb(m) order by m.id) from public.company_memberships m where m.company_id=c.id) memberships from public.companies c where c.id=any($1) order by c.id`,[ids]));}
try{
 check(files.at(-1)==='20261101120000_company_accounting_provisioning.sql'&&files.length===63,'63 forward migrations replay');
 for(const [role,uid] of Object.entries(users)){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,`${role}@example.invalid`]);await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[sessions[role],uid]);}
 await db.query('insert into private.system_administrators(user_id) values($1)',[users.owner]);
 await db.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[users.owner]);
 await db.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1) where user_id=$1',[users.owner]);
 // Preserve 17 historical synthetic Companies including immutable posted ledger rows.
 const historical=[];
 for(let i=0;i<17;i++){
  const cid=randomUUID(),a=randomUUID(),b=randomUUID(),j=randomUUID();historical.push(cid);
  await db.query('insert into public.companies(id,code,name) values($1,$2,$2)',[cid,`HISTORY-${i}`]);
  await db.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[cid,users.admin]);
  await db.query("insert into public.accounts(id,company_id,code,name,account_type) values($1,$3,'A','Historical asset','ASSET'),($2,$3,'E','Historical expense','EXPENSE')",[a,b,cid]);
  await db.exec('begin');
  await db.query("insert into public.journal_entries(id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose) values($1,$2,'HIST-1',current_date,'Synthetic immutable history','TEST',$3,'POST')",[j,cid,randomUUID()]);
  await db.query('insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,debit_minor,credit_minor) values($1,$2,1,$3,12345,0),($1,$2,2,$4,0,12345)',[cid,j,b,a]);await db.exec('commit');
 }
 const before=await snapshot(historical);
 const input=await company(),key=randomUUID();
 check((await as('admin','select public.get_company_accounting_setup($1) r',[input.id]))[0].r.accounting_setup==='INCOMPLETE','activation remains setup-pending');
 for(const [role,companyRole] of [['accountant','ACCOUNTANT'],['viewer','MANAGEMENT_VIEWER'],['system','SYSTEM_ADMIN']]) await db.query('insert into public.company_memberships(company_id,user_id,role) values($1,$2,$3)',[input.id,users[role],companyRole]);
 for(const role of ['admin','accountant','viewer','foreign','system'])await reject(()=>provision(input,randomUUID(),role),'42501',`${role} cannot provision`);
 await reject(()=>provision(input,key,'owner',{aal:'aal1'}),'42501','AAL1 denied');
 await reject(()=>provision(input,key,'owner',{session_id:randomUUID()}),'42501','revoked session denied');
 await reject(()=>provision(input,key,'owner',{amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)-601}]}),'42501','stale MFA denied');
 await reject(()=>provision({...input,code:'OTHER'}),'42501','Company code cannot redirect');
 await reject(()=>provision({...input,version:'1'}),'40001','stale setup version denied');
 await reject(()=>provision({...input,system_key:'OWNER_CURRENT'}),'22023','caller cannot choose account mappings');
 await reject(()=>provision({...input,treasury_type:'BANK'}),'22023','Bank requires real bank name');
 await reject(()=>provision({...input,bank_name:'Unexpected'}),'22023','Cash rejects bank metadata');
 await reject(async()=>provision(await company(false)),'42501','Draft rejected');
 const partial=await company();await db.query("insert into public.accounts(company_id,code,name,account_type) values($1,'PREEXISTING','Keep intact','ASSET')",[partial.id]);
 await reject(()=>provision(partial),'23514','partial/existing chart rejected');
 check((await q('select count(*)::int n from public.accounts where company_id=$1',[partial.id]))[0].n===1,'partial chart untouched');
 const legacy={...input,id:historical[0],code:'HISTORY-0',version:'0'};
 await reject(()=>provision(legacy),'22023','legacy cannot be adopted through setup');
 const adoptedId=randomUUID();await db.query("insert into public.companies(id,code,name) values($1,'ADOPTED-LEGACY','Existing legacy company')",[adoptedId]);
 await db.query("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[adoptedId,users.admin]);
 await cmd('set_lifecycle',{id:adoptedId,version:'0',state:'SUSPENDED',reason:'Synthetic administrative adoption'});
 await cmd('set_lifecycle',{id:adoptedId,version:'2',state:'ACTIVE',reason:'Synthetic reactivation'});
 check((await as('admin','select public.get_company_accounting_setup($1) r',[adoptedId]))[0].r.accounting_setup==='UNASSESSED','legacy administrative adoption does not mislabel existing workspace as a new pending setup');
 await reject(()=>provision({...input,id:adoptedId,code:'ADOPTED-LEGACY',version:'3'}),'23514','adopting legacy administrative metadata does not authorize accounting provisioning');
 // A late failure must roll back all eleven prior account inserts and its receipt/audit.
 await db.exec("create function public.synthetic_reject_treasury() returns trigger language plpgsql as $$begin raise exception 'Synthetic late failure' using errcode='23514';end$$; create trigger synthetic_reject before insert on public.treasury_accounts for each row execute function public.synthetic_reject_treasury();");
 await reject(()=>provision(input,key),'23514','late failure atomic');
 check((await q('select count(*)::int n from public.accounts where company_id=$1',[input.id]))[0].n===0,'late failure leaves no accounts');
 check((await q('select count(*)::int n from private.platform_requests where request_id=$1',[key]))[0].n===0,'failed request receipt rolls back');
 await db.exec('drop trigger synthetic_reject on public.treasury_accounts;drop function public.synthetic_reject_treasury()');
 const receipt=await provision(input,key);check(receipt.id===input.id&&receipt.command==='provision_accounting','fresh setup succeeds');
 const accounts=await q('select * from public.accounts where company_id=$1 order by code',[input.id]);
 check(accounts.length===11&&accounts.filter(a=>a.system_key).length===10,'11 accounts / ten canonical keys');
 check(accounts.filter(a=>a.system_key).every(a=>systemAccountTypes[a.system_key]===a.account_type)&&Object.keys(systemAccountTypes).every(k=>accounts.some(a=>a.system_key===k)),'every mapping matches the existing approved GL provisioning infrastructure');
 check(accounts.every(a=>a.created_by===users.owner&&a.status==='ACTIVE'),'derived actor provenance');
 check(!accounts.some(a=>a.system_key==='OWNER_CURRENT'),'undefined owner policy never invented');
 const treasury=(await q('select * from public.treasury_accounts where company_id=$1',[input.id]))[0];
 check(treasury.name===input.treasury_name&&treasury.type==='CASH'&&treasury.gl_account_id===accounts[0].id,'real named Treasury maps to ordinary Asset');
 check((await as('admin','select public.get_company_accounting_setup($1) r',[input.id]))[0].r.accounting_setup==='COMPLETE','Company-scoped setup complete');
 check((await as('owner','select public.list_platform_entities(0,25,$1) r',[input.code]))[0].r.items[0].accounting_setup==='COMPLETE','owner directory reflects setup complete');
 const foundation=await snapshot([input.id]);
 check(JSON.stringify(await provision({...input,reason:` ${input.reason} `},key))===JSON.stringify(receipt),'normalized same-key retry returns same receipt');
 await provision({...input,version:'3'},randomUUID());check(await snapshot([input.id])===foundation,'new-key equivalent retry makes no accounts/Treasury/Company changes');
 await reject(()=>provision({...input,treasury_name:'Different location'},key),'22023','same-key mismatched intent rejected');
 await reject(()=>provision({...input,treasury_name:'Different location'}),'22023','new-key takeover rejected');
 check((await q("select count(*)::int n from private.platform_events where target_id=$1 and action='provision_accounting'",[input.id]))[0].n===1,'one provisioning audit event');
 check((await q('select count(*)::int n from public.treasury_accounts where company_id=$1',[input.id]))[0].n===1,'retries create one Treasury');
 check((await q('select count(*)::int n from private.reference_counters where company_id=$1',[input.id]))[0].n===0,'no fiscal/reference rows fabricated');
 check((await q('select count(*)::int n from public.journal_entries where company_id=$1',[input.id]))[0].n===0,'no financial transactions created by provisioning');
 const bankInput={...await company(),treasury_type:'BANK',bank_name:'Verified synthetic bank'};await provision(bankInput);
 check((await q('select bank_name from public.treasury_accounts where company_id=$1',[bankInput.id]))[0].bank_name===bankInput.bank_name,'Bank branch provisions');
 await reject(()=>as('foreign','select public.get_company_accounting_setup($1)',[input.id]),'42501','cross-company status denied');
 check((await as('foreign','select count(*)::int n from public.accounts where company_id=$1',[input.id]))[0].n===0,'cross-company chart hidden by existing RLS');
 check((await as('owner','select count(*)::int n from public.accounts where company_id=$1',[input.id]))[0].n===0,'platform owner acquires no financial read access');
 check((await as('admin','select count(*)::int n from public.accounts where company_id=$1',[input.id]))[0].n===11,'actual tenant admin can use chart');
 await reject(()=>as('admin',"insert into public.accounts(company_id,code,name,account_type) values($1,'BYPASS','Denied','ASSET')",[input.id]),'42501','arbitrary GL insertion remains denied');
 for(const role of ['anon','service_role'])check((await q('select has_function_privilege($1,$2,\'execute\') allowed',[role,'public.provision_company_accounting(uuid,jsonb)']))[0].allowed===false,`${role} RPC grant denied`);
 await reject(()=>as('admin','select * from private.company_accounting_provisions'),'42501','private provisioning records inaccessible');
 // Prove the foundation feeds the existing posting engine, using only new local synthetic masters.
 const supplier=randomUUID(),category=randomUUID();
 await db.query("insert into public.parties(id,company_id,type,name) values($1,$2,'SUPPLIER','Local synthetic supplier')",[supplier,bankInput.id]);
 await db.query("insert into public.expense_categories(id,company_id,code,name) values($1,$2,'LOCAL-ONLY','Local synthetic expense')",[category,bankInput.id]);
 const posted=(await as('admin',"select * from public.post_expense($1,current_date,null,$2,'Provisioning integration proof',10000,'ZERO',null,'SUPPLIER_CREDIT',null,null,$3,'OTHER',false,null,null,$4)",[bankInput.id,category,supplier,randomUUID()]))[0];
 check(!!posted.expense_id&&!posted.replayed,'authorized tenant admin posts through unchanged expense engine after local provisioning');
 check((await q('select count(*)=2 and sum(debit_minor-credit_minor)=0 balanced from public.journal_lines where journal_entry_id=$1',[posted.journal_entry_id]))[0].balanced,'existing engine creates balanced two-line journal');
 check((await q("select count(*)=2 valid from public.journal_lines l join public.accounts a on a.id=l.account_id where l.journal_entry_id=$1 and a.company_id=$2 and a.system_key in ('COMPANY_EXPENSE','SUPPLIER_PAYABLE')",[posted.journal_entry_id,bankInput.id]))[0].valid,'posting resolves provisioned stable keys within exact Company');
 await cmd('set_lifecycle',{id:input.id,version:'3',state:'SUSPENDED',reason:'Synthetic suspension'});
 await reject(()=>provision(input,key),'42501','receipt recovery cannot bypass suspended Company');
 await reject(()=>as('admin','select public.get_company_accounting_setup($1)',[input.id]),'42501','suspended Company status denied');
 check(await snapshot(historical)===before,'all 17 historical Companies/accounts/memberships/posted journals/lines byte-for-byte preserved');
 console.log(`PASS: ${checks} focused accounting-provisioning checks; ${files.length} migrations; synthetic local PostgreSQL only.`);
}finally{await db.close();}
