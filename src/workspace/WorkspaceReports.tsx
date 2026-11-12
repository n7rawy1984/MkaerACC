import {useSearchParams,Link} from 'react-router-dom';
import {AccountingPeriodReport} from '../dashboard/AccountingPeriodReport';
import {validMonth} from '../dashboard/monthlyFinancialModel';
import {useProductionMasterData} from '../master/productionMasterDataContext';
import {CustodyReconciliation} from '../reports/CustodyReconciliation';
import {PartyStatement} from '../reports/PartyStatement';
import {ProjectCostLedger} from '../reports/ProjectCostLedger';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {ReportExport} from '../reports/ReportExport';
import {postedJournalReport} from '../reports/postedJournalReport';
import {postedExpenseReport} from '../reports/postedExpenseReport';
import {isAccountingReader} from './workspaceNavigation';
import {useWorkspaceText} from './useWorkspaceText';
export function WorkspaceReports(){const {state}=useAuth(),{locale}=useI18n(),t=useWorkspaceText(),master=useProductionMasterData(),[query]=useSearchParams();if(state.phase!=='TENANT_READY')return null;if(!isAccountingReader(state.activeTenant.role))return <p role="alert">{t('dashboardUnavailable')}</p>;const {companyId,companyName}=state.activeTenant;
 if(query.get('view')==='transactions'){
  if(master.phase!=='READY'||master.company.id!==companyId)return <p role="status">{locale==='ar'?'جار تحميل التقارير…':'Loading reports…'}</p>;
  const m=query.get('month')??'',month=validMonth(m)&&m>='0002-01'&&m<='9998-12'?m:undefined;
  const status=query.get('status')??'ALL',safeStatus=['ALL','POSTED','DRAFT','CLASSIFIED_UNPOSTED','UNCLASSIFIED','NEEDS_REVIEW','POSSIBLE_DUPLICATE'].includes(status)?status:'ALL';
  return <section><Link className="cycle-report-link" to="/accounting-reports">{locale==='ar'?'كل التقارير':'All reports'}</Link><AccountingPeriodReport key={companyId+state.activeTenant.role+query.toString()} user={state.profile.userId} company={companyId} companyName={companyName} role={state.activeTenant.role} locale={locale} revision={0} projects={master.projects} initialMonth={month} initialFilters={{domain:query.get('domain')==='SOURCES'?'SOURCES':'JOURNALS',status:safeStatus,search:(query.get('search')??'').slice(0,100),unknown:query.get('unknown')==='true'}}/></section>;
 }
 return <section><Link className="cycle-report-link" to="/accounting-reports?view=transactions">{locale==='ar'?'كل المعاملات والتقارير الشهرية':'All transactions & monthly reports'}</Link><p className="suite-scope-note">{t('reportsIntro')}</p><div className="workspace-report-grid"><article><h2>{t('postedExport')}</h2><p>{t('exportScope')}</p><ReportExport build={()=>postedJournalReport(companyId,companyName,locale)}/></article><article><h2>{t('expenseExport')}</h2><p>{t('exportScope')}</p><ReportExport build={()=>postedExpenseReport(companyId,companyName,locale)}/></article></div><CustodyReconciliation/><PartyStatement/><ProjectCostLedger/><p className="workspace-guidance">{t('statementGap')}</p></section>;
}
