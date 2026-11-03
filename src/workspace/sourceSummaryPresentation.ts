import {sourceCurrentAmount,sourceDirection,sourceOriginalAmount,type SourceRecord} from '../historical/sourceModel';
// An unknown invoice/Payroll amount is not evidence of numeric zero.
export function sourceSummaryKnown(rows:SourceRecord[],kind:'OUT'|'IN'|'NONE'|'PAYROLL'){
 const relevant=rows.filter(r=>kind==='PAYROLL'?r.record_type==='PAYROLL':r.record_type==='GENERAL'&&sourceDirection(r)===kind);
 return relevant.every(r=>sourceOriginalAmount(r)!==null&&sourceCurrentAmount(r)!==null);
}
