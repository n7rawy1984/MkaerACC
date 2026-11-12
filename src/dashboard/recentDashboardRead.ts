import type {SupabaseClient} from '@supabase/supabase-js';
import {readDashboardPage,type DashboardRow} from './dashboardOverviewRead';
export type RecentTransaction=DashboardRow&{amount:string|null;funding:{accountId:string;partyId:string|null;direction:'IN'|'OUT'}[]|null};
type Line={id:string;company_id:string;journal_entry_id:string;account_id:string;party_id:string|null;debit_minor:string;credit_minor:string};
// Read only the five visible journals, never the ledger history. If an unusually
// large journal exceeds the display budget, withhold its enrichment rather than
// reporting a balanced but incomplete subset as a verified document amount.
export async function readRecentTransactions(client:SupabaseClient,user:string,company:string,month:string,fundingAccounts:string[],current:()=>boolean):Promise<RecentTransaction[]>{
 const result=await readDashboardPage(client,user,company,month,'ALL',{domain:'JOURNALS',page:0,pageSize:10,search:'',status:'POSTED',type:'',sort:'DESC',unknown:false},current);
 const rows=result.rows.slice(0,5),ids=rows.map(r=>r.id),lines:Line[]=[];let cursor='',complete=false;
 if(!ids.length)return[];
 for(let n=0;n<20&&lines.length<=200;n++){
  let q=client.from('journal_lines').select('id,company_id,journal_entry_id,account_id,party_id,debit_minor::text,credit_minor::text').eq('company_id',company).in('journal_entry_id',ids).order('id').limit(50);if(cursor)q=q.gt('id',cursor);
  const response=await q;if(!current()||response.error||!Array.isArray(response.data))throw Error('Recent journal read unavailable');const batch=response.data as Line[];
  if(batch.some((l,i)=>l.company_id!==company||!ids.includes(l.journal_entry_id)||l.id<=cursor||i>0&&l.id<=batch[i-1].id||!/^\d+$/.test(l.debit_minor)||!/^\d+$/.test(l.credit_minor)||(BigInt(l.debit_minor)>0n)===(BigInt(l.credit_minor)>0n)))throw Error('Recent journal scope mismatch');
  if(!batch.length){complete=true;break;}lines.push(...batch);cursor=batch.at(-1)!.id;
 }
 const s=await client.auth.getSession();if(!current()||s.error||s.data.session?.user.id!==user)throw Error('Session changed');
 return rows.map(r=>{const ls=lines.filter(l=>l.journal_entry_id===r.id),debit=ls.reduce((s,l)=>s+BigInt(l.debit_minor),0n),credit=ls.reduce((s,l)=>s+BigInt(l.credit_minor),0n),verified=complete&&ls.length>=2&&debit===credit&&debit>0n;
 return {...r,amount:verified?String(debit):null,funding:verified?ls.filter(l=>fundingAccounts.includes(l.account_id)).map(l=>({accountId:l.account_id,partyId:l.party_id,direction:BigInt(l.debit_minor)>0n?'IN':'OUT'})):null};});
}
