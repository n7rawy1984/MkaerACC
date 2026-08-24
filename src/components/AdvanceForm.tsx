import { useMemo, useState } from "react";
import { useAppData, type NewAdvanceInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { PaymentMethod } from "../domain/types";

const today = () => new Date().toISOString().slice(0, 10);

export function AdvanceForm({ onDone }: { onDone: () => void }) {
  const { parties, projects, addAdvance } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);

  const [date, setDate] = useState(today());
  const [fromPartyId, setFromPartyId] = useState(owners[0]?.id ?? "");
  const [custodianId, setCustodianId] = useState(custodians[0]?.id ?? "");
  const [amount, setAmount] = useState("");
  const [projectId, setProjectId] = useState("");
  const [paymentMethod, setPaymentMethod] = useState<PaymentMethod>("BANK");
  const [reference, setReference] = useState("");
  const [notes, setNotes] = useState("");
  const [errors, setErrors] = useState<Record<string, string>>({});

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!date) e.date = "Required";
    if (!fromPartyId) e.fromPartyId = "Required";
    if (!custodianId) e.custodianId = "Required";
    const n = Number(amount);
    if (!Number.isFinite(n) || n <= 0) e.amount = "Enter an amount greater than zero";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    if (Object.keys(validation).length > 0) return;

    const input: NewAdvanceInput = {
      date,
      fromPartyId,
      custodianId,
      amount: Number(amount),
      projectId: projectId || undefined,
      paymentMethod,
      reference: reference.trim() || undefined,
      notes: notes.trim() || undefined,
    };
    addAdvance(input);
    onDone();
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
        <Field label="From (Owner)" required error={errors.fromPartyId}>
          <select value={fromPartyId} onChange={(e) => setFromPartyId(e.target.value)} className={inputClassName}>
            {owners.map((o) => (
              <option key={o.id} value={o.id}>
                {o.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="To (Custodian)" required error={errors.custodianId}>
          <select value={custodianId} onChange={(e) => setCustodianId(e.target.value)} className={inputClassName}>
            {custodians.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Project (optional)">
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">— General —</option>
            {projects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
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
      </div>

      <Field label="Reference (optional)">
        <input value={reference} onChange={(e) => setReference(e.target.value)} className={inputClassName} />
      </Field>

      <Field label="Notes (optional)">
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
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
          Save Advance
        </button>
      </div>
    </form>
  );
}
