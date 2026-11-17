import type{SupabaseClient}from'@supabase/supabase-js';
import{validFinancialDate}from'../historical/sourceDatePresentation';
export type AccountingPeriod={id:string;company_id:string;year_id:string;label:string;from_date:string;through_date:string;state:'OPEN'|'CLOSED';version:number};
export type FiscalYear={id:string;company_id:string;label:string;from_date:string;through_date:string};
export type PeriodRead={company:string;configured:boolean;years:FiscalYear[];periods:AccountingPeriod[]};
export type PeriodRequest={cid:string;request_id:string;action:'CREATE_YEAR'|'CLOSE'|'REOPEN';input:Record<string,unknown>};
export function fiscalYearInput(label:string,from:string,through:string,reason:string){
 if(!validFinancialDate(from)||!validFinancialDate(through)||from>through||!label.trim()||reason.trim().length<5)throw Error('invalid');
 const days=(Date.parse(through+'T00:00:00Z')-Date.parse(from+'T00:00:00Z'))/86400000;if(days>371)throw Error('invalid');
 const periods:{label:string;from:string;through:string}[]=[];let cursor=from;
 while(cursor<=through){const monthEnd=new Date(cursor+'T00:00:00Z');monthEnd.setUTCMonth(monthEnd.getUTCMonth()+1,0);const end=monthEnd.toISOString().slice(0,10);const last=end<through?end:through;periods.push({label:cursor.slice(0,7),from:cursor,through:last});if(last===through)break;cursor=new Date(Date.parse(last+'T00:00:00Z')+86400000).toISOString().slice(0,10);}
 return{label:label.trim(),from,through,periods,reason:reason.trim()};
}
export async function readAccountingPeriods(client:SupabaseClient,cid:string,user:string,valid:()=>boolean=()=>true):Promise<PeriodRead>{
 const before=await client.auth.getSession();if(!valid()||before.error||before.data.session?.user.id!==user)throw Error('session');
 const{data,error}=await client.rpc('read_accounting_periods',{cid});
 if(!valid())throw Error('session');if(error)throw Error('unavailable');
 const r=data as PeriodRead;if(!r||r.company!==cid||typeof r.configured!=='boolean'||!Array.isArray(r.years)||!Array.isArray(r.periods)||r.years.some(y=>y.company_id!==cid||!validFinancialDate(y.from_date)||!validFinancialDate(y.through_date))||r.periods.some(p=>p.company_id!==cid||!r.years.some(y=>y.id===p.year_id)||!['OPEN','CLOSED'].includes(p.state)||!Number.isSafeInteger(p.version)||p.version<1||!validFinancialDate(p.from_date)||!validFinancialDate(p.through_date)))throw Error('integrity');
 const after=await client.auth.getSession();if(!valid()||after.error||after.data.session?.user.id!==user)throw Error('session');return r;
}
export async function sendPeriodRequest(client:SupabaseClient,request:PeriodRequest,user:string,valid:()=>boolean=()=>true){
 const before=await client.auth.getSession();if(!valid()||before.error||before.data.session?.user.id!==user)throw Error('session');
 const{data,error}=await client.rpc('command_accounting_period',request);
 if(!valid())throw Error('session');
 if(error){const code=String(error.code??'');throw Error(/^(22|23|40001|42501|PGRST202)/.test(code)?'rejected':'uncertain');}
 const after=await client.auth.getSession();if(!valid()||after.error||after.data.session?.user.id!==user)throw Error('session');if(!data||data.company!==request.cid)throw Error('uncertain');return data;
}
