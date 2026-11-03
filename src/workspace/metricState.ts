import {sourceCurrentAmount,sourceDirection,sourceReportingMonth,type SourceRecord,type ReportingBasis} from '../historical/sourceModel';
export type MetricState='LOADING'|'AVAILABLE'|'VERIFIED_ZERO'|'UNAVAILABLE'|'ERROR';
export type Metric={state:'AVAILABLE'|'VERIFIED_ZERO';minor:string}|{state:'LOADING'|'UNAVAILABLE'|'ERROR'};
export function moneyMetric(value:string|null|undefined,phase:'READY'|'LOADING'|'ERROR'|'DENIED'='READY'):Metric{
 if(phase==='LOADING'||phase==='ERROR')return {state:phase};
 if(phase==='DENIED'||value===null||value===undefined)return {state:'UNAVAILABLE'};
 if(!/^-?\d+$/.test(value))return {state:'ERROR'};
 return {state:BigInt(value)===0n?'VERIFIED_ZERO':'AVAILABLE',minor:value};
}
export type MonthlyKind='inflow'|'outflow'|'payroll';
// Source evidence, never GL truth. No row/coverage is not proof of a zero period.
export function sourceMonthMetric(rows:SourceRecord[],month:string,kind:MonthlyKind,basis:ReportingBasis='SOURCE'):Metric{
 try{
 const matching=rows.filter(r=>r.review_status!=='CANCELLED'&&sourceReportingMonth(r,basis)===month&&(kind==='payroll'?r.record_type==='PAYROLL':r.record_type==='GENERAL'&&sourceDirection(r)===(kind==='inflow'?'IN':'OUT')));
 if(!matching.length)return {state:'UNAVAILABLE'};
 const values=matching.map(sourceCurrentAmount);if(values.some(v=>v===null))return {state:'UNAVAILABLE'};
 if(values.some(v=>!/^\d+$/.test(v!)))return {state:'ERROR'};
 return moneyMetric(values.reduce((n,v)=>n+BigInt(v!),0n).toString());
 }catch{return {state:'ERROR'};}
}
export function cycleMonths(start:string):string[]{
 if(!/^\d{4}-(0[1-9]|1[0-2])$/.test(start))return [];
 const [year,month]=start.split('-').map(Number);if(year<1900||year>9998)return [];
 return [0,1,2].map(i=>{const index=year*12+month-1+i;return `${Math.floor(index/12)}-${String(index%12+1).padStart(2,'0')}`;});
}
