import {ThemeSwitcher} from '../theme/ThemeSwitcher';
import { useEffect, useRef, useState, type ReactNode } from "react";
import { Link, NavLink, useLocation } from "react-router-dom";
import { ArrowUpRight, Building2, ChevronRight, CreditCard, Fingerprint, LayoutDashboard, LogOut, Mail, Menu, ScrollText, Settings2, ShieldCheck, Users, UsersRound, X } from "lucide-react";
import { LanguageButton } from "../auth/AuthFrame";
import { usePlatformText } from "./usePlatformText";
import { type PlatformTextKey, platformText } from "./platformText";
const groups = [
  { label: "workspaceGroup", items: [{ key: "overview", icon: LayoutDashboard }, { key: "onboarding", icon: ShieldCheck }, { key: "customers", icon: UsersRound }, { key: "entities", icon: Building2 }] },
  { label: "accessGroup", items: [{ key: "users", icon: Users }, { key: "memberships", icon: Fingerprint }, { key: "invitations", icon: Mail }] },
  { label: "operationsGroup", items: [{ key: "subscriptions", icon: CreditCard }, { key: "audit", icon: ScrollText }, { key: "settings", icon: Settings2 }] }
] as const;
export function PlatformShell({ children, signOut }: { children: ReactNode; signOut: () => void }) {
  const t = usePlatformText(); const { pathname } = useLocation(); const menu = useRef<HTMLDialogElement>(null); const trigger = useRef<HTMLButtonElement>(null);
  const [mobileOpen, setMobileOpen] = useState(false);
  useEffect(() => { if (mobileOpen) menu.current?.showModal(); }, [mobileOpen]);
  const tab = pathname.split("/")[2] || "overview"; const title = Object.hasOwn(platformText.en, tab) ? t(tab === "onboarding" ? "commercialOnboarding" : tab as PlatformTextKey) : t("overview");
  const navigation = (mobile = false) => <><Link className="platform-brand" to="/platform" onClick={() => menu.current?.close()}><span className="platform-brand-symbol"><LayersMark/></span><span>NARVO <small>ERP</small><em>{t("ownerConsole")}</em></span></Link>
    <nav aria-label={t("title")}>{groups.map(group => <div className="platform-nav-group" key={group.label}><p>{t(group.label)}</p>{group.items.map(({ key, icon: Icon }) => <NavLink key={key} to={key === "overview" ? "/platform" : `/platform/${key}`} end={key === "overview"} onClick={() => { if (mobile) menu.current?.close(); }}><Icon size={19} aria-hidden="true"/>{t(key === "onboarding" ? "commercialOnboarding" : key)}</NavLink>)}</div>)}</nav>
    <div className="platform-sidebar-footer"><div className="platform-owner-card"><span><ShieldCheck size={18} aria-hidden="true"/></span><div><strong>{t("platformOwner")}</strong><small>{t("protectedAdministration")}</small></div></div><Link to="/" onClick={() => menu.current?.close()}>{t("accounting")}<ArrowUpRight size={16} aria-hidden="true"/></Link><button onClick={signOut}><LogOut size={16} aria-hidden="true"/>{t("signOut")}</button></div></>;
  return <div className="platform-app"><a className="platform-skip" href="#platform-main">{t("skipContent")}</a>
    <aside className="platform-sidebar">{navigation()}</aside>
    {mobileOpen && <dialog ref={menu} className="platform-navigation-dialog" aria-labelledby="platform-nav-title" onClose={() => { setMobileOpen(false); trigger.current?.focus(); }}><header><h2 id="platform-nav-title">{t("navigation")}</h2><button onClick={() => menu.current?.close()} aria-label={t("closeNavigation")}><X size={20} aria-hidden="true"/></button></header>{navigation(true)}</dialog>}
    <div className="platform-workspace"><header className="platform-topbar"><div className="platform-breadcrumb"><button className="platform-menu-toggle" ref={trigger} onClick={() => setMobileOpen(true)} aria-label={t("openNavigation")} aria-haspopup="dialog"><Menu size={21} aria-hidden="true"/></button><span>{t("ownerConsole")}</span><ChevronRight size={14} className="platform-directional" aria-hidden="true"/><strong>{title}</strong></div><div className="platform-topbar-actions"><span className="platform-protected"><ShieldCheck size={15} aria-hidden="true"/>{t("protectedAdministration")}</span><ThemeSwitcher/><LanguageButton/><span className="platform-avatar" aria-hidden="true"><UsersRound size={19} aria-hidden="true"/></span></div></header>
      <main id="platform-main" tabIndex={-1}>{children}</main><footer className="platform-app-footer"><span>NARVO ERP</span><span>{t("administrationOnly")}</span></footer>
    </div>
  </div>;
}
function LayersMark() { return <svg width="24" height="24" viewBox="0 0 24 24" fill="none" aria-hidden="true"><path d="m4 8 8-4 8 4-8 4-8-4Zm0 5 8 4 8-4M4 18l8 4 8-4" stroke="currentColor" strokeWidth="1.8" strokeLinecap="round" strokeLinejoin="round"/></svg>; }
