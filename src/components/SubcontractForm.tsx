import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import type { Subcontract, SubcontractStatus } from "../domain/types";

export function SubcontractForm({
  contract,
  defaultProjectId,
  defaultSubcontractorId,
  onDone,
}: {
  contract?: Subcontract;
  defaultProjectId?: string;
  defaultSubcontractorId?: string;
  onDone: () => void;
}) {
  const { companies, projects, parties, addSubcontract, updateSubcontract } = useAppData();
  const isEdit = Boolean(contract);

  const subcontractors = useMemo(() => parties.filter((p) => p.type === "SUBCONTRACTOR"), [parties]);
  const eligibleSubcontractors = useMemo(
    () => subcontractors.filter((s) => s.status !== "INACTIVE" || s.id === contract?.subcontractorId),
    [subcontractors, contract?.subcontractorId],
  );

  const defaultProject = projects.find((p) => p.id === (contract?.projectId ?? defaultProjectId));
  const [companyId, setCompanyId] = useState(defaultProject?.companyId ?? companies[0]?.id ?? "");
  const [projectId, setProjectId] = useState(contract?.projectId ?? defaultProjectId ?? "");
  const [subcontractorId, setSubcontractorId] = useState(contract?.subcontractorId ?? defaultSubcontractorId ?? "");
  const [contractNumber, setContractNumber] = useState(contract?.contractNumber ?? "");
  const [scopeOfWork, setScopeOfWork] = useState(contract?.scopeOfWork ?? "");
  const [originalContractValue, setOriginalContractValue] = useState(
    contract?.originalContractValue?.toString() ?? "",
  );
  const [approvedVariations, setApprovedVariations] = useState(contract?.approvedVariations?.toString() ?? "0");
  const [retentionPercent, setRetentionPercent] = useState(contract?.retentionPercent?.toString() ?? "10");
  const [startDate, setStartDate] = useState(contract?.startDate ?? "");
  const [endDate, setEndDate] = useState(contract?.endDate ?? "");
  const [status, setStatus] = useState<SubcontractStatus>(contract?.status ?? "ACTIVE");
  const [notes, setNotes] = useState(contract?.notes ?? "");
  const [errors, setErrors] = useState<Record<string, string>>({});
  const [submitError, setSubmitError] = useState("");

  const companyProjects = useMemo(
    () => projects.filter((p) => p.companyId === companyId && (p.status !== "CLOSED" || p.id === contract?.projectId)),
    [projects, companyId, contract?.projectId],
  );

  function validate(): Record<string, string> {
    const e: Record<string, string> = {};
    if (!projectId) e.projectId = "Select a project";
    if (!subcontractorId) e.subcontractorId = "Select a subcontractor";
    if (!contractNumber.trim()) e.contractNumber = "Required";
    if (!scopeOfWork.trim()) e.scopeOfWork = "Required";
    const value = Number(originalContractValue);
    if (!originalContractValue || Number.isNaN(value) || value < 0) e.originalContractValue = "Must be zero or more";
    const retention = Number(retentionPercent);
    if (Number.isNaN(retention) || retention < 0 || retention > 100) e.retentionPercent = "Must be between 0 and 100";
    return e;
  }

  function handleSubmit(ev: React.FormEvent) {
    ev.preventDefault();
    const validation = validate();
    setErrors(validation);
    setSubmitError("");
    if (Object.keys(validation).length > 0) return;

    const input: NewSubcontractInput = {
      projectId,
      subcontractorId,
      contractNumber: contractNumber.trim(),
      scopeOfWork: scopeOfWork.trim(),
      originalContractValue: Number(originalContractValue),
      approvedVariations: Number(approvedVariations) || 0,
      retentionPercent: Number(retentionPercent),
      startDate: startDate || undefined,
      endDate: endDate || undefined,
      status,
      notes: notes.trim() || undefined,
    };

    try {
      if (isEdit && contract) updateSubcontract(contract.id, input);
      else addSubcontract(input);
      onDone();
    } catch (err) {
      setSubmitError(err instanceof Error ? err.message : "Could not save this contract.");
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label="Company" required>
          <select
            value={companyId}
            onChange={(e) => {
              setCompanyId(e.target.value);
              setProjectId("");
            }}
            className={inputClassName}
          >
            {companies.map((c) => (
              <option key={c.id} value={c.id}>
                {c.name}
              </option>
            ))}
          </select>
        </Field>
        <Field label="Project" required error={errors.projectId}>
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">Select…</option>
            {companyProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name} ({p.code})
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label="Subcontractor" required error={errors.subcontractorId}>
        <select value={subcontractorId} onChange={(e) => setSubcontractorId(e.target.value)} className={inputClassName}>
          <option value="">Select…</option>
          {eligibleSubcontractors.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
              {s.status === "INACTIVE" ? " (Inactive)" : ""}
            </option>
          ))}
        </select>
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Contract Number" required error={errors.contractNumber}>
          <input
            value={contractNumber}
            onChange={(e) => setContractNumber(e.target.value)}
            className={inputClassName}
            placeholder="e.g. SC-AN-02"
          />
        </Field>
        <Field label="Status" required>
          <select value={status} onChange={(e) => setStatus(e.target.value as SubcontractStatus)} className={inputClassName}>
            <option value="ACTIVE">Active</option>
            <option value="COMPLETED">Completed</option>
            <option value="CLOSED">Closed</option>
          </select>
        </Field>
      </div>

      <Field label="Scope of Work" required error={errors.scopeOfWork}>
        <textarea
          value={scopeOfWork}
          onChange={(e) => setScopeOfWork(e.target.value)}
          className={inputClassName}
          rows={2}
        />
      </Field>

      <div className="grid grid-cols-3 gap-4">
        <Field label="Original Value (AED)" required error={errors.originalContractValue}>
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
        <Field label="Approved Variations (AED)">
          <input
            type="number"
            step="0.01"
            value={approvedVariations}
            onChange={(e) => setApprovedVariations(e.target.value)}
            className={inputClassName}
          />
        </Field>
        <Field label="Retention (%)" required error={errors.retentionPercent}>
          <input
            type="number"
            min="0"
            max="100"
            step="0.1"
            value={retentionPercent}
            onChange={(e) => setRetentionPercent(e.target.value)}
            className={inputClassName}
          />
        </Field>
      </div>

      <div className="grid grid-cols-2 gap-4">
        <Field label="Start Date (optional)">
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label="Expected End Date (optional)">
          <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={inputClassName} />
        </Field>
      </div>

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
          {isEdit ? "Save Changes" : "Create Subcontract"}
        </button>
      </div>
    </form>
  );
}
