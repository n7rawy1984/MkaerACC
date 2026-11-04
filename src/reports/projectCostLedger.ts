import{allocateSharedCost}from'../financial/sharedCostAllocation';
import{expenseAllocationSections,type ExpenseAllocationEvidence}from'./expenseAllocationSections';
import {readCorrectionExecutions,correctionExecutionSections,type CorrectionExecutionEvidence} from '../financial/projectCorrectionExecution';
import {readCorrectionReviews,correctionReviewSections,type CorrectionReview} from '../financial/expenseCorrectionReviews';
import type {SupabaseClient} from '@supabase/supabase-js';
import {moneyCell,type FinancialReport} from './reportExport';
export type CostScope={companyId:string;from:string;through:string;project:string};
export type CostProject={id:string;company_id:string;code:string;name:string;status:string};
export type CostAccount={id:string;company_id:string;code:string;name:string;account_type:string;system_key?:string|null};
export type CostEntry={id:string;company_id:string;journal_reference:string;posting_date:string;description:string;source_type:string;source_id:string;posting_purpose:string;reversal_of_journal_entry_id:string|null};
export type CostLine={id:string;company_id:string;journal_entry_id:string;line_number:number;account_id:string;project_id:string|null;debit_minor:string;credit_minor:string};
export type CostDocument=ExpenseAllocationEvidence&{id:string;company_id:string;project_id:string|null;reference:string;subcontract_id?:string};
export type CostInput={projects:CostProject[];accounts:CostAccount[];entries:CostEntry[];lines:CostLine[];originals:CostEntry[];documents:CostDocument[]};
export type CostRow={id:string;date:string;journal:string;description:string;sourceType:string;sourceId:string;document:string;subcontract:string|null;reversalOf:string|null;projectId:string|null;project:string;account:string;debit:string;credit:string;net:string};
export type CostResult={sourceAllocations?:CostDocument[];executionEvidence?:CorrectionExecutionEvidence;projects:CostProject[];correctionReviews?:CorrectionReview[];correctionReviewsAvailable?:boolean;scope:CostScope;captured:string;rows:CostRow[];groups:{id:string;label:string;debit:string;credit:string;net:string}[];debit:string;credit:string;net:string};
export const validCostDate=(s:string)=>/^\d{4}-\d{2}-\d{2}$/.test(s)&&Number.isFinite(Date.parse(s+'T00:00:00Z'))&&new Date(s+'T00:00:00Z').toISOString().slice(0,10)===s;
export function validateCostScope(s:CostScope){if(!s.companyId||!validCostDate(s.from)||!validCostDate(s.through)||s.from>s.through||!s.project)throw Error('invalid');}
function unique<T extends {id:string;company_id:string}>(rows:T[],company:string){const map=new Map<string,T>();for(const row of rows){if(row.company_id!==company||map.has(row.id))throw Error('integrity');map.set(row.id,row);}return map;}
export function reconcileProjectCosts(scope:CostScope,input:CostInput):CostResult{
 validateCostScope(scope);const projects=unique(input.projects,scope.companyId),accounts=unique(input.accounts,scope.companyId),entries=unique(input.entries,scope.companyId),originals=unique(input.originals,scope.companyId),docs=unique(input.documents,scope.companyId);unique(input.lines,scope.companyId);
 if(!['ALL','COMPANY'].includes(scope.project)&&!projects.has(scope.project))throw Error('scope');
 for(const entry of entries.values()){
  const source=entry.reversal_of_journal_entry_id?(entries.get(entry.reversal_of_journal_entry_id)??originals.get(entry.reversal_of_journal_entry_id)):entry,doc=source?docs.get(source.source_id):undefined;
  if(source?.source_type==='EXPENSE'&&doc?.allocation_plan){
   if(!doc.allocation_event_id||!doc.net_amount_minor)throw Error('integrity');
   const expected=allocateSharedCost(doc.net_amount_minor,doc.allocation_plan),costs=input.lines.filter(l=>l.journal_entry_id===entry.id&&accounts.get(l.account_id)?.account_type==='EXPENSE');
   if(costs.length!==expected.destinations.length)throw Error('integrity');
   for(const part of expected.destinations){const matching=costs.filter(l=>l.project_id===part.project_id);if(matching.length!==1)throw Error('integrity');const l=matching[0],account=accounts.get(l.account_id)!;
    if(account.system_key!==(part.project_id?'PROJECT_COST':'COMPANY_EXPENSE')||(entry.reversal_of_journal_entry_id?l.credit_minor!==part.amount_minor||l.debit_minor!=='0':l.debit_minor!==part.amount_minor||l.credit_minor!=='0'))throw Error('integrity');
   }
  }
 }
 const sums=new Map<string,{debit:bigint;credit:bigint}>(),rows:CostRow[]=[];
 for(const entry of entries.values())if(!validCostDate(entry.posting_date)||entry.posting_date<scope.from||entry.posting_date>scope.through)throw Error('integrity');
 for(const line of input.lines){const entry=entries.get(line.journal_entry_id),account=accounts.get(line.account_id);if(!entry||!account||line.project_id&&!projects.has(line.project_id)||!/^\d+$/.test(line.debit_minor)||!/^\d+$/.test(line.credit_minor))throw Error('integrity');
  const debit=BigInt(line.debit_minor),credit=BigInt(line.credit_minor);if(debit>9223372036854775807n||credit>9223372036854775807n||debit>0n&&credit>0n)throw Error('integrity');const sum=sums.get(entry.id)??{debit:0n,credit:0n};sum.debit+=debit;sum.credit+=credit;sums.set(entry.id,sum);
  if(account.account_type!=='EXPENSE'||scope.project==='COMPANY'&&line.project_id!==null||!['ALL','COMPANY'].includes(scope.project)&&line.project_id!==scope.project)continue;
  const original=entry.reversal_of_journal_entry_id?(entries.get(entry.reversal_of_journal_entry_id)??originals.get(entry.reversal_of_journal_entry_id)):null;
  if(entry.reversal_of_journal_entry_id&&!original)throw Error('integrity');
  const source=original??entry,doc=docs.get(source.source_id);
  if(['EXPENSE','SUBCONTRACTOR_CERTIFICATE'].includes(source.source_type)&&(!doc||!doc.allocation_plan&&doc.project_id!==line.project_id))throw Error('integrity');
  rows.push({id:line.id,date:entry.posting_date,journal:entry.journal_reference,description:entry.description,sourceType:source.source_type,sourceId:source.source_id,document:doc?.reference??source.journal_reference,subcontract:doc?.subcontract_id??null,reversalOf:original?.journal_reference??null,projectId:line.project_id,project:line.project_id?projects.get(line.project_id)!.code+' · '+projects.get(line.project_id)!.name:'COMPANY',account:account.code+' · '+account.name,debit:line.debit_minor,credit:line.credit_minor,net:(debit-credit).toString()});
 }
 if(input.entries.some(e=>!sums.has(e.id)||sums.get(e.id)!.debit!==sums.get(e.id)!.credit))throw Error('integrity');
 rows.sort((a,b)=>a.date.localeCompare(b.date)||a.journal.localeCompare(b.journal)||a.id.localeCompare(b.id));
 const groups=new Map<string,{id:string;label:string;debit:bigint;credit:bigint}>();
 for(const row of rows){const id=row.projectId??'COMPANY',g=groups.get(id)??{id,label:row.project,debit:0n,credit:0n};g.debit+=BigInt(row.debit);g.credit+=BigInt(row.credit);groups.set(id,g);}
 const debit=rows.reduce((n,r)=>n+BigInt(r.debit),0n),credit=rows.reduce((n,r)=>n+BigInt(r.credit),0n);
 return {projects:input.projects,scope:{...scope},captured:new Date().toISOString(),rows,groups:[...groups.values()].map(g=>({...g,debit:g.debit.toString(),credit:g.credit.toString(),net:(g.debit-g.credit).toString()})),debit:debit.toString(),credit:credit.toString(),net:(debit-credit).toString()};
}
const entryColumns='id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose,reversal_of_journal_entry_id';
export async function readProjectCostLedger(client:SupabaseClient,scope:CostScope,valid:()=>boolean=()=>true):Promise<CostResult>{
 validateCostScope(scope);
 async function read<T extends {id:string;company_id:string}>(table:string,columns:string,filter:(q:any)=>any=q=>q):Promise<T[]>{
  const rows:T[]=[];let cursor='';for(;;){if(!valid())throw Error('session');let q=filter(client.from(table).select(columns).eq('company_id',scope.companyId)).order('id').limit(500);if(cursor)q=q.gt('id',cursor);const{data,error}=await q;if(!valid())throw Error('session');if(error||!data)throw Error('read');const batch=data as T[];if(batch.some((r,i)=>r.company_id!==scope.companyId||r.id<=cursor||i>0&&r.id<=batch[i-1].id)||new Set(batch.map(r=>r.id)).size!==batch.length)throw Error('integrity');rows.push(...batch);if(!batch.length)break;cursor=batch.at(-1)!.id;}return rows;
 }
 const period=(q:any)=>q.gte('posting_date',scope.from).lte('posting_date',scope.through);
 const projects=await read<CostProject>('projects','id,company_id,code,name,status');
 if(!['ALL','COMPANY'].includes(scope.project)&&!projects.some(p=>p.id===scope.project))throw Error('scope');
 const accounts=await read<CostAccount>('accounts','id,company_id,code,name,account_type,system_key');
 const entries=await read<CostEntry>('journal_entries',entryColumns,period),lines:CostLine[]=[],originals:CostEntry[]=[],documents:CostDocument[]=[];
 for(let start=0;start<entries.length;start+=100){const ids=entries.slice(start,start+100).map(e=>e.id);lines.push(...await read<CostLine>('journal_lines','id,company_id,journal_entry_id,line_number,account_id,project_id,debit_minor::text,credit_minor::text',q=>q.in('journal_entry_id',ids)));}
 const missing=[...new Set(entries.map(e=>e.reversal_of_journal_entry_id).filter((id):id is string=>!!id&&!entries.some(e=>e.id===id)))];
 for(let start=0;start<missing.length;start+=100)originals.push(...await read<CostEntry>('journal_entries',entryColumns,q=>q.in('id',missing.slice(start,start+100))));
 for(const [kind,table,reference,extra]of [['EXPENSE','expenses','expense_reference',',allocation_event_id,allocation_plan,net_amount_minor::text,expense_date,status,posted_journal_entry_id'],['SUBCONTRACTOR_CERTIFICATE','subcontractor_certificates','certificate_reference',',subcontract_id']]){
  const ids=[...new Set([...entries,...originals].filter(e=>e.source_type===kind).map(e=>e.source_id))];for(let start=0;start<ids.length;start+=100){const docs=await read<any>(table,`id,company_id,project_id,${reference}${extra}`,q=>q.in('id',ids.slice(start,start+100)));documents.push(...docs.map(d=>({...d,reference:d[reference]})));}
 }
 const executionEvidence=await readCorrectionExecutions(client,scope.companyId);
 const result=reconcileProjectCosts(scope,{projects,accounts,entries,lines,originals,documents});
 const relevantCorrections=executionEvidence.corrections.filter(c=>result.rows.some(r=>r.sourceType==='PROJECT_COST_CORRECTION'&&r.sourceId===c.id||r.sourceType==='EXPENSE'&&r.sourceId===c.expense_id));
 for(const row of result.rows){if(row.sourceType==='PROJECT_COST_CORRECTION'){const correction=relevantCorrections.find(c=>c.id===row.sourceId);if(!correction)throw Error('integrity');row.document=correction.correction_reference;}}
 const filteredEvidence={...executionEvidence,corrections:relevantCorrections,reversals:executionEvidence.reversals.filter(v=>relevantCorrections.some(c=>c.id===v.correction_id))};
 const reviews=await readCorrectionReviews(client,scope.companyId,[...new Set([...result.rows.filter(r=>r.sourceType==='EXPENSE').map(r=>r.sourceId),...relevantCorrections.map(c=>c.expense_id)])],filteredEvidence);if(!valid())throw Error('session');
 // Read all correction evidence before final header validation: do not annotate a
 // captured ledger with a later reversal that was not part of that capture.
 const again=await read<CostEntry>('journal_entries',entryColumns,period);
 if(JSON.stringify(entries)!==JSON.stringify(again))throw Error('changed');
 return {...result,sourceAllocations:documents.filter(d=>d.allocation_plan&&result.rows.some(r=>r.sourceType==='EXPENSE'&&r.sourceId===d.id)),executionEvidence:filteredEvidence,correctionReviews:reviews.rows,correctionReviewsAvailable:reviews.available};
}
export function projectCostReport(result:CostResult,company:string,locale:'en'|'ar'):FinancialReport{
 const ar=locale==='ar',label=(s:string)=>s==='COMPANY'?(ar?'مصروفات الشركة':'Company overhead'):s;
 const source=(s:string)=>({EXPENSE:ar?'مصروف':'Expense',SUBCONTRACTOR_CERTIFICATE:ar?'مستخلص مقاول باطن':'Subcontractor certificate',PAYROLL:ar?'رواتب':'Payroll',PROJECT_COST_CORRECTION:ar?'تصحيح تخصيص المشروع':'Project allocation correction'}[s]??s);
 return {company,locale,title:ar?'تكاليف المشروعات المرحلة':'Posted project costs',period:result.scope.from+' — '+result.scope.through,generated:result.captured,filename:'NARVO-Posted-Project-Costs',note:ar?'حركة حسابات المصروفات المرحلة حسب تاريخ القيد وصلاحيات الحساب، بما فيها العكس. تستثنى المصادر غير المرحلة والأصول والأعمال تحت التنفيذ. قد تُحجب الرواتب حسب الصلاحية. ليس بيان ربحية أو رصيد تكلفة شاملًا.':'Posted expense-account movements by journal date and authorized visibility, including reversals. Unposted sources, assets and WIP are excluded. Payroll may be restricted by permission. This is not profitability or a complete project-cost balance.',sections:[{title:ar?'حسب المشروع':'By Project',headers:ar?['المشروع','مدين (درهم)','دائن (درهم)','صافي الحركة (درهم)']:['Project','Debit AED','Credit AED','Net movement AED'],rows:[...result.groups.map(g=>[label(g.label),moneyCell(g.debit),moneyCell(g.credit),moneyCell(g.net)]),[ar?'الإجمالي':'Total',moneyCell(result.debit),moneyCell(result.credit),moneyCell(result.net)]]},{title:ar?'تفاصيل حركة التكلفة':'Cost movements',headers:ar?['التاريخ / القيد','المشروع / الحساب','المستند / التصنيف','الحالة / عكس قيد','مدين (درهم)','دائن (درهم)','صافي الحركة (درهم)']:['Date / Journal','Project / Account','Document / Classification','Status / Reversal of','Debit AED','Credit AED','Net movement AED'],rows:result.rows.map(r=>[r.date+' · '+r.journal,label(r.project)+' · '+r.account,r.document+' · '+source(r.sourceType),r.reversalOf?(ar?'عكس':'Reversal')+' · '+r.reversalOf:(ar?'مرحل':'Posted'),moneyCell(r.debit),moneyCell(r.credit),moneyCell(r.net)])},{title:ar?'مراجع المستندات':'Document references',headers:ar?['القيد','الوصف','معرف المصدر','معرف عقد الباطن']:['Journal','Description','Source ID','Subcontract ID'],rows:result.rows.map(r=>[r.journal,r.description,r.sourceId,r.subcontract])},...expenseAllocationSections(result.sourceAllocations??[],result.projects,locale),...correctionReviewSections(result.correctionReviews??[],result.projects,locale),...correctionExecutionSections(result.executionEvidence??{available:false,corrections:[],reversals:[]},result.projects,(result.correctionReviews??[]).map(r=>({id:r.expense_id,reference:r.snapshot.expense_reference})),locale),...(!result.correctionReviewsAvailable?[{title:ar?'حالة مراجعات التصحيح':'Correction review availability',headers:[ar?'الحالة':'Status'],rows:[[ar?'سجل المراجعة غير متاح؛ لم يُفترض عدم وجود تصحيحات.':'Review history unavailable; absence of corrections is not asserted.']]}]:[])]};
}
