import type {SupabaseClient} from '@supabase/supabase-js';
import {validFinancialDate,formatFinancialDate} from '../historical/sourceDatePresentation';
import {readCompanyRows,readPostedLedger,validatePostedLedger,type LedgerEntry,type LedgerLine} from './postedLedgerRead';
import {moneyCell,type FinancialReport} from './reportExport';
export type StatementAccount={id:string;company_id:string;code:string;name:string;reporting_role?:string;account_type:'ASSET'|'LIABILITY'|'EQUITY'|'REVENUE'|'EXPENSE'};
export type StatementScope={companyId:string;from:string;through:string};
export type TrialRow={account:StatementAccount;opening:string;debit:string;credit:string;closing:string;incomeMovement?:string};
export type FinancialStatements={scope:StatementScope;captured:string;rows:TrialRow[];journalCount:number;debit:string;credit:string;assets:string;liabilities:string;equity:string;unclosedResult:string;revenue:string;expenses:string;profit:string;salesRevenue:string|null;costOfSales:string|null;grossProfit:string|null};
export function validateStatementDates(scope:StatementScope){if(!scope.companyId||!validFinancialDate(scope.from)||!validFinancialDate(scope.through)||scope.from>scope.through)throw Error('dates');}
// Debit-positive balances throughout; conversion to presentation signs happens once.
// Income is the selected period. Balance Sheet includes all posted movements to cutoff,
// including prior unclosed results, and never certifies completeness of historical openings.
export function calculateFinancialStatements(scope:StatementScope,accounts:StatementAccount[],entries:LedgerEntry[],lines:LedgerLine[]):FinancialStatements{
 validateStatementDates(scope);validatePostedLedger(scope.companyId,entries,lines);
 const byAccount=new Map(accounts.map(a=>[a.id,a])),byEntry=new Map(entries.map(e=>[e.id,e]));
 if(byAccount.size!==accounts.length||accounts.some(a=>a.company_id!==scope.companyId||!['ASSET','LIABILITY','EQUITY','REVENUE','EXPENSE'].includes(a.account_type))||lines.some(l=>!byAccount.has(l.account_id)))throw Error('integrity');
 const isClosing=(e:LedgerEntry)=>e.source_type==='ANNUAL_CLOSE'||!!e.reversal_of_journal_entry_id&&byEntry.get(e.reversal_of_journal_entry_id)?.source_type==='ANNUAL_CLOSE';
 const balances=new Map(accounts.map(a=>[a.id,{opening:0n,debit:0n,credit:0n,income:0n}]));
 for(const l of lines){const date=byEntry.get(l.journal_entry_id)!.posting_date;if(date>scope.through)continue;const b=balances.get(l.account_id)!,d=BigInt(l.debit_minor),c=BigInt(l.credit_minor);if(date<scope.from)b.opening+=d-c;else{b.debit+=d;b.credit+=c;if(!isClosing(byEntry.get(l.journal_entry_id)!))b.income+=d-c;}}
 const rows=accounts.slice().sort((a,b)=>a.code.localeCompare(b.code)||a.id.localeCompare(b.id)).map(account=>{const b=balances.get(account.id)!;return{account,opening:String(b.opening),debit:String(b.debit),credit:String(b.credit),closing:String(b.opening+b.debit-b.credit),incomeMovement:String(b.income)};});
 const total=(type:string,key:'closing'|'opening'='closing')=>rows.filter(r=>r.account.account_type===type).reduce((n,r)=>n+BigInt(r[key]),0n);
 // Closing transfers and their exact reversals clear balances, not earned income.
 const movement=(type:string)=>lines.reduce((n,l)=>{const e=byEntry.get(l.journal_entry_id)!;return byAccount.get(l.account_id)!.account_type===type&&e.posting_date>=scope.from&&e.posting_date<=scope.through&&!isClosing(e)?n+BigInt(l.debit_minor)-BigInt(l.credit_minor):n;},0n);
 const classifiedMovement=(role:string)=>lines.reduce((n,l)=>{const e=byEntry.get(l.journal_entry_id)!;return byAccount.get(l.account_id)!.reporting_role===role&&e.posting_date>=scope.from&&e.posting_date<=scope.through&&!isClosing(e)?n+BigInt(l.debit_minor)-BigInt(l.credit_minor):n;},0n),classified=accounts.some(a=>a.reporting_role==='COGS')&&accounts.some(a=>a.reporting_role==='SALES');
 const salesRevenue=classified?-classifiedMovement('SALES'):null,costOfSales=classified?classifiedMovement('COGS'):null;
 const debit=rows.reduce((n,r)=>n+BigInt(r.debit),0n),credit=rows.reduce((n,r)=>n+BigInt(r.credit),0n),assets=total('ASSET'),liabilities=-total('LIABILITY'),equity=-total('EQUITY'),unclosedResult=-total('REVENUE')-total('EXPENSE'),revenue=-movement('REVENUE'),expenses=movement('EXPENSE');
 if(debit!==credit||rows.reduce((n,r)=>n+BigInt(r.opening),0n)!==0n||assets!==liabilities+equity+unclosedResult)throw Error('integrity');
 return{scope,captured:new Date().toISOString(),rows,journalCount:entries.filter(e=>e.posting_date>=scope.from&&e.posting_date<=scope.through).length,debit:String(debit),credit:String(credit),assets:String(assets),liabilities:String(liabilities),equity:String(equity),unclosedResult:String(unclosedResult),revenue:String(revenue),expenses:String(expenses),profit:String(revenue-expenses),salesRevenue:salesRevenue===null?null:String(salesRevenue),costOfSales:costOfSales===null?null:String(costOfSales),grossProfit:salesRevenue===null||costOfSales===null?null:String(salesRevenue-costOfSales)};
}
export async function readFinancialStatements(client:SupabaseClient,scope:StatementScope,user:string,valid:()=>boolean=()=>true){
 validateStatementDates(scope);
 async function access(){if(!valid())throw Error('session');const session=await client.auth.getSession();if(!valid()||session.error||session.data.session?.user.id!==user)throw Error('session');
 const roles=await Promise.all(['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER'].map(required_role=>client.rpc('has_company_role',{target_company_id:scope.companyId,required_role})));
 const payroll=await client.rpc('has_permission',{target_company_id:scope.companyId,required_permission:'payroll.manage'});
 if(!valid())throw Error('session');if(roles.some(r=>r.error||typeof r.data!=='boolean')||!roles.some(r=>r.data===true)||payroll.error||payroll.data!==true)throw Error('restricted');}
 // Existing RLS hides entire confidential Payroll journals. A subset can still balance:
 // do not pass that subset off as complete Company financial statements.
 await access();
 const columns='id,company_id,code,name,account_type',accounts=await readCompanyRows<StatementAccount>(client,scope.companyId,'accounts',columns,valid);
 const ledger=await readPostedLedger(client,scope.companyId,valid);
 const again=await readCompanyRows<StatementAccount>(client,scope.companyId,'accounts',columns,valid);
 if(JSON.stringify(accounts)!==JSON.stringify(again))throw Error('changed');await access();
 if(!valid())throw Error('session');type StatementControls={sales?:string;cost_of_sales?:string};let controls:StatementControls|null=null;
 try{const r=await client.rpc('read_statement_controls',{cid:scope.companyId});if(!r.error)controls=r.data as StatementControls;}catch{/* Older compatible schemas can still return account-type statements, without a claimed gross profit. */}
 await access();return calculateFinancialStatements(scope,accounts.map(a=>({...a,reporting_role:a.id===controls?.sales?'SALES':a.id===controls?.cost_of_sales?'COGS':undefined})),ledger.entries,ledger.lines);
}
export function financialStatementReport(result:FinancialStatements,company:string,locale:'en'|'ar'):FinancialReport{
 const ar=locale==='ar',l=(en:string,arabic:string)=>ar?arabic:en,m=moneyCell;
 const balanceRows=(type:StatementAccount['account_type'])=>result.rows.filter(r=>r.account.account_type===type).map(r=>[r.account.code,r.account.name,m(String(BigInt(r.closing)*(type==='ASSET'?1n:-1n)))]);
 const openingDebit=result.rows.reduce((n,r)=>n+(BigInt(r.opening)>0n?BigInt(r.opening):0n),0n),closingDebit=result.rows.reduce((n,r)=>n+(BigInt(r.closing)>0n?BigInt(r.closing):0n),0n);
 const split=(value:string,debit:boolean)=>m(String((debit?BigInt(value):-BigInt(value))>0n?(debit?BigInt(value):-BigInt(value)):0n));
 return{company,locale,title:l('Financial statements — posted ledger','القوائم المالية — الأستاذ المرحّل'),period:formatFinancialDate(result.scope.from,locale)+' — '+formatFinancialDate(result.scope.through,locale),generated:result.captured,filename:'NARVO-Financial-Statements',note:l('AED. Posting-date basis, all Company accounts, including reversals. Prior posted movements are not certification of complete opening balances. Income covers the selected dates; the Balance Sheet is cumulative through the end date. Unclosed results include all unclosed prior and current income/expense balances; they are not a new equity posting. Account-type presentation does not assert current/non-current classification, statutory compliance, or a complete Cash Flow Statement.','درهم إماراتي. حسب تاريخ القيد لجميع حسابات الشركة، بما فيها العكس. الحركة السابقة لا تثبت اكتمال الأرصدة الافتتاحية. الدخل للفترة المحددة والميزانية تراكمية حتى نهايتها. النتائج غير المقفلة تشمل الأرصدة السابقة والحالية دون إنشاء قيد حقوق ملكية. العرض حسب نوع الحساب ولا يثبت تصنيف المتداول أو الامتثال القانوني أو اكتمال قائمة التدفقات النقدية.'),sections:[
 {title:l('Trial Balance','ميزان المراجعة'),headers:[l('Code','الرمز'),l('Account','الحساب'),l('Opening Dr','افتتاحي مدين'),l('Opening Cr','افتتاحي دائن'),l('Period Dr','حركة مدينة'),l('Period Cr','حركة دائنة'),l('Closing Dr','ختامي مدين'),l('Closing Cr','ختامي دائن')],rows:[...result.rows.map(r=>[r.account.code,r.account.name,split(r.opening,true),split(r.opening,false),m(r.debit),m(r.credit),split(r.closing,true),split(r.closing,false)]),[l('Total','الإجمالي'),'',m(String(openingDebit)),m(String(openingDebit)),m(result.debit),m(result.credit),m(String(closingDebit)),m(String(closingDebit))]]},
 {title:l('Income Statement','قائمة الدخل'),headers:[l('Code','الرمز'),l('Account','الحساب'),l('Period AED','الفترة بالدرهم')],rows:[...result.rows.filter(r=>['REVENUE','EXPENSE'].includes(r.account.account_type)).map(r=>[r.account.code,r.account.name,m(String(BigInt(r.incomeMovement??String(BigInt(r.debit)-BigInt(r.credit)))*(r.account.account_type==='REVENUE'?-1n:1n)))]),['',l('Revenue','الإيرادات'),m(result.revenue)],['',l('Expenses','المصروفات'),m(result.expenses)],...(result.grossProfit!=null?[["",l('Sales revenue','إيراد المبيعات'),m(result.salesRevenue!)],["",l('Cost of Goods Sold','تكلفة البضاعة المباعة'),m(result.costOfSales!)],["",l('Gross profit','مجمل الربح'),m(result.grossProfit)]]:[]),['',l('Net profit / loss','صافي الربح / الخسارة'),m(result.profit)]]},
 {title:l('Balance Sheet','الميزانية العمومية'),headers:[l('Code','الرمز'),l('Account','الحساب'),l('Closing AED','الرصيد الختامي بالدرهم')],rows:[...balanceRows('ASSET'),['',l('Total assets','إجمالي الأصول'),m(result.assets)],...balanceRows('LIABILITY'),['',l('Total liabilities','إجمالي الالتزامات'),m(result.liabilities)],...balanceRows('EQUITY'),['',l('Recorded equity','حقوق الملكية المسجلة'),m(result.equity)],['',l('Unclosed cumulative profit / loss','الأرباح / الخسائر التراكمية غير المقفلة'),m(result.unclosedResult)],['',l('Liabilities + equity + unclosed result','الالتزامات + حقوق الملكية + النتيجة غير المقفلة'),m(String(BigInt(result.liabilities)+BigInt(result.equity)+BigInt(result.unclosedResult)))]]}
 ]};
}
