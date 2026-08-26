import { useMemo, useState } from "react";
import { ChevronDown, ChevronUp, FileCheck2, Plus, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card, CardHeader } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { AdvanceForm } from "../components/AdvanceForm";
import { CustodySettlementForm } from "../components/CustodySettlementForm";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { cashReturnedByCustodian, custodianBalance, lastSettlementDate } from "../accounting/ledger";
import { useT } from "../i18n/I18nContext";
import type { AdvanceTransaction, Party } from "../domain/types";

function CustodianPanel({ custodian }: { custodian: Party }) {
  const t = useT();
  const {
    advances,
    expenses,
    custodySettlements,
    journalEntries,
    parties,
    treasuryAccounts,
    finalizeCustodySettlement,
    discardDraftSettlement,
  } = useAppData();
  const [open, setOpen] = useState(false);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const treasuryById = useMemo(() => indexById(treasuryAccounts), [treasuryAccounts]);

  function fundingSourceLabel(a: AdvanceTransaction): string {
    return a.fundingSourceType === "OWNER_CURRENT"
      ? partiesById[a.fundingSourceId]?.name ?? t("common.owner")
      : treasuryById[a.fundingSourceId]?.name ?? t("advanceForm.treasuryGroup");
  }

  const custodianAdvances = useMemo(
    () => advances.filter((a) => a.custodianId === custodian.id).sort((a, b) => (a.date < b.date ? 1 : -1)),
    [advances, custodian.id],
  );
  const custodianExpenses = useMemo(
    () =>
      expenses
        .filter((e) => e.paidFromType === "CUSTODIAN" && e.paidFromPartyId === custodian.id)
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    [expenses, custodian.id],
  );
  const custodianSettlements = useMemo(
    () =>
      custodySettlements
        .filter((s) => s.custodianId === custodian.id)
        .sort((a, b) => (a.createdAt < b.createdAt ? 1 : -1)),
    [custodySettlements, custodian.id],
  );

  const given = custodianAdvances.reduce((sum, a) => sum + a.amount, 0);
  const charged = custodianExpenses.reduce((sum, e) => sum + e.totalAmount, 0);
  const returned = cashReturnedByCustodian(custodySettlements, custodian.id);
  const balance = custodianBalance(journalEntries, custodian.id);
  const lastSettled = lastSettlementDate(custodySettlements, custodian.id);

  function handleFinalize(id: string) {
    if (!window.confirm(t("advances.confirmFinalize"))) return;
    try {
      finalizeCustodySettlement(id);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : t("advances.finalizeError"));
    }
  }

  function handleDiscard(id: string) {
    if (!window.confirm(t("advances.confirmDiscard"))) return;
    discardDraftSettlement(id);
  }

  return (
    <Card>
      <button
        type="button"
        onClick={() => setOpen((v) => !v)}
        className="flex w-full flex-col gap-4 px-5 py-4 text-left"
      >
        <div className="flex items-center justify-between">
          <div className="flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
              <Wallet size={18} />
            </div>
            <div>
              <p className="text-sm font-semibold text-slate-900">{custodian.name}</p>
              <p className="text-xs text-slate-400">{custodian.notes ?? "Custodian"}</p>
            </div>
          </div>
          {open ? <ChevronUp size={16} className="text-slate-400" /> : <ChevronDown size={16} className="text-slate-400" />}
        </div>
        <div className="grid grid-cols-3 gap-3 text-center sm:grid-cols-6">
          <div>
            <p className="text-xs text-slate-400">{t("advances.totalReceived")}</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(given)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("advances.expensesCharged")}</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(charged)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("advances.cashReturned")}</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(returned)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("advances.currentBalance")}</p>
            <p className={`text-sm font-semibold ${balance < 0 ? "text-rose-600" : "text-emerald-600"}`}>
              {formatAED(balance)}
            </p>
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("advances.openAdvances")}</p>
            <p className="text-sm font-semibold text-slate-900">{custodianAdvances.length}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">{t("advances.lastSettlement")}</p>
            <p className="text-sm font-semibold text-slate-900">{lastSettled ? formatDate(lastSettled) : "—"}</p>
          </div>
        </div>
      </button>

      {open && (
        <div className="space-y-4 border-t border-slate-100 px-5 py-4">
          <div>
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
              {t("advances.sectionAdvances")}
            </p>
            {custodianAdvances.length === 0 && (
              <p className="text-sm text-slate-400">{t("advances.noneRecordedYet")}</p>
            )}
            <div className="space-y-1">
              {custodianAdvances.map((a) => (
                <div key={a.id} className="flex items-center justify-between text-sm">
                  <span className="text-slate-600">
                    {formatDate(a.date)} · {fundingSourceLabel(a)}
                    {a.reference ? ` · ${a.reference}` : ""}
                  </span>
                  <span className="font-medium text-slate-900">{formatAED(a.amount)}</span>
                </div>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
              {t("advances.sectionExpensesCharged")}
            </p>
            {custodianExpenses.length === 0 && (
              <p className="text-sm text-slate-400">{t("advances.noneRecordedYet")}</p>
            )}
            <div className="max-h-40 space-y-1 overflow-y-auto">
              {custodianExpenses.map((e) => (
                <div key={e.id} className="flex items-center justify-between text-sm">
                  <span className="text-slate-600">
                    {formatDate(e.date)} · {e.description}
                  </span>
                  <span className="font-medium text-slate-900">{formatAED(e.totalAmount)}</span>
                </div>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">
              {t("advances.sectionSettlements")}
            </p>
            {custodianSettlements.length === 0 && (
              <p className="text-sm text-slate-400">{t("advances.noSettlementsYet")}</p>
            )}
            <div className="space-y-2">
              {custodianSettlements.map((s) => (
                <div key={s.id} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2 text-sm">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-slate-800">{s.settlementNumber}</span>
                      <Badge tone={s.status === "SETTLED" ? "green" : "slate"}>
                        {t(s.status === "SETTLED" ? "settlementStatus.SETTLED" : "settlementStatus.DRAFT")}
                      </Badge>
                    </div>
                    <p className="text-xs text-slate-400">
                      {formatDate(s.settlementDate)} · {t("advances.expensesCount", { count: s.selectedExpenseIds.length })}
                      {s.cashReturnAmount > 0 &&
                        ` · ${t("advances.returnedAmount", { amount: formatAED(s.cashReturnAmount) })}`}
                    </p>
                  </div>
                  {s.status === "DRAFT" && (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleDiscard(s.id)}
                        className="rounded-lg border border-slate-300 px-2.5 py-1 text-xs font-medium text-slate-500 hover:bg-slate-50"
                      >
                        {t("advances.discard")}
                      </button>
                      <button
                        type="button"
                        onClick={() => handleFinalize(s.id)}
                        className="rounded-lg bg-slate-900 px-2.5 py-1 text-xs font-medium text-white hover:bg-slate-800"
                      >
                        {t("advances.finalize")}
                      </button>
                    </div>
                  )}
                </div>
              ))}
            </div>
          </div>
        </div>
      )}
    </Card>
  );
}

export function Advances() {
  const t = useT();
  const { parties, advances, treasuryAccounts } = useAppData();
  const [showAdvanceForm, setShowAdvanceForm] = useState(false);
  const [settlementCustodianId, setSettlementCustodianId] = useState<string | null>(null);

  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const treasuryById = useMemo(() => indexById(treasuryAccounts), [treasuryAccounts]);

  function fundingSourceLabel(a: (typeof advances)[number]): string {
    return a.fundingSourceType === "OWNER_CURRENT"
      ? (partiesById[a.fundingSourceId]?.name ?? t("common.owner"))
      : (treasuryById[a.fundingSourceId]?.name ?? t("advanceForm.treasuryGroup"));
  }

  const recentAdvances = useMemo(() => [...advances].sort((a, b) => (a.date < b.date ? 1 : -1)), [advances]);

  return (
    <div>
      <PageHeader
        title={t("advances.title")}
        subtitle={t("advances.subtitle")}
        action={
          <div className="flex gap-2">
            <button
              onClick={() => setSettlementCustodianId(custodians[0]?.id ?? null)}
              disabled={custodians.length === 0}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
            >
              <FileCheck2 size={16} /> {t("advances.newSettlement")}
            </button>
            <button
              onClick={() => setShowAdvanceForm(true)}
              className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
            >
              <Plus size={16} /> {t("advances.newAdvance")}
            </button>
          </div>
        }
      />

      <div className="space-y-4">
        {custodians.map((c) => (
          <CustodianPanel key={c.id} custodian={c} />
        ))}
      </div>

      <Card className="mt-6">
        <CardHeader title={t("advances.historyTitle")} subtitle={t("advances.historyCount", { count: advances.length })} />
        <div className="divide-y divide-slate-100">
          {recentAdvances.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("advances.noAdvancesRecorded")}</p>
          )}
          {recentAdvances.map((a) => (
            <div key={a.id} className="flex items-center justify-between px-5 py-3.5">
              <div>
                <p className="text-sm font-medium text-slate-800">
                  {fundingSourceLabel(a)} &rarr; {partiesById[a.custodianId]?.name}
                </p>
                <p className="text-xs text-slate-400">
                  {formatDate(a.date)}
                  {a.reference && ` · ${a.reference}`}
                </p>
              </div>
              <p className="text-sm font-semibold text-slate-900">{formatAED(a.amount)}</p>
            </div>
          ))}
        </div>
      </Card>

      {showAdvanceForm && (
        <Modal title={t("advances.newAdvanceModalTitle")} onClose={() => setShowAdvanceForm(false)}>
          <AdvanceForm onDone={() => setShowAdvanceForm(false)} />
        </Modal>
      )}

      {settlementCustodianId && (
        <Modal
          title={t("advances.newSettlementModalTitle", { name: partiesById[settlementCustodianId]?.name ?? "" })}
          onClose={() => setSettlementCustodianId(null)}
          width="max-w-2xl"
        >
          {custodians.length > 1 && (
            <div className="mb-4">
              <label className="mb-1 block text-xs font-medium text-slate-600">{t("advances.custodianLabel")}</label>
              <select
                value={settlementCustodianId}
                onChange={(e) => setSettlementCustodianId(e.target.value)}
                className="w-full rounded-lg border border-slate-300 px-3 py-2 text-sm text-slate-900 focus:border-slate-500 focus:outline-none focus:ring-1 focus:ring-slate-500"
              >
                {custodians.map((c) => (
                  <option key={c.id} value={c.id}>
                    {c.name}
                  </option>
                ))}
              </select>
            </div>
          )}
          <CustodySettlementForm
            key={settlementCustodianId}
            custodianId={settlementCustodianId}
            onDone={() => setSettlementCustodianId(null)}
          />
        </Modal>
      )}
    </div>
  );
}
