import {getSupabaseClient} from '../lib/supabase';
import {exactMinor} from './payrollRepository';
import type {Database} from '../types/database.generated';
type FunctionName='prepare_payroll_accounting'|'post_payroll'|'pay_salary'|'reverse_salary_payment'|'reverse_payroll'|'read_payroll_postings';
export interface Posting {id:string;company_id:string;month:string;reversed:boolean;created_at:string;replaces_id:string|null}
export interface Entitlement {id:string;company_id:string;payroll_id:string;employee_name:string;project_id:string|null;amount_minor:string;unpaid_minor:string}
export interface Payment {id:string;company_id:string;entitlement_id:string;amount_minor:string;payment_date:string;reference:string;reversed:boolean}
export interface State {accounting:{version:number}|null;postings:Posting[];entitlements:Entitlement[];payments:Payment[];treasuries:{id:string;name:string;project_id:string|null}[]}
export function decodePostings(value:unknown,company:string):State {
 const s=value as State;if(!s||!Array.isArray(s.postings)||!Array.isArray(s.entitlements)||!Array.isArray(s.payments)||!Array.isArray(s.treasuries))throw Error('Invalid payroll state');
 for(const row of [...s.postings,...s.entitlements,...s.payments])if(row.company_id!==company)throw Error('Payroll scope changed');
 for(const e of s.entitlements){exactMinor(e.amount_minor);exactMinor(e.unpaid_minor);}for(const p of s.payments)exactMinor(p.amount_minor);return s;
}
export async function postingRequest(user:string,name:FunctionName,args:Record<string,unknown>,current:()=>boolean){
 const client=getSupabaseClient();const before=await client.auth.getSession();if(!current()||before.error||before.data.session?.user.id!==user)throw Error('Session changed');
 // BIGINT inputs stay strings on the wire; generated SDK numeric declarations are not money conversion.
 const {data,error}=await client.rpc(name,args as Database['public']['Functions'][typeof name]['Args']);if(error)throw Error(/^(22|23|40|42501|P0001)/.test(error.code)?'REJECTED':'UNCERTAIN');
 const after=await client.auth.getSession();if(!current()||after.error||after.data.session?.user.id!==user)throw Error('Session changed');return data;
}
