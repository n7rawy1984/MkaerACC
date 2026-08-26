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
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";
import type { TreasuryAccount, TreasuryAccountType } from "../domain/types";

const TYPE_KEY: Record<TreasuryAccountType, TranslationKey> = {
  CASH: "treasuryType.CASH",
  PETTY_CASH: "treasuryType.PETTY_CASH",
  BANK: "treasuryType.BANK",
  PROJECT_CASH_BOX: "treasuryType.PROJECT_CASH_BOX",
  PROJECT_BANK: "treasuryType.PROJECT_BANK",
};

export function Treasury() {
  const t = useT();
  const { treasuryAccounts, companies, projects, journalEntries } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [editingAccount, setEditingAccount] = useState<TreasuryAccount | null>(null);

  const companiesById = useMemo(() => indexById(companies), [companies]);
  const projectsById = useMemo(() => indexById(projects), [projects]);

  return (
    <div>
      <PageHeader
        title={t("treasury.title")}
        subtitle={t("treasury.subtitle")}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> {t("treasury.newAccount")}
          </button>
        }
      />

      <Card>
        <div className="divide-y divide-slate-100">
          {treasuryAccounts.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("treasury.noAccountsYet")}</p>
          )}
          {treasuryAccounts.map((account) => (
            <div key={account.id} className="flex items-center justify-between px-5 py-4">
              <div className="flex items-center gap-3">
                <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
                  {account.type === "BANK" || account.type === "PROJECT_BANK" ? (
                    <Landmark size={18} />
                  ) : (
                    <Wallet size={18} />
                  )}
                </div>
                <div>
                  <div className="flex items-center gap-2">
                    <p className="text-sm font-semibold text-slate-900">{account.name}</p>
                    <Badge tone={account.status === "ACTIVE" ? "green" : "slate"}>
                      {t(account.status === "ACTIVE" ? "common.active" : "common.inactive")}
                    </Badge>
                    <Badge tone="slate">{t(TYPE_KEY[account.type])}</Badge>
                  </div>
                  <p className="text-xs text-slate-400">
                    {account.code} · {companiesById[account.companyId]?.name ?? "—"}
                    {account.projectId && ` · ${projectsById[account.projectId]?.name ?? "—"}`}
                    {account.bankName && ` · ${account.bankName}`}
                  </p>
                </div>
              </div>
              <div className="flex items-center gap-4">
                <div className="text-right">
                  <p className="text-xs text-slate-400">{t("treasury.currentBalance")}</p>
                  <p className="text-sm font-semibold text-slate-900">
                    {formatAED(treasuryAccountBalance(journalEntries, account.glAccountId))}
                  </p>
                </div>
                <button
                  type="button"
                  onClick={() => setEditingAccount(account)}
                  className="flex items-center gap-1.5 rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-slate-50"
                >
                  <Pencil size={13} /> {t("common.edit")}
                </button>
              </div>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title={t("treasury.newAccount")} onClose={() => setShowForm(false)}>
          <TreasuryAccountForm onDone={() => setShowForm(false)} />
        </Modal>
      )}

      {editingAccount && (
        <Modal title={t("treasury.editAccount")} onClose={() => setEditingAccount(null)}>
          <TreasuryAccountForm account={editingAccount} onDone={() => setEditingAccount(null)} />
        </Modal>
      )}
    </div>
  );
}
