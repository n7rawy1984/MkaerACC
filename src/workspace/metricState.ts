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
export function sourceMonthMetric(rows:SourceRecord[],month:string,kind:MonthlyKind,basis:ReportingBasis='DATE'):Metric{
 try{
 const matching=rows.filter(r=>r.review_status!=='CANCELLED'&&sourceReportingMonth(r,basis)===month&&(kind==='payroll'?r.record_type==='PAYROLL':r.record_type==='GENERAL'&&sourceDirection(r)===(kind==='inflow'?'IN':'OUT')));
 if(!matching.length)return {state:'UNAVAILABLE'};
 const values=matching.map(sourceCurrentAmount);if(values.some(v=>v===null))return {state:'UNAVAILABLE'};
 if(values.some(v=>!/^\d+$/.test(v!)))return {state:'ERROR'};
 return moneyMetric(values.reduce((n,v)=>n+BigInt(v!),0n).toString());
 }catch{return {state:'ERROR'};}
}
// Explicit inclusive range; callers discover boundaries from authoritative data.
export function cycleMonths(start:string,through:string):string[]{
 const valid=(s:string)=>/^\d{4}-(0[1-9]|1[0-2])$/.test(s)&&Number(s.slice(0,4))>=1;
 if(!valid(start)||!valid(through)||start>through)return [];
 const[y,m]=start.split('-').map(Number),[ey,em]=through.split('-').map(Number),result:string[]=[];
 for(let i=y*12+m-1;i<=ey*12+em-1;i++)result.push(`${String(Math.floor(i/12)).padStart(4,'0')}-${String(i%12+1).padStart(2,'0')}`);
 return result;
}
