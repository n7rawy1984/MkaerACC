import { useMemo } from "react";
import { Link } from "react-router-dom";
import { ArrowRight, Building2 } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { formatAED } from "../domain/money";
import { totalInputVat, totalProjectCost } from "../accounting/ledger";
import type { ProjectStatus } from "../domain/types";

const STATUS_TONE: Record<ProjectStatus, "green" | "amber" | "slate" | "red"> = {
  ACTIVE: "green",
  ON_HOLD: "amber",
  COMPLETED: "slate",
  CANCELLED: "red",
};

export function Projects() {
  const { projects, expenses, journalEntries } = useAppData();

  const rows = useMemo(
    () =>
      projects.map((project) => ({
        project,
        cost: totalProjectCost(journalEntries, project.id),
        vat: totalInputVat(journalEntries, project.id),
        expenseCount: expenses.filter((e) => e.projectId === project.id).length,
      })),
    [projects, expenses, journalEntries],
  );

  return (
    <div>
      <PageHeader title="Projects" subtitle={`${projects.length} projects tracked`} />

      <Card>
        <div className="divide-y divide-slate-100">
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
                    {project.code} · {project.client ?? "—"} · {project.location ?? "—"}
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
    </div>
  );
}
