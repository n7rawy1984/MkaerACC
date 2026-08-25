import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractorAdvanceInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { PaymentMethod, SubcontractorFundingSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SubcontractorAdvanceForm({
  contractId,
  onDone,
}: {
  contractId: string;
  onDone: () => void;
}) {
  const { parties, subcontracts, treasuryAccounts, addSubcontractorAdvance } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);
  const contract = subcontracts.find((c) => c.id === contractId);

  const eligibleTreasuryAccounts = useMemo(
    () => treasuryAccounts.filter((t) => t.status === "ACTIVE" && (!t.projectId || t.projectId === contract?.projectId)),
    [treasuryAccounts, contract?.projectId],
  );

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState("");
  const [paymentSourceType, setPaymentSourceType] = useState<SubcontractorFundingSourceType>("TREASURY");
  const [paymentSourcePartyId, setPaymentSourcePartyId] = useState("");
  const [treasuryAccountId, setTreasuryAccountId] = useState(eligibleTreasuryAccounts[0]?.id ?? "");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("TRANSFER");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const needsParty = paymentSourceType === "OWNER" || paymentSourceType === "CUSTODIAN";
  const needsTreasury = paymentSourceType === "TREASURY";
  const partyOptions = paymentSourceType === "OWNER" ? owners : custodians;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    if (needsParty && !paymentSourcePartyId) e.paymentSourcePartyId = "Select the source";
    if (needsTreasury && !treasuryAccountId) e.treasuryAccountId = "Select the cash/bank account";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSubcontractorAdvanceInput = {
      contractId,
      date,
      amount: Number(amount),
      paymentSourceType,
      paymentSourcePartyId: needsParty ? paymentSourcePartyId : undefined,
      treasuryAccountId: needsTreasury ? treasuryAccountId : undefined,
      paymentMethod,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
    };
    try {
      addSubcontractorAdvance(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this advance.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Date" required>
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
        <Field label="Paid From" required>
          <select
            value={paymentSourceType}
            onChange={(e) => {
              setPaymentSourceType(e.target.value as SubcontractorFundingSourceType);
              setPaymentSourcePartyId("");
            }}
            className={inputClassName}
          >
            <option value="TREASURY">Cash / Bank (Treasury)</option>
            <option value="OWNER">Owner Current Account</option>
            <option value="CUSTODIAN">Custodian</option>
          </select>
        </Field>
        {needsTreasury ? (
          <Field label="Cash / Bank Account" required error={errors.treasuryAccountId}>
            <select value={treasuryAccountId} onChange={(e) => setTreasuryAccountId(e.target.value)} className={inputClassName}>
              <option value="">Select…</option>
              {eligibleTreasuryAccounts.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </Field>
        ) : needsParty ? (
          <Field
            label={paymentSourceType === "OWNER" ? "Owner" : "Custodian"}
            required
            error={errors.paymentSourcePartyId}
          >
            <select
              value={paymentSourcePartyId}
              onChange={(e) => setPaymentSourcePartyId(e.target.value)}
              className={inputClassName}
            >
              <option value="">Select…</option>
              {partyOptions.map((p) => (
                <option key={p.id} value={p.id}>
                  {p.name}
                </option>
              ))}
            </select>
          </Field>
        ) : (
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
        )}
      </div>

      <Field label="Reference (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      <Field label="Notes (optional)">
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
      </Field>

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        Recorded as a recoverable advance to the subcontractor — it will not affect project cost until it's
        recovered through a certificate.
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
          Save Advance
        </button>
      </div>
    </form>
  );
}
