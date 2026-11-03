import {Link} from 'react-router-dom';
import {Plus,ArrowUpRight,FolderKanban,HardHat,BookOpen} from 'lucide-react';
import {useAuth} from '../auth/AuthContext';
import {useWorkspaceSubscription} from './workspaceSubscriptionContext';
import {useWorkspaceText} from './useWorkspaceText';
import {canPostExpense} from '../financial/expensePostRepository';
import {canPostSupplierPayment} from '../financial/supplierPaymentPostRepository';
export function WorkspaceQuickActions({compact=false}:{compact?:boolean}){
 const {state}=useAuth(),s=useWorkspaceSubscription(),t=useWorkspaceText();if(state.phase!=='TENANT_READY')return null;
 const Heading=compact?'h2':'h1';
 const verified=s?.companyId===state.activeTenant.companyId&&s.loaded&&!!s.row;
 const full=verified&&s.row?.access==='FULL';const role=state.activeTenant.role;
 return <section className={"workspace-quick-actions"+(compact?" cycle-compact-actions":"")} aria-label={t('quickActions')}><div><small>{t('quickActions')}</small><Heading>{t('dashboardTitle')}</Heading><p>{t('dashboardIntro')}</p></div><div className="workspace-action-links">
 {canPostExpense(role)&&(full?<Link className="workspace-action-primary" to="/expenses#new-expense"><Plus size={17} aria-hidden="true"/>{t('newExpense')}</Link>:<span className="workspace-action-disabled" aria-disabled="true" title={t(verified?'subscriptionRequired':'subscriptionChecking')}><Plus size={17} aria-hidden="true"/>{t('newExpense')}</span>)}
 {canPostSupplierPayment(role)&&(verified?<Link to="/supplier-payments"><ArrowUpRight size={17} aria-hidden="true"/>{t('recordPayment')}</Link>:<span className="workspace-action-disabled" aria-disabled="true">{t('recordPayment')}</span>)}
 {role!=='SYSTEM_ADMIN'&&<Link to="/projects"><FolderKanban size={17} aria-hidden="true"/>{t('openProjects')}</Link>}
 {['ACCOUNTING_ADMIN','ACCOUNTANT','MANAGEMENT_VIEWER','PROCUREMENT','PROJECT_MANAGER'].includes(role)&&<Link to="/subcontracts"><HardHat size={17} aria-hidden="true"/>{t('openContracts')}</Link>}
 <Link to="/accounting-cycle"><BookOpen size={17} aria-hidden="true"/>{t('cycle')}</Link></div>
 {canPostExpense(role)&&!verified&&<p className="workspace-action-note">{t('subscriptionUnknown')}</p>}
 {verified&&s.row?.access==='LIMITED'&&<p className="workspace-action-note">{t('subscriptionLimited')}</p>}
 </section>;
}
