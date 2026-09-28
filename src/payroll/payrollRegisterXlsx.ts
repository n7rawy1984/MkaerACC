import type {SheetData,CellObject} from 'write-excel-file/universal';
import {registerText,type PayrollRegister} from './payrollRegister';
export async function registerWorkbook(register:PayrollRegister):Promise<Blob>{
 const {default:write}=await import('write-excel-file/universal');
 const t=registerText[register.locale];
 const cell=(value:string,bold=false):CellObject=>({value,type:String,format:'@',fontWeight:bold?'bold':undefined,wrap:true,align:register.locale==='ar'?'right':'left',fontSize:10});
 const heading=(value:string)=>[{...cell(value,true),columnSpan:13},...Array(12).fill(null)];
 const row=(values:string[],bold=false)=>values.map((v,i)=>({...cell(v,bold),align:i>=5?'right' as const:register.locale==='ar'?'right' as const:'left' as const,...(bold?{backgroundColor:'#E2E8F0'}:{})}));
 const data:SheetData=[heading(t.title),heading(`${register.company} · ${register.month} · ${register.status}`),heading(register.id),row(t.columns,true),...register.rows.map(r=>row(r)),row(register.totals,true),heading(t.note)];
 return write(data,{sheet:t.title,orientation:'landscape',rightToLeft:register.locale==='ar',showGridLines:false,columns:[22,17,16,28,22,20,18,16,20,20,16,20,20].map(width=>({width}))}).toBlob();
}
