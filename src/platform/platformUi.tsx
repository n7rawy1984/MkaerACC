import { statusTone } from "../components/ui/statusTone";
import type { ReactNode } from "react";
import { ArrowUpRight, Building2, CheckCheck, CircleHelp, Inbox, Layers3, Mail, ShieldCheck, Users } from "lucide-react";
import { Link } from "react-router-dom";
import { useI18n } from "../i18n/I18nContext";
import { platformText, type PlatformTextKey } from "./platformText";
import type { PlatformRow } from "./platformApi";

import { usePlatformText } from "./usePlatformText";
const statusFields = new Set(["lifecycle", "state", "status", "onboarding", "accounting_setup", "effective_state", "subscription_access", "delivery", "payment_status", "plan_key", "role", "entity_kind"]);
export function StatusBadge({ status, children }: { status: string; children: ReactNode }) {
  return <span className={`platform-badge erp-badge erp-badge-${statusTone(status)}`}><span className="platform-badge-dot" aria-hidden="true"/>{children}</span>;
}
export function DirectoryCell({ row, field, showCode = false }: { row: PlatformRow; field: string; showCode?: boolean }) {
  const t = usePlatformText(); const { locale } = useI18n(); const raw = row[field];
  if (raw === null || raw === undefined || raw === "") return <span className="platform-muted">—</span>;
  const text = String(raw); const label = Object.hasOwn(platformText.en, text) ? t(text as PlatformTextKey) : text;
  if (statusFields.has(field)) return <StatusBadge status={text}>{label}</StatusBadge>;
  if (typeof raw === "object") return <details className="platform-event-detail"><summary>{t("eventDetails")}</summary><pre>{JSON.stringify(raw, null, 2)}</pre></details>;
  if (["created_at", "expires_at", "starts_on", "ends_on", "renewal_due_on"].includes(field) && Number.isFinite(Date.parse(text))) {
    return <time dateTime={text}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-AE" : "en-GB", { dateStyle: "medium", timeZone: field.endsWith("_on") ? "UTC" : "Asia/Dubai" }).format(new Date(text))}</time>;
  }
  if (field === "name" || field === "company_name") return <span className="platform-record-name"><bdi>{label}</bdi>{showCode && field === "name" && row.code && <small><bdi>{String(row.code)}</bdi></small>}</span>;
  return <bdi className={field.endsWith("_id") ? "platform-reference" : undefined}>{label}</bdi>;
}
export function LoadingState() {
  const t = usePlatformText(); return <section className="platform-loading" role="status" aria-busy="true"><span className="platform-loading-label">{t("loading")}</span><div className="platform-skeletons" aria-hidden="true">{[0, 1, 2].map(i => <div key={i}/>)}</div></section>;
}
export function EmptyState({ reset }: { reset: () => void }) {
  const t = usePlatformText(); return <section className="platform-empty"><Inbox size={30} aria-hidden="true"/><h2>{t("empty")}</h2><p>{t("emptyHelp")}</p><button onClick={reset}>{t("clearFilters")}</button></section>;
}
export function PageHelp({ children }: { children: ReactNode }) {
  const t = usePlatformText(); return <details className="platform-help"><summary><CircleHelp size={16} aria-hidden="true"/>{t("workflowHelp")}</summary><div>{children}</div></details>;
}
export function PlatformOverview({ data }: { data: Record<string, unknown> }) {
  const t = usePlatformText(); const { locale } = useI18n();
  // readPlatformOverview has already validated all nine nonnegative integer counts.
  const count = (key: string) => data[key] as number;
  const format = (n: number) => new Intl.NumberFormat(locale).format(n);
  const segments = [{ key: "ACTIVE", count: count("active"), tone: "active" }, { key: "SUSPENDED", count: count("suspended"), tone: "suspended" }, { key: "ARCHIVED", count: count("archived"), tone: "archived" }, { key: "otherStates", count: Math.max(0, count("entities") - count("active") - count("suspended") - count("archived")), tone: "other" }] as const;
  const total = count("entities");
  return <div className="platform-overview">
    <section className="platform-stats" aria-label={t("platformMetrics")}>
      {[{ key: "entities", icon: Building2, note: "registeredCompanies" }, { key: "active", icon: CheckCheck, note: "activeCompanies" }, { key: "customers", icon: Layers3, note: "customerRecords" }, { key: "users", icon: Users, note: "userProfiles" }].map(({ key, icon: Icon, note }) => <article key={key}><div className="platform-stat-label"><p>{key === "active" ? t("ACTIVE") : t(key as PlatformTextKey)}</p><span><Icon size={20} aria-hidden="true"/></span></div><strong>{format(count(key))}</strong><p className="platform-stat-note">{t(note as PlatformTextKey)}</p></article>)}
    </section>
    <div className="platform-overview-grid">
      <section className="platform-panel platform-lifecycle"><div className="platform-section-title"><div><h2>{t("companyLifecycle")}</h2><p>{t("currentSnapshot")}</p></div><Building2 size={20} aria-hidden="true"/></div>
        <div className="platform-chart" role="img" aria-label={`${t("companyLifecycle")}: ${segments.map(s => `${t(s.key)} ${s.count}`).join(", ")}`}>
          <div className="platform-chart-total"><strong>{format(total)}</strong><span>{t("entities")}</span></div>
          <div className="platform-chart-track" aria-hidden="true">{total > 0 ? segments.filter(s => s.count > 0).map(s => <span key={s.key} className={`platform-chart-${s.tone}`} style={{ width: `${s.count / total * 100}%` }}/>) : <span className="platform-chart-empty"/>}</div>
        </div>
        <ul className="platform-chart-legend">{segments.map(s => <li key={s.key}><span><i className={`platform-chart-${s.tone}`} aria-hidden="true"/>{t(s.key)}</span><strong>{format(s.count)}</strong></li>)}</ul>
      </section>
      <section className="platform-panel platform-attention"><div className="platform-section-title"><div><h2>{t("needsAttention")}</h2><p>{t("operationalQueue")}</p></div><Inbox size={20} aria-hidden="true"/></div>
        {[{ key: "pending_setup", label: "setupPending", to: "entities", icon: Building2 }, { key: "pending_invitations", label: "pending_invitations", to: "invitations", icon: Mail }, { key: "delivery_failures", label: "delivery_failures", to: "invitations", icon: Inbox }].map(({ key, label, to, icon: Icon }) => <Link to={`/platform/${to}`} key={key} className="platform-queue-link"><span className="platform-queue-icon"><Icon size={18} aria-hidden="true"/></span><span>{t(label as PlatformTextKey)}</span><strong>{format(count(key))}</strong><ArrowUpRight size={16} aria-hidden="true"/></Link>)}
      </section>
    </div>
    <section className="platform-overview-footer"><div><ShieldCheck size={18} aria-hidden="true"/><span>{t("zero")}</span></div><p>{t("lastVerified")} <time dateTime={String(data.checked_at)}>{new Intl.DateTimeFormat(locale === "ar" ? "ar-AE" : "en-GB", { dateStyle: "medium", timeStyle: "short", timeZone: "Asia/Dubai" }).format(new Date(String(data.checked_at)))}</time> · {t("dubaiTime")}</p></section>
  </div>;
}
