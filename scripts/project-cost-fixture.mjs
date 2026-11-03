// Synthetic local database only; no hosted URL/configuration accepted.
import{platformTestDatabase}from'./verify-platform-database.mjs';
export const costId=n=>`e5000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
export async function projectCostFixture(database){
 const{db}=await platformTestDatabase(database,{through:'20261101130000'}),id=costId,company=id(10),foreignCompany=id(11),admin=id(1),viewer=id(2),foreign=id(3),accountant=id(4),manager=id(5),project=id(20),project2=id(21),cash=id(30),cost=id(31),overhead=id(32),payable=id(33),wip=id(34),treasury=id(35),category=id(36);
 for(const uid of[admin,viewer,foreign,accountant,manager])await db.query('insert into auth.users(id,email) values($1,$2)',[uid,uid+'@example.invalid']);
 for(const cid of[company,foreignCompany])await db.query("insert into public.companies(id,code,name) values($1,$2,'Synthetic cost Company')",[cid,cid]);
 for(const[uid,cid,role]of[[admin,company,'ACCOUNTING_ADMIN'],[viewer,company,'MANAGEMENT_VIEWER'],[accountant,company,'ACCOUNTANT'],[manager,company,'PROJECT_MANAGER'],[foreign,foreignCompany,'ACCOUNTING_ADMIN']])await db.query('insert into public.company_memberships(company_id,user_id,role) values($1,$2,$3)',[cid,uid,role]);
 for(const[pid,code]of[[project,'P-ONE'],[project2,'P-TWO']])await db.query("insert into public.projects(id,company_id,code,name,status) values($1,$2,$3,$3,'ACTIVE')",[pid,company,code]);
 for(const[aid,code,type,key]of[[cash,'CASH','ASSET',null],[cost,'PROJECT-COST','EXPENSE','PROJECT_COST'],[overhead,'COMPANY-COST','EXPENSE','COMPANY_EXPENSE'],[payable,'AP','LIABILITY',null],[wip,'WIP','ASSET',null]])await db.query('insert into public.accounts(id,company_id,code,name,account_type,system_key) values($1,$2,$3,$3,$4,$5)',[aid,company,code,type,key]);
 await db.query("insert into public.treasury_accounts(id,company_id,code,name,type,gl_account_id) values($1,$2,'CASH','Synthetic cash','CASH',$3)",[treasury,company,cash]);await db.query("insert into public.expense_categories(id,company_id,code,name) values($1,$2,'COST','Synthetic category')",[category,company]);
 const as=(actor,sql,args=[])=>db.transaction(async t=>{await t.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor})]);await t.exec('set local role authenticated');return(await t.query(sql,args)).rows});
 const posted=(await as(admin,"select * from public.post_expense($1,'2026-09-10',$2,$3,'Synthetic posted project expense',10000,'ZERO',null,'TREASURY',$4,null,null,'CASH',false,null,null,$5)",[company,project,category,treasury,id(40)]))[0];
 await as(admin,"select * from public.reverse_expense($1,$2,'2026-10-05','Synthetic correction reversal',$3)",[company,posted.expense_id,id(41)]);
 const journal=async(n,date,type,projectId,debitAccount,creditAccount,amount)=>db.transaction(async t=>{await t.query('insert into public.journal_entries(id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose) values($1,$2,$3,$4,$3,$5,$6,\'POST\')',[id(n),company,'SYN-J'+n,date,type,id(n+100)]);await t.query('insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,project_id,debit_minor,credit_minor) values($1,$2,1,$3,$5,$6,0),($1,$2,2,$4,$5,0,$6)',[company,id(n),debitAccount,creditAccount,projectId,amount]);});
 await journal(50,'2026-09-20','PAYROLL',project,cost,payable,'20000');
 await journal(51,'2026-09-21','SUPPLIER_PAYMENT',project,payable,cash,'10000');
 await journal(52,'2026-09-22','ASSET_ACQUISITION',project,wip,cash,'30000');
 await journal(53,'2026-09-23','COMPANY_RENT',null,overhead,cash,'5000');
 await journal(54,'2026-09-24','PROJECT_ADJUSTMENT',project2,cost,payable,'7000');
 await db.query("update public.projects set status='CLOSED' where id=$1",[project]);
 const allowed=new Set(['projects','accounts','journal_entries','journal_lines','expenses','subcontractor_certificates','expense_correction_reviews']);
 async function read(actor,table,columns,filters=[],limit=500){
  if(!allowed.has(table)||!filters.some(([op,k,v])=>op==='eq'&&k==='company_id'&&v===company))throw Error('Unscoped fixture query');
  const values=[],clauses=[];for(const[op,key,value]of filters){if(!['company_id','id','posting_date','journal_entry_id','expense_id'].includes(key))throw Error('Fixture filter');if(op==='in'){if(!Array.isArray(value))throw Error('Fixture list');const placeholders=value.map(v=>{values.push(v);return '$'+values.length;});clauses.push(key+' in ('+placeholders.join(',')+')');}else{const operator={eq:'=',gt:'>',gte:'>=',lte:'<='}[op];if(!operator)throw Error('Fixture operator');values.push(value);clauses.push(key+operator+'$'+values.length);}}
  if(!(columns==='*'&&table==='expense_correction_reviews')&&!/^[a-z_,:]+$/.test(columns))throw Error('Fixture projection');
  const sqlColumns=columns.split(',').map(c=>c==='posting_date'?'posting_date::text':c).join(',');
  return as(actor,'select '+sqlColumns+' from public.'+table+' where '+clauses.join(' and ')+' order by id limit '+Math.min(limit,500),values);
 }
 function client(actor=admin){return {from(table){let columns='',limit=500;const filters=[];const q={select(c){columns=c;return q},eq(k,v){filters.push(['eq',k,v]);return q},gte(k,v){filters.push(['gte',k,v]);return q},lte(k,v){filters.push(['lte',k,v]);return q},gt(k,v){filters.push(['gt',k,v]);return q},in(k,v){filters.push(['in',k,v]);return q},order(){return q},limit(n){limit=n;return q},then(done){return read(actor,table,columns,filters,limit).then(data=>({data,error:null}),e=>({data:null,error:{code:e.code??'FIXTURE'}})).then(done)}};return q}};}
 return {db,id,admin,viewer,foreign,accountant,manager,company,foreignCompany,project,project2,cost,cash,overhead,as,read,client,posted};
}
