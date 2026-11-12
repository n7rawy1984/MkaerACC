import type {SupabaseClient} from '@supabase/supabase-js';
import {readCompanyRows,readPostedLedger,type LedgerEntry,type LedgerLine} from '../reports/postedLedgerRead';
export type MonthlyAccount={id:string;company_id:string;code:string;name:string;system_key:string|null;account_type:string};
export type MonthlyParty={id:string;company_id:string;name:string;type:string};
export type MonthlyProject={id:string;company_id:string;name:string;code:string};
export type MonthlyTreasury={id:string;company_id:string;gl_account_id:string;type:string;code:string};
export type StockMovement={id:string;company_id:string;event_id:string;location_id:string;material_id:string;movement_date:string;quantity_micros:string;value_minor:string};
export type PayrollPeriod={id:string;company_id:string;month:string;posting_date:string;journal_id:string};
export type MonthlyFinancialData={company:string;entries:LedgerEntry[];lines:LedgerLine[];accounts:MonthlyAccount[];parties:MonthlyParty[];projects:MonthlyProject[];treasuries:MonthlyTreasury[];stock:StockMovement[];locations:{id:string;company_id:string;project_id:string|null}[];payroll:PayrollPeriod[];payrollVisible:boolean;custodyComplete:boolean;inventoryAccount:string|null;captured:string};
export async function readMonthlyFinancials(client:SupabaseClient,user:string,company:string,current:()=>boolean):Promise<MonthlyFinancialData>{
 const session=async()=>{const s=await client.auth.getSession();if(!current()||s.error||s.data.session?.user.id!==user)throw Error('Monthly report session changed');};
 await session();const roles=await Promise.all(['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].map(required_role=>client.rpc('has_company_role',{target_company_id:company,required_role})));
 if(!current()||roles.some(r=>r.error||typeof r.data!=='boolean')||!roles.some(r=>r.data===true))throw Error('Monthly financial reporting denied');
 const permission=await client.rpc('has_permission',{target_company_id:company,required_permission:'payroll.manage'});if(!current()||permission.error||typeof permission.data!=='boolean')throw Error('Payroll visibility could not be verified');
 const payrollVisible=permission.data===true,read=<T extends{id:string;company_id:string}>(table:string,columns:string)=>readCompanyRows<T>(client,company,table,columns,current);
 const [ledger,accounts,parties,projects,treasuries,stock,locations,payroll]=await Promise.all([
 readPostedLedger(client,company,current),read<MonthlyAccount>('accounts','id,company_id,code,name,system_key,account_type'),read<MonthlyParty>('parties','id,company_id,name,type'),read<MonthlyProject>('projects','id,company_id,code,name'),read<MonthlyTreasury>('treasury_accounts','id,company_id,gl_account_id,type,code'),
 read<StockMovement>('inventory_movements','id,company_id,event_id,location_id,material_id,movement_date,quantity_micros::text,value_minor::text'),read<{id:string;company_id:string;project_id:string|null}>('inventory_locations','id,company_id,project_id'),payrollVisible?read<PayrollPeriod>('payroll_postings','id,company_id,month,posting_date,journal_id'):Promise.resolve([])]);
 const personRoles=await readCompanyRows<{id:string;company_id:string;role:string}>(client,company,'party_person_roles','id:party_id,company_id,role',current,'party_id');
 const config=await client.from('inventory_configuration').select('company_id,inventory_account_id').eq('company_id',company);
 if(!current()||config.error||!config.data||config.data.length>1||config.data.some(r=>r.company_id!==company))throw Error('Stock configuration could not be verified');
 const inventoryAccount=config.data[0]?.inventory_account_id??null;
 // Roles can be EMPLOYEE + CUSTODIAN. Check every holder observed in the actual
 // control ledger; HR RLS stays intact and hidden movements never imply zero.
 const custodyIds=new Set(accounts.filter(a=>a.system_key==='CUSTODY_ADVANCE').map(a=>a.id));
 const holders=new Set(ledger.lines.filter(l=>custodyIds.has(l.account_id)&&l.party_id).map(l=>l.party_id!));
 for(const r of personRoles)if(r.role==='CUSTODIAN')holders.add(r.id);
 for(const p of parties)if(p.type==='CUSTODIAN')holders.add(p.id);
 const coverage=await Promise.all([...holders].map(holder=>client.rpc('custody_reporting_complete',{cid:company,holder})));
 if(!current()||coverage.some(r=>r.error||typeof r.data!=='boolean'))throw Error('Custody completeness could not be verified');
 await session();const finalRoles=await Promise.all(['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].map(required_role=>client.rpc('has_company_role',{target_company_id:company,required_role})));if(!current()||finalRoles.some(r=>r.error)||!finalRoles.some(r=>r.data===true))throw Error('Reporting access changed');
 const last=await readCompanyRows<LedgerEntry>(client,company,'journal_entries','id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose,reversal_of_journal_entry_id',current);if(JSON.stringify(last)!==JSON.stringify(ledger.entries))throw Error('Accounting changed; refresh');
 return{company,...ledger,accounts,parties,projects,treasuries,stock,locations,payroll,payrollVisible,inventoryAccount,custodyComplete:coverage.every(r=>r.data===true),captured:new Date().toISOString()};
}
