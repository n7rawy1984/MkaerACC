import {statementType} from '../reports/partyStatement';
import {formatFinancialDate,reportingMonthLabel} from '../historical/sourceDatePresentation';
import {moneyCell,type FinancialReport,type ReportCell} from '../reports/reportExport';
import {financialMetricKeys,monthlyJournalEntries,sourceMonthlySummary,unconfirmedSources,type FinancialMonth,type MonthlyScope} from './monthlyFinancialModel';
import {financialMetricText,monthlyFinancialText} from './monthlyFinancialText';
import type {MonthlyFinancialData} from './monthlyFinancialRead';
import type {SourceRecord,ReportingBasis} from '../historical/sourceModel';
export function monthlyFinancialReport(data:MonthlyFinancialData,rows:FinancialMonth[],sources:SourceRecord[],scope:MonthlyScope,basis:ReportingBasis,company:string,locale:'en'|'ar'):FinancialReport{
 const ar=locale==='ar',t=monthlyFinancialText[locale],metric=(key:typeof financialMetricKeys[number])=>financialMetricText[key][ar?1:0],visible=(key:string)=>!key.startsWith('custody')||data.custodyComplete,hr=(key:string)=>!['employeeAdvances','payrollCost','payrollPayments'].includes(key)||data.payrollVisible;
 const cell=(key:string,value:string):ReportCell=>visible(key)&&hr(key)?moneyCell(value):t.restricted;
 const relevant=monthlyJournalEntries(data,scope);
 return{company,locale,title:t.title,period:reportingMonthLabel(scope.from,locale)+' — '+reportingMonthLabel(scope.through,locale),generated:data.captured,filename:'monthly-financial-'+scope.from+'-'+scope.through+'-'+locale,note:t.note+' '+t.custodyNote+' '+t.projectNote+' '+t.periodNote+' '+t.project+': '+scope.project+'; '+t.holder+': '+scope.holder+'; '+t.basis+': '+(basis==='DATE'?t.date:t.provenance),sections:[
 {title:t.posted,headers:[t.netLabel,...financialMetricKeys.map(metric),t.custodyOpening,t.custodyClosing,t.treasuryOpening,t.treasuryClosing,t.journals,t.stockMovements,t.payrollPeriods],rows:rows.map(r=>[reportingMonthLabel(r.month,locale),...financialMetricKeys.map(k=>cell(k,r.values[k])),cell('custody',r.custodyOpening),cell('custody',r.custodyClosing),moneyCell(r.treasuryOpening),moneyCell(r.treasuryClosing),r.journals,r.stockMovements,data.payrollVisible?r.payrollPeriods:t.restricted])},
 {title:t.imported,headers:[t.from,t.sourceIn,t.sourceOut,t.sourcePayroll,t.unclassified,t.unposted,t.linked],rows:rows.map(r=>{const s=sourceMonthlySummary(sources,data.company,r.month,basis,scope.project);return[reportingMonthLabel(r.month,locale),s.inflowCount&&!s.unknownAmounts?moneyCell(s.inflow):t.sourceEmpty,s.outflowCount&&!s.unknownAmounts?moneyCell(s.outflow):t.sourceEmpty,data.payrollVisible?s.payrollCount&&!s.unknownAmounts?moneyCell(s.payroll):t.sourceEmpty:t.restricted,s.unclassified,s.unposted,s.posted];})},
 {title:t.unknown,headers:[t.document,t.date],rows:unconfirmedSources(sources).filter(r=>scope.project==='ALL'||(scope.project==='COMPANY'?!r.assigned_project_id:r.assigned_project_id===scope.project)).map(r=>[r.source_reference,t.unknown])},
 {title:t.details,headers:[t.dateLabel,t.journal,t.type,t.document,t.sourceLink],rows:relevant.map(e=>[formatFinancialDate(e.posting_date,locale),e.journal_reference,statementType(e.source_type,ar),e.source_id,sources.filter(s=>s.source_document?.receipt?.journal===e.id||s.expense?.posted_journal_entry_id===e.id).map(s=>s.source_reference).join(' · ')])}
 ]};
}
