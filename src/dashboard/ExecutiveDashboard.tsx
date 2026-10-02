import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { Building2, Receipt, Truck, Hammer, Landmark, RefreshCw, type LucideIcon } from "lucide-react";
import { useAuth } from "../auth/AuthContext";
import { useI18n } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { useProductionMasterData } from "../master/productionMasterDataContext";
import type { ProductionProjectSummary } from "../master/masterTypes";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { useDashboardRead } from "./useDashboardRead";
import { dashboardAED, summarizeDashboard, type DashboardSummary } from "./dashboardSummary";
import { DashboardChart } from "./DashboardChart";

export default function ExecutiveDashboard() {
  const { state } = useAuth();
  if (state.phase !== "TENANT_READY") return null;
  return <DashboardContent key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} userId={state.profile.userId} companyId={state.activeTenant.companyId} role={state.activeTenant.role} />;
}
function Kpi({ label, value, icon: Icon, hint, warning = false }: { label: string; value: string; icon: LucideIcon; hint?: string; warning?: boolean }) {
  return <div className={`min-w-0 rounded-xl border bg-white p-5 shadow-sm ${warning ? "border-s-4 border-s-amber-400 border-slate-200" : "border-slate-200"}`}>
    <div className="flex items-start justify-between gap-3"><p className="text-xs font-medium text-slate-500">{label}</p><span className={`shrink-0 rounded-lg p-2 ${warning ? "bg-amber-50 text-amber-700" : "bg-slate-100 text-slate-600"}`}><Icon size={17} aria-hidden="true" /></span></div>
    <p className="mt-3 break-words text-2xl font-semibold text-slate-900"><bdi dir="ltr" className="tabular-nums">{value}</bdi></p>
    {hint && <p className="mt-2 text-xs leading-5 text-slate-500">{hint}</p>}
  </div>;
}
function DashboardContent({ userId, companyId, role }: { userId: string; companyId: string; role: string }) {
  const { t } = useI18n(), master = useProductionMasterData();
  const [revision, setRevision] = useState(0);
  const masterReady = master.phase === "READY" && master.company.id === companyId
    && [...master.projects, ...master.parties, ...master.expenseCategories].every(row => row.companyId === companyId);
  const read = useDashboardRead(getSupabaseClient(), userId, companyId, role, revision, masterReady);
  const summary = useMemo(() => {
    if (!masterReady || master.phase !== "READY" || read.phase !== "READY") return null;
    try { return summarizeDashboard(master, read.data, t("executiveDashboard.companyOverhead")); }
    catch { return null; }
  }, [masterReady, master, read, t]);
  return <section aria-labelledby="executive-dashboard-title" className="min-w-0 space-y-6">
    <div className="flex flex-wrap items-start justify-between gap-3"><div><h2 id="executive-dashboard-title" className="text-2xl font-semibold text-slate-900">{t("executiveDashboard.title")}</h2><p className="mt-1 max-w-3xl text-sm leading-6 text-slate-500">{t("executiveDashboard.subtitle")}</p></div>
      {masterReady && read.phase !== "DENIED" && <button type="button" disabled={read.phase === "LOADING"} onClick={() => setRevision(n => n + 1)} className="flex items-center gap-2 rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm disabled:opacity-50"><RefreshCw size={14} aria-hidden="true" />{t("executiveDashboard.refresh")}</button>}
      {master.phase !== "LOADING" && !masterReady && <button type="button" onClick={() => window.location.reload()} className="rounded-lg border border-slate-300 bg-white px-3 py-2 text-sm">{t("executiveDashboard.refresh")}</button>}
    </div>
    {master.phase === "LOADING" && <p role="status">{t("executiveDashboard.loading")}</p>}
    {master.phase !== "LOADING" && !masterReady && <p role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">{t("executiveDashboard.error")}</p>}
    {masterReady && master.phase === "READY" && <>
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <Kpi label={t("executiveDashboard.activeProjects")} value={String(master.projects.filter(p => p.status === "ACTIVE").length)} icon={Building2} />
        {summary && <>
          <Kpi label={t("executiveDashboard.postedExpenseNet")} value={dashboardAED(summary.postedExpenseNet)} icon={Receipt} hint={t("executiveDashboard.expenseScope")} />
          <Kpi label={t("executiveDashboard.supplierOutstanding")} value={dashboardAED(summary.supplierOutstanding)} icon={Truck} warning />
          <Kpi label={t("executiveDashboard.subcontractorOutstanding")} value={dashboardAED(summary.subcontractorOutstanding)} icon={Hammer} warning hint={t("executiveDashboard.payableScope")} />
          <Kpi label={t("executiveDashboard.retentionHeld")} value={dashboardAED(summary.retentionHeld)} icon={Landmark} hint={t("executiveDashboard.retentionScope")} />
        </>}
      </div>
      {read.phase === "LOADING" && <p role="status" className="rounded-xl border border-slate-200 bg-white p-6 text-sm text-slate-500">{t("executiveDashboard.loading")}</p>}
      {(read.phase === "ERROR" || read.phase === "READY" && !summary) && <p role="alert" className="rounded-xl border border-red-200 bg-red-50 p-4 text-sm text-red-800">{t("executiveDashboard.error")}</p>}
      {read.phase === "DENIED" && <p className="text-sm text-slate-500">{t("executiveDashboard.operationalOnly")}</p>}
      {summary && <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <DashboardChart title={t("executiveDashboard.expensesByProject")} subtitle={t("executiveDashboard.expenseScope")} groups={summary.byProject} />
        <DashboardChart title={t("executiveDashboard.expensesByCategory")} subtitle={t("executiveDashboard.expenseScope")} groups={summary.byCategory} />
        <DashboardChart title={t("executiveDashboard.suppliersChart")} subtitle={t("executiveDashboard.outstandingScope")} groups={summary.bySupplier} />
        <DashboardChart title={t("executiveDashboard.subcontractorsChart")} subtitle={t("executiveDashboard.payableScope")} groups={summary.bySubcontractor} />
      </div>}
      {(summary || read.phase === "DENIED") && <ProjectOverview projects={summary?.projects ?? master.projects} financial={!!summary} />}
      {summary && <Card className="min-w-0"><CardHeader title={t("executiveDashboard.recentExpenses")} subtitle={t("executiveDashboard.recentScope")} action={<Link to="/expenses" className="shrink-0 text-xs font-medium text-blue-700">{t("common.viewAll")}</Link>} />
        {summary.recentExpenses.length === 0 ? <p className="p-5 text-sm text-slate-500">{t("executiveDashboard.noData")}</p> : <ul className="divide-y divide-slate-100">{summary.recentExpenses.map(expense => <li key={expense.id} className="flex flex-wrap items-baseline justify-between gap-3 px-5 py-3"><div className="min-w-0 break-words"><p className="font-medium"><bdi>{expense.description}</bdi></p><p className="mt-1 text-xs text-slate-500"><bdi dir="ltr">{expense.expense_reference}</bdi> · <bdi dir="ltr">{expense.expense_date}</bdi></p></div><bdi dir="ltr" className="text-sm font-semibold tabular-nums">{dashboardAED(expense.net_amount_minor)}</bdi></li>)}</ul>}
      </Card>}
    </>}
  </section>;
}
function ProjectOverview({ projects, financial }: { projects: (ProductionProjectSummary | DashboardSummary["projects"][number])[]; financial: boolean }) {
  const { t } = useI18n();
  return <Card className="min-w-0 overflow-hidden"><CardHeader title={t("executiveDashboard.projects")} subtitle={financial ? t("executiveDashboard.expenseScope") : undefined} action={<Link to="/projects" className="shrink-0 text-xs font-medium text-blue-700">{t("common.viewAll")}</Link>} />
    {projects.length === 0 ? <p className="p-5 text-sm text-slate-500">{t("productionProjects.empty")}</p> : <div className="overflow-x-auto"><table className="w-full text-start text-sm"><thead className="bg-slate-50 text-xs text-slate-500"><tr><th scope="col" className="px-5 py-3">{t("executiveDashboard.project")}</th><th scope="col" className="px-5 py-3">{t("common.status")}</th>{financial && <th scope="col" className="px-5 py-3">{t("executiveDashboard.postedExpenseNet")}</th>}</tr></thead><tbody className="divide-y divide-slate-100">{projects.map(project => <tr key={project.id}><td className="px-5 py-3"><p className="font-medium"><bdi>{project.name}</bdi></p><p className="mt-1 text-xs text-slate-500"><bdi dir="ltr">{project.code}</bdi></p></td><td className="whitespace-nowrap px-5 py-3"><Badge tone={project.status === "ACTIVE" ? "green" : "slate"}>{t(`projectStatus.${project.status}`)}</Badge></td>{financial && <td className="px-5 py-3"><bdi dir="ltr" className="tabular-nums">{dashboardAED("postedExpenseNet" in project ? project.postedExpenseNet : "0")}</bdi></td>}</tr>)}</tbody></table></div>}
  </Card>;
}
