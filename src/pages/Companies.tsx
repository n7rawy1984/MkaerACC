import { useState } from "react";
import { Briefcase, Pencil, Plus } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { CompanyForm } from "../components/CompanyForm";
import type { Company } from "../domain/types";

export function Companies() {
  const { companies, projects } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [editingCompany, setEditingCompany] = useState<Company | null>(null);

  return (
    <div>
      <PageHeader
        title="Company"
        subtitle="The legal entities projects and treasury accounts belong to"
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> New Company
          </button>
        }
      />

      <Card>
        <div className="divide-y divide-slate-100">
          {companies.length === 0 && <p className="px-5 py-8 text-center text-sm text-slate-400">No companies yet.</p>}
          {companies.map((c) => (
            <div key={c.id} className="flex items-center justify-between px-5 py-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  <Briefcase size={18} />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-900">{c.name}</p>
                    <Badge tone={c.status === "ACTIVE" ? "green" : "slate"}>{c.status}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {c.code}
                    {c.trn && ` · TRN ${c.trn}`} · {projects.filter((p) => p.companyId === c.id).length} projects
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setEditingCompany(c)}
                className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50"
              >
                <Pencil size={13} /> Edit
              </button>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title="New Company" onClose={() => setShowForm(false)}>
          <CompanyForm onDone={() => setShowForm(false)} />
        </Modal>
      )}

      {editingCompany && (
        <Modal title={`Edit ${editingCompany.name}`} onClose={() => setEditingCompany(null)}>
          <CompanyForm company={editingCompany} onDone={() => setEditingCompany(null)} />
        </Modal>
      )}
    </div>
  );
}
