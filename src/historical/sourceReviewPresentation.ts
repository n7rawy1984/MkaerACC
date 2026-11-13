import {confirmedSourcePayment} from '../financial/paymentPolicy';
import {sourceAccounting,sourceDirection,sourceLinked,sourceTransactionDate,sourceCurrentAmount,sourceValue,type SourceRecord} from './sourceModel';
// A review annotation is a conditional funding default, never posting authority.
export function sourceCustodyDefault(row:SourceRecord):boolean{
 return confirmedSourcePayment(row)?.mode==='CUSTODIAN';
}
export const custodyDefaultLabel=(locale:'en'|'ar')=>locale==='ar'?'دافع العهدة مؤكد لمصروفات الشركة':'Custody payer confirmed for Company outgoings';
// Payment-source confirmation is independent of an imported outflow claim.
export function sourcePaymentState(row:SourceRecord):'PAID'|'RECEIVED'|'UNCONFIRMED'|'NO_CASH'|'DOCUMENTED'|'CUSTODY_DEFAULT'{
 if(row.source_document?.state==='POSTED')return 'DOCUMENTED';
 const direction=sourceDirection(row);
 if(direction==='NONE')return 'NO_CASH';
 if(sourceCustodyDefault(row))return 'CUSTODY_DEFAULT';
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
 if(!sourceValue(row,'nature',row.classification.nature)||sourceValue(row,'nature',row.classification.nature)==='NEEDS_REVIEW')issues.push('CLASSIFICATION_REQUIRED');
 if(!sourceTransactionDate(row))issues.push('DATE_UNCONFIRMED');
 if(sourceCurrentAmount(row)===null)issues.push('AMOUNT_UNCONFIRMED');
 if(row.classification.legal_company_verified===false)issues.push('COMPANY_UNCONFIRMED');
 if(row.payment_policy?.contradicted||row.completion.funding_contradiction==='true')issues.push('PAYMENT_CONTRADICTION');
 else if(sourceDirection(row)!=='NONE'&&!row.cash_treasury_id&&!confirmedSourcePayment(row))issues.push('PAYMENT_SOURCE_UNCONFIRMED');
 if(row.classification.independent_payment_evidence_verified===false&&!confirmedSourcePayment(row))issues.push('PAYMENT_EVIDENCE_UNCONFIRMED');
 if(row.classification.potential_duplicate===true)issues.push('POSSIBLE_DUPLICATE');
 if(row.review_status!=='REVIEWED')issues.push('SOURCE_REVIEW_REQUIRED');
 return issues;
};
export const reviewIssueLabels={
 PAYMENT_CONTRADICTION:['Review the conflicting payment evidence','راجع دليل الدفع المتعارض'],
 LINK_UNAVAILABLE:['Document links unavailable','تعذر التحقق من روابط المستندات'],
 DATE_UNCONFIRMED:['Without a confirmed date','بدون تاريخ مؤكد'],
 AMOUNT_UNCONFIRMED:['Amount requires evidence','المبلغ يحتاج إثباتاً'],
 CLASSIFICATION_REQUIRED:['Choose the economic type: Expense, advance, Contractor payment or materials.','حدد نوع العملية: مصروف، سلفة، دفعة مقاول، أو شراء مواد.'],
 PROJECT_REQUIRED:['Select the Project for this cost, or choose Company operating expense.','حدد المشروع المرتبط بهذه التكلفة، أو اختر مصروف الشركة.'],
 DESCRIPTION_REQUIRED:['Complete the transaction description.','استكمل وصف المعاملة.'],
 CATEGORY_REQUIRED:['Select the established cost category.','حدد فئة التكلفة المعتمدة.'],
 VAT_REQUIRED:['Select the VAT treatment and provide invoice evidence when claiming VAT.','حدد المعالجة الضريبية وأرفق دليل الفاتورة عند المطالبة بالضريبة.'],
 EVIDENCE_REQUIRED:['Add the existing supporting evidence reference.','أضف مرجع الإثبات المتوفر.'],
 SOURCE_MATCH_REQUIRED:['Match the saved source date and description; original evidence stays preserved.','طابق تاريخ المصدر المحفوظ ووصفه؛ تبقى الأدلة الأصلية محفوظة.'],
 COMPANY_UNCONFIRMED:['Accounting Company unconfirmed','الشركة المحاسبية غير مؤكدة'],
 PAYMENT_SOURCE_UNCONFIRMED:['Payment source unconfirmed','مصدر الدفع غير مؤكد'],
 PAYMENT_EVIDENCE_UNCONFIRMED:['Payment evidence unconfirmed','إثبات الدفع غير مؤكد'],
 POSSIBLE_DUPLICATE:['Possible duplicate','قد تكون مكررة'],
 SOURCE_REVIEW_REQUIRED:['Source review required','مراجعة المصدر مطلوبة'],
}as const;
export function sourceReviewIssueLabel(issue:string,locale:'en'|'ar'){return(reviewIssueLabels[issue as keyof typeof reviewIssueLabels]??['Review the source evidence','راجع أدلة المصدر'])[locale==='ar'?1:0];}
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
export function sourceAccountingLabel(state:string,locale:'en'|'ar'){return(sourceAccountingLabels[state as keyof typeof sourceAccountingLabels]??['Needs review','يحتاج مراجعة'])[locale==='ar'?1:0];}

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
 return [...new Set(codes)].filter(code=>!(confirmedSourcePayment(row)&&['ACTUAL_FUNDING_SOURCE_UNCONFIRMED','RECORDED_TREASURY_GL_BALANCE_ZERO_NO_VERIFIED_FUNDING_OR_OPENING'].includes(code))).map(code=>{if(confirmedSourcePayment(row)&&code==='INDEPENDENT_PAYMENT_AND_LEGAL_OWNERSHIP_NOT_CERTIFIED')return locale==='ar'?'تحقق من تبعية العملية للشركة المحاسبية':'Verify the accounting Company ownership';if(confirmedSourcePayment(row)&&code==='CONTRACT_NOTES_ARE_NOT_INDEPENDENT_PAYMENT_OR_TAX_EVIDENCE')return locale==='ar'?'تحقق من المعالجة الضريبية وأدلتها المطبقة':'Verify the applicable VAT treatment and evidence';return savedReviewLabels[code]?.[locale==='ar'?1:0]??(/^[A-Z][A-Z0-9_]+$/.test(code)?(locale==='ar'?'راجع متطلب المراجعة المحفوظ في أدلة المصدر':'Review the saved requirement in source evidence'):code);});
}
export const sourceNeedsReview=(row:SourceRecord)=>row.record_type==='GENERAL'&&row.review_status!=='CANCELLED'&&!sourceLinked(row)&&(sourceReviewIssues(row).length>0||sourceSavedReviewReasons(row,'en').length>0);
export const sourceUnpostedWarning=(locale:'en'|'ar')=>locale==='ar'?'غير مرحّل — يحتاج مراجعة':'Not posted — needs review';
export function sourceReviewRequirements(row:SourceRecord,locale:'en'|'ar'){
 const live=sourceReviewIssues(row).map(code=>sourceReviewIssueLabel(code,locale));
 const saved=sourceSavedReviewReasons(row,locale);
 return [...live,...(saved.length?[(locale==='ar'?'متطلبات المراجعة المحفوظة: ':'Saved review requirements: ')+saved.join(' · ')]:[])].join(' · ');
}

// Compact labels describe saved canonical lifecycle; they do not assert posting eligibility.
export function compactSourceStatus(row:SourceRecord,locale:'en'|'ar'){
 const state=sourceAccounting(row),ar=locale==='ar';
 return ({POSTED:ar?'مرحّل':'Posted',REVERSED:ar?'معكوس':'Reversed',RECLASSIFIED:ar?'تم التصحيح':'Corrected',DOCUMENT_DRAFT:ar?'مسودة':'Draft',DOCUMENT_REVIEWED:ar?'مسودة مراجعة':'Reviewed draft',DOCUMENT_APPROVED:ar?'جاهز للترحيل':'Ready to post',LINKED:ar?'مرتبط بمستند مرحّل':'Linked to posted document'} as Record<string,string>)[state]??(ar?'يحتاج مراجعة':'Needs review');
}

export function sourceNatureLabel(value:string,locale:'en'|'ar'){
 const labels:Record<string,[string,string]>={EXPENSE:['Expense','مصروف'],NEEDS_REVIEW:['Classification required','يحتاج تصنيفاً'],SUBCONTRACTOR_ADVANCE:['Contractor advance','سلفة مقاول'],SUBCONTRACTOR_PAYMENT:['Contractor settlement','سداد مقاول'],CONTRACTOR_PAYMENT:['Contractor payment','دفعة مقاول'],EMPLOYEE_ADVANCE:['Employee advance','سلفة موظف'],SUPPLIER_PAYMENT:['Supplier settlement','سداد مورد'],PAYROLL_OR_SALARY_PAYMENT:['Salary payment','دفعة راتب'],MATERIAL_PURCHASE:['Materials','مواد'],MATERIALS:['Materials','مواد'],ASSET_PURCHASE:['Asset purchase','شراء أصل'],CUSTODY_TRANSFER:['Custody transfer','تحويل عهدة']};
 return labels[value]?.[locale==='ar'?1:0]??(/^[A-Z][A-Z0-9_]+$/.test(value)?(locale==='ar'?'نوع يحتاج مراجعة':'Type needs review'):value);
}
