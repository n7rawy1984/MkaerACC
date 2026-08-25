import { useMemo, useState } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, Building2, Plus } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { ProjectForm } from "../components/ProjectForm";
import { formatAED } from "../domain/money";
import { totalInputVat, totalProjectCost } from "../accounting/ledger";
import { indexById } from "../domain/utils";
import type { ProjectStatus } from "../domain/types";

const ALL = "ALL";

const STATUS_TONE: Record<ProjectStatus, "green" | "amber" | "slate" | "blue"> = {
  PLANNING: "blue",
  ACTIVE: "green",
  ON_HOLD: "amber",
  COMPLETED: "slate",
  CLOSED: "slate",
};

export function Projects() {
  const { projects, companies, expenses, journalEntries } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [statusFilter, setStatusFilter] = useState<typeof ALL | ProjectStatus>(ALL);
  const [companyFilter, setCompanyFilter] = useState(ALL);

  const companiesById = useMemo(() => indexById(companies), [companies]);

  const rows = useMemo(
    () =>
      projects
        .filter((p) => (statusFilter === ALL ? true : p.status === statusFilter))
        .filter((p) => (companyFilter === ALL ? true : p.companyId === companyFilter))
        .map((project) => ({
          project,
          cost: totalProjectCost(journalEntries, project.id),
          vat: totalInputVat(journalEntries, project.id),
          expenseCount: expenses.filter((e) => e.projectId === project.id).length,
        })),
    [projects, expenses, journalEntries, statusFilter, companyFilter],
  );

  return (
    <div>
      <PageHeader
        title="Projects"
        subtitle={`${rows.length} of ${projects.length} projects`}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> New Project
          </button>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <select
          value={statusFilter}
          onChange={(e) => setStatusFilter(e.target.value as typeof ALL | ProjectStatus)}
          className="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
        >
          <option value={ALL}>All statuses</option>
          <option value="PLANNING">Planning</option>
          <option value="ACTIVE">Active</option>
          <option value="ON_HOLD">On Hold</option>
          <option value="COMPLETED">Completed</option>
          <option value="CLOSED">Closed</option>
        </select>
        <select
          value={companyFilter}
          onChange={(e) => setCompanyFilter(e.target.value)}
          className="rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
        >
          <option value={ALL}>All companies</option>
          {companies.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
      </div>

      <Card>
        <div className="divide-y divide-slate-100">
          {rows.length === 0 && <p className="px-5 py-8 text-center text-sm text-slate-400">No projects match these filters.</p>}
          {rows.map(({ project, cost, vat, expenseCount }) => (
            <Link
              key={project.id}
              to={`/projects/${project.id}`}
              className="flex items-center justify-between px-5 py-4 hover:bg-slate-50"
            >
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  <Building2 size={18} />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-900">{project.name}</p>
                    <Badge tone={STATUS_TONE[project.status]}>{project.status.replace("_", " ")}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {project.code} · {companiesById[project.companyId]?.name ?? "—"} · {project.client ?? "—"} ·{" "}
                    {project.location ?? "—"}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-8">
                <div className="text-right">
                  <p className="text-xs text-slate-400">Cost</p>
                  <p className="text-sm font-semibold text-slate-900">{formatAED(cost)}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs text-slate-400">VAT</p>
                  <p className="text-sm font-medium text-slate-600">{formatAED(vat)}</p>
                </div>
                <div className="text-right">
                  <p className="text-xs text-slate-400">Expenses</p>
                  <p className="text-sm font-medium text-slate-600">{expenseCount}</p>
                </div>
                <ArrowRight size={16} className="text-slate-300" />
              </div>
            </Link>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title="New Project" onClose={() => setShowForm(false)} width="max-w-2xl">
          <ProjectForm onDone={() => setShowForm(false)} />
        </Modal>
      )}
    </div>
  );
}
