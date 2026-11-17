import {sourceSupplierId} from '../historical/sourceCounterparty';
import {minorDecimal,sourceCurrentAmount,sourceTransactionDate,sourceValue,type SourceRecord} from '../historical/sourceModel';
import type {ProductionParty} from '../master/masterTypes';
import {newExpenseDraft,type DraftInput} from './expenseDrafts';
import {confirmedSourcePayment,paymentFields} from './paymentPolicy';

/** Reuse verified working facts, never infer tax treatment or economic classification. */
export function sourceExpenseInput(source:SourceRecord,parties:ProductionParty[],categoryId:string):DraftInput {
 const c=source.completion,date=sourceTransactionDate(source)??'',payer=confirmedSourcePayment(source);
 const vat=typeof c.vat_mode==='string'?c.vat_mode:'';
 const amount=sourceCurrentAmount(source);
 return {...newExpenseDraft(),date,period_month:date.slice(0,7),description:sourceValue(source,'description',source.description),
  source_reference:'HISTORICAL:'+source.id,supplier_id:sourceSupplierId(source,parties),
  notes:source.source_reference+' · '+source.source_file,
  nature:c.reclassification_destination==='PROJECT_COST'?'PROJECT_COST':c.reclassification_destination==='OPERATING_EXPENSE'?'OPERATING_EXPENSE':'',
  project_id:source.assigned_project_id??'',category_id:categoryId,vat_mode:vat,
  net_aed:typeof c.net_aed==='string'&&c.net_aed.trim()?c.net_aed:vat==='ZERO'&&amount!==null&&/^\d+$/.test(amount)?minorDecimal(amount):'',
  vat_aed:typeof c.vat_aed==='string'?c.vat_aed:'',has_invoice:c.has_invoice===true,
  invoice_number:typeof c.invoice_number==='string'?c.invoice_number:'',
  ...paymentFields(payer),supporting_reference:typeof c.supporting_reference==='string'&&c.supporting_reference.trim()?c.supporting_reference:payer?.reference??''};
}

/** Choosing gross-cost/no-recovery treatment reuses the known paid amount, not an assumed tax rate. */
export function sourceExpenseVatChange(input:DraftInput,vatMode:string,source?:SourceRecord):DraftInput {
 const amount=source?sourceCurrentAmount(source):null;
 const gross=amount!==null&&/^\d+$/.test(amount)?minorDecimal(amount):'';
 return {...input,vat_mode:vatMode,...(gross&&vatMode==='ZERO'&&!input.net_aed?{net_aed:gross}:gross&&input.vat_mode==='ZERO'&&vatMode!=='ZERO'&&input.net_aed===gross?{net_aed:''}:{})};
}

export function sourceHasDuplicateEvidence(source:SourceRecord):boolean {
 const candidates=source.raw_source.existing_match_candidates_unverified;
 return source.completion.operator_review_issue==='POSSIBLE_DUPLICATE'||source.classification.potential_duplicate===true||!!source.classification.duplicate_group||Array.isArray(candidates)&&candidates.length>0;
}
