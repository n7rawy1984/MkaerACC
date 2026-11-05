import {priorityFinancialFixture} from './priority-financial-fixture.mjs';
import {readFileSync} from 'node:fs';
export async function openingReconciliationFixture(){
 const f=await priorityFinancialFixture();await f.db.exec(readFileSync('supabase/migrations/20261105090000_certified_opening_cash_reconciliation.sql','utf8'));
 const tables=new Set(['opening_balance_drafts','opening_balance_postings','opening_balance_reversals','cash_reconciliation_register','cash_reconciliation_counts','cash_reconciliation_reviews','opening_loan_payments','opening_loan_payment_reversals','payroll_postings','salary_payments','payroll_reversals','salary_payment_reversals']);
 const commands=new Set(['prepare_certified_opening','approve_certified_opening','reverse_certified_opening','record_cash_reconciliation','review_cash_reconciliation','pay_opening_partner_loan','reverse_opening_loan_payment']);
 const quote=k=>{if(!/^[a-z_]+$/.test(k))throw Error('Identifier');return '"'+k+'"';};
 async function read(actor,table,columns,filters=[],limit=500){
  if(!tables.has(table))return f.read(actor,table,columns,filters,limit);
  if(!filters.some(([op,k,v])=>op==='eq'&&k==='company_id'&&v===f.company))throw Error('Unscoped fixture read');
  const params=[],where=filters.map(([op,k,v])=>{if(op==='in')return quote(k)+' in ('+v.map(x=>{params.push(x);return '$'+params.length;}).join(',')+')';const operator={eq:'=',gt:'>',gte:'>=',lte:'<='}[op];if(!operator)throw Error('Filter');params.push(v);return quote(k)+operator+'$'+params.length;});
  const cols=columns.split(',').map(c=>{const key=c.replace(/::text$/,'');return quote(key)+(/_date$|_month$|_minor$|^month$/.test(key)||c.endsWith('::text')?'::text as '+quote(key):'');});
  return f.as(actor,'select '+cols.join(',')+' from public.'+quote(table)+' where '+where.join(' and ')+' order by id limit '+Math.min(limit,500),params);
 }
 async function rpc(actor,name,args){if(!commands.has(name))return f.rpc(actor,name,args);const keys=Object.keys(args);return(await f.as(actor,'select public.'+quote(name)+'('+keys.map((k,n)=>quote(k)+'=> $'+(n+1)).join(',')+') r',keys.map(k=>args[k])))[0].r;}
 function client(actor=f.admin){const original=f.client(actor);return{...original,rpc:async(name,args)=>{try{return{data:await rpc(actor,name,args),error:null}}catch(e){return{data:null,error:{code:e.code??'FIXTURE',message:e.message}}}},from(table){if(!tables.has(table))return original.from(table);let columns='',limit=500;const filters=[],q={select(c){columns=c;return q},eq(k,v){filters.push(['eq',k,v]);return q},gt(k,v){filters.push(['gt',k,v]);return q},gte(k,v){filters.push(['gte',k,v]);return q},lte(k,v){filters.push(['lte',k,v]);return q},in(k,v){filters.push(['in',k,v]);return q},order(){return q},limit(n){limit=n;return q},then(done){return read(actor,table,columns,filters,limit).then(data=>({data,error:null}),e=>({data:null,error:{code:e.code??'FIXTURE',message:e.message}})).then(done)}};return q;}};}
 return{...f,read,rpc,client};
}
