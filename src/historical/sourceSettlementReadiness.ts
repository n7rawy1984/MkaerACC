import {sourceCurrentAmount,sourceTransactionDate,type SourceRecord}from'./sourceModel';
// UI guidance only. Canonical commands remain the posting/authorization boundary.
export function sourceSettlementMissing(row:SourceRecord,v:Record<string,string>,locale:'en'|'ar'){
 const ar=locale==='ar',issues:string[]=[];const need=(ok:boolean,en:string,a:string)=>{if(!ok)issues.push(ar?a:en)};
 need(row.review_status==='REVIEWED','Complete source ownership review','استكمل مراجعة ملكية المصدر');
 need(!!sourceTransactionDate(row)&&v.date===sourceTransactionDate(row),'Confirm the actual source date','أكد تاريخ المصدر الفعلي');
 need(/^\d+$/.test(v.amount_minor??'')&&BigInt(v.amount_minor||'0')>0n&&v.amount_minor===sourceCurrentAmount(row),'Match the actual source amount','طابق مبلغ المصدر الفعلي');
 need(!!v.evidence?.trim(),'Provide payment / agreement evidence','أضف دليل الدفع / الاتفاقية');
 need(['TREASURY','CUSTODIAN'].includes(v.funding_mode??'TREASURY'),'Select supported Treasury or Custody funding','اختر تمويل الخزينة أو العهدة المدعوم');
 if((v.funding_mode??'TREASURY')==='CUSTODIAN'){need(!!v.custodian_id,'Select the actual Custody holder','اختر صاحب العهدة الفعلي');need(!!v.custody_account_id,'Select the mapped Custody account','اختر حساب العهدة المرتبط');need(!v.treasury_id,'Remove the conflicting Treasury input','أزل حقل الخزينة المتعارض');}
 else{need(!!v.treasury_id,'Select the actual funding Treasury','اختر خزينة التمويل الفعلية');need(!v.custodian_id&&!v.custody_account_id,'Remove conflicting Custody inputs','أزل حقول العهدة المتعارضة');}
 if(v.kind==='EMPLOYEE_ADVANCE'){need(!!v.employee_id,'Match the employee identity','طابق هوية الموظف');need(/^\d+$/.test(v.monthly_limit_minor??'')&&BigInt(v.monthly_limit_minor||'0')>0n,'Enter the approved recovery limit','أدخل حد الاسترداد المعتمد');}
 else{need(!!v.contract_id&&!!v.project_id,'Match the Contract and Project','طابق العقد والمشروع');if(v.kind==='CONTRACT_PAYMENT')need(!!v.certificate_id,'Match the posted certified liability','طابق المستحق المعتمد المرحّل');}
 return issues;
}
