import { useMemo } from "react";
import { Link } from "react-router-dom";
import { Wallet, HandCoins, Truck, FileWarning, Receipt, Landmark, Hammer, FileCheck2 } from "lucide-react";
import {
  Bar,
  BarChart,
  CartesianGrid,
  Cell,
  ResponsiveContainer,
  Tooltip,
  XAxis,
  YAxis,
} from "recharts";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { StatCard } from "../components/ui/StatCard";
import { Badge } from "../components/ui/Badge";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { DemoDataBadge } from "../components/ui/DemoDataBadge";
import { useT } from "../i18n/I18nContext";
import {
  costByCategory,
  costByProject,
  expensesWithoutInvoice,
  ownerCurrentBalance,
  totalInputVat,
  totalOpenCustodianAdvances,
  totalProjectCost,
  totalRetentionHeld,
  totalSubcontractorPayables,
  totalSupplierPayables,
} from "../accounting/ledger";

const CATEGORICAL = ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300", "#4a3aa7"];

export function Dashboard() {
  const t = useT();
  const { projects, parties, categories, expenses, journalEntries, subcontracts, subcontractorCertificates } =
    useAppData();

  const projectsById = useMemo(() => indexById(projects), [projects]);
  const categoriesById = useMemo(() => indexById(categories), [categories]);

  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);
  const subcontractors = useMemo(() => parties.filter((p) => p.type === "SUBCONTRACTOR"), [parties]);

  const totalCost = useMemo(() => totalProjectCost(journalEntries), [journalEntries]);
  const openAdvances = useMemo(
    () => totalOpenCustodianAdvances(journalEntries, custodians.map((c) => c.id)),
    [journalEntries, custodians],
  );
  const payables = useMemo(
    () => totalSupplierPayables(journalEntries, suppliers.map((s) => s.id)),
    [journalEntries, suppliers],
  );
  const noInvoice = useMemo(() => expensesWithoutInvoice(expenses), [expenses]);
  const noInvoiceTotal = useMemo(
    () => noInvoice.reduce((sum, e) => sum + e.totalAmount, 0),
    [noInvoice],
  );
  const inputVat = useMemo(() => totalInputVat(journalEntries), [journalEntries]);

  const subcontractorPayables = useMemo(
    () => totalSubcontractorPayables(journalEntries, subcontractors.map((s) => s.id)),
    [journalEntries, subcontractors],
  );
  const retentionHeld = useMemo(
    () => totalRetentionHeld(journalEntries, subcontractors.map((s) => s.id)),
    [journalEntries, subcontractors],
  );
  const totalCertified = useMemo(
    () =>
      subcontractorCertificates
        .filter((c) => c.status !== "DRAFT")
        .reduce((sum, c) => sum + c.grossCurrentValue, 0),
    [subcontractorCertificates],
  );
  const activeSubcontracts = useMemo(() => subcontracts.filter((c) => c.status === "ACTIVE").length, [subcontracts]);

  const projectCostData = useMemo(
    () =>
      costByProject(journalEntries, projects)
        .map((row) => ({ name: row.project.name, cost: row.totalCost }))
        .sort((a, b) => b.cost - a.cost),
    [journalEntries, projects],
  );

  const categoryData = useMemo(
    () =>
      costByCategory(expenses)
        .map((row) => ({ name: categoriesById[row.categoryId]?.name ?? row.categoryId, amount: row.amount }))
        .sort((a, b) => b.amount - a.amount),
    [expenses, categoriesById],
  );

  const recentExpenses = useMemo(
    () => [...expenses].sort((a, b) => (a.date < b.date ? 1 : -1)).slice(0, 8),
    [expenses],
  );

  return (
    <div>
      <PageHeader title={t("dashboard.title")} subtitle={t("dashboard.subtitle")} action={<DemoDataBadge />} />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3">
        <StatCard label={t("dashboard.totalProjectCosts")} value={totalCost} icon={Receipt} />
        <StatCard
          label={t("dashboard.cashWithCustodians")}
          value={openAdvances}
          icon={Wallet}
          hint={
            custodians.length > 0
              ? t("dashboard.heldBy", { names: custodians.map((c) => c.name).join(", ") })
              : t("dashboard.noCustodiansRecorded")
          }
        />
        <StatCard label={t("dashboard.supplierPayables")} value={payables} icon={Truck} tone="warning" />
        <StatCard
          label={t("dashboard.expensesWithoutInvoice")}
          value={noInvoiceTotal}
          icon={FileWarning}
          tone="danger"
          hint={t(noInvoice.length === 1 ? "dashboard.transactionCount" : "dashboard.transactionCountPlural", {
            count: noInvoice.length,
          })}
        />
        <StatCard label={t("dashboard.inputVat")} value={inputVat} icon={Landmark} />
        <StatCard
          label={t("dashboard.ownerCurrentAccounts")}
          value={owners.reduce((sum, o) => sum + ownerCurrentBalance(journalEntries, o.id), 0)}
          icon={HandCoins}
          hint={t("dashboard.owedToOwnersHint")}
        />
      </div>

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card>
          <CardHeader title={t("dashboard.projectCostChartTitle")} subtitle={t("dashboard.projectCostChartSubtitle")} />
          <div className="h-72 px-4 py-4">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart data={projectCostData} margin={{ top: 8, right: 8, left: 8, bottom: 8 }}>
                <CartesianGrid vertical={false} stroke="#e1e0d9" />
                <XAxis
                  dataKey="name"
                  tick={{ fill: "#898781", fontSize: 12 }}
                  axisLine={{ stroke: "#c3c2b7" }}
                  tickLine={false}
                />
                <YAxis
                  tick={{ fill: "#898781", fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                  width={72}
                  tickFormatter={(v: number) => formatAED(v)}
                />
                <Tooltip
                  cursor={{ fill: "#f9f9f7" }}
                  formatter={(v) => formatAED(Number(v))}
                  contentStyle={{ borderRadius: 8, borderColor: "#e1e0d9", fontSize: 12 }}
                />
                <Bar dataKey="cost" radius={[4, 4, 0, 0]}>
                  {projectCostData.map((_, i) => (
                    <Cell key={i} fill={CATEGORICAL[i % CATEGORICAL.length]} />
                  ))}
                </Bar>
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>

        <Card>
          <CardHeader
            title={t("dashboard.projectCostBreakdownTitle")}
            subtitle={t("dashboard.projectCostBreakdownSubtitle")}
          />
          <div className="h-72 px-4 py-4">
            <ResponsiveContainer width="100%" height="100%">
              <BarChart
                data={categoryData}
                layout="vertical"
                margin={{ top: 8, right: 16, left: 8, bottom: 8 }}
              >
                <CartesianGrid horizontal={false} stroke="#e1e0d9" />
                <XAxis
                  type="number"
                  tick={{ fill: "#898781", fontSize: 12 }}
                  axisLine={{ stroke: "#c3c2b7" }}
                  tickLine={false}
                  tickFormatter={(v: number) => formatAED(v)}
                />
                <YAxis
                  type="category"
                  dataKey="name"
                  tick={{ fill: "#52514e", fontSize: 12 }}
                  axisLine={false}
                  tickLine={false}
                  width={100}
                />
                <Tooltip
                  cursor={{ fill: "#f9f9f7" }}
                  formatter={(v) => formatAED(Number(v))}
                  contentStyle={{ borderRadius: 8, borderColor: "#e1e0d9", fontSize: 12 }}
                />
                <Bar dataKey="amount" radius={[0, 4, 4, 0]} fill={CATEGORICAL[0]} />
              </BarChart>
            </ResponsiveContainer>
          </div>
        </Card>
      </div>

      {subcontracts.length > 0 && (
        <Card className="mt-6">
          <CardHeader
            title={t("dashboard.subcontractorsSummaryTitle")}
            subtitle={t("dashboard.subcontractorsSummarySubtitle")}
            action={
              <Link to="/subcontractors" className="text-xs font-medium text-slate-500 hover:text-slate-900">
                {t("common.viewAll")}
              </Link>
            }
          />
          <div className="grid grid-cols-2 gap-4 px-5 py-4 sm:grid-cols-4">
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                <FileCheck2 size={16} />
              </div>
              <div>
                <p className="text-xs text-slate-400">{t("dashboard.totalCertified")}</p>
                <p className="text-sm font-semibold text-slate-900">{formatAED(totalCertified)}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-amber-100 text-amber-700">
                <Truck size={16} />
              </div>
              <div>
                <p className="text-xs text-slate-400">{t("dashboard.outstandingPayable")}</p>
                <p className="text-sm font-semibold text-slate-900">{formatAED(subcontractorPayables)}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                <Landmark size={16} />
              </div>
              <div>
                <p className="text-xs text-slate-400">{t("dashboard.retentionHeld")}</p>
                <p className="text-sm font-semibold text-slate-900">{formatAED(retentionHeld)}</p>
              </div>
            </div>
            <div className="flex items-center gap-3">
              <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                <Hammer size={16} />
              </div>
              <div>
                <p className="text-xs text-slate-400">{t("dashboard.activeSubcontracts")}</p>
                <p className="text-sm font-semibold text-slate-900">{activeSubcontracts}</p>
              </div>
            </div>
          </div>
        </Card>
      )}

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-5">
        <Card className="lg:col-span-3">
          <CardHeader
            title={t("dashboard.recentExpenses")}
            action={
              <Link to="/expenses" className="text-xs font-medium text-slate-500 hover:text-slate-900">
                {t("common.viewAll")}
              </Link>
            }
          />
          <div className="divide-y divide-slate-100">
            {recentExpenses.length === 0 && (
              <p className="px-5 py-6 text-sm text-slate-400">{t("dashboard.noTransactionsYet")}</p>
            )}
            {recentExpenses.map((e) => (
              <div key={e.id} className="flex items-center justify-between px-5 py-3">
                <div>
                  <p className="text-sm font-medium text-slate-800">{e.description}</p>
                  <p className="text-xs text-slate-400">
                    {formatDate(e.date)}
                    {e.projectId && ` · ${projectsById[e.projectId]?.name ?? ""}`}
                    {" · "}
                    {categoriesById[e.categoryId]?.name}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-semibold text-slate-900">{formatAED(e.totalAmount)}</p>
                  {!e.hasInvoice && <Badge tone="amber">{t("badge.noInvoice")}</Badge>}
                </div>
              </div>
            ))}
          </div>
        </Card>

        <Card className="lg:col-span-2">
          <CardHeader
            title={t("dashboard.expensesWithoutInvoiceTitle")}
            subtitle={t("dashboard.expensesWithoutInvoiceSubtitle")}
          />
          <div className="divide-y divide-slate-100">
            {noInvoice.length === 0 && (
              <p className="px-5 py-6 text-sm text-slate-400">{t("dashboard.allExpensesHaveInvoices")}</p>
            )}
            {noInvoice.slice(0, 8).map((e) => (
              <div key={e.id} className="flex items-center justify-between px-5 py-3">
                <div>
                  <p className="text-sm font-medium text-slate-800">{e.description}</p>
                  <p className="text-xs text-slate-400">
                    {formatDate(e.date)}
                    {e.projectId && ` · ${projectsById[e.projectId]?.name ?? ""}`}
                  </p>
                </div>
                <p className="text-sm font-semibold text-rose-600">{formatAED(e.totalAmount)}</p>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
