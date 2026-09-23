import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeSubcontractMetadata, type SubcontractMetadataInput } from "./subcontractMetadataMutations";
import type { ProductionSubcontract } from "./masterTypes";

export function SubcontractMetadataForm({ subcontract, disabled, onSave, onCancel }: {
  subcontract: ProductionSubcontract; disabled: boolean;
  onSave: (input: SubcontractMetadataInput) => Promise<void>; onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<SubcontractMetadataInput>({ scope_of_work: subcontract.scopeOfWork, start_date: subcontract.startDate, expected_end_date: subcontract.expectedEndDate, notes: subcontract.notes });
  const [invalid, setInvalid] = useState(false);
  const form = useRef<HTMLFormElement>(null);
  const alert = useRef<HTMLParagraphElement>(null);
  useLayoutEffect(() => { form.current?.querySelector<HTMLElement>('[name="scope_of_work"]')?.focus({ preventScroll: true }); form.current?.scrollIntoView({ block: "nearest" }); }, []);
  useLayoutEffect(() => { if (invalid) alert.current?.focus(); }, [invalid]);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeSubcontractMetadata(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 min-w-0 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t("subcontractMetadata.edit")}>
    <p className="text-sm text-slate-500">{t("subcontractMetadata.scope")}</p>
    <fieldset disabled={disabled} className="min-w-0 space-y-3">
      <Field label={t("subcontractMetadata.scope_of_work")}><textarea name="scope_of_work" required className={`${inputClassName} min-w-0`} value={input.scope_of_work} onChange={e => setInput({ ...input, scope_of_work: e.target.value })} /></Field>
      <Field label={t("subcontractMetadata.start_date")}><input name="start_date" type="date" className={`${inputClassName} min-w-0`} value={input.start_date ?? ""} onChange={e => setInput({ ...input, start_date: e.target.value || null })} /></Field>
      <Field label={t("subcontractMetadata.expected_end_date")}><input name="expected_end_date" type="date" className={`${inputClassName} min-w-0`} value={input.expected_end_date ?? ""} onChange={e => setInput({ ...input, expected_end_date: e.target.value || null })} /></Field>
      <Field label={t("subcontractMetadata.notes")}><textarea name="notes" className={`${inputClassName} min-w-0`} value={input.notes ?? ""} onChange={e => setInput({ ...input, notes: e.target.value })} /></Field>
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("subcontractMetadata.save")}</button>
    </fieldset>
    {invalid && <p ref={alert} tabIndex={-1} role="alert">{t("subcontractMetadata.invalid")}</p>}
    <button type="button" onClick={onCancel} className="text-sm underline">{t("subcontractMetadata.close")}</button>
  </form>;
}
