import {useEffect,useState} from 'react';
import {sourceClient} from './useHistoricalSources';
import type {SourceRecord} from './sourceModel';
type ExpenseSource=Pick<SourceRecord,'id'|'company_id'|'record_type'|'raw_source'|'completion'|'source_reference'>&{expense_id:string};
/** Read-only provenance. Never substitutes a supplier in the posted document/subledger. */
export function useExpenseSourceCounterparties(company:string,expenseIds:string[],enabled:boolean){
 const key=[...expenseIds].sort().join(',');
 const [state,setState]=useState<{scope:string;rows:ExpenseSource[]}>({scope:'',rows:[]});
 const scope=company+':'+key;
 useEffect(()=>{let live=true;if(!enabled||!company||!key)return;
 void(async()=>{try{const result:ExpenseSource[]=[];let cursor='';for(;;){let q=sourceClient().from('historical_source_records').select('id,company_id,record_type,raw_source,completion,source_reference,expense_id').eq('company_id',company).eq('record_type','GENERAL').in('expense_id',key.split(',')).order('id').limit(500);if(cursor)q=q.gt('id',cursor);const {data,error}=await q;if(!live)return;if(error||!data)throw Error('Source counterparty unavailable');const rows=data as ExpenseSource[];if(rows.some(r=>r.company_id!==company||r.record_type!=='GENERAL'||!key.split(',').includes(r.expense_id)))throw Error('Source scope');result.push(...rows);if(rows.length<500)break;cursor=rows.at(-1)!.id;}if(live)setState({scope,rows:result});}catch{if(live)setState({scope,rows:[]});}})();return()=>{live=false;};
 },[company,key,scope,enabled]);
 return enabled&&state.scope===scope?state.rows:[];
}
