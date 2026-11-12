import type {SupabaseClient} from '@supabase/supabase-js';
import {validFinancialDate} from '../historical/sourceDatePresentation';
export type LedgerEntry={id:string;company_id:string;journal_reference:string;posting_date:string;description:string;source_type:string;source_id:string;posting_purpose:string;reversal_of_journal_entry_id:string|null};
export type LedgerLine={id:string;company_id:string;journal_entry_id:string;line_number:number;account_id:string;debit_minor:string;credit_minor:string;project_id:string|null;treasury_account_id:string|null;party_id:string|null;subcontract_id:string|null};
export async function readCompanyRows<T extends{id:string;company_id:string}>(client:SupabaseClient,company:string,table:string,columns:string,valid:()=>boolean=()=>true,key='id'):Promise<T[]>{
 const rows:T[]=[];let cursor='';
 for(;;){if(!valid())throw Error('Report session changed');let q=client.from(table).select(columns).eq('company_id',company).order(key).limit(500);if(cursor)q=q.gt(key,cursor);
 const {data,error}=await q;if(!valid()||error||!data)throw Error('Report read failed');const batch=data as unknown as T[];
 if(batch.some((r,i)=>r.company_id!==company||r.id<=cursor||i>0&&r.id<=batch[i-1].id))throw Error('Report Company or paging changed');
 rows.push(...batch);if(!batch.length)return rows;cursor=batch.at(-1)!.id;}
}
export async function readPostedLedger(client:SupabaseClient,company:string,valid:()=>boolean=()=>true){
 const columns='id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose,reversal_of_journal_entry_id';
 const entries=await readCompanyRows<LedgerEntry>(client,company,'journal_entries',columns,valid);
 const lines=await readCompanyRows<LedgerLine>(client,company,'journal_lines','id,company_id,journal_entry_id,line_number,account_id,debit_minor::text,credit_minor::text,project_id,treasury_account_id,party_id,subcontract_id',valid);
 validatePostedLedger(company,entries,lines);
 const again=await readCompanyRows<LedgerEntry>(client,company,'journal_entries',columns,valid);
 if(JSON.stringify(entries)!==JSON.stringify(again))throw Error('Posted journals changed; refresh');
 return{entries,lines};
}
export function validatePostedLedger(company:string,entries:LedgerEntry[],lines:LedgerLine[]){
 const ids=new Set(entries.map(e=>e.id)),lineIds=new Set<string>(),sums=new Map<string,{d:bigint;c:bigint;sequence:Set<number>}>();
 if(ids.size!==entries.length||entries.some(e=>e.company_id!==company||!validFinancialDate(e.posting_date)||e.reversal_of_journal_entry_id&&!ids.has(e.reversal_of_journal_entry_id)))throw Error('Journal scope/date/reversal incomplete');
 for(const l of lines){if(l.company_id!==company||!ids.has(l.journal_entry_id)||lineIds.has(l.id)||!/^\d+$/.test(l.debit_minor)||!/^\d+$/.test(l.credit_minor)||!Number.isSafeInteger(l.line_number)||l.line_number<1)throw Error('Journal line incomplete');lineIds.add(l.id);const d=BigInt(l.debit_minor),c=BigInt(l.credit_minor);if(d>0n&&c>0n||d===0n&&c===0n)throw Error('Invalid journal line');const s=sums.get(l.journal_entry_id)??{d:0n,c:0n,sequence:new Set<number>()};if(s.sequence.has(l.line_number))throw Error('Duplicate journal sequence');s.sequence.add(l.line_number);s.d+=d;s.c+=c;sums.set(l.journal_entry_id,s);}
 if(entries.some(e=>!sums.has(e.id)||sums.get(e.id)!.sequence.size<2||sums.get(e.id)!.d!==sums.get(e.id)!.c))throw Error('Journal lines incomplete or unbalanced');
}
