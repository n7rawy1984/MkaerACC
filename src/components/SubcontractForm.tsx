import { useMemo, useState } from "react";
import { useAppData, type NewSubcontractInput } from "../state/AppDataContext";
import { Field, inputClassName } from "./ui/Field";
import { useT } from "../i18n/I18nContext";
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
  const t = useT();
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
    if (!projectId) e.projectId = t("subcontractForm.selectProject");
    if (!subcontractorId) e.subcontractorId = t("subcontractForm.selectSubcontractor");
    if (!contractNumber.trim()) e.contractNumber = t("common.required");
    if (!scopeOfWork.trim()) e.scopeOfWork = t("common.required");
    const value = Number(originalContractValue);
    if (!originalContractValue || Number.isNaN(value) || value < 0)
      e.originalContractValue = t("project.form.mustBeZeroOrMore");
    const retention = Number(retentionPercent);
    if (Number.isNaN(retention) || retention < 0 || retention > 100)
      e.retentionPercent = t("subcontractForm.mustBeBetween0And100");
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
      setSubmitError(err instanceof Error ? err.message : t("subcontractForm.saveError"));
    }
  }

  return (
    <form onSubmit={handleSubmit} className="space-y-4">
      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractForm.company")} required>
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
        <Field label={t("subcontractForm.project")} required error={errors.projectId}>
          <select value={projectId} onChange={(e) => setProjectId(e.target.value)} className={inputClassName}>
            <option value="">{t("common.selectEllipsis")}</option>
            {companyProjects.map((p) => (
              <option key={p.id} value={p.id}>
                {p.name} ({p.code})
              </option>
            ))}
          </select>
        </Field>
      </div>

      <Field label={t("subcontractForm.subcontractor")} required error={errors.subcontractorId}>
        <select value={subcontractorId} onChange={(e) => setSubcontractorId(e.target.value)} className={inputClassName}>
          <option value="">{t("common.selectEllipsis")}</option>
          {eligibleSubcontractors.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
              {s.status === "INACTIVE" ? t("subcontractForm.inactiveSuffix") : ""}
            </option>
          ))}
        </select>
      </Field>

      <div className="grid grid-cols-2 gap-4">
        <Field label={t("subcontractForm.contractNumber")} required error={errors.contractNumber}>
          <input
            value={contractNumber}
            onChange={(e) => setContractNumber(e.target.value)}
            className={inputClassName}
            placeholder={t("subcontractForm.contractNumberPlaceholder")}
          />
        </Field>
        <Field label={t("common.status")} required>
          <select value={status} onChange={(e) => setStatus(e.target.value as SubcontractStatus)} className={inputClassName}>
            <option value="ACTIVE">{t("subcontractStatus.ACTIVE")}</option>
            <option value="COMPLETED">{t("subcontractStatus.COMPLETED")}</option>
            <option value="CLOSED">{t("subcontractStatus.CLOSED")}</option>
          </select>
        </Field>
      </div>

      <Field label={t("subcontractForm.scopeOfWork")} required error={errors.scopeOfWork}>
        <textarea
          value={scopeOfWork}
          onChange={(e) => setScopeOfWork(e.target.value)}
          className={inputClassName}
          rows={2}
        />
      </Field>

      <div className="grid grid-cols-3 gap-4">
        <Field label={t("subcontractForm.originalValueAed")} required error={errors.originalContractValue}>
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
        <Field label={t("subcontractForm.approvedVariationsAed")}>
          <input
            type="number"
            step="0.01"
            value={approvedVariations}
            onChange={(e) => setApprovedVariations(e.target.value)}
            className={inputClassName}
          />
        </Field>
        <Field label={t("subcontractForm.retentionPercent")} required error={errors.retentionPercent}>
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
        <Field label={t("subcontractForm.startDateOptional")}>
          <input type="date" value={startDate} onChange={(e) => setStartDate(e.target.value)} className={inputClassName} />
        </Field>
        <Field label={t("subcontractForm.expectedEndDateOptional")}>
          <input type="date" value={endDate} onChange={(e) => setEndDate(e.target.value)} className={inputClassName} />
        </Field>
      </div>

      <Field label={t("common.notesOptional")}>
        <textarea value={notes} onChange={(e) => setNotes(e.target.value)} className={inputClassName} rows={2} />
      </Field>

      {submitError && <p className="text-xs text-rose-500">{submitError}</p>}

      <div className="flex justify-end gap-2 pt-2">
        <button
          type="button"
          onClick={onDone}
          className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium text-slate-600 hover:bg-slate-50"
        >
          {t("common.cancel")}
        </button>
        <button
          type="submit"
          className="rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
        >
          {isEdit ? t("common.saveChanges") : t("subcontractForm.createButton")}
        </button>
      </div>
    </form>
  );
}
