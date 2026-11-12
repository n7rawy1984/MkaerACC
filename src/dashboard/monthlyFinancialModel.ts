import {cycleMonths} from '../workspace/metricState';
import {sourceAccounting,sourceCurrentAmount,sourceDirection,sourceReportingMonth,sourceTransactionDate,type SourceRecord,type ReportingBasis} from '../historical/sourceModel';
import {validFinancialDate} from '../historical/sourceDatePresentation';
import {validatePostedLedger} from '../reports/postedLedgerRead';
import {custodyMovementKind} from '../reports/custodyReconciliation';
import type {MonthlyFinancialData} from './monthlyFinancialRead';
export const financialMetricKeys=['treasuryIn','treasuryOut','cashChange','bankChange','custodyFunding','custodyPayments','custodyReturns','custodyOther','operating','projectCost','contractAdvances','contractSettlements','employeeAdvances','payrollCost','payrollPayments','stockValue'] as const;
export type FinancialMetricKey=typeof financialMetricKeys[number];
export type FinancialMonth={month:string;values:Record<FinancialMetricKey,string>;custodyOpening:string;custodyClosing:string;treasuryOpening:string;treasuryClosing:string;journals:number;stockMovements:number;payrollPeriods:number};
export type MonthlyScope={from:string;through:string;project:string;holder:string};
export const validMonth=(m:string)=>/^\d{4}-(0[1-9]|1[0-2])$/.test(m)&&validFinancialDate(m+'-01');
export function monthlyRange(from:string,through:string){const range=cycleMonths(from,through);if(!range.length)throw Error('Choose a valid month range');return range;}

export function discoverFinancialMonths(data:MonthlyFinancialData|undefined,sources:SourceRecord[],basis:ReportingBasis='DATE'){
 const months=new Set<string>();for(const r of sources){if(r.review_status==='CANCELLED')continue;const m=sourceReportingMonth(r,basis);if(validMonth(m))months.add(m);}
 for(const e of data?.entries??[])months.add(e.posting_date.slice(0,7));for(const s of data?.stock??[])if(validFinancialDate(s.movement_date))months.add(s.movement_date.slice(0,7));for(const p of data?.payroll??[])if(validFinancialDate(p.month))months.add(p.month.slice(0,7));return [...months].filter(validMonth).sort();
}
export function sourceMonthlySummary(rows:SourceRecord[],company:string,month:string,basis:ReportingBasis,project='ALL'){
 if(new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Duplicate source record');
 let inflow=0n,outflow=0n,payroll=0n;let unclassified=0,unposted=0,posted=0,count=0,unknownAmounts=0,inflowCount=0,outflowCount=0,payrollCount=0;
 for(const r of rows){if(r.company_id!==company)throw Error('Source Company scope mismatch');if(r.review_status==='CANCELLED'||project!=='ALL'&&(project==='COMPANY'?r.assigned_project_id!==null&&r.assigned_project_id!==undefined:r.assigned_project_id!==project)||sourceReportingMonth(r,basis)!==month)continue;count++;if(r.record_type==='PAYROLL')payrollCount++;else if(sourceDirection(r)==='IN')inflowCount++;else if(sourceDirection(r)==='OUT')outflowCount++;const a=sourceCurrentAmount(r);if(a===null||!/^\d+$/.test(a))unknownAmounts++;else {const n=BigInt(a);if(r.record_type==='PAYROLL')payroll+=n;else if(sourceDirection(r)==='IN')inflow+=n;else if(sourceDirection(r)==='OUT')outflow+=n;}
 const state=sourceAccounting(r);if(state==='POSTED'||state==='RECLASSIFIED')posted++;else unposted++;if(state==='UNCLASSIFIED')unclassified++;
 }
 return{count,inflowCount,outflowCount,payrollCount,inflow:String(inflow),outflow:String(outflow),payroll:String(payroll),unclassified,unposted,posted,unknownAmounts};
}
export function unconfirmedSources(rows:SourceRecord[]){return rows.filter(r=>r.review_status!=='CANCELLED'&&r.record_type==='GENERAL'&&!sourceTransactionDate(r));}
export function summarizeFinancialMonths(data:MonthlyFinancialData,scope:MonthlyScope):FinancialMonth[]{
 validatePostedLedger(data.company,data.entries,data.lines);
 for(const rows of [data.accounts,data.parties,data.projects,data.treasuries,data.stock,data.locations,data.payroll])if(rows.some(r=>r.company_id!==data.company)||new Set(rows.map(r=>r.id)).size!==rows.length)throw Error('Monthly financial Company/duplicate scope mismatch');
 if(scope.project!=='ALL'&&scope.project!=='COMPANY'&&!data.projects.some(p=>p.id===scope.project)||scope.holder!=='ALL'&&!data.parties.some(p=>p.id===scope.holder))throw Error('Unknown report dimension');
 const accounts=new Map(data.accounts.map(a=>[a.id,a])),entries=new Map(data.entries.map(e=>[e.id,e]));
 const treasury=new Map(data.treasuries.map(t=>[t.gl_account_id,t]));if(treasury.size!==data.treasuries.length)throw Error('Duplicate Treasury GL mapping');
 const months=monthlyRange(scope.from,scope.through),result=months.map(month=>({month,values:Object.fromEntries(financialMetricKeys.map(k=>[k,'0'])) as Record<FinancialMetricKey,string>,custodyOpening:'0',custodyClosing:'0',treasuryOpening:'0',treasuryClosing:'0',journals:0,stockMovements:0,payrollPeriods:0})),byMonth=new Map(result.map(r=>[r.month,r]));
 const journals=new Map<string,Set<string>>();let custodyBefore=0n,treasuryBefore=0n;const custodyDelta=new Map<string,bigint>(),treasuryDelta=new Map<string,bigint>();
 const inProject=(id:string|null)=>scope.project==='ALL'||(scope.project==='COMPANY'?id===null:id===scope.project);
 const add=(r:FinancialMonth,key:FinancialMetricKey,n:bigint)=>{r.values[key]=String(BigInt(r.values[key])+n);};
 for(const l of data.lines){const e=entries.get(l.journal_entry_id)!,a=accounts.get(l.account_id);if(!a||l.project_id&&!data.projects.some(p=>p.id===l.project_id))throw Error('Missing account or Project');if(!inProject(l.project_id))continue;
 const original=e.reversal_of_journal_entry_id?entries.get(e.reversal_of_journal_entry_id)!:e,type=original.source_type,m=e.posting_date.slice(0,7),r=byMonth.get(m),net=BigInt(l.debit_minor)-BigInt(l.credit_minor),t=treasury.get(a.id),custody=a.system_key==='CUSTODY_ADVANCE'&&(scope.holder==='ALL'||l.party_id===scope.holder);
 if(custody){if(a.account_type!=='ASSET')throw Error('Invalid Custody control');if(m<scope.from)custodyBefore+=net;if(r)custodyDelta.set(m,(custodyDelta.get(m)??0n)+net);}
 if(t){if(a.account_type!=='ASSET')throw Error('Invalid Treasury control');if(m<scope.from)treasuryBefore+=net;if(r)treasuryDelta.set(m,(treasuryDelta.get(m)??0n)+net);}
 if(!r)continue;const set=journals.get(m)??new Set<string>();set.add(e.id);journals.set(m,set);
 if(t){add(r,net>=0n?'treasuryIn':'treasuryOut',net>=0n?net:-net);add(r,['CASH','PETTY_CASH','PROJECT_CASH_BOX'].includes(t.type)?'cashChange':'bankChange',net);}
 if(custody){const kind=custodyMovementKind(type);if(kind==='FUNDING')add(r,'custodyFunding',net);else if(kind==='SPENDING')add(r,'custodyPayments',-net);else if(kind==='RETURN')add(r,'custodyReturns',-net);else add(r,'custodyOther',net);}
 if(a.account_type==='EXPENSE'){if(l.project_id)add(r,'projectCost',net);else if(type!=='PAYROLL')add(r,'operating',net);if(type==='PAYROLL'&&data.payrollVisible)add(r,'payrollCost',net);}
 if(a.system_key==='SUBCONTRACTOR_ADVANCE')add(r,'contractAdvances',net);
 if(['SUBCONTRACTOR_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE'].includes(a.system_key??'')&&['SUBCONTRACTOR_PAYMENT','SUBCONTRACTOR_RETENTION_PAYMENT'].includes(type))add(r,'contractSettlements',net);
 if(type==='HR_EMPLOYEE_ADVANCE'&&a.account_type==='ASSET'&&a.system_key!=='CUSTODY_ADVANCE'&&!t&&data.payrollVisible)add(r,'employeeAdvances',net);
 if(type==='SALARY_PAYMENT'&&a.system_key==='SALARY_PAYABLE'&&data.payrollVisible)add(r,'payrollPayments',net);
 if(type.startsWith('INVENTORY_')&&!data.inventoryAccount)throw Error('Missing canonical inventory asset configuration');
 if(a.id===data.inventoryAccount)add(r,'stockValue',net);
 }
 for(const movement of data.stock){if(!validFinancialDate(movement.movement_date))throw Error('Invalid stock movement date');const location=data.locations.find(l=>l.id===movement.location_id);if(!location)throw Error('Missing stock location');if(inProject(location.project_id)){const row=byMonth.get(movement.movement_date.slice(0,7));if(row)row.stockMovements++;}}
 for(const period of data.payroll){if(!validFinancialDate(period.month))throw Error('Invalid payroll period');const entry=entries.get(period.journal_id);if(!entry)throw Error('Missing payroll journal');if(scope.project!=='ALL'&&!data.lines.some(l=>l.journal_entry_id===entry.id&&inProject(l.project_id)))continue;const r=byMonth.get(period.month.slice(0,7));if(r)r.payrollPeriods++;}
 for(const r of result){r.custodyOpening=String(custodyBefore);custodyBefore+=custodyDelta.get(r.month)??0n;r.custodyClosing=String(custodyBefore);r.treasuryOpening=String(treasuryBefore);treasuryBefore+=treasuryDelta.get(r.month)??0n;r.treasuryClosing=String(treasuryBefore);r.journals=journals.get(r.month)?.size??0;}
 return result;
}

export function monthlyJournalEntries(data:MonthlyFinancialData,scope:MonthlyScope){return data.entries.filter(e=>e.posting_date.slice(0,7)>=scope.from&&e.posting_date.slice(0,7)<=scope.through&&(scope.project==='ALL'||data.lines.some(l=>l.journal_entry_id===e.id&&(scope.project==='COMPANY'?l.project_id===null:l.project_id===scope.project)))).sort((a,b)=>a.posting_date.localeCompare(b.posting_date)||a.journal_reference.localeCompare(b.journal_reference)||a.id.localeCompare(b.id));}
