import {PartyStatement} from '../reports/PartyStatement';
import {ProjectCostLedger} from '../reports/ProjectCostLedger';
import {useAuth} from '../auth/AuthContext';
import {useI18n} from '../i18n/I18nContext';
import {ReportExport} from '../reports/ReportExport';
import {postedJournalReport} from '../reports/postedJournalReport';
import {postedExpenseReport} from '../reports/postedExpenseReport';
import {isAccountingReader} from './workspaceNavigation';
import {useWorkspaceText} from './useWorkspaceText';
export function WorkspaceReports(){const {state}=useAuth(),{locale}=useI18n(),t=useWorkspaceText();if(state.phase!=='TENANT_READY')return null;if(!isAccountingReader(state.activeTenant.role))return <p role="alert">{t('dashboardUnavailable')}</p>;const {companyId,companyName}=state.activeTenant;
 return <section><p className="suite-scope-note">{t('reportsIntro')}</p><div className="workspace-report-grid"><article><h2>{t('postedExport')}</h2><p>{t('exportScope')}</p><ReportExport build={()=>postedJournalReport(companyId,companyName,locale)}/></article><article><h2>{t('expenseExport')}</h2><p>{t('exportScope')}</p><ReportExport build={()=>postedExpenseReport(companyId,companyName,locale)}/></article></div><PartyStatement/><ProjectCostLedger/><p className="workspace-guidance">{t('statementGap')}</p></section>;
}
