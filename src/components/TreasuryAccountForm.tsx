import { useMemo, useState } from "react";
import { useAppData, type NewTreasuryAccountInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { TreasuryAccount, TreasuryAccountStatus, TreasuryAccountType } from "../domain/types";

const TYPE_LABELS: Record<TreasuryAccountType, string> = {
  CASH: "Cash",
  PETTY_CASH: "Petty Cash",
  BANK: "Bank",
  PROJECT_CASH_BOX: "Project Cash Box",
  PROJECT_BANK: "Project Bank Account",
};

export function TreasuryAccountForm({ account, onDone }: { account?: TreasuryAccount; onDone: () => void }) {
  const { companies, projects, accounts, addTreasuryAccount, updateTreasuryAccount } = useAppData();
  const activeCompanies = useMemo(() => companies.filter((c) => c.status === "ACTIVE"), [companies]);
  const isEdit = Boolean(account);
  const glAccount = account ? accounts.find((a) => a.id === account.glAccountId) : undefined;

  const [companyId, setCompanyId] = useState(account?.companyId ?? activeCompanies[0]?.id ?? "");
  const [projectId, setProjectId] = useState(account?.projectId ?? "");
  const [code, setCode] = useState(account?.code ?? "");
  const [name, setName] = useState(account?.name ?? "");
  const [type, setType] = useState<TreasuryAccountType>(account?.type ?? "CASH");
  const [status, setStatus] = useState<TreasuryAccountStatus>(account?.status ?? "ACTIVE");
  const [bankName, setBankName] = useState(account?.bankName ?? "");
  const [accountReference, setAccountReference] = useState(account?.accountReference ?? "");
  const [notes, setNotes] = useState(account?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const companyProjects = useMemo(() => projects.filter((p) => p.companyId === companyId), [projects, companyId]);
  const isBankType = type === "BANK" || type === "PROJECT_BANK";

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!code.trim()) e.code = "Required";
    if (!name.trim()) e.name = "Required";
    if (!companyId) e.companyId = "Select a company";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewTreasuryAccountInput = {
      companyId,
      projectId: projectId || undefined,
      code: code.trim(),
      name: name.trim(),
      type,
      bankName: isBankType ? bankName.trim() || undefined : undefined,
      accountReference: isBankType ? accountReference.trim() || undefined : undefined,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && account) updateTreasuryAccount(account.id, { ...input, status });
      else addTreasuryAccount(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this treasury account.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Company" required error={errors.companyId}>
          <select
            value={companyId}
            onChange={(e) => {
              setCompanyId(e.target.value);
              setProjectId("");
            }}
            className={inputClassName}
          >
            {activeCompanies.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Project (optional — leave blank for a company-wide account)">
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">— Company-wide —</option>
            {companyProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Code" required error={errors.code}>
          <input value={code} onChange={(e) => setCode(e.target.value)} className={inputClassName} placeholder="e.g. BANK-01" />
        </Field>
        <Field label="Name" required error={errors.name}>
          <input value={name} onChange={(e) => setName(e.target.value)} className={inputClassName} placeholder="e.g. Main Bank" />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Type" required>
          <select value={type} onChange={(e) => setType(e.target.value as TreasuryAccountType)} className={inputClassName}>
            {(Object.keys(TYPE_LABELS) as TreasuryAccountType[]).map((t) => (
              <option key={t} value={t}>
                {TYPE_LABELS[t]}
              </option>
            ))}
          </select>
        </Field>
        {isEdit && (
          <Field label="Status">
            <select value={status} onChange={(e) => setStatus(e.target.value as TreasuryAccountStatus)} className={inputClassName}>
              <option value="ACTIVE">Active</option>
              <option value="INACTIVE">Inactive</option>
            </select>
          </Field>
        )}
      </div>

      <div className="rounded-lg bg-slate-50 px-3 py-2 text-xs text-slate-500">
        {isEdit && glAccount ? (
          <>
            Posts to its own dedicated GL account{" "}
            <span className="font-semibold text-slate-700">
              {glAccount.code} · {glAccount.name}
            </span>
            . This never changes after creation, even if you edit the type below.
          </>
        ) : (
          <>
            A new, dedicated GL account will be created automatically for this treasury account — under{" "}
            <span className="font-semibold text-slate-700">
              {type === "BANK" || type === "PROJECT_BANK" ? "1100 Bank Account" : "1000 Cash on Hand"}
            </span>
            . You never pick Debit/Credit accounts directly.
          </>
        )}
      </div>

      {isBankType && (
        <div className="grid grid-cols-2 gap-4">
          <Field label="Bank Name (optional)">
            <input value={bankName} onChange={(e) => setBankName(e.target.value)} className={inputClassName} />
          </Field>
          <Field label="Account Reference (optional)">
            <input value={accountReference} onChange={(e) => setAccountReference(e.target.value)} className={inputClassName} />
          </Field>
        </div>
      )}

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
          {isEdit ? "Save Changes" : "Create Treasury Account"}
        </button>
      </div>
    </form>
  );
}
