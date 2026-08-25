import { useEffect, useMemo, useState } from "react";
import { useAppData, type NewAdvanceInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { AdvanceFundingSourceType, PaymentMethod } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

/** "treasury:<id>" or "owner:<id>" — a single select needs one flat value even
 * though it represents two different funding-source kinds under the hood. */
function encodeFundingSource(type: AdvanceFundingSourceType, id: string): string {
  return `${type === "TREASURY" ? "treasury" : "owner"}:${id}`;
}
function decodeFundingSource(value: string): { type: AdvanceFundingSourceType; id: string } | null {
  const [kind, id] = value.split(":");
  if (!kind || !id) return null;
  return { type: kind === "treasury" ? "TREASURY" : "OWNER_CURRENT", id };
}

export function AdvanceForm({ onDone }: { onDone: () => void }) {
  const { parties, projects, treasuryAccounts, addAdvance } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const openProjects = useMemo(() => projects.filter((p) => p.status !== "CLOSED"), [projects]);

  const [date, setDate] = useState(today());
  const [custodianId, setCustodianId] = useState(custodians[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [projectId, setProjectId] = useState("");
  const [fundingSource, setFundingSource] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("BANK");

  const selectedProject = projects.find((p) => p.id === projectId);
  // Company-wide treasury accounts are always eligible; project-specific ones only
  // for their own project — never another project's dedicated cash box (Phase 2B.1A).
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
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  // Defaults (and re-defaults, if the current pick fell out of scope when the
  // project changed) to the first eligible treasury account.
  useEffect(() => {
    const stillEligible = eligibleTreasuryAccounts.some((t) => fundingSource === encodeFundingSource("TREASURY", t.id));
    if (!stillEligible) {
      setFundingSource(eligibleTreasuryAccounts[0] ? encodeFundingSource("TREASURY", eligibleTreasuryAccounts[0].id) : "");
    }
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [eligibleTreasuryAccounts]);

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!date) e.date = "Required";
    if (!custodianId) e.custodianId = "Required";
    if (!fundingSource) e.fundingSource = "Select where the cash is coming from";
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const decoded = decodeFundingSource(fundingSource);
    if (!decoded) {
      setErrors({ fundingSource: "Select where the cash is coming from" });
      return;
    }

    const input: NewAdvanceInput = {
      date,
      custodianId,
      amount: Number(amount),
      projectId: projectId || undefined,
      fundingSourceType: decoded.type,
      fundingSourceId: decoded.id,
      paymentMethod,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
    };
    try {
      addAdvance(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not record this advance.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Date" required error={errors.date}>
          <input type="date" value={date} onChange={(e) => setDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Amount (AED)" required error={errors.amount}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={amount}
            onChange={(e) => setAmount(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="To (Custodian)" required error={errors.custodianId}>
          <select value={custodianId} onChange={(e) => setCustodianId(e.target.value)} className={inputClassName}>
            {custodians.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Project / Purpose (optional)">
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">— General —</option>
            {openProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Funding Source" required error={errors.fundingSource}>
        <select value={fundingSource} onChange={(e) => setFundingSource(e.target.value)} className={inputClassName}>
          <option value="">Select…</option>
          {eligibleTreasuryAccounts.length > 0 && (
            <optgroup label="Treasury">
              {eligibleTreasuryAccounts.map((t) => (
                <option key={t.id} value={encodeFundingSource("TREASURY", t.id)}>
                  {t.name}
                </option>
              ))}
            </optgroup>
          )}
          {owners.length > 0 && (
            <optgroup label="Owners">
              {owners.map((o) => (
                <option key={o.id} value={encodeFundingSource("OWNER_CURRENT", o.id)}>
                  {o.name} (Current Account)
                </option>
              ))}
            </optgroup>
          )}
        </select>
      </Field>

      <Field label="Payment Method">
        <select
          value={paymentMethod}
          onChange={(e) => setPaymentMethod(e.target.value as PaymentMethod)}
          className={inputClassName}
        >
          <option value="CASH">Cash</option>
          <option value="BANK">Bank</option>
          <option value="TRANSFER">Transfer</option>
          <option value="CHEQUE">Cheque</option>
          <option value="OTHER">Other</option>
        </select>
      </Field>

      <Field label="Reference (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      <Field label="Notes (optional)">
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
      </Field>

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
          Save Advance
        </button>
      </div>
    </form>
  );
}
