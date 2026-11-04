import type {SupabaseClient} from '@supabase/supabase-js';
import {readPartyStatement, statementType, type StatementResult, type StatementRow, type StatementScope} from './partyStatement';
import {moneyCell, type FinancialReport} from './reportExport';

export type CustodyMovement = StatementRow & {funding:string;spending:string;returned:string;other:string};
export type CustodyReconciliation = {statement:StatementResult;opening:string;funding:string;spending:string;returned:string;other:string;difference:string;closing:string;rows:CustodyMovement[]};
// Custody is a Company/person receivable. These are journal movements, never a
// calculated cash box or an automatically recognized reimbursement liability.
export function reconcileCustody(statement:StatementResult):CustodyReconciliation {
 if(!statement.operational.applicable||statement.scope.account!=='ALL'||statement.scope.transaction!=='ALL')throw Error('scope');
 const groups=statement.groups.filter(g=>g.account.system_key==='CUSTODY_ADVANCE');
 if(!statement.coverage.some(c=>c.key==='CUSTODY_ADVANCE'&&c.state==='AVAILABLE')||groups.some(g=>g.account.account_type!=='ASSET'||g.contract))throw Error('scope');
 let opening=0n,closing=0n,funding=0n,spending=0n,returned=0n,other=0n;
 const rows:CustodyMovement[]=[];
 for(const g of groups){opening+=BigInt(g.opening);closing+=BigInt(g.closing);
  for(const r of g.rows){const net=BigInt(r.debit)-BigInt(r.credit);let f=0n,s=0n,t=0n,o=0n;
   if(r.type==='CUSTODY_ADVANCE')f=net;else if(r.type==='EXPENSE')s=-net;else if(r.type==='CUSTODY_CASH_RETURN')t=-net;else o=net;
   funding+=f;spending+=s;returned+=t;other+=o;
   rows.push({...r,funding:String(f),spending:String(s),returned:String(t),other:String(o)});
  }
 }
 const difference=funding-spending-returned;
 if(opening+difference+other!==closing)throw Error('integrity');
 rows.sort((a,b)=>a.date.localeCompare(b.date)||a.journal.localeCompare(b.journal)||a.id.localeCompare(b.id));
 return{statement,opening:String(opening),funding:String(funding),spending:String(spending),returned:String(returned),other:String(other),difference:String(difference),closing:String(closing),rows};
}
export async function readCustodyReconciliation(client:SupabaseClient,scope:StatementScope,valid:()=>boolean=()=>true){
 return reconcileCustody(await readPartyStatement(client,scope,valid));
}
export const custodyNote=(ar:boolean)=>ar
 ?'الفرق التشغيلي = التمويل − الإنفاق − المرتجعات خلال الفترة؛ وقد يكون سالبًا دون أن يثبت استحقاق تعويض أو دين على الموظف. الرصيد الدفتري ذمة عهدة وليس نقدية فعلية. الافتتاحي حركة مرحلة سابقة، وليس إقرارًا باكتمال الأرصدة الافتتاحية. نطاق المشروع ليس الرصيد المجمع للشخص؛ المرتجعات غير المخصصة لا تُوزع افتراضيًا. التسويات لا تضيف تكلفة. لا يشمل الكشف مصروفات شخصية غير مرحلة أو افتتاحيات غير مسجلة.'
 :'Period operating difference = funding − spending − returns; it may be negative without establishing employee debt or a reimbursement entitlement. The GL balance is a custody receivable, not physical cash. Opening is prior posted movement, not certification of complete opening balances. Project scope is not the pooled person balance; unassigned returns are not inferred into Projects. Settlements add no cost. Unposted personal spending and unrecorded openings are excluded.';
export function custodyReport(result:CustodyReconciliation,company:string,locale:'ar'|'en'):FinancialReport {
 const ar=locale==='ar',s=result.statement,project=(id:string|null)=>id?(s.projects.find(p=>p.id===id)?.code??id):(ar?'غير مخصص':'Unassigned');
 return{company,locale,title:(ar?'كشف وتسوية العهدة':'Custody statement and reconciliation')+' · '+s.party.name,period:s.scope.from+' — '+s.scope.through,generated:s.captured,filename:'custody-reconciliation-'+s.scope.from+'-'+locale,note:custodyNote(ar)+' '+(ar?'نطاق المشروع: ':'Project scope: ')+(s.scope.project==='ALL'?(ar?'جميع المشروعات':'All Projects'):s.scope.project==='COMPANY'?project(null):project(s.scope.project)),sections:[
  {title:ar?'الأرصدة والحركات':'Balances and movements',headers:ar?['البيان','درهم']:['Measure','AED'],rows:[
   [ar?'الافتتاحي الدفتري':'GL opening',moneyCell(result.opening)],[ar?'التمويل — صافي العكس':'Funding — net of reversals',moneyCell(result.funding)],[ar?'الإنفاق — شامل الضريبة وصافي العكس':'Spending — gross, net of reversals',moneyCell(result.spending)],[ar?'المرتجعات — صافي العكس':'Returns — net of reversals',moneyCell(result.returned)],[ar?'الفرق التشغيلي للفترة':'Period operating difference',moneyCell(result.difference)],[ar?'حركات أخرى تتطلب مراجعة':'Other movements requiring review',moneyCell(result.other)],[ar?'الختامي الدفتري':'GL closing',moneyCell(result.closing)]]},
  {title:ar?'حركات العهدة':'Custody movements',headers:ar?['التاريخ','المستند','النوع','المشروع','الوصف','التمويل','الإنفاق','المرتجع','حركة أخرى','حالة القيد','حالة المصدر الحالية','القيد / معرف المصدر']:['Date','Document','Type','Project','Description','Funding AED','Spending AED','Returns AED','Other AED','Posting status','Current source status','Journal / Source ID'],rows:result.rows.map(r=>[r.date,r.document.reference,statementType(r.type,ar),project(r.projectId),r.description,moneyCell(r.funding),moneyCell(r.spending),moneyCell(r.returned),moneyCell(r.other),r.reversalOf?(ar?'عكس: ':'Reversal: ')+r.reversalOf:(ar?'مرحل':'Posted'),r.document.status,r.journal+' / '+r.document.id])},
  {title:ar?'حالة التسويات':'Settlement status',headers:ar?['المرجع','التاريخ','الحالة']:['Reference','Date','Status'],rows:s.operational.available?s.operational.rows.map(r=>[r.reference,r.date,r.status]):[[ar?'غير متاح':'Unavailable','','']]}
 ]};
}
export function custodyHistoryTemplate(company:string,locale:'ar'|'en'):FinancialReport {
 const ar=locale==='ar';return{company,locale,title:ar?'قالب أدلة العهد التاريخية':'Historical custody evidence template',period:ar?'من أغسطس 2026 — دون استيراد أو ترحيل':'From August 2026 — no import or posting',generated:new Date().toISOString(),filename:'custody-history-template-'+locale,note:ar?'قالب فارغ لجمع الأدلة فقط. لا تنشئ أرصدة أو قيودًا. استخدم معرفات الشركة والطرف والمشروع المعتمدة والتواريخ والمراجع الأصلية. المبالغ بوحدات الفلس الصحيحة؛ العملة درهم. يراجع التصنيف قبل أي استيراد.':'Blank evidence collection template only. Creates no balances or journals. Use authoritative Company, Party and Project IDs and original dates/references. Amounts are integer minor units (AED fils). Classification must be reviewed before any import.',sections:[{title:ar?'الأدلة':'Evidence',headers:ar?['التاريخ','مستند المصدر','معرف الشركة','معرف صاحب العهدة','معرف المشروع — اختياري','نوع المعاملة','المستلم — فلس','الإنفاق المعتمد — فلس','المرتجع — فلس','التعويض — فلس','التصنيف المحاسبي','الوصف','مراجع الإثبات','حالة المراجعة']:['Transaction date','Source document','Company ID','Custodian Party ID','Project ID — optional','Transaction type','Funding minor','Approved spending minor','Returns minor','Reimbursement minor','Accounting classification','Description','Supporting references','Review status'],rows:[]}]};
}
