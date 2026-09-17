import { useLayoutEffect, useRef, useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeProjectMetadata, type ProjectMetadataInput } from "./projectMetadataMutations";
import type { ProductionProjectSummary } from "./masterTypes";

export function ProjectMetadataForm({ project, disabled, onSave, onCancel }: {
  project: ProductionProjectSummary; disabled: boolean;
  onSave: (input: ProjectMetadataInput) => Promise<void>; onCancel: () => void;
}) {
  const t = useT();
  const [input, setInput] = useState<ProjectMetadataInput>({ name: project.name, client_name: project.clientName, location: project.location, contract_number: project.contractNumber, notes: project.notes });
  const [invalid, setInvalid] = useState(false);
  const form = useRef<HTMLFormElement>(null);
  useLayoutEffect(() => {
    form.current?.querySelector<HTMLInputElement>('input[name="name"]')?.focus({ preventScroll: true });
    form.current?.scrollIntoView({ block: "nearest" });
  }, []);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const normalized = normalizeProjectMetadata(input);
    setInvalid(!normalized);
    if (normalized) void onSave(normalized);
  };
  return <form ref={form} onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t("projectMetadata.edit")}>
    <p className="text-sm text-slate-500">{t("projectMetadata.scope")}</p>
    <fieldset disabled={disabled} className="min-w-0 space-y-3">
      {(["name", "client_name", "location", "contract_number", "notes"] as const).map((field) => <Field key={field} label={t(`projectMetadata.${field}`)}>
        {field === "notes" ? <textarea name={field} className={inputClassName} value={input[field] ?? ""} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />
          : <input name={field} type="text" required={field === "name"} className={inputClassName} value={input[field] ?? ""} onChange={(e) => setInput({ ...input, [field]: e.target.value })} />}
      </Field>)}
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("projectMetadata.save")}</button>
    </fieldset>
    {invalid && <p role="alert">{t("projectMetadata.invalid")}</p>}
    <button type="button" onClick={onCancel} className="text-sm underline">{t("projectMetadata.close")}</button>
  </form>;
}
