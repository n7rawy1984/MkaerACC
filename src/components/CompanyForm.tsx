import { useState } from "react";
import { useAppData, type NewCompanyInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { Company, CompanyStatus } from "../domain/types";

export function CompanyForm({ company, onDone }: { company?: Company; onDone: () => void }) {
  const { addCompany, updateCompany } = useAppData();
  const isEdit = Boolean(company);

  const [code, setCode] = useState(company?.code ?? "");
  const [name, setName] = useState(company?.name ?? "");
  const [legalName, setLegalName] = useState(company?.legalName ?? "");
  const [trn, setTrn] = useState(company?.trn ?? "");
  const [address, setAddress] = useState(company?.address ?? "");
  const [status, setStatus] = useState<CompanyStatus>(company?.status ?? "ACTIVE");
  const [notes, setNotes] = useState(company?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!code.trim()) e.code = "Required";
    if (!name.trim()) e.name = "Required";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewCompanyInput = {
      code: code.trim(),
      name: name.trim(),
      legalName: legalName.trim() || undefined,
      trn: trn.trim() || undefined,
      address: address.trim() || undefined,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && company) updateCompany(company.id, { ...input, status });
      else addCompany(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this company.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Company Code" required error={errors.code}>
          <input value={code} onChange={(e) => setCode(e.target.value)} className={inputClassName} placeholder="e.g. CO-001" />
        </Field>
        <Field label="Trade Name" required error={errors.name}>
          <input value={name} onChange={(e) => setName(e.target.value)} className={inputClassName} />
        </Field>
      </div>

      <Field label="Legal Name (optional)">
        <input value={legalName} onChange={(e) => setLegalName(e.target.value)} className={inputClassName} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Tax Registration Number (optional)">
          <input value={trn} onChange={(e) => setTrn(e.target.value)} className={inputClassName} />
        </Field>
        {isEdit && (
          <Field label="Status">
            <select value={status} onChange={(e) => setStatus(e.target.value as CompanyStatus)} className={inputClassName}>
              <option value="ACTIVE">Active</option>
              <option value="INACTIVE">Inactive</option>
            </select>
          </Field>
        )}
      </div>

      <Field label="Address (optional)">
        <input value={address} onChange={(e) => setAddress(e.target.value)} className={inputClassName} />
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
          {isEdit ? "Save Changes" : "Create Company"}
        </button>
      </div>
    </form>
  );
}
