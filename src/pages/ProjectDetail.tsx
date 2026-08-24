import { useMemo } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, ArrowRight, HardHat } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { StatCard } from "../components/ui/StatCard";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { Receipt, FileWarning, Landmark, Hash, ListChecks } from "lucide-react";
import {
  costByCategory,
  directExpenseCost,
  expensesWithoutInvoice,
  subcontractorCertifiedCost,
  subcontractorPayableBalance,
  subcontractorRetentionHeld,
  totalInputVat,
  totalProjectCost,
} from "../accounting/ledger";

export function ProjectDetail() {
  const { id } = useParams<{ id: string }>();
  const { projects, expenses, categories, journalEntries, subcontracts, parties } = useAppData();

  const project = projects.find((p) => p.id === id);
  const categoriesById = useMemo(() => indexById(categories), [categories]);
  const partiesById = useMemo(() => indexById(parties), [parties]);

  const projectExpenses = useMemo(
    () => expenses.filter((e) => e.projectId === id).sort((a, b) => (a.date < b.date ? 1 : -1)),
    [expenses, id],
  );

  const cost = useMemo(() => totalProjectCost(journalEntries, id), [journalEntries, id]);
  const vat = useMemo(() => totalInputVat(journalEntries, id), [journalEntries, id]);
  const noInvoice = useMemo(() => expensesWithoutInvoice(projectExpenses), [projectExpenses]);
  const categoryBreakdown = useMemo(() => costByCategory(expenses, id), [expenses, id]);

  const projectSubcontracts = useMemo(
    () => subcontracts.filter((c) => c.projectId === id),
    [subcontracts, id],
  );
  const directCost = useMemo(() => directExpenseCost(journalEntries, id), [journalEntries, id]);
  const subCertifiedCost = useMemo(() => subcontractorCertifiedCost(journalEntries, id), [journalEntries, id]);
  const subPayables = useMemo(
    () =>
      projectSubcontracts.reduce(
        (sum, c) => sum + subcontractorPayableBalance(journalEntries, c.subcontractorId),
        0,
      ),
    [projectSubcontracts, journalEntries],
  );
  const subRetention = useMemo(
    () =>
      projectSubcontracts.reduce(
        (sum, c) => sum + subcontractorRetentionHeld(journalEntries, c.subcontractorId, id),
        0,
      ),
    [projectSubcontracts, journalEntries, id],
  );

  if (!project) {
    return (
      <div>
        <Link to="/projects" className="text-sm text-slate-500 hover:text-slate-900">
          &larr; Back to projects
        </Link>
        <p className="mt-4 text-sm text-slate-500">Project not found.</p>
      </div>
    );
  }

  return (
    <div>
      <Link
        to="/projects"
        className="mb-3 inline-flex items-center gap-1 text-sm text-slate-500 hover:text-slate-900"
      >
        <ArrowLeft size={14} /> Back to projects
      </Link>
      <PageHeader
        title={project.name}
        subtitle={`${project.code} · ${project.client ?? "—"} · ${project.location ?? "—"} · started ${formatDate(project.startDate)}`}
      />

      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-5">
        <StatCard
          label="Total Cost"
          value={cost}
          icon={Receipt}
          hint={
            projectSubcontracts.length > 0
              ? `Direct ${formatAED(directCost)} + Subcontractor ${formatAED(subCertifiedCost)}`
              : undefined
          }
        />
        <StatCard label="Input VAT" value={vat} icon={Landmark} />
        <StatCard
          label="Transactions"
          value={projectExpenses.length}
          format="count"
          icon={ListChecks}
          hint="Expenses posted to this project"
        />
        <StatCard
          label="Expenses Without Invoice"
          value={noInvoice.reduce((s, e) => s + e.totalAmount, 0)}
          icon={FileWarning}
          tone="danger"
          hint={`${noInvoice.length} of ${projectExpenses.length} transactions`}
        />
        <StatCard
          label="Budget"
          value={project.budget ?? 0}
          icon={Hash}
          tone={project.budget && cost > project.budget ? "danger" : "default"}
          hint={
            project.budget
              ? `${((cost / project.budget) * 100).toFixed(0)}% used${cost > project.budget ? " — over budget" : ""}`
              : "No budget set"
          }
        />
      </div>

      {projectSubcontracts.length > 0 && (
        <Card className="mt-6">
          <CardHeader title="Subcontractors on this Project" subtitle="Certified cost, payable, and retention" />
          <div className="grid grid-cols-2 gap-4 border-b border-slate-100 px-5 py-4 sm:grid-cols-4">
            <div>
              <p className="text-xs text-slate-400">Direct Expenses</p>
              <p className="text-sm font-semibold text-slate-900">{formatAED(directCost)}</p>
            </div>
            <div>
              <p className="text-xs text-slate-400">Subcontractor Certified Cost</p>
              <p className="text-sm font-semibold text-slate-900">{formatAED(subCertifiedCost)}</p>
            </div>
            <div>
              <p className="text-xs text-slate-400">Subcontractor Payables</p>
              <p className="text-sm font-semibold text-slate-900">{formatAED(subPayables)}</p>
            </div>
            <div>
              <p className="text-xs text-slate-400">Retention Held</p>
              <p className="text-sm font-semibold text-slate-900">{formatAED(subRetention)}</p>
            </div>
          </div>
          <div className="divide-y divide-slate-100">
            {projectSubcontracts.map((c) => (
              <Link
                key={c.id}
                to={`/subcontractors/${c.id}`}
                className="flex items-center justify-between px-5 py-3 hover:bg-slate-50"
              >
                <div className="flex items-center gap-3">
                  <div className="flex h-8 w-8 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                    <HardHat size={15} />
                  </div>
                  <div>
                    <p className="text-sm font-medium text-slate-800">{partiesById[c.subcontractorId]?.name}</p>
                    <p className="text-xs text-slate-400">{c.contractNumber} · {c.scopeOfWork}</p>
                  </div>
                </div>
                <ArrowRight size={14} className="text-slate-300" />
              </Link>
            ))}
          </div>
        </Card>
      )}

      <div className="mt-6 grid grid-cols-1 gap-6 lg:grid-cols-5">
        <Card className="lg:col-span-2">
          <CardHeader title="Cost by Category" subtitle="Net of VAT" />
          <div className="divide-y divide-slate-100">
            {categoryBreakdown.length === 0 && (
              <p className="px-5 py-6 text-sm text-slate-400">No expenses yet.</p>
            )}
            {categoryBreakdown.map((row) => (
              <div key={row.categoryId} className="flex items-center justify-between px-5 py-3">
                <p className="text-sm text-slate-700">{categoriesById[row.categoryId]?.name}</p>
                <p className="text-sm font-medium text-slate-900">{formatAED(row.amount)}</p>
              </div>
            ))}
          </div>
        </Card>

        <Card className="lg:col-span-3">
          <CardHeader title="Recent Expenses" />
          <div className="divide-y divide-slate-100">
            {projectExpenses.length === 0 && (
              <p className="px-5 py-6 text-sm text-slate-400">No expenses recorded for this project.</p>
            )}
            {projectExpenses.slice(0, 10).map((e) => (
              <div key={e.id} className="flex items-center justify-between px-5 py-3">
                <div>
                  <p className="text-sm font-medium text-slate-800">{e.description}</p>
                  <p className="text-xs text-slate-400">
                    {formatDate(e.date)} · {categoriesById[e.categoryId]?.name}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-sm font-semibold text-slate-900">{formatAED(e.totalAmount)}</p>
                  {!e.hasInvoice && <Badge tone="amber">No invoice</Badge>}
                </div>
              </div>
            ))}
          </div>
        </Card>
      </div>
    </div>
  );
}
