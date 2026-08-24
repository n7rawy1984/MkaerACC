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
import type { Party } from "../domain/types";

function CustodianPanel({ custodian }: { custodian: Party }) {
  const {
    advances,
    expenses,
    custodySettlements,
    journalEntries,
    parties,
    finalizeCustodySettlement,
    discardDraftSettlement,
  } = useAppData();
  const [open, setOpen] = useState(false);
  const partiesById = useMemo(() => indexById(parties), [parties]);

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
    if (!window.confirm("Finalize this settlement? It cannot be edited afterward.")) return;
    try {
      finalizeCustodySettlement(id);
    } catch (err) {
      window.alert(err instanceof Error ? err.message : "Could not finalize this settlement.");
    }
  }

  function handleDiscard(id: string) {
    if (!window.confirm("Discard this draft settlement?")) return;
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
            <p className="text-xs text-slate-400">Total Received</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(given)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">Expenses Charged</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(charged)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">Cash Returned</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(returned)}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">Current Balance</p>
            <p className={`text-sm font-semibold ${balance < 0 ? "text-rose-600" : "text-emerald-600"}`}>
              {formatAED(balance)}
            </p>
          </div>
          <div>
            <p className="text-xs text-slate-400">Open Advances</p>
            <p className="text-sm font-semibold text-slate-900">{custodianAdvances.length}</p>
          </div>
          <div>
            <p className="text-xs text-slate-400">Last Settlement</p>
            <p className="text-sm font-semibold text-slate-900">{lastSettled ? formatDate(lastSettled) : "—"}</p>
          </div>
        </div>
      </button>

      {open && (
        <div className="space-y-4 border-t border-slate-100 px-5 py-4">
          <div>
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">Advances</p>
            {custodianAdvances.length === 0 && <p className="text-sm text-slate-400">None recorded yet.</p>}
            <div className="space-y-1">
              {custodianAdvances.map((a) => (
                <div key={a.id} className="flex items-center justify-between text-sm">
                  <span className="text-slate-600">
                    {formatDate(a.date)} · {partiesById[a.fromPartyId]?.name}
                    {a.reference ? ` · ${a.reference}` : ""}
                  </span>
                  <span className="font-medium text-slate-900">{formatAED(a.amount)}</span>
                </div>
              ))}
            </div>
          </div>

          <div>
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">Expenses Charged</p>
            {custodianExpenses.length === 0 && <p className="text-sm text-slate-400">None recorded yet.</p>}
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
            <p className="mb-1.5 text-xs font-semibold uppercase tracking-wide text-slate-400">Settlements</p>
            {custodianSettlements.length === 0 && <p className="text-sm text-slate-400">No settlements yet.</p>}
            <div className="space-y-2">
              {custodianSettlements.map((s) => (
                <div key={s.id} className="flex items-center justify-between rounded-lg border border-slate-100 px-3 py-2 text-sm">
                  <div>
                    <div className="flex items-center gap-2">
                      <span className="font-medium text-slate-800">{s.settlementNumber}</span>
                      <Badge tone={s.status === "SETTLED" ? "green" : "slate"}>{s.status}</Badge>
                    </div>
                    <p className="text-xs text-slate-400">
                      {formatDate(s.settlementDate)} · {s.selectedExpenseIds.length} expenses
                      {s.cashReturnAmount > 0 && ` · Returned ${formatAED(s.cashReturnAmount)}`}
                    </p>
                  </div>
                  {s.status === "DRAFT" && (
                    <div className="flex gap-2">
                      <button
                        type="button"
                        onClick={() => handleDiscard(s.id)}
                        className="rounded-lg border border-slate-300 px-2.5 py-1 text-xs font-medium text-slate-500 hover:bg-slate-50"
                      >
                        Discard
                      </button>
                      <button
                        type="button"
                        onClick={() => handleFinalize(s.id)}
                        className="rounded-lg bg-slate-900 px-2.5 py-1 text-xs font-medium text-white hover:bg-slate-800"
                      >
                        Finalize
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
  const { parties, advances } = useAppData();
  const [showAdvanceForm, setShowAdvanceForm] = useState(false);
  const [settlementCustodianId, setSettlementCustodianId] = useState<string | null>(null);

  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const partiesById = useMemo(() => indexById(parties), [parties]);

  const recentAdvances = useMemo(() => [...advances].sort((a, b) => (a.date < b.date ? 1 : -1)), [advances]);

  return (
    <div>
      <PageHeader
        title="Advances & Settlements"
        subtitle="How much cash each custodian is holding right now, what they've spent, and what's been reconciled"
        action={
          <div className="flex gap-2">
            <button
              onClick={() => setSettlementCustodianId(custodians[0]?.id ?? null)}
              disabled={custodians.length === 0}
              className="flex items-center gap-2 rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50 disabled:opacity-50"
            >
              <FileCheck2 size={16} /> New Settlement
            </button>
            <button
              onClick={() => setShowAdvanceForm(true)}
              className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
            >
              <Plus size={16} /> New Advance
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
        <CardHeader title="Advance History" subtitle={`${advances.length} advances recorded`} />
        <div className="divide-y divide-slate-100">
          {recentAdvances.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">No advances recorded yet.</p>
          )}
          {recentAdvances.map((a) => (
            <div key={a.id} className="flex items-center justify-between px-5 py-3.5">
              <div>
                <p className="text-sm font-medium text-slate-800">
                  {partiesById[a.fromPartyId]?.name} &rarr; {partiesById[a.custodianId]?.name}
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
        <Modal title="New Cash Advance" onClose={() => setShowAdvanceForm(false)}>
          <AdvanceForm onDone={() => setShowAdvanceForm(false)} />
        </Modal>
      )}

      {settlementCustodianId && (
        <Modal
          title={`New Settlement · ${partiesById[settlementCustodianId]?.name ?? ""}`}
          onClose={() => setSettlementCustodianId(null)}
          width="max-w-2xl"
        >
          {custodians.length > 1 && (
            <div className="mb-4">
              <label className="mb-1 block text-xs font-medium text-slate-600">Custodian</label>
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
