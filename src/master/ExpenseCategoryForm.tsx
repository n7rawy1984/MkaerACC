import { useState, type FormEvent } from "react";
import { Field, inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import { normalizeExpenseCategory, type ExpenseCategoryInput } from "./expenseCategoryMutations";
import type { ProductionExpenseCategory } from "./masterTypes";

export function ExpenseCategoryForm({ category, disabled, onSave, onCancel }: {
  category: ProductionExpenseCategory | null;
  disabled: boolean;
  onSave: (input: ExpenseCategoryInput) => Promise<void>;
  onCancel: () => void;
}) {
  const t = useT();
  const [code, setCode] = useState(category?.code ?? "");
  const [name, setName] = useState(category?.name ?? "");
  const [description, setDescription] = useState(category?.description ?? "");
  const [invalid, setInvalid] = useState(false);
  const submit = (event: FormEvent) => {
    event.preventDefault();
    if (disabled) return;
    const input = normalizeExpenseCategory({ code, name, description });
    setInvalid(!input);
    if (input) void onSave(input);
  };
  return <form onSubmit={submit} className="mt-4 space-y-3 rounded-lg border border-slate-200 p-4" aria-label={t(category ? "categoryMutation.edit" : "categoryMutation.create")}>
    <h3 className="font-semibold">{t(category ? "categoryMutation.edit" : "categoryMutation.create")}</h3>
    {!category && <p className="text-sm text-slate-500">{t("categoryMutation.activeOnCreate")}</p>}
    <fieldset disabled={disabled} className="space-y-3">
      <Field label={t("categoryMutation.code")} required><input className={inputClassName} value={code} onChange={(e) => setCode(e.target.value)} required /></Field>
      <Field label={t("categoryMutation.name")} required><input className={inputClassName} value={name} onChange={(e) => setName(e.target.value)} required /></Field>
      <Field label={t("categoryMutation.description")}><textarea className={inputClassName} value={description} onChange={(e) => setDescription(e.target.value)} /></Field>
      {invalid && <p role="alert" className="text-sm text-red-700">{t("categoryMutation.invalid")}</p>}
      <button type="submit" className="rounded-lg bg-[var(--tenant-primary)] px-4 py-2 text-sm text-white disabled:opacity-50">{t("categoryMutation.save")}</button>
    </fieldset>
    <button type="button" onClick={onCancel} className="text-sm underline">{t("categoryMutation.close")}</button>
  </form>;
}
