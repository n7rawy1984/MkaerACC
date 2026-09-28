import {getSupabaseClient} from '../lib/supabase';
import {payrollAllowed,payrollRequest} from './payrollRepository';
import {postingRequest} from './payrollPostingRepository';
import {makeRegister,type RegisterContext,type RegisterSource} from './payrollRegister';
export async function readPayrollRegister(context:RegisterContext,source:RegisterSource,locale:'en'|'ar',current:()=>boolean){
 if(!payrollAllowed(context.role)||!current())throw Error('Denied');
 const args={target_company_id:context.companyId,target_month:context.month};
 const data=source.kind==='DRAFT'
  ?await payrollRequest(getSupabaseClient(),context.userId,'read_payroll_draft',args,current)
  :await postingRequest(context.userId,'read_payroll_postings',args,current);
 if(!current())throw Error('Scope changed');
 return makeRegister(data,context,source,locale);
}
