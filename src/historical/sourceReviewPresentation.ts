import {sourceDirection,sourceLinked,sourceTransactionDate,sourceCurrentAmount,sourceValue,type SourceRecord} from './sourceModel';
// Payment-source confirmation is independent of an imported outflow claim.
export function sourcePaymentState(row:SourceRecord):'PAID'|'RECEIVED'|'UNCONFIRMED'|'NO_CASH'|'DOCUMENTED'{
 if(row.source_document?.state==='POSTED')return 'DOCUMENTED';
 const direction=sourceDirection(row);
 if(direction==='NONE')return 'NO_CASH';
 if(!row.cash_treasury_id)return 'UNCONFIRMED';
 return direction==='OUT'?'PAID':'RECEIVED';
}
export function sourceDuplicateCandidate(row:SourceRecord):string|null{
 if(row.classification.potential_duplicate!==true)return null;
 const candidate=row.classification.duplicate_candidate_source_reference;
 return typeof candidate==='string'&&candidate.trim()?candidate:null;
}

// Review information only. These flags never grant posting authority or replace
// the canonical command's current membership, period, mapping and balance checks.
export const sourceReviewIssues = (row:SourceRecord) => {
 const issues:string[]=[];
 if(row.source_document_unavailable)issues.push('LINK_UNAVAILABLE');
 if(sourceLinked(row))return issues;
 if(!sourceTransactionDate(row))issues.push('DATE_UNCONFIRMED');
 if(sourceCurrentAmount(row)===null)issues.push('AMOUNT_UNCONFIRMED');
 if(!sourceValue(row,'nature',row.classification.nature)||sourceValue(row,'nature',row.classification.nature)==='NEEDS_REVIEW')issues.push('CLASSIFICATION_REQUIRED');
 if(row.classification.legal_company_verified===false)issues.push('COMPANY_UNCONFIRMED');
 if(sourceDirection(row)!=='NONE'&&!row.cash_treasury_id)issues.push('PAYMENT_SOURCE_UNCONFIRMED');
 if(row.classification.independent_payment_evidence_verified===false)issues.push('PAYMENT_EVIDENCE_UNCONFIRMED');
 if(row.classification.potential_duplicate===true)issues.push('POSSIBLE_DUPLICATE');
 if(row.review_status!=='REVIEWED')issues.push('SOURCE_REVIEW_REQUIRED');
 return issues;
};
export const reviewIssueLabels={
 LINK_UNAVAILABLE:['Document links unavailable','تعذر التحقق من روابط المستندات'],
 DATE_UNCONFIRMED:['Without a confirmed date','بدون تاريخ مؤكد'],
 AMOUNT_UNCONFIRMED:['Amount requires evidence','المبلغ يحتاج إثباتاً'],
 CLASSIFICATION_REQUIRED:['Classification needs review','التصنيف يحتاج مراجعة'],
 COMPANY_UNCONFIRMED:['Accounting Company unconfirmed','الشركة المحاسبية غير مؤكدة'],
 PAYMENT_SOURCE_UNCONFIRMED:['Payment source unconfirmed','مصدر الدفع غير مؤكد'],
 PAYMENT_EVIDENCE_UNCONFIRMED:['Payment evidence unconfirmed','إثبات الدفع غير مؤكد'],
 POSSIBLE_DUPLICATE:['Possible duplicate','قد تكون مكررة'],
 SOURCE_REVIEW_REQUIRED:['Source review required','مراجعة المصدر مطلوبة'],
}as const;
export function sourceReviewIssueLabel(issue:string,locale:'en'|'ar'){return(reviewIssueLabels[issue as keyof typeof reviewIssueLabels]??[issue,issue])[locale==='ar'?1:0];}
export const sourceAccountingLabels={
 NEEDS_COMPLETION:['Source captured — needs review','مصدر محفوظ — يحتاج مراجعة'],
 SOURCE_REVIEWED:['Source reviewed — no canonical document','مصدر مراجع — دون مستند محاسبي'],
 DOCUMENT_DRAFT:['Canonical draft prepared','مسودة مستند محاسبي مجهزة'],
 DOCUMENT_REVIEWED:['Canonical document reviewed','مستند محاسبي مراجع'],
 DOCUMENT_APPROVED:['Canonical document approved — not posted','مستند محاسبي معتمد — غير مرحل'],
 POSTED:['Posted','مرحل'],REVERSED:['Reversed','معكوس'],RECLASSIFIED:['Corrected classification','تصنيف مصحح'],
 LINKED:['Linked to posted Payroll','مرتبط برواتب مرحلة'],UNAVAILABLE:['Document link unavailable','تعذر التحقق من ارتباط المستند'],
}as const;
export function sourceAccountingLabel(state:string,locale:'en'|'ar'){return(sourceAccountingLabels[state as keyof typeof sourceAccountingLabels]??[state,state])[locale==='ar'?1:0];}
