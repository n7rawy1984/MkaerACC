import type {SupabaseClient} from '@supabase/supabase-js';
import {commandExpenseDraft,type DraftCommand,type DraftInput,type ExpenseDraft} from './expenseDrafts';
import {sourceCurrentAmount,sourceLinked,sourceTransactionDate,sourceValue,type SourceRecord} from '../historical/sourceModel';
import {sourceExpenseCandidate} from '../historical/sourcePosting';

/** UI orchestration only. Each state transition is validated by the existing canonical command. */
export type ExpenseApproval={cid:string;draft:string;input:DraftInput;source?:SourceRecord;confirmations:NonNullable<DraftCommand['confirmations']>;latest:ExpenseDraft|null;needsSave:boolean;needsReview:boolean;sourceReviewed?:boolean;next:DraftCommand|null};
export function expenseCompletionIssue(v:DraftInput,source?:SourceRecord):string|null{
 if(source&&(sourceLinked(source)||source.source_document_unavailable||source.review_status==='CANCELLED'))return 'LINK_UNAVAILABLE';
 if(source&&!sourceExpenseCandidate(source))return 'CLASSIFICATION_REQUIRED';
 if(!['OPERATING_EXPENSE','PROJECT_COST'].includes(String(v.nature)))return 'CLASSIFICATION_REQUIRED';
 if(v.nature==='PROJECT_COST'&&!v.project_id||v.nature==='OPERATING_EXPENSE'&&v.project_id)return 'PROJECT_REQUIRED';
 if(!/^\d{4}-\d{2}-\d{2}$/.test(String(v.date))||v.period_month!==String(v.date).slice(0,7))return 'DATE_UNCONFIRMED';
 if(!String(v.description??'').trim())return 'DESCRIPTION_REQUIRED';
 if(!v.category_id)return 'CATEGORY_REQUIRED';
 if(!['TREASURY','CUSTODIAN','PERSONAL','SUPPLIER_CREDIT'].includes(String(v.funding_mode))||v.funding_mode==='TREASURY'&&!v.treasury_id||['CUSTODIAN','PERSONAL'].includes(String(v.funding_mode))&&!v.paid_by_id)return 'PAYMENT_SOURCE_UNCONFIRMED';
 if(!/^\d+(\.\d{1,2})?$/.test(String(v.net_aed))||!/[1-9]/.test(String(v.net_aed)))return 'AMOUNT_UNCONFIRMED';
 if(!['ZERO','AUTO_5','MANUAL'].includes(String(v.vat_mode))||v.vat_mode!=='ZERO'&&(!v.has_invoice||!v.invoice_number))return 'VAT_REQUIRED';
 if(!String(v.supporting_reference??'').trim())return 'EVIDENCE_REQUIRED';
 if(source&&(v.date!==sourceTransactionDate(source)||String(v.description).trim()!==sourceValue(source,'description',source.description).trim()))return 'SOURCE_MATCH_REQUIRED';
 return null;
}
const stable=(v:Record<string,unknown>)=>JSON.stringify(Object.entries(v).sort(([a],[b])=>a.localeCompare(b)));
/** The final accountant action can record source review without changing its working facts. */
export async function reviewExpenseSource(client:SupabaseClient,cid:string,source:SourceRecord){
 const {data,error}=await client.from('historical_source_records').select('*').eq('company_id',cid).eq('id',source.id).single();
 if(error||!data||data.company_id!==cid||!sourceExpenseCandidate(data as SourceRecord))throw Error('Source changed or already linked; refresh');
 const current=data as SourceRecord;
 if(stable(current.completion)!==stable(source.completion)||sourceCurrentAmount(current)!==sourceCurrentAmount(source)||sourceTransactionDate(current)!==sourceTransactionDate(source)||current.description!==source.description)throw Error('Source changed; refresh');
 if(current.review_status==='REVIEWED')return;
 if(current.updated_at!==source.updated_at)throw Error('Source changed; refresh');
 const r=await client.rpc('complete_historical_source',{target_company_id:cid,target_id:source.id,expected_updated_at:current.updated_at,details:current.completion,target_status:'REVIEWED'});
 if(r.error)throw Error(r.error.message);
}
/** A lost response retains the exact pending request. Retry continues, never starts a second draft. */
export async function runExpenseApproval(client:SupabaseClient,run:ExpenseApproval,guard:()=>Promise<void>,accept:(r:ExpenseDraft)=>void){
 while(run.latest?.state!=='POSTED'){
  await guard();
  if(!run.next){
   if(run.latest?.state==='CANCELLED')throw Error('Final draft cannot be changed');
   const action=run.needsSave?'SAVE':run.needsReview||run.latest?.state==='DRAFT'?'REVIEW':'POST';
   run.next={cid:run.cid,draft:run.draft,expected_version:run.latest?.version??0,request_id:crypto.randomUUID(),action,input:action==='SAVE'?run.input:{},reason:'Accountant approved distinct original cost, Company ownership and reviewed accounting treatment',...(run.source?{source_id:run.source.id,confirmations:run.confirmations}:{})};
  }
  const command=run.next,r=await commandExpenseDraft(client,command);
  const expected=command.action==='SAVE'?'DRAFT':command.action==='REVIEW'?'REVIEWED':'POSTED';
  if(r.state!==expected)throw Error('Unconfirmed accounting transition; retry identical request');
  run.latest=r;run.next=null;
  if(command.action==='SAVE')run.needsSave=false;
  if(command.action==='REVIEW')run.needsReview=false;
  await guard();accept(r);
 }
 return run.latest;
}
