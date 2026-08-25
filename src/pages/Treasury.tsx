import { useMemo, useState } from "react";
import { Landmark, Pencil, Plus, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { TreasuryAccountForm } from "../components/TreasuryAccountForm";
import { formatAED } from "../domain/money";
import { indexById } from "../domain/utils";
import { treasuryAccountBalance } from "../accounting/ledger";
import type { TreasuryAccount, TreasuryAccountType } from "../domain/types";

const TYPE_LABELS: Record<TreasuryAccountType, string> = {
  CASH: "Cash",
  PETTY_CASH: "Petty Cash",
  BANK: "Bank",
  PROJECT_CASH_BOX: "Project Cash Box",
  PROJECT_BANK: "Project Bank Account",
};

export function Treasury() {
  const { treasuryAccounts, companies, projects, journalEntries } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [editingAccount, setEditingAccount] = useState<TreasuryAccount | null>(null);

  const companiesById = useMemo(() => indexById(companies), [companies]);
  const projectsById = useMemo(() => indexById(projects), [projects]);

  return (
    <div>
      <PageHeader
        title="Cash & Banks"
        subtitle="Named funding sources — where advances, expenses, and payments actually draw from"
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> New Treasury Account
          </button>
        }
      />

      <Card>
        <div className="divide-y divide-slate-100">
          {treasuryAccounts.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">No treasury accounts yet.</p>
          )}
          {treasuryAccounts.map((t) => (
            <div key={t.id} className="flex items-center justify-between px-5 py-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  {t.type === "BANK" || t.type === "PROJECT_BANK" ? <Landmark size={18} /> : <Wallet size={18} />}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-900">{t.name}</p>
                    <Badge tone={t.status === "ACTIVE" ? "green" : "slate"}>{t.status}</Badge>
                    <Badge tone="slate">{TYPE_LABELS[t.type]}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {t.code} · {companiesById[t.companyId]?.name ?? "—"}
                    {t.projectId && ` · ${projectsById[t.projectId]?.name ?? "—"}`}
                    {t.bankName && ` · ${t.bankName}`}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="text-right">
                  <p className="text-xs text-slate-400">Current Balance</p>
                  <p className="text-sm font-semibold text-slate-900">
                    {formatAED(treasuryAccountBalance(journalEntries, t.glAccountId))}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setEditingAccount(t)}
                  className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50"
                >
                  <Pencil size={13} /> Edit
                </button>
              </div>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title="New Treasury Account" onClose={() => setShowForm(false)}>
          <TreasuryAccountForm onDone={() => setShowForm(false)} />
        </Modal>
      )}

      {editingAccount && (
        <Modal title={`Edit ${editingAccount.name}`} onClose={() => setEditingAccount(null)}>
          <TreasuryAccountForm account={editingAccount} onDone={() => setEditingAccount(null)} />
        </Modal>
      )}
    </div>
  );
}
