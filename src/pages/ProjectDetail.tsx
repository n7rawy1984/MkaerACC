import { useMemo, useState } from "react";
import { Link, useParams } from "react-router-dom";
import { ArrowLeft, ArrowRight, HardHat, Pencil } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { StatCard } from "../components/ui/StatCard";
import { Modal } from "../components/ui/Modal";
import { ProjectForm } from "../components/ProjectForm";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { Receipt, FileWarning, Landmark, Hash, ListChecks } from "lucide-react";
import {
  contractPayableBalance,
  contractRetentionHeld,
  costByCategory,
  directExpenseCost,
  expensesWithoutInvoice,
  subcontractorCertifiedCost,
  totalInputVat,
  totalProjectCost,
} from "../accounting/ledger";

export function ProjectDetail() {
  const { id } = useParams<{ id: string }>();
  const { projects, companies, expenses, categories, journalEntries, subcontracts, parties } = useAppData();
  const [showEditForm, setShowEditForm] = useState(false);

  const project = projects.find((p) => p.id === id);
  const categoriesById = useMemo(() => indexById(categories), [categories]);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const companiesById = useMemo(() => indexById(companies), [companies]);

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
  // Contract-scoped (Phase 2B.2), summed per contract on this project — never party-scoped, so two
  // contracts for the same subcontractor on this project can never double-count each other.
  const subPayables = useMemo(
    () => projectSubcontracts.reduce((sum, c) => sum + contractPayableBalance(journalEntries, c.id), 0),
    [projectSubcontracts, journalEntries],
  );
  const subRetention = useMemo(
    () => projectSubcontracts.reduce((sum, c) => sum + contractRetentionHeld(journalEntries, c.id), 0),
    [projectSubcontracts, journalEntries],
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
        subtitle={`${project.code} · ${companiesById[project.companyId]?.name ?? "—"} · ${project.client ?? "—"} · ${project.location ?? "—"}${
          project.startDate ? ` · started ${formatDate(project.startDate)}` : ""
        }${project.contractNumber ? ` · Contract ${project.contractNumber}` : ""}`}
        action={
          <button
            onClick={() => setShowEditForm(true)}
            className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
          >
            <Pencil size={15} /> Edit Project
          </button>
        }
      />

      {project.status === "CLOSED" && (
        <div className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-3 py-2 text-xs text-amber-800">
          This project is closed — it cannot accept new expenses, advances, subcontractor advances, or
          certificates. Reopen it (Edit Project → Status) to resume operational activity. Historical activity
          below remains fully visible.
        </div>
      )}

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
                to={`/subcontracts/${c.id}`}
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

      {showEditForm && (
        <Modal title="Edit Project" onClose={() => setShowEditForm(false)} width="max-w-2xl">
          <ProjectForm project={project} onDone={() => setShowEditForm(false)} />
        </Modal>
      )}
    </div>
  );
}
