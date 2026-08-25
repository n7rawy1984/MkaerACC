import { useMemo, useState } from "react";
import { useAppData, type NewProjectInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { Project, ProjectStatus } from "../domain/types";

export function ProjectForm({ project, onDone }: { project?: Project; onDone: () => void }) {
  const { companies, treasuryAccounts, addProject, updateProject } = useAppData();
  const activeCompanies = useMemo(() => companies.filter((c) => c.status === "ACTIVE"), [companies]);
  const isEdit = Boolean(project);

  const [code, setCode] = useState(project?.code ?? "");
  const [name, setName] = useState(project?.name ?? "");
  const [companyId, setCompanyId] = useState(project?.companyId ?? activeCompanies[0]?.id ?? "");
  const [status, setStatus] = useState<ProjectStatus>(project?.status ?? "PLANNING");
  const [client, setClient] = useState(project?.client ?? "");
  const [location, setLocation] = useState(project?.location ?? "");
  const [contractNumber, setContractNumber] = useState(project?.contractNumber ?? "");
  const [originalContractValue, setOriginalContractValue] = useState(
    project?.originalContractValue?.toString() ?? "",
  );
  const [budget, setBudget] = useState(project?.budget?.toString() ?? "");
  const [startDate, setStartDate] = useState(project?.startDate ?? "");
  const [expectedCompletionDate, setExpectedCompletionDate] = useState(project?.expectedCompletionDate ?? "");
  const [notes, setNotes] = useState(project?.notes ?? "");
  const [dedicatedBankAccountId, setDedicatedBankAccountId] = useState(project?.dedicatedBankAccountId ?? "");
  const [dedicatedCashBoxId, setDedicatedCashBoxId] = useState(project?.dedicatedCashBoxId ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  // Company-wide treasury accounts are always eligible; project-specific ones only if
  // they already belong to this project — never another project's dedicated box (Phase 2B.1A).
  const companyTreasuryAccounts = useMemo(
    () =>
      treasuryAccounts.filter(
        (t) =>
          t.companyId === companyId &&
          t.status === "ACTIVE" &&
          (!t.projectId || t.projectId === project?.id),
      ),
    [treasuryAccounts, companyId, project?.id],
  );
  const bankOptions = useMemo(
    () => companyTreasuryAccounts.filter((t) => t.type === "BANK" || t.type === "PROJECT_BANK"),
    [companyTreasuryAccounts],
  );
  const cashOptions = useMemo(
    () => companyTreasuryAccounts.filter((t) => t.type === "CASH" || t.type === "PETTY_CASH" || t.type === "PROJECT_CASH_BOX"),
    [companyTreasuryAccounts],
  );

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!code.trim()) e.code = "Required";
    if (!name.trim()) e.name = "Required";
    if (!companyId) e.companyId = "Select a company";
    if (originalContractValue && Number(originalContractValue) < 0) e.originalContractValue = "Must be zero or more";
    if (budget && Number(budget) < 0) e.budget = "Must be zero or more";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewProjectInput = {
      code: code.trim(),
      name: name.trim(),
      companyId,
      status,
      client: client.trim() || undefined,
      location: location.trim() || undefined,
      contractNumber: contractNumber.trim() || undefined,
      originalContractValue: originalContractValue ? Number(originalContractValue) : undefined,
      budget: budget ? Number(budget) : undefined,
      startDate: startDate || undefined,
      expectedCompletionDate: expectedCompletionDate || undefined,
      notes: notes.trim() || undefined,
      dedicatedBankAccountId: dedicatedBankAccountId || undefined,
      dedicatedCashBoxId: dedicatedCashBoxId || undefined,
    };

    try {
      if (isEdit && project) updateProject(project.id, input);
      else addProject(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this project.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Project Code" required error={errors.code}>
          <input value={code} onChange={(e) => setCode(e.target.value)} className={inputClassName} placeholder="e.g. PRJ-2026-001" />
        </Field>
        <Field label="Company" required error={errors.companyId}>
          <select value={companyId} onChange={(e) => setCompanyId(e.target.value)} className={inputClassName}>
            {activeCompanies.length === 0 && <option value="">No active companies</option>}
            {activeCompanies.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Project Name" required error={errors.name}>
        <input value={name} onChange={(e) => setName(e.target.value)} className={inputClassName} />
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Client / Project Owner (optional)">
          <input value={client} onChange={(e) => setClient(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Location (optional)">
          <input value={location} onChange={(e) => setLocation(e.target.value)} className={inputClassName} />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Contract Number (optional)">
          <input value={contractNumber} onChange={(e) => setContractNumber(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Status" required>
          <select value={status} onChange={(e) => setStatus(e.target.value as ProjectStatus)} className={inputClassName}>
            <option value="PLANNING">Planning</option>
            <option value="ACTIVE">Active</option>
            <option value="ON_HOLD">On Hold</option>
            <option value="COMPLETED">Completed</option>
            <option value="CLOSED">Closed</option>
          </select>
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Original Contract Value (AED, optional)" error={errors.originalContractValue}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={originalContractValue}
            onChange={(e) => setOriginalContractValue(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
        <Field label="Budget (AED, optional)" error={errors.budget}>
          <input
            type="number"
            min="0"
            step="0.01"
            value={budget}
            onChange={(e) => setBudget(e.target.value)}
            className={inputClassName}
            placeholder="0.00"
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Start Date (optional)">
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Expected Completion Date (optional)">
          <input
            type="date"
            value={expectedCompletionDate}
            onChange={(e) => setExpectedCompletionDate(e.target.value)}
            className={inputClassName}
          />
        </Field>
      </div>

      {(bankOptions.length > 0 || cashOptions.length > 0) && (
        <div className="grid grid-cols-2 gap-4">
          <Field label="Dedicated Bank Account (optional)">
            <select
              value={dedicatedBankAccountId}
              onChange={(e) => setDedicatedBankAccountId(e.target.value)}
              className={inputClassName}
            >
              <option value="">— None —</option>
              {bankOptions.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
          </Field>
          <Field label="Dedicated Cash Box (optional)">
            <select
              value={dedicatedCashBoxId}
              onChange={(e) => setDedicatedCashBoxId(e.target.value)}
              className={inputClassName}
            >
              <option value="">— None —</option>
              {cashOptions.map((t) => (
                <option key={t.id} value={t.id}>
                  {t.name}
                </option>
              ))}
            </select>
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
          {isEdit ? "Save Changes" : "Create Project"}
        </button>
      </div>
    </form>
  );
}
