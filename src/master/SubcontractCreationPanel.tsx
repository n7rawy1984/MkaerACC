import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import { Field, inputClassName } from "../components/ui/Field";
import { SupplierPartyForm } from "./SupplierPartyForm";
import { useProductionMasterData } from "./productionMasterDataContext";
import { normalizeSupplierParty } from "./supplierPartyMutations";
import { canCreateSubcontractMaster, createSubcontractMaster, subcontractCreationInput } from "./subcontractCreationRepository";

export function SubcontractCreationPanel({ kind }: { kind: "party" | "subcontract" }) {
  const { state } = useAuth(); const master = useProductionMasterData(); const t = useT();
  const [open, setOpen] = useState(false); const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState(""); const lock = useRef(false);
  const origin = useRef<HTMLButtonElement>(null);
  const restoreFocus = useRef(false);
  useLayoutEffect(() => {
    if (!open && !busy && restoreFocus.current && origin.current && !origin.current.disabled) {
      origin.current.focus(); restoreFocus.current = false;
    }
  }, [open, busy, message]);
  if (state.phase !== "TENANT_READY" || master.phase !== "READY" || !canCreateSubcontractMaster(state.activeTenant.role)) return null;
  const companyId = state.activeTenant.companyId, userId = state.profile.userId;
  const close = () => { restoreFocus.current = true; setOpen(false); };
  const refresh = async () => kind === "party" ? master.refreshParties() : master.refreshSubcontracts();
  const recover = async () => {
    if (lock.current) return;
    const committed = message === "refreshError";
    lock.current = true; setBusy(true); close();
    try {
      const ok = await refresh();
      setMessage(ok ? committed ? "saved" : "review" : committed ? "refreshError" : "uncertain");
    } catch { setMessage(committed ? "refreshError" : "uncertain"); }
    finally { lock.current = false; setBusy(false); }
  };
  const save = async (input: Record<string, string | null>) => {
    if (lock.current || message === "uncertain" || message === "refreshError") return;
    lock.current = true; setBusy(true); setMessage("");
    try {
      const client = getSupabaseClient();
      const { data, error } = await client.auth.getSession();
      if (error || data.session?.user.id !== userId) { setMessage("denied"); return; }
      const result = await createSubcontractMaster(client, companyId, kind, input);
      if (!result.ok) { setMessage(result.error); return; }
      if (!await refresh()) { setMessage("refreshError"); return; }
      setMessage("saved"); close();
    } catch { setMessage("uncertain"); }
    finally { lock.current = false; setBusy(false); }
  };
  const submit = (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault(); if (busy) return;
    try {
      const fields = Object.fromEntries(new FormData(event.currentTarget).entries()) as Record<string,string>;
      const input = subcontractCreationInput(fields);
      if (!master.projects.some(p => p.companyId === companyId && p.id === input.project_id && p.status !== "CLOSED")
        || !master.parties.some(p => p.companyId === companyId && p.id === input.subcontractor_id && p.type === "SUBCONTRACTOR" && p.status === "ACTIVE")) throw new Error("invalid");
      void save(input);
    } catch { setMessage("invalid"); }
  };
  const blocked = busy || message === "uncertain" || message === "refreshError";
  const label = t(kind === "party" ? "masterCreation.party" : "masterCreation.subcontract");
  return <section className="mt-4 min-w-0">
    <button ref={origin} type="button" disabled={busy || open || blocked} onClick={() => { setMessage(""); setOpen(true); }} className="rounded-lg border px-3 py-2 text-sm disabled:opacity-50">{label}</button>
    {message && <p className="mt-3 text-sm" role={message === "saved" ? "status" : "alert"}>{t(`masterCreation.${message}` as never)}</p>}
    {busy && <p role="status">{t("supplierMutation.pending")}</p>}
    {(message === "uncertain" || message === "refreshError") && <button type="button" disabled={busy} className="mt-2 underline" onClick={() => { void recover(); }}>{t("supplierMutation.refresh")}</button>}
    {open && kind === "party" && <SupplierPartyForm title={label} supplier={null} disabled={blocked} onCancel={close} onSave={async raw => { const input = normalizeSupplierParty(raw); if (input) await save({ ...input }); else setMessage("invalid"); }} />}
    {open && kind === "subcontract" && <form onSubmit={submit} className="mt-4 min-w-0 space-y-3 rounded-lg border p-4" aria-label={label}>
      <fieldset disabled={blocked} className="space-y-3">
        <Field label={t("subcontractForm.project")} required><select autoFocus required name="project_id" className={inputClassName}><option value="">{t("common.selectEllipsis")}</option>{master.projects.filter(p => p.companyId === companyId && p.status !== "CLOSED").map(p => <option key={p.id} value={p.id}>{p.code} · {p.name}</option>)}</select></Field>
        <Field label={t("subcontractForm.subcontractor")} required><select required name="subcontractor_id" className={inputClassName}><option value="">{t("common.selectEllipsis")}</option>{master.parties.filter(p => p.companyId === companyId && p.type === "SUBCONTRACTOR" && p.status === "ACTIVE").map(p => <option key={p.id} value={p.id}>{p.name}</option>)}</select></Field>
        {([ ["contract_number","subcontractForm.contractNumber"], ["scope_of_work","subcontractForm.scopeOfWork"], ["original_contract_value_minor","subcontractForm.originalValueAed"], ["approved_variations_minor","subcontractForm.approvedVariationsAed"], ["retention_bps","subcontractForm.retentionPercent"], ["start_date","subcontractForm.startDateOptional"], ["expected_end_date","subcontractForm.expectedEndDateOptional"], ["notes","common.notesOptional"] ] as const).map(([name,key]) => <Field key={name} label={t(key)} required={["contract_number","scope_of_work","original_contract_value_minor","retention_bps"].includes(name)}><input name={name} type={name.endsWith("date") ? "date" : "text"} dir={name.includes("minor") || name === "retention_bps" || name.endsWith("date") ? "ltr" : undefined} inputMode={name.includes("minor") || name === "retention_bps" ? "decimal" : undefined} defaultValue={name === "approved_variations_minor" ? "0" : undefined} required={["contract_number","scope_of_work","original_contract_value_minor","retention_bps"].includes(name)} className={inputClassName} /></Field>)}
        <Field label={t("common.status")}><select name="status" className={inputClassName}>{(["ACTIVE","COMPLETED","CLOSED"] as const).map(status => <option key={status} value={status}>{t(`subcontractStatus.${status}`)}</option>)}</select></Field>
        <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-white">{t("supplierMutation.save")}</button>
      </fieldset>
      <button type="button" disabled={busy} onClick={close} className="underline">{t("supplierMutation.close")}</button>
    </form>}
  </section>;
}
