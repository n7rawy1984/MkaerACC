import type {SheetData,CellObject} from 'write-excel-file/universal';
import {minorDecimal} from '../historical/sourceModel';
export type ReportCell=string|number|null|{minor:string};
export type ReportSection={title:string;headers:string[];rows:ReportCell[][]};
export type FinancialReport={company:string;title:string;period:string;locale:'en'|'ar';generated:string;note:string;sections:ReportSection[];filename:string};
export const moneyCell=(minor:string):ReportCell=>({minor});
export function reportNumericMinor(minor:string):number {
 const n=BigInt(minor),abs=n<0n?-n:n;
 // Excel preserves 15 significant decimal digits. Reject unrepresentable cents,
 // rather than silently rounding large financial values at the export boundary.
 if(abs>999999999999999n)throw Error('This amount exceeds Excel numeric precision. Use the exact PDF report.');
 const decimal=minorDecimal(minor),value=Number(decimal);
 if(value.toFixed(2)!==decimal)throw Error('This amount cannot be exported as an exact numeric Excel cell.');return value;
}
export async function financialWorkbook(report:FinancialReport):Promise<Blob>{
 const {default:write}=await import('write-excel-file/universal');const rtl=report.locale==='ar';
 const sheets=report.sections.map(section=>{
  const width=section.headers.length;
  const text=(value:string,bold=false):CellObject=>({value,type:String,wrap:true,fontWeight:bold?'bold':undefined,fontSize:10,align:rtl?'right':'left'});
  const heading=(value:string)=>[{...text(value,true),columnSpan:width},...Array(Math.max(0,width-1)).fill(null)];
  const cell=(value:ReportCell):CellObject|null=>value===null?null:typeof value==='object'?{value:reportNumericMinor(value.minor),type:Number,format:'#,##0.00',align:'right',fontSize:10}:typeof value==='number'?{value,type:Number,align:'right',fontSize:10}:text(value);
  const data:SheetData=[heading(report.company),heading(report.title+' · '+section.title),heading(report.period),heading(report.generated),heading(report.note),section.headers.map(label=>({...text(label,true),backgroundColor:'#E2E8F0'})),...section.rows.map(row=>row.map(cell))];return data;
 });
 return write(sheets.map((data,i)=>({data,sheet:'Report '+(i+1),rightToLeft:rtl,showGridLines:false,orientation:'landscape' as const,columns:report.sections[i].headers.map((_,j)=>({width:j===2?34:22}))}))).toBlob();
}
export const displayReportCell=(cell:ReportCell)=>cell===null?'—':typeof cell==='object'?minorDecimal(cell.minor).replace(/\B(?=(\d{3})+(?!\d))/g,','):String(cell);
