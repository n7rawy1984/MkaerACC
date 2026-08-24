import { useMemo, useState } from "react";
import { useAppData, type NewSupplierPaymentInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { SupplierPaymentSourceType } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function SupplierPaymentForm({
  supplierId,
  onDone,
}: {
  supplierId: string;
  onDone: () => void;
}) {
  const { parties, addSupplierPayment } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);

  const [date, setDate] = useState(today());
  const [amount, setAmount] = useState("");
  const [sourceType, setSourceType] = useState<SupplierPaymentSourceType>("BANK");
  const [sourcePartyId, setSourcePartyId] = useState("");
  const [reference, setReference] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  const needsParty = sourceType === "CUSTODIAN" || sourceType === "OWNER";
  const partyOptions = sourceType === "CUSTODIAN" ? custodians : owners;

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    if (needsParty && !sourcePartyId) e.sourcePartyId = "Select who paid";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    if (Object.keys(validation).length > 0) return;

    const input: NewSupplierPaymentInput = {
      date,
      supplierId,
      amount: Number(amount),
      sourceType,
      sourcePartyId: needsParty ? sourcePartyId : undefined,
      reference: reference.trim() || undefined,
    };
    addSupplierPayment(input);
    onDone();
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

      <Field label="Paid From" required>
        <select
          value={sourceType}
          onChange={(e) => {
            setSourceType(e.target.value as SupplierPaymentSourceType);
            setSourcePartyId("");
          }}
          className={inputClassName}
        >
          <option value="BANK">Company Bank</option>
          <option value="CASH">Company Cash</option>
          <option value="CUSTODIAN">Custodian</option>
          <option value="OWNER">Owner</option>
        </select>
      </Field>

      {needsParty && (
        <Field label={sourceType === "CUSTODIAN" ? "Custodian" : "Owner"} required error={errors.sourcePartyId}>
          <select value={sourcePartyId} onChange={(e) => setSourcePartyId(e.target.value)} className={inputClassName}>
            <option value="">Select…</option>
            {partyOptions.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      )}

      <Field label="Reference (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

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
          Save Payment
        </button>
      </div>
    </form>
  );
}
