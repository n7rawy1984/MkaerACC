import{formatFinancialDate}from'../historical/sourceDatePresentation';
import type {SupabaseClient} from '@supabase/supabase-js';
export type CorrectionMovement={journal_id:string;phase:'REVERSAL'|'REPLACEMENT';actual_new_payment:false;correction_id:string|null;source_id:string|null;original_payment_date:string|null;original_payment_journal:string|null;restricted:boolean};
const uuid=/^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export async function readCorrectionMovements(client:SupabaseClient,company:string,journals:string[],valid:()=>boolean=()=>true):Promise<CorrectionMovement[]>{
 const ids=[...new Set(journals)].sort(),result:CorrectionMovement[]=[];
 for(let i=0;i<ids.length;i+=500){
  const chunk=ids.slice(i,i+500);if(!valid())throw Error('session');
  const{data,error}=await client.rpc('read_operational_correction_movements',{cid:company,journal_ids:chunk});
  if(!valid())throw Error('session');if(error||!Array.isArray(data))throw Error('correction-read');
  for(const r of data){
   if(!r||!chunk.includes(r.journal_id)||!['REVERSAL','REPLACEMENT'].includes(r.phase)||r.actual_new_payment!==false||typeof r.restricted!=='boolean'||result.some(x=>x.journal_id===r.journal_id)
    ||['correction_id','source_id','original_payment_journal'].some(k=>r[k]!==null&&(typeof r[k]!=='string'||!uuid.test(r[k])))||r.original_payment_date!==null&&!/^\d{4}-\d{2}-\d{2}$/.test(r.original_payment_date)
    ||r.restricted&&['correction_id','source_id','original_payment_date','original_payment_journal'].some(k=>r[k]!==null))throw Error('integrity');
   result.push(r as CorrectionMovement);
  }
 }
 return result;
}
export function correctionMovementLabel(row:CorrectionMovement,ar:boolean){return (ar?'تصحيح محاسبي — دون دفعة أو رد نقدي جديد':'Accounting correction — no new payment or cash return')+(row.original_payment_date?' · '+(ar?'الدفع الأصلي: ':'Original payment: ')+formatFinancialDate(row.original_payment_date,ar?'ar':'en'):'');}
