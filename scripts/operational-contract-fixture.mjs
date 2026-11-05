import {openingReconciliationFixture} from './opening-reconciliation-fixture.mjs';
import {readFileSync} from 'node:fs';
export async function operationalContractFixture(){
 const f=await openingReconciliationFixture();await f.db.exec(readFileSync('supabase/migrations/20261105100000_operational_subcontract_measurements.sql','utf8'));
 const tables=new Set(['subcontract_certificate_withdrawals','subcontract_term_events','subcontract_measurements','subcontract_operating_summary','subcontractor_certificates','subcontractor_payments','subcontractor_retention_payments']);
 const commands=new Set(['create_operational_subcontract','amend_operational_subcontract','prepare_measured_certificate','withdraw_subcontract_certificate']);
 const quote=k=>{if(!/^[a-z_]+$/.test(k))throw Error('Identifier');return '"'+k+'"';};
 async function read(actor,table,columns,filters=[],limit=500){
  if(!tables.has(table))return f.read(actor,table,columns,filters,limit);
  if(!filters.some(([op,k,v])=>op==='eq'&&k==='company_id'&&v===f.company))throw Error('Unscoped fixture');
  const args=[],where=filters.map(([op,k,v])=>{args.push(v);return quote(k)+({eq:'=',gt:'>'}[op]??(()=>{throw Error('Filter')})())+'$'+args.length;});
  return f.as(actor,'select '+(columns==='*'?'*':columns.split(',').map(x=>quote(x.replace(/::text$/,''))+(x.endsWith('::text')?'::text':'')).join(','))+' from public.'+quote(table)+' where '+where.join(' and ')+' order by id limit '+Math.min(limit,500),args);
 }
 async function rpc(actor,name,args){if(!commands.has(name))return f.rpc(actor,name,args);const keys=Object.keys(args);return(await f.as(actor,'select public.'+quote(name)+'('+keys.map((k,n)=>quote(k)+'=> $'+(n+1)).join(',')+') r',keys.map(k=>args[k])))[0].r;}
 return{...f,read,rpc};
}
