import type { DashboardFinancialRead } from "./dashboardRead";
import type { ProductionMasterDataState } from "../master/masterTypes";

type Masters = Extract<ProductionMasterDataState, { phase: "READY" }>;
export interface DashboardGroup { id: string; label: string; minor: string }
// Reporting only: sum existing document amounts/outstanding read values. No posting,
// settlement, payroll, VAT treatment, or ledger reconstruction happens here.
const sum = (values: string[]) => values.reduce((total, value) => total + BigInt(value), 0n).toString();
function group(rows: { id: string; minor: string }[], name: (id: string) => string): DashboardGroup[] {
  const totals = new Map<string, bigint>();
  for (const row of rows) totals.set(row.id, (totals.get(row.id) ?? 0n) + BigInt(row.minor));
  return [...totals].map(([id, minor]) => ({ id, label: name(id), minor: minor.toString() }))
    .sort((a, b) => BigInt(a.minor) === BigInt(b.minor) ? a.id.localeCompare(b.id) : BigInt(a.minor) > BigInt(b.minor) ? -1 : 1);
}
export function summarizeDashboard(master: Masters, financial: DashboardFinancialRead, companyOverhead: string) {
  const companyId = master.company.id;
  if ([...master.projects, ...master.parties, ...master.expenseCategories].some(row => row.companyId !== companyId)
    || [...financial.expenses, ...financial.supplierOutstanding, ...financial.certificateOutstanding,
      ...financial.releasedRetentionOutstanding, ...financial.retentionHeld].some(row => row.company_id !== companyId)) throw new Error("Dashboard scope mismatch");
  const partyName = (id: string, type: "SUPPLIER" | "SUBCONTRACTOR") => master.parties.find(p => p.id === id && p.type === type)?.name ?? id;
  const payable = [...financial.certificateOutstanding, ...financial.releasedRetentionOutstanding];
  const byProject = group(financial.expenses.map(e => ({ id: e.project_id ?? "company-overhead", minor: e.net_amount_minor })),
    id => id === "company-overhead" ? companyOverhead : master.projects.find(p => p.id === id)?.name ?? id);
  const projectAmounts = new Map(byProject.map(row => [row.id, row.minor]));
  return {
    activeProjects: master.projects.filter(p => p.status === "ACTIVE").length,
    postedExpenseNet: sum(financial.expenses.map(e => e.net_amount_minor)),
    supplierOutstanding: sum(financial.supplierOutstanding.map(e => e.outstanding_amount_minor)),
    subcontractorOutstanding: sum(payable.map(e => e.outstanding_amount_minor)),
    retentionHeld: sum(financial.retentionHeld.map(e => e.remaining_amount_minor)),
    byProject,
    byCategory: group(financial.expenses.map(e => ({ id: e.expense_category_id, minor: e.net_amount_minor })),
      id => master.expenseCategories.find(c => c.id === id)?.name ?? id),
    bySupplier: group(financial.supplierOutstanding.map(e => ({ id: e.supplier_id, minor: e.outstanding_amount_minor })), id => partyName(id, "SUPPLIER")),
    bySubcontractor: group(payable.map(e => ({ id: e.subcontractor_id, minor: e.outstanding_amount_minor })), id => partyName(id, "SUBCONTRACTOR")),
    projects: master.projects.map(project => ({ ...project, postedExpenseNet: projectAmounts.get(project.id) ?? "0" })),
    recentExpenses: [...financial.expenses].sort((a, b) => b.expense_date.localeCompare(a.expense_date) || a.id.localeCompare(b.id)).slice(0, 6),
  };
}
export type DashboardSummary = ReturnType<typeof summarizeDashboard>;

export function dashboardAED(minor: string): string {
  const n = BigInt(minor), digits = (n < 0n ? -n : n).toString().padStart(3, "0");
  return `${n < 0n ? "-" : ""}${digits.slice(0, -2).replace(/\B(?=(\d{3})+(?!\d))/g, ",")}.${digits.slice(-2)} AED`;
}
// Recharts needs a Number coordinate. Normalize with integer arithmetic first;
// exact monetary labels/tooltips remain strings even beyond Number's safe range.
export function dashboardChartRows(groups: DashboardGroup[]) {
  const max = groups.reduce((n, row) => BigInt(row.minor) > n ? BigInt(row.minor) : n, 0n);
  return groups.map(row => ({ ...row, weight: max === 0n ? 0 : Number(BigInt(row.minor) * 10000n / max) / 100 }));
}
