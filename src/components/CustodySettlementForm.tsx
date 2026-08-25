import { useMemo, useState } from "react";
import { useAppData, type NewCustodySettlementInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { custodianBalance } from "../accounting/ledger";
import type { CashReturnDestinationType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function CustodySettlementForm({ custodianId, onDone }: { custodianId: string; onDone: () => void }) {
  const { parties, projects, expenses, custodySettlements, journalEntries, treasuryAccounts, addCustodySettlement } =
    useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodian = parties.find((p) => p.id === custodianId);
  const openProjects = useMemo(() => projects.filter((p) => p.status !== "CLOSED"), [projects]);

  const claimedExpenseIds = useMemo(
    () => new Set(custodySettlements.flatMap((s) => s.selectedExpenseIds)),
    [custodySettlements],
  );

  const availableExpenses = useMemo(
    () =>
      expenses
        .filter((e) => e.paidFromType === "CUSTODIAN" && e.paidFromPartyId === custodianId)
        .filter((e) => !claimedExpenseIds.has(e.id))
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    [expenses, custodianId, claimedExpenseIds],
  );

  const balance = useMemo(() => custodianBalance(journalEntries, custodianId), [journalEntries, custodianId]);

  const [settlementDate, setSettlementDate] = useState(today());
  const [projectId, setProjectId] = useState("");
  const [selectedIds, setSelectedIds] = useState<Set<string>>(new Set());
  const [cashReturnAmount, setCashReturnAmount] = useState("");
  const [cashReturnDestinationType, setCashReturnDestinationType] = useState<CashReturnDestinationType>("TREASURY");
  const [cashReturnOwnerId, setCashReturnOwnerId] = useState(owners[0]?.id ?? "");
  const [cashReturnTreasuryAccountId, setCashReturnTreasuryAccountId] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const selectedProject = projects.find((p) => p.id === projectId);
  const eligibleTreasuryAccounts = useMemo(
    () =>
      treasuryAccounts.filter((t) => {
        if (t.status !== "ACTIVE") return false;
        if (selectedProject && t.companyId !== selectedProject.companyId) return false;
        if (t.projectId && t.projectId !== projectId) return false;
        return true;
      }),
    [treasuryAccounts, selectedProject, projectId],
  );

  const selectedTotal = useMemo(
    () =>
      availableExpenses
        .filter((e) => selectedIds.has(e.id))
        .reduce((sum, e) => sum + e.totalAmount, 0),
    [availableExpenses, selectedIds],
  );

  const returnAmount = Number(cashReturnAmount) || 0;

  function toggle(id: string) {
    setSelectedIds((prev) => {
      const next = new Set(prev);
      if (next.has(id)) next.delete(id);
      else next.add(id);
      return next;
    });
  }

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!settlementDate) e.settlementDate = "Required";
    if (cashReturnAmount && (returnAmount < 0 || Number.isNaN(returnAmount))) {
      e.cashReturnAmount = "Enter a valid amount";
    }
    if (returnAmount > balance + 0.01) {
      e.cashReturnAmount = `Cannot return more than the current balance (${formatAED(balance)})`;
    }
    if (returnAmount > 0 && cashReturnDestinationType === "OWNER" && !cashReturnOwnerId) {
      e.cashReturnOwnerId = "Select which owner receives the cash";
    }
    if (returnAmount > 0 && cashReturnDestinationType === "TREASURY" && !cashReturnTreasuryAccountId) {
      e.cashReturnTreasuryAccountId = "Select the cash/bank account";
    }
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewCustodySettlementInput = {
      settlementDate,
      custodianId,
      projectId: projectId || undefined,
      notes: notes.trim() || undefined,
      selectedExpenseIds: [...selectedIds],
      cashReturnAmount: returnAmount,
      cashReturnDestinationType: returnAmount > 0 ? cashReturnDestinationType : undefined,
      cashReturnOwnerId: returnAmount > 0 && cashReturnDestinationType === "OWNER" ? cashReturnOwnerId : undefined,
      cashReturnTreasuryAccountId:
        returnAmount > 0 && cashReturnDestinationType === "TREASURY" ? cashReturnTreasuryAccountId : undefined,
    };
    try {
      addCustodySettlement(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this settlement.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        Reconciling <span className="font-semibold text-slate-700">{custodian?.name}</span> — current balance{" "}
        <span className="font-semibold text-slate-700">{formatAED(balance)}</span>. This groups expenses already
        posted; it does not create new expense entries.
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Settlement Date" required error={errors.settlementDate}>
          <input
            type="date"
            value={settlementDate}
            onChange={(e) => setSettlementDate(e.target.value)}
            className={inputClassName}
          />
        </Field>
        <Field label="Project (optional)">
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">— All projects —</option>
            {openProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div>
        <p className="mb-1.5 text-xs font-medium text-slate-600">
          Expenses to include ({selectedIds.size} selected, {formatAED(selectedTotal)})
        </p>
        <div className="max-h-48 overflow-y-auto rounded-lg border border-slate-200">
          {availableExpenses.length === 0 && (
            <p className="px-3 py-4 text-sm text-slate-400">
              No unclaimed expenses for this custodian — everything has already been settled.
            </p>
          )}
          {availableExpenses.map((e) => (
            <label
              key={e.id}
              className="flex items-center gap-3 border-b border-slate-100 px-3 py-2 text-sm last:border-b-0 hover:bg-slate-50"
            >
              <input
                type="checkbox"
                checked={selectedIds.has(e.id)}
                onChange={() => toggle(e.id)}
                className="h-4 w-4 rounded border-slate-300"
              />
              <span className="flex-1 text-slate-700">
                {formatDate(e.date)} · {e.description}
              </span>
              <span className="font-medium text-slate-900">{formatAED(e.totalAmount)}</span>
            </label>
          ))}
        </div>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Cash Returned (optional)" error={errors.cashReturnAmount}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={cashReturnAmount}
            onChange={(e) => setCashReturnAmount(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
        {returnAmount > 0 && (
          <Field label="Return Destination">
            <select
              value={cashReturnDestinationType}
              onChange={(e) => setCashReturnDestinationType(e.target.value as CashReturnDestinationType)}
              className={inputClassName}
            >
              <option value="TREASURY">Cash / Bank (Treasury)</option>
              <option value="OWNER">Owner Directly</option>
            </select>
          </Field>
        )}
      </div>

      {returnAmount > 0 && cashReturnDestinationType === "TREASURY" && (
        <Field label="Cash / Bank Account" required error={errors.cashReturnTreasuryAccountId}>
          <select
            value={cashReturnTreasuryAccountId}
            onChange={(e) => setCashReturnTreasuryAccountId(e.target.value)}
            className={inputClassName}
          >
            <option value="">Select…</option>
            {eligibleTreasuryAccounts.map((t) => (
              <option key={t.id} value={t.id}>
                {t.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      {returnAmount > 0 && cashReturnDestinationType === "OWNER" && (
        <Field label="Owner" required error={errors.cashReturnOwnerId}>
          <select
            value={cashReturnOwnerId}
            onChange={(e) => setCashReturnOwnerId(e.target.value)}
            className={inputClassName}
          >
            {owners.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      <Field label="Notes (optional)">
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
      </Field>

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        This creates a <span className="font-semibold text-slate-700">draft</span> settlement. Review it, then
        finalize it from the Advances &amp; Settlements page — a finalized settlement can no longer be edited.
      </div>

      {submitError && <p className="text-xs text-rose-500">{submitError}</p>}

      <div className="flex justify-end gap-2 pt-2">
        <button
          type="button"
          onClick={onDone}
          className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          Cancel
        </button>
        <button
          type="submit"
          className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
        >
          Save Draft Settlement
        </button>
      </div>
    </form>
  );
}
