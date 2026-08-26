import { useState } from "react";
import { Briefcase, Pencil, Plus } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { CompanyForm } from "../components/CompanyForm";
import { useT } from "../i18n/I18nContext";
import type { Company } from "../domain/types";

export function Companies() {
  const t = useT();
  const { companies, projects } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [editingCompany, setEditingCompany] = useState<Company | null>(null);

  return (
    <div>
      <PageHeader
        title={t("company.title")}
        subtitle={t("company.subtitle")}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> {t("company.newCompany")}
          </button>
        }
      />

      <Card>
        <div className="divide-y divide-slate-100">
          {companies.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("company.noCompaniesYet")}</p>
          )}
          {companies.map((c) => (
            <div key={c.id} className="flex items-center justify-between px-5 py-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  <Briefcase size={18} />
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-900">{c.name}</p>
                    <Badge tone={c.status === "ACTIVE" ? "green" : "slate"}>
                      {t(c.status === "ACTIVE" ? "common.active" : "common.inactive")}
                    </Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {c.code}
                    {c.trn && ` · ${t("company.trn", { trn: c.trn })}`} ·{" "}
                    {t(
                      projects.filter((p) => p.companyId === c.id).length === 1
                        ? "company.projectCount"
                        : "company.projectCountPlural",
                      { count: projects.filter((p) => p.companyId === c.id).length },
                    )}
                  </p>
                </div>
              </div>
              <button
                type="button"
                onClick={() => setEditingCompany(c)}
                className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50"
              >
                <Pencil size={13} /> {t("common.edit")}
              </button>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title={t("company.newCompany")} onClose={() => setShowForm(false)}>
          <CompanyForm onDone={() => setShowForm(false)} />
        </Modal>
      )}

      {editingCompany && (
        <Modal title={t("company.editCompany")} onClose={() => setEditingCompany(null)}>
          <CompanyForm company={editingCompany} onDone={() => setEditingCompany(null)} />
        </Modal>
      )}
    </div>
  );
}
