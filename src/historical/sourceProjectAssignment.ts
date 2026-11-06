import type {ProductionProjectSummary} from '../master/masterTypes';
import {sourceAccounting,sourceCurrentAmount,sourceValue,type SourceRecord} from './sourceModel';
import type {FinancialReport} from '../reports/reportExport';
export type AssignmentItem={source_id:string;expected_updated_at:string;scope:'PROJECT'|'COMPANY';project_id:string|null};
export type AssignmentAttempt={request_id:string;items:AssignmentItem[];reason:string};
export type AssignmentEvent={id:string;company_id:string;request_id:string;actor_id:string;reason:string;created_at:string;changes:{source_id:string;source_reference:string;previous_scope:string|null;previous_project_id:string|null;scope:string;project_id:string|null}[]};
export function assignmentBlock(row:SourceRecord,companyId:string):string|null {
 if(row.company_id!==companyId)return 'foreign';
 if(row.expense_id||row.payroll_entitlement_id)return 'posted';
 if(row.expense_allocation_id)return 'allocated';
 if(row.review_status==='CANCELLED')return 'archived';
 if(row.record_type!=='GENERAL'||sourceValue(row,'nature',row.classification.nature)!=='EXPENSE'||!/^\d+$/.test(row.outflow_minor??'')||BigInt(row.outflow_minor??'0')<=0n)return 'nature';
 const amount=sourceCurrentAmount(row);if(!amount||!/^\d+$/.test(amount)||BigInt(amount)<=0n)return 'amount';
 return null;
}
export type AssignmentSummary={scope:'PROJECT'|'COMPANY';project_id:string|null;count:number;amount:string};
export function assignmentSummary(rows:SourceRecord[],companyId:string,items:AssignmentItem[]):AssignmentSummary[]{
 if(!items.length||items.length>100||new Set(items.map(i=>i.source_id)).size!==items.length)throw Error('Invalid selection');
 const groups=new Map<string,AssignmentSummary>();
 for(const item of items){const matching=rows.filter(r=>r.id===item.source_id);if(matching.length!==1)throw Error('Source unavailable');const row=matching[0];
  if(assignmentBlock(row,companyId)||row.updated_at!==item.expected_updated_at)throw Error('Source changed');
  if(!['PROJECT','COMPANY'].includes(item.scope)||(item.scope==='PROJECT')!==!!item.project_id)throw Error('Invalid destination');
  const key=item.scope==='COMPANY'?'COMPANY':item.project_id!,group=groups.get(key)??{scope:item.scope,project_id:item.project_id,count:0,amount:'0'};
  group.count++;group.amount=(BigInt(group.amount)+BigInt(sourceCurrentAmount(row)!)).toString();groups.set(key,group);
 }
 return [...groups.values()];
}
export function prepareAssignment(rows:SourceRecord[],companyId:string,projects:ProductionProjectSummary[],selected:string[],destinations:Record<string,string>,reason:string):AssignmentAttempt {
 if(!reason.trim()||[...reason.trim()].length>500)throw Error('Reason required');
 const items=selected.map(id=>{const row=rows.find(r=>r.id===id),destination=destinations[id];if(!row||!destination)throw Error('Destination required');
  const scope=destination==='COMPANY'?'COMPANY' as const:'PROJECT' as const,project_id=scope==='COMPANY'?null:destination;
  if(project_id&&!projects.some(p=>p.companyId===companyId&&p.id===project_id&&p.status!=='CLOSED'))throw Error('Project unavailable');
  if(row.allocation_scope===scope&&row.assigned_project_id===project_id)throw Error('Assignment unchanged');
  return {source_id:id,expected_updated_at:row.updated_at,scope,project_id};
 });
 assignmentSummary(rows,companyId,items);return {request_id:crypto.randomUUID(),items,reason:reason.trim()};
}
export function assignmentReport(rows:SourceRecord[],companyId:string,company:string,projects:ProductionProjectSummary[],locale:'en'|'ar',attempt:AssignmentAttempt|null,events:AssignmentEvent[]):FinancialReport {
 if(rows.some(r=>r.company_id!==companyId)||events.some(e=>e.company_id!==companyId))throw Error('Company changed');
 const ar=locale==='ar',project=(id:string|null|undefined)=>id?(projects.find(p=>p.companyId===companyId&&p.id===id)?.code??id):'—';
 const scope=(value:string|null|undefined)=>value==='PROJECT'?(ar?'مشروع':'Project'):value==='COMPANY'?(ar?'مصروفات الشركة':'Company overhead'):(ar?'غير محدد':'Unassigned');
 const months=[...new Set(rows.map(r=>r.source_month))].sort();
 const summary=attempt?assignmentSummary(rows,companyId,attempt.items):[];
 const eligible=attempt?rows.filter(r=>attempt.items.some(i=>i.source_id===r.id)):[];
 const total=eligible.reduce((n,r)=>n+BigInt(sourceCurrentAmount(r)!),0n).toString();
 const status=(r:SourceRecord)=>({RECLASSIFIED:ar?'أعيد التصنيف':'Reclassified',DOCUMENT_DRAFT:ar?'مسودة مستند':'Document draft',DOCUMENT_REVIEWED:ar?'مستند مراجع':'Document reviewed',UNAVAILABLE:ar?'تعذر التحقق':'Unavailable',POSTED:ar?'مرحل':'Posted',REVERSED:ar?'معكوس':'Reversed',LINKED:ar?'مرتبط':'Linked',DRAFT:ar?'مسودة مراجعة':'Reviewed draft',NEEDS_COMPLETION:ar?'غير مرحل':'Unposted'})[sourceAccounting(r)];
 return {company,title:ar?'تخصيص مصادر المصروفات':'Expense source assignment',period:months.join(', ')||(ar?'لا توجد فترة':'No period'),locale,generated:new Date().toISOString(),filename:'expense-source-assignment',note:ar?'مبالغ المصدر وليست تكاليف مرحلة. المقترحات لا تغير المحاسبة. الإجمالي للمصادر المختارة غير المرحلة فقط.':'Source amounts, not posted project costs. Proposals do not change accounting. Total covers selected unposted sources only.',sections:[{title:ar?'مصادر المصروفات':'Expense sources',headers:ar?['المرجع','التاريخ','الوصف','مبلغ المصدر (درهم)','الحالة','التخصيص الحالي','المشروع الحالي','التخصيص المقترح','المشروع المقترح']:['Reference','Date','Description','Source amount (AED)','Status','Current assignment','Current Project','Proposed assignment','Proposed Project'],rows:[...rows.map(r=>{const proposed=attempt?.items.find(i=>i.source_id===r.id);const amount=sourceCurrentAmount(r);return [r.source_reference,sourceValue(r,'date',r.source_date),sourceValue(r,'description',r.description),amount&&/^\d+$/.test(amount)?{minor:amount}:null,r.review_status==='CANCELLED'?(ar?'مؤرشف':'Archived'):status(r),r.expense_allocation_id?(ar?'تخصيص مشترك':'Shared allocation'):scope(r.allocation_scope),project(r.assigned_project_id??r.expense?.project_id),proposed?scope(proposed.scope):'—',project(proposed?.project_id)];}),[ar?'إجمالي المصادر المختارة غير المرحلة':'Selected unposted source total',null,null,{minor:total},null,null,null,null,null]]},{title:ar?'ملخص التخصيص المقترح — غير مرحل':'Proposed allocation summary — unposted',headers:ar?['التخصيص','المشروع','عدد المصادر','مبلغ المصدر (درهم)']:['Assignment','Project','Source count','Source amount (AED)'],rows:[...summary.map(g=>[scope(g.scope),project(g.project_id),g.count,{minor:g.amount}]),[ar?'إجمالي المصادر المختارة':'Selected source total',null,eligible.length,{minor:total}]]},{title:ar?'مرجع المقترح':'Proposal reference',headers:ar?['مرجع الطلب','السبب','الحالة']:['Request reference','Reason','Status'],rows:attempt?[[attempt.request_id,attempt.reason,ar?'غير مرحل':'Unposted']]:[]},{title:ar?'تفاصيل سجل التخصيص':'Assignment audit details',headers:ar?['مرجع التدقيق / الطلب','المصدر','التخصيص السابق','المشروع السابق','التخصيص الجديد','المشروع الجديد']:['Audit / Request reference','Source','Previous assignment','Previous Project','New assignment','New Project'],rows:events.flatMap(e=>e.changes.map(c=>[e.id+' · '+e.request_id,c.source_reference,scope(c.previous_scope),project(c.previous_project_id),scope(c.scope),project(c.project_id)]))},{title:ar?'آخر 50 عملية تخصيص':'Latest 50 assignment batches',headers:ar?['الوقت','المستخدم','السبب','مرجع الطلب','عدد المصادر']:['Time','Actor reference','Reason','Request reference','Source count'],rows:events.map(e=>[e.created_at,e.actor_id,e.reason,e.request_id,e.changes.length])}]};
}
