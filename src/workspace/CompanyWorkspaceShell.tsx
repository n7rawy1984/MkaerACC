import './workspaceLayouts.css';
import {ThemeSwitcher} from '../theme/ThemeSwitcher';
import {workspaceBusinessAccess} from './workspaceBusinessAccess';
import {useEffect,useRef,useState,type ReactNode} from 'react';
import {Link,NavLink,useLocation} from 'react-router-dom';
import {Building2,ChevronDown,Menu,LogOut,ArrowLeftRight,ShieldCheck,Plus,CalendarDays} from 'lucide-react';
import {NarvoMark} from '../components/ui/NarvoMark';
import {moduleIcon} from './moduleIcons';
import {useProductionMasterData} from '../master/productionMasterDataContext';
import {useAuth} from '../auth/AuthContext';
import {useT,useI18n} from '../i18n/I18nContext';
import {roleLabel} from '../i18n/roleLabels';
import {LanguageButton} from '../auth/AuthFrame';
import {useTenantSettings} from '../tenant/TenantSettingsContext';
import {TenantBrandMark} from '../tenant/TenantBrandMark';
import {CompanySubscriptionStatus} from '../master/CompanySubscriptionStatus';
import {CompanyAccountingSetupStatus} from '../master/CompanyAccountingSetupStatus';
import {canPostExpense} from '../financial/expensePostRepository';
import {useWorkspaceSubscription} from './workspaceSubscriptionContext';
import {navigationForRole} from './workspaceNavigation';
import {useWorkspaceText} from './useWorkspaceText';
import {useWorkspaceUiText} from './useWorkspaceUiText';
import {PageHeader,WorkspaceDrawer} from './workspaceUi';
import './workspace.css';
import './workspaceSuite.css';
export function CompanyWorkspaceShell({children}:{children:ReactNode}){
 const {locale}=useI18n();
 const {state,showCompanySelector,signOut}=useAuth(),branding=useTenantSettings(),master=useProductionMasterData(),t=useWorkspaceText(),u=useWorkspaceUiText(),authText=useT(),{pathname}=useLocation(),subscription=useWorkspaceSubscription();
 const [open,setOpen]=useState(false);const trigger=useRef<HTMLButtonElement>(null);
 useEffect(()=>{window.scrollTo({top:0});},[pathname]);
 if(state.phase!=='TENANT_READY')return null;
 const {activeTenant:tenant}=state;const groups=navigationForRole(tenant.role);const current=groups.flatMap(g=>g.items).find(i=>i.path===pathname),group=groups.find(g=>g.items.some(i=>i.path===pathname));
 const name=branding.phase==='READY'?branding.settings.effectiveDisplayName:tenant.companyName;
 const identity=master.phase==='READY'&&master.company.id===tenant.companyId ? master.company.legalName ? `${master.company.name} · ${master.company.legalName}` : master.company.name : tenant.companyLegalName??tenant.companyName;
 const verified=subscription?.companyId===tenant.companyId&&subscription.loaded&&!!subscription.row;
 const newExpense=pathname==='/expenses'&&canPostExpense(tenant.role);
 const actions=newExpense?(workspaceBusinessAccess(subscription,tenant.companyId)==='FULL'?<a className="suite-primary" href="#new-expense" onClick={()=>{const d=document.getElementById('new-expense');if(d instanceof HTMLDetailsElement)d.open=true;}}><Plus size={16} aria-hidden="true"/>{u('newExpense')}</a>:<span className="suite-disabled" aria-disabled="true" title={u(verified?'renew':'unverified')}>{u('newExpense')}</span>):null;
 const navigation=<><Link className="workspace-brand" to="/"><span className="workspace-brand-icon"><NarvoMark/></span><span>NARVO <small>ERP</small><em>{t('workspace')}</em></span></Link>
 <div className="workspace-tenant" title={identity}><TenantBrandMark logoUrl={branding.phase==='READY'?branding.settings.logoUrl:null}/><div><small>{t('currentCompany')}</small><strong><bdi>{name}</bdi></strong><span><bdi dir="ltr">{tenant.companyCode}</bdi></span></div></div>
 <nav aria-label={t('navigation')}>{groups.map(g=>{const Icon=moduleIcon(g.label);return <details className="workspace-nav-group" key={g.label} open={g.items.some(i=>i.path===pathname)||g.label==='dashboard'}><summary><Icon size={17} aria-hidden="true"/><span>{t(g.label)}</span><ChevronDown size={15} aria-hidden="true"/></summary><div>{g.items.map(item=>{const ItemIcon=moduleIcon(item.path);return <NavLink end key={item.path} to={item.path}><ItemIcon size={17} aria-hidden="true"/><span>{t(item.label)}</span></NavLink>;})}</div></details>;})}</nav>
 <div className="workspace-sidebar-footer"><span><ShieldCheck size={15} aria-hidden="true"/>{t('companyScoped')}</span></div></>;
 return <div className="company-workspace workspace-suite"><a className="workspace-skip" href="#company-workspace-main">{t('skip')}</a><aside className="workspace-sidebar">{navigation}</aside>
 {open&&<WorkspaceDrawer title={t('navigation')} closeLabel={t('closeNavigation')} onClose={()=>{setOpen(false);trigger.current?.focus();}}>{navigation}</WorkspaceDrawer>}
 <div className="workspace-content"><header className="workspace-topbar"><div className="suite-company-control"><button ref={trigger} className="workspace-menu-toggle" type="button" onClick={()=>setOpen(true)} aria-label={t('openNavigation')} aria-haspopup="dialog"><Menu size={20} aria-hidden="true"/></button><Building2 size={18} aria-hidden="true"/><div title={identity}><small>{u('company')}</small><strong><bdi>{name}</bdi><span><bdi dir="ltr">{tenant.companyCode}</bdi></span></strong></div>{state.memberships.length>1&&<button onClick={showCompanySelector} className="workspace-switch" aria-label={t('switchCompany')} title={t('switchCompany')}><ArrowLeftRight size={16} aria-hidden="true"/></button>}</div><div className="workspace-topbar-actions"><ThemeSwitcher/><LanguageButton/><details className="suite-account-menu" onKeyDown={e=>{if(e.key==='Escape'){e.currentTarget.open=false;e.currentTarget.querySelector('summary')?.focus();}}} onBlur={e=>{if(!e.currentTarget.contains(e.relatedTarget as Node))e.currentTarget.open=false;}}><summary aria-label={u('account')}><span className="suite-avatar" aria-hidden="true">{state.profile.displayName?.slice(0,1)||'N'}</span><span><strong><bdi>{state.profile.displayName}</bdi></strong><small>{tenant.role==='MANAGEMENT_VIEWER'?u('readonly'):roleLabel(tenant.role,locale)}</small></span><ChevronDown size={13} aria-hidden="true"/></summary><div><p><bdi>{state.profile.displayName}</bdi></p><p>{roleLabel(tenant.role,locale)}</p><button type="button" onClick={()=>void signOut()}><LogOut size={15} aria-hidden="true"/>{t('signOut')}</button></div></details></div></header>
 <div className="workspace-status" role="region" aria-label={u('notices')}>{(branding.phase==='MISSING'||branding.phase==='ERROR')&&<p role="alert">{authText('auth.tenantSettingsUnavailable')}</p>}{branding.phase==='LOADING'&&<p role="status">{authText('auth.loadingTenantSettings')}</p>}<CompanySubscriptionStatus companyId={tenant.companyId} compact={pathname==='/'}/><CompanyAccountingSetupStatus key={`${state.profile.userId}:${tenant.companyId}`} companyId={tenant.companyId}/></div>
 <main className={'workspace-layout-'+(pathname==='/'?'dashboard':pathname==='/company-profile'?'form':pathname.startsWith('/accounting-reports')?'report':'data')} id="company-workspace-main" tabIndex={-1}>{pathname!=='/'&&<PageHeader title={current?t(current.label):t('workspace')} breadcrumb={group?t(group.label):t('workspace')} description={pathname==='/expenses'?u('sourceHint'):['/attendance','/payroll'].includes(pathname)?u('periodHint'):undefined} actions={actions}/>} {['/attendance','/payroll'].includes(pathname)&&<p className="suite-period-context"><CalendarDays size={14} aria-hidden="true"/>{u('noPeriod')}</p>}<div className="workspace-route-body" data-route={pathname}>{children}</div></main><footer className="workspace-footer"><span>NARVO ERP</span><span>{t('footer')}</span></footer></div></div>;
}
