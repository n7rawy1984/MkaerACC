export type SourceRecord = {
 id: string; company_id?: string; source_reference: string; source_file: string; source_month: string;
 record_type: string; source_date: string | null; description: string;
 outflow_minor: string | null; funding_minor: string | null; payroll_net_minor: string | null;
 raw_source: Record<string, unknown>; classification: Record<string, unknown>;
 completion: Record<string, unknown>; review_status: string; updated_at: string;
 expense_id: string | null; payroll_entitlement_id: string | null; cash_treasury_id: string | null; payroll_profile_id: string | null;
 payroll_status?:'POSTED'|'REVERSED'|'LINKED';
 expense?: {status: string; expense_reference?:string;posted_journal_entry_id?:string} | null; cash_treasury?: {code: string} | null;
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
export const sourceMonth = (r:SourceRecord) => r.record_type==='PAYROLL'?sourceValue(r,'salary_month',r.source_month):(sourceValue(r,'date',r.source_date)?.slice(0,7)||r.source_month);
export const sourceDirection = (r:SourceRecord) => BigInt(r.outflow_minor??'0')>0n?'OUT':BigInt(r.funding_minor??'0')>0n?'IN':'NONE';
export const sourceAccounting = (r:SourceRecord) => r.expense?.status==='REVERSED'?'REVERSED':r.expense_id?'POSTED':r.payroll_entitlement_id?(r.payroll_status??'LINKED'):r.review_status==='REVIEWED'?'DRAFT':'NEEDS_COMPLETION';
export const sourceLinked = (r:SourceRecord) => !!(r.expense_id||r.payroll_entitlement_id);
export function minorDecimal(v:string|null):string {if(v===null)return '—';const n=BigInt(v),a=n<0n?-n:n;return `${n<0n?'-':''}${a/100n}.${(a%100n).toString().padStart(2,'0')}`;}
export function minorDisplay(v:string|null):string {return minorDecimal(v).replace(/\B(?=(\d{3})+(?!\d))/g,',');}
export type ReportingBasis='SOURCE'|'DATE';
export const sourceReportingMonth=(r:SourceRecord,basis:ReportingBasis='SOURCE')=>basis==='SOURCE'?r.source_month:sourceMonth(r);
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
