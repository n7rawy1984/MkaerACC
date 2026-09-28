import {decodeDraft,displayDailySalary,displayPayrollMoney,type PayrollDraft} from './payrollRepository';
export type RegisterSource={kind:'DRAFT';id:string;version:number}|{kind:'POSTED';id:string};
export interface RegisterContext {userId:string;companyId:string;companyName:string;role:string;month:string}
export const registerText={
 en:{title:'Payroll register',draft:'DRAFT',posted:'POSTED',reversed:'REVERSED',excel:'Export Excel',preview:'Print / Save PDF',print:'Print',close:'Close',total:'Total',error:'Output unavailable. Reload payroll and confirm a fresh reviewed draft or an authorized posted snapshot.',note:'Amounts are exact two-decimal text in Excel. Salary / Day is display-only. Days worked are calendar days less absence days. Gross, additions, deductions and net are authoritative payroll values.',columns:['Work Station','Payroll ID','Type','Employee Name','Profession','Monthly Salary','Salary / Day','No. of Days Worked','Gross Salary','Addition','Absence / Deduction Days','Other Deduction','Net Salary']},
 ar:{title:'كشف الرواتب',draft:'مسودة DRAFT',posted:'مرحّل POSTED',reversed:'معكوس REVERSED',excel:'تصدير Excel',preview:'طباعة / حفظ PDF',print:'طباعة',close:'إغلاق',total:'الإجمالي',error:'تعذر إخراج الكشف. أعد تحميل الرواتب وتأكد من مراجعة المسودة المحدثة أو صلاحية الوصول إلى النسخة المرحّلة.',note:'المبالغ في Excel نصوص دقيقة بمنزلتين عشريتين. الراتب اليومي للعرض فقط. أيام العمل هي أيام الشهر ناقص أيام الغياب. الإجمالي والإضافات والخصومات والصافي من قيم الرواتب المعتمدة.',columns:['موقع العمل','الرقم الوظيفي','النوع','اسم الموظف','المهنة','الراتب الشهري','الراتب / اليوم','عدد أيام العمل','إجمالي الراتب','الإضافة','أيام الغياب / الخصم','خصومات أخرى','صافي الراتب']}
};
export interface PayrollRegister {company:string;month:string;status:string;id:string;locale:'en'|'ar';rows:string[][];totals:string[];filename:string}
const money=(n:bigint)=>`${n/100n}.${String(n%100n).padStart(2,'0')}`;
const days=(n:bigint)=>`${n/2n}${n%2n?'.5':''}`;
export function makeRegister(raw:unknown,context:RegisterContext,source:RegisterSource,locale:'en'|'ar'):PayrollRegister {
 let draft:PayrollDraft;let reversed=false;
 if(source.kind==='POSTED'){
  const postings=(raw as {postings?:unknown[]})?.postings;
  const p=postings?.find(p=>(p as {id:string}).id===source.id) as {company_id:string;month:string;period_id:string;draft_version:number;snapshot:unknown;reversed:boolean}|undefined;
  if(!p||p.company_id!==context.companyId||p.month!==context.month||typeof p.reversed!=='boolean')throw Error('Invalid snapshot');
  draft=decodeDraft(p.snapshot,context.companyId);reversed=p.reversed;
  if(draft.period?.id!==p.period_id||draft.period?.version!==p.draft_version)throw Error('Invalid snapshot version');
 }else{
  draft=decodeDraft(raw,context.companyId);
  if(draft.stale||draft.review_valid!==true||!draft.attendance_review_valid||draft.period?.id!==source.id||draft.period?.version!==source.version)throw Error('Review fresh draft first');
 }
 if(!draft.period||draft.period.month!==context.month||!Number.isInteger(draft.period.version)||draft.rows.some(r=>typeof r.included!=='boolean'))throw Error('Invalid month');
 const totals=Array<bigint>(13).fill(0n);
 const rows=draft.rows.filter(r=>r.included).map(r=>{
  const text=[r.work_station,r.payroll_id,r.payroll_type,r.employee_name,r.profession];
  if(text.some(v=>typeof v!=='string'))throw Error('Invalid register text');
  const worked=BigInt(r.calendar_days*2-r.absence_half_units),absence=BigInt(r.absence_half_units);
  const amounts:[[number,string],[number,string],[number,string],[number,string],[number,string]]=[[5,r.monthly_salary_minor],[8,r.gross_salary_minor],[9,r.additions_minor],[11,r.deductions_minor],[12,r.net_salary_minor]];
  for(const [i,v] of amounts)totals[i]+=BigInt(v);totals[7]+=worked;totals[10]+=absence;
  return [...text,displayPayrollMoney(r.monthly_salary_minor),displayDailySalary(r.monthly_salary_minor,r.calendar_days),days(worked),displayPayrollMoney(r.gross_salary_minor),displayPayrollMoney(r.additions_minor),days(absence),displayPayrollMoney(r.deductions_minor),displayPayrollMoney(r.net_salary_minor)];
 });
 const t=registerText[locale],status=`${source.kind==='DRAFT'?t.draft:t.posted}${reversed?` · ${t.reversed}`:''}`;
 const total=totals.map((n,i)=>[5,8,9,11,12].includes(i)?money(n):[7,10].includes(i)?days(n):'');total[0]=t.total;
 const safe=context.companyName.replace(/[^\p{L}\p{N}_-]+/gu,'-').slice(0,60)||'Company';
 return {company:context.companyName,month:context.month.slice(0,7),status,id:source.id,locale,rows,totals:total,filename:`${safe}-Payroll-${context.month.slice(0,7)}-${source.kind}${reversed?'-REVERSED':''}.xlsx`};
}
