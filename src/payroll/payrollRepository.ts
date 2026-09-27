import type { SupabaseClient } from '@supabase/supabase-js';
import type { Database } from '../types/database.generated';
export interface PayrollProfile {
 id:string; company_id:string; employee_id:string; employee_name:string; employee_status:string; payroll_id:string; payroll_type:string;
 profession:string; work_station:string; default_project_id:string|null; monthly_salary_minor:string; payment_type:string; status:'ACTIVE'|'INACTIVE'; version:number;
}
export interface PayrollProfiles { profiles:PayrollProfile[]; employees:{id:string;name:string}[]; projects:{id:string;name:string}[] }
export interface PayrollRow {
 id:string; company_id:string; employee_id:string; included:boolean; employee_name:string; payroll_id:string; payroll_type:string; profession:string;
 work_station:string; default_project_id:string|null; payment_type:string; monthly_salary_minor:string; calendar_days:number; absence_half_units:number;
 absence_deduction_minor:string; additions_minor:string; deductions_minor:string; gross_salary_minor:string; net_salary_minor:string;
}
export interface PayrollAdjustment {
 id:string; company_id:string; row_id:string; kind:'ADDITION'|'DEDUCTION'; amount_minor:string; reason:string; voided:boolean; version:number;
 change_reason:string|null; created_by:string; created_at:string; updated_by:string; updated_at:string;
}
export interface PayrollDraft {
 attendance_review_valid:boolean; stale:boolean; review_valid:boolean;
 period:{id:string;company_id:string;month:string;state:'DRAFT';version:number;calendar_days:number;reviewed_by:string|null;reviewed_at:string|null}|null;
 rows:PayrollRow[]; adjustments:PayrollAdjustment[];
}
const max=9000000000000000n;
export const payrollAllowed=(role:string)=>role==='ACCOUNTANT'||role==='ACCOUNTING_ADMIN';
export function exactMinor(value:unknown):string {
 if(typeof value!=='string'||!/^\d+$/.test(value)||BigInt(value)>max)throw new Error('Invalid exact payroll money');return value;
}
export function parsePayrollMoney(text:string):string {
 const v=text.trim();if(!/^\d+(\.\d{1,2})?$/.test(v))throw new Error('Enter an exact amount');
 const [whole,fraction='']=v.split('.');return exactMinor((BigInt(whole)*100n+BigInt(fraction.padEnd(2,'0'))).toString());
}
export function displayPayrollMoney(value:string):string {const n=BigInt(exactMinor(value));return `${n/100n}.${(n%100n).toString().padStart(2,'0')}`;}
// Display only. No deduction/net calculation is performed in the browser.
export function displayDailySalary(salary:string,days:number):string {
 if(!Number.isInteger(days)||days<28||days>31)throw new Error('Invalid calendar days');
 const divisor=BigInt(days);const amount=BigInt(exactMinor(salary));
 return displayPayrollMoney(((amount*2n+divisor)/(2n*divisor)).toString());
}
export function decodeProfiles(data:unknown,company:string):PayrollProfiles {
 const value=data as PayrollProfiles;
 if(!value||!Array.isArray(value.profiles)||!Array.isArray(value.employees)||!Array.isArray(value.projects))throw new Error('Payroll unavailable');
 for(const row of value.profiles){if(row.company_id!==company)throw new Error('Payroll scope changed');exactMinor(row.monthly_salary_minor);}
 return value;
}
export function decodeDraft(data:unknown,company:string):PayrollDraft {
 const value=data as PayrollDraft;
 if(!value||!Array.isArray(value.rows)||!Array.isArray(value.adjustments)||typeof value.stale!=='boolean'||typeof value.attendance_review_valid!=='boolean')throw new Error('Payroll unavailable');
 if(value.period&&(value.period.company_id!==company||value.period.state!=='DRAFT'))throw new Error('Invalid draft scope');
 for(const row of value.rows){
  if(row.company_id!==company||!Number.isInteger(row.calendar_days)||row.calendar_days<28||row.calendar_days>31||!Number.isInteger(row.absence_half_units)||row.absence_half_units<0||row.absence_half_units>2*row.calendar_days)throw new Error('Invalid draft row');
  for(const key of ['monthly_salary_minor','absence_deduction_minor','additions_minor','deductions_minor','gross_salary_minor','net_salary_minor'] as const)exactMinor(row[key]);
 }
 for(const a of value.adjustments){if(a.company_id!==company)throw new Error('Invalid adjustment scope');exactMinor(a.amount_minor);}
 return value;
}
type PayrollRPC='read_payroll_profiles'|'read_payroll_draft'|'save_payroll_profile'|'refresh_payroll_draft'|'save_payroll_draft_adjustment'|'review_payroll_draft';
type Args<T>={[K in keyof T]:K extends 'target_salary_minor'|'target_amount_minor'?string:K extends 'target_project_id'|'target_change_reason'?T[K]|null:T[K]};
export async function payrollRequest<N extends PayrollRPC>(client:SupabaseClient<Database>,userId:string,name:N,args:Args<Database['public']['Functions'][N]['Args']>,current:()=>boolean=()=>true){
 const before=await client.auth.getSession();
 if(!current()||before.error||before.data.session?.user.id!==userId)throw new Error('Payroll session changed');
 const {data,error}=await client.rpc(name,args as Database['public']['Functions'][N]['Args']);
 if(error)throw new Error(error.code==='40001'?'STALE':error.code==='23514'?'POLICY':'REQUEST');
 const after=await client.auth.getSession();
 if(!current()||after.error||after.data.session?.user.id!==userId)throw new Error('Payroll session changed');return data;
}
