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
 UNCLASSIFIED:['Unclassified — not posted','غير مصنف — غير مرحّل'],
 CLASSIFIED_UNPOSTED:['Classified — not posted','مصنف — غير مرحّل'],
 NEEDS_COMPLETION:['Source captured — needs review','مصدر محفوظ — يحتاج مراجعة'],
 SOURCE_REVIEWED:['Source reviewed — no canonical document','مصدر مراجع — دون مستند محاسبي'],
 DOCUMENT_DRAFT:['Canonical draft prepared','مسودة مستند محاسبي مجهزة'],
 DOCUMENT_REVIEWED:['Canonical document reviewed','مستند محاسبي مراجع'],
 DOCUMENT_APPROVED:['Canonical document approved — not posted','مستند محاسبي معتمد — غير مرحل'],
 POSTED:['Posted','مرحل'],REVERSED:['Reversed','معكوس'],RECLASSIFIED:['Corrected classification','تصنيف مصحح'],
 LINKED:['Linked to posted Payroll','مرتبط برواتب مرحلة'],UNAVAILABLE:['Document link unavailable','تعذر التحقق من ارتباط المستند'],
}as const;
export function sourceAccountingLabel(state:string,locale:'en'|'ar'){return(sourceAccountingLabels[state as keyof typeof sourceAccountingLabels]??[state,state])[locale==='ar'?1:0];}

// These are saved review findings, not a live posting-authority decision. Keep
// their provenance visible; only canonical commands can validate readiness.
const savedReviewLabels:Record<string,readonly[string,string]>={
 SOURCE_NOT_REVIEWED:['Source review not confirmed','لم تؤكد مراجعة المصدر'],
 INDEPENDENT_PAYMENT_AND_LEGAL_OWNERSHIP_NOT_CERTIFIED:['Actual payment and accounting Company ownership need evidence','يلزم إثبات الدفع الفعلي وتبعية العملية للشركة المحاسبية'],
 VAT_AND_RECOGNITION_PERIOD_REQUIRE_VERIFICATION:['VAT treatment and recognition period need verification','يلزم التحقق من المعالجة الضريبية وفترة الاعتراف'],
 NO_COMPLETE_APPROVED_CANONICAL_DOCUMENT:['Canonical document is incomplete or not approved','المستند المحاسبي غير مكتمل أو غير معتمد'],
 ACTUAL_FUNDING_SOURCE_UNCONFIRMED:['Actual payer and funding source are unconfirmed','الدافع الفعلي ومصدر التمويل غير مؤكدين'],
 LEGAL_ENTITY_AND_BENEFICIARY_SITE_NOT_CONFIRMED_NO_COMPANY_MOVE:['Legal Company and beneficiary site need confirmation; preserve original Company','يلزم تأكيد الشركة القانونية والموقع المستفيد مع حفظ الشركة الأصلية'],
 DATE_UNCONFIRMED:['Without a confirmed date','بدون تاريخ مؤكد'],
 PURPOSE_AND_COUNTERPARTY_UNCONFIRMED:['Economic purpose and counterparty are unconfirmed','الغرض الاقتصادي والطرف المقابل غير مؤكدين'],
 PHYSICAL_RECEIPT_CONSUMPTION_OWNERSHIP_AND_VALUATION_REQUIRED:['Material receipt, consumption, ownership and valuation need evidence','يلزم إثبات استلام المواد واستهلاكها وملكيتها وتقييمها'],
 INVENTORY_CONFIGURATION_NOT_RECORDED:['Inventory configuration needs completion','يلزم استكمال إعداد المخزون'],
 POSSIBLE_DUPLICATE_RETAIN_BOTH_SOURCES:['Possible duplicate; retain both sources until cleared','احتمال تكرار؛ احفظ المصدرين حتى التحقق'],
 ADVANCE_VS_CERTIFIED_SETTLEMENT_UNESTABLISHED:['Contractor advance versus certified settlement is unresolved','لم يحدد هل الدفع سلفة مقاول أم سداد مستخلص'],
 NO_POSTED_CERTIFICATION:['No posted certification matched','لم يطابق مستخلص مرحّل'],
 NO_CANONICAL_CONTRACTOR_PAYMENT_OR_ADVANCE:['No canonical contractor payment or advance linked','لا توجد دفعة أو سلفة مقاول محاسبية مرتبطة'],
 NO_RECORDED_STONE_CONTRACT:['Required subcontract is not recorded','العقد المطلوب غير مسجل'],
 RETENTION_AND_VAT_NOT_VERIFIED:['Retention and VAT require verification','يلزم التحقق من المحتجزات والضريبة'],
 MATCH_EMPLOYEE_ID_AND_APPROVED_RECOVERY_TERMS:['Match employee identity and approved recovery terms','طابق هوية الموظف وشروط الاسترداد المعتمدة'],
 EMPLOYEE_RECEIVABLE_MAPPING_NOT_RECORDED:['Employee receivable account mapping needs confirmation','يلزم تأكيد ربط حساب ذمم الموظف'],
 RECORDED_TREASURY_GL_BALANCE_ZERO_NO_VERIFIED_FUNDING_OR_OPENING:['Saved Treasury balance hold: verify the actual funding route; Custody funding does not prove the payer','تنبيه رصيد الخزينة المحفوظ: تحقق من مسار التمويل الفعلي؛ تمويل العهدة لا يثبت هوية الدافع'],
 MATCH_EMPLOYEE_EARNED_PERIOD_AND_PAYROLL_LIABILITY_NO_SECOND_SALARY_COST:['Match earned salary period and payroll liability; do not repeat salary cost','طابق فترة استحقاق الراتب والتزام الرواتب دون تكرار التكلفة'],
 LOAN_VS_CAPITAL_DRAWING_AND_BENEFICIARY_UNESTABLISHED:['Loan versus equity/drawing and beneficiary need confirmation','يلزم تحديد القرض أو حقوق الملكية أو المسحوبات والمستفيد'],
 CONTRACT_NOTES_ARE_NOT_INDEPENDENT_PAYMENT_OR_TAX_EVIDENCE:['Contract notes do not establish payment or VAT evidence','ملاحظات العقد لا تثبت الدفع أو المعالجة الضريبية'],
 NO_SUPPORTED_DEPOSIT_CANONICAL_POSTING_COMMAND_DO_NOT_EXPENSE:['Deposit workflow unsupported; do not classify as an Expense','مسار الوديعة غير مدعوم؛ لا تصنفها مصروفاً'],
};
export function sourceSavedReviewReasons(row:SourceRecord,locale:'en'|'ar'):string[]{
 if(sourceLinked(row))return [];
 const note=row.completion.operational_review_notes;
 if(typeof note!=='string'||!note.trim())return [];
 const marker='Evidence requirements:';const start=note.indexOf(marker);
 if(start<0)return [note];
 const codes=note.slice(start+marker.length).trim().replace(/\.$/,'').split(/,\s*/).filter(Boolean);
 return [...new Set(codes)].map(code=>savedReviewLabels[code]?.[locale==='ar'?1:0]??code);
}
export const sourceNeedsReview=(row:SourceRecord)=>row.record_type==='GENERAL'&&row.review_status!=='CANCELLED'&&!sourceLinked(row)&&(sourceReviewIssues(row).length>0||sourceSavedReviewReasons(row,'en').length>0);
export const sourceUnpostedWarning=(locale:'en'|'ar')=>locale==='ar'?'غير مرحّل — يحتاج مراجعة':'Not posted — needs review';
export function sourceReviewRequirements(row:SourceRecord,locale:'en'|'ar'){
 const live=sourceReviewIssues(row).map(code=>sourceReviewIssueLabel(code,locale));
 const saved=sourceSavedReviewReasons(row,locale);
 return [...live,...(saved.length?[(locale==='ar'?'متطلبات المراجعة المحفوظة: ':'Saved review requirements: ')+saved.join(' · ')]:[])].join(' · ');
}
