import{validFinancialDate,UNCONFIRMED_DATE}from'./sourceDatePresentation';
export type SourceRecord = {
 source_document?:{correction?:{id:string;state:string;target:string;reversed:boolean;receipt:{id:string;kind:string;journal:string}|null};kind?:string;draft_id:string;state:string;receipt:{id:string;reference:string;journal:string}|null;reversed:boolean};source_document_unavailable?:boolean;
 id: string; company_id?: string; source_reference: string; source_file: string; source_month: string;
 record_type: string; source_date: string | null; description: string;
 outflow_minor: string | null; funding_minor: string | null; payroll_net_minor: string | null;
 raw_source: Record<string, unknown>; classification: Record<string, unknown>;
 completion: Record<string, unknown>; review_status: string; updated_at: string;
 expense_allocation_id?:string|null;
 allocation_scope?:'PROJECT'|'COMPANY'|null; assigned_project_id?:string|null;
 expense_id: string | null; payroll_entitlement_id: string | null; cash_treasury_id: string | null; payroll_profile_id: string | null;
 payroll_status?:'POSTED'|'REVERSED'|'LINKED';
 expense?: {status: string;project_id?:string|null; expense_reference?:string;posted_journal_entry_id?:string} | null; cash_treasury?: {code: string} | null;
};
export const sourceValue = (r: SourceRecord, key: string, fallback: unknown = '') => String(r.completion[key] ?? fallback ?? '');
export function decimalMinor(value: string): string {
 if (!/^\d+(\.\d{1,2})?$/.test(value)) throw Error('Enter a nonnegative amount with up to two decimal places.');
 const [w,f=''] = value.split('.'); const n=BigInt(w)*100n+BigInt(f.padEnd(2,'0'));
 if(n>9000000000000000n)throw Error('Amount exceeds the supported range.');return n.toString();
}
export function sourceOriginalAmount(r: SourceRecord): string | null {
 if(r.record_type==='PAYROLL')return r.payroll_net_minor;
 if(BigInt(r.outflow_minor??'0')>0n)return r.outflow_minor;
 if(BigInt(r.funding_minor??'0')>0n)return r.funding_minor;
 try{return decimalMinor(String(r.raw_source['Invoice/Gross Amount']??''));}catch{return null;}
}
export const sourceCurrentAmount = (r:SourceRecord) => r.completion.amount_minor === undefined ? sourceOriginalAmount(r) : String(r.completion.amount_minor);
export function sourceTransactionDate(r:SourceRecord):string|null{const value=Object.hasOwn(r.completion,'date')?r.completion.date:r.source_date;return validFinancialDate(value)?value:null;}
export const sourceMonth = (r:SourceRecord) => r.record_type==='PAYROLL'?sourceValue(r,'salary_month',r.source_month):(sourceTransactionDate(r)?.slice(0,7)??UNCONFIRMED_DATE);
export const sourceDirection = (r:SourceRecord) => BigInt(r.outflow_minor??'0')>0n?'OUT':BigInt(r.funding_minor??'0')>0n?'IN':'NONE';
export const sourceAccounting = (r:SourceRecord) => r.source_document?.correction?(r.source_document.correction.reversed?'REVERSED':'RECLASSIFIED'):r.source_document?.reversed?'REVERSED':r.source_document?.state==='POSTED'?'POSTED':r.source_document?.state==='APPROVED'?'DOCUMENT_APPROVED':r.source_document?.state==='REVIEWED'?'DOCUMENT_REVIEWED':r.source_document?.state==='DRAFT'?'DOCUMENT_DRAFT':r.source_document_unavailable&&!r.expense_id&&!r.payroll_entitlement_id?'UNAVAILABLE':r.expense?.status==='REVERSED'?'REVERSED':r.expense_id?'POSTED':r.payroll_entitlement_id?(r.payroll_status??'LINKED'):r.review_status==='REVIEWED'?'SOURCE_REVIEWED':r.record_type==='GENERAL'?(sourceValue(r,'nature',r.classification.nature)&&sourceValue(r,'nature',r.classification.nature)!=='NEEDS_REVIEW'?'CLASSIFIED_UNPOSTED':'UNCLASSIFIED'):'NEEDS_COMPLETION';
export const sourceLinked = (r:SourceRecord) => !!(r.expense_id||r.payroll_entitlement_id||r.source_document?.state==='POSTED');
export function minorDecimal(v:string|null):string {if(v===null)return '—';const n=BigInt(v),a=n<0n?-n:n;return `${n<0n?'-':''}${a/100n}.${(a%100n).toString().padStart(2,'0')}`;}
export function minorDisplay(v:string|null):string {return minorDecimal(v).replace(/\B(?=(\d{3})+(?!\d))/g,',');}
export type ReportingBasis='SOURCE'|'DATE';
export const sourceReportingMonth=(r:SourceRecord,basis:ReportingBasis='DATE')=>basis==='SOURCE'?r.source_month:sourceMonth(r);
export function sourceTotals(rows:SourceRecord[]) {
 const general=rows.filter(r=>r.record_type==='GENERAL'),payroll=rows.filter(r=>r.record_type==='PAYROLL');
 const sum=(rs:SourceRecord[],value:(r:SourceRecord)=>string|null)=>rs.reduce((n,r)=>n+BigInt(value(r)??'0'),0n).toString();
 const active=(r:SourceRecord)=>r.review_status!=='CANCELLED';
 return {general:general.length,payroll:payroll.length,total:rows.length,
 originalOut:sum(general,r=>r.outflow_minor),originalIn:sum(general,r=>r.funding_minor),originalPayroll:sum(payroll,r=>r.payroll_net_minor),originalInvoice:sum(general.filter(r=>sourceDirection(r)==='NONE'),sourceOriginalAmount),
 correctedOut:sum(general.filter(r=>active(r)&&sourceDirection(r)==='OUT'),sourceCurrentAmount),
 correctedIn:sum(general.filter(r=>active(r)&&sourceDirection(r)==='IN'),sourceCurrentAmount),
 correctedInvoice:sum(general.filter(r=>active(r)&&sourceDirection(r)==='NONE'),sourceCurrentAmount),correctedPayroll:sum(payroll.filter(active),sourceCurrentAmount),active:rows.filter(active).length};
}
export function notifySourceChange(companyId:string) {window.dispatchEvent(new CustomEvent('historical-source-changed',{detail:{companyId}}));}
