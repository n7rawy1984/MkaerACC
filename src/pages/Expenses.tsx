import { useMemo, useState } from "react";
import { Plus, Search } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { ExpenseForm } from "../components/ExpenseForm";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";

const ALL = "ALL";

const PAID_FROM_KEY: Record<string, TranslationKey> = {
  SUPPLIER_CREDIT: "expenses.paidFrom.SUPPLIER_CREDIT",
  CASH: "expenses.paidFrom.CASH",
  BANK: "expenses.paidFrom.BANK",
};

export function Expenses() {
  const t = useT();
  const { expenses, projects, categories, parties, treasuryAccounts } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [search, setSearch] = useState("");
  const [projectFilter, setProjectFilter] = useState(ALL);
  const [categoryFilter, setCategoryFilter] = useState(ALL);
  const [supplierFilter, setSupplierFilter] = useState(ALL);
  const [invoiceFilter, setInvoiceFilter] = useState<"ALL" | "WITH" | "WITHOUT">("ALL");

  const projectsById = useMemo(() => indexById(projects), [projects]);
  const categoriesById = useMemo(() => indexById(categories), [categories]);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const treasuryById = useMemo(() => indexById(treasuryAccounts), [treasuryAccounts]);
  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);

  function paidFromLabel(e: (typeof expenses)[number]): string {
    if (e.paidFromType === "CUSTODIAN" || e.paidFromType === "OWNER") {
      return partiesById[e.paidFromPartyId ?? ""]?.name ?? e.paidFromType;
    }
    if (e.paidFromType === "TREASURY") {
      return treasuryById[e.treasuryAccountId ?? ""]?.name ?? t("advanceForm.treasuryGroup");
    }
    const key = PAID_FROM_KEY[e.paidFromType];
    return key ? t(key) : e.paidFromType;
  }

  const filtered = useMemo(() => {
    const q = search.trim().toLowerCase();
    return expenses
      .filter((e) => (projectFilter === ALL ? true : e.projectId === projectFilter))
      .filter((e) => (categoryFilter === ALL ? true : e.categoryId === categoryFilter))
      .filter((e) => (supplierFilter === ALL ? true : e.supplierId === supplierFilter))
      .filter((e) => {
        if (invoiceFilter === "WITH") return e.hasInvoice;
        if (invoiceFilter === "WITHOUT") return !e.hasInvoice;
        return true;
      })
      .filter((e) => {
        if (!q) return true;
        return (
          e.description.toLowerCase().includes(q) ||
          e.invoiceNumber?.toLowerCase().includes(q) ||
          (e.projectId && projectsById[e.projectId]?.name.toLowerCase().includes(q))
        );
      })
      .sort((a, b) => (a.date < b.date ? 1 : -1));
  }, [expenses, search, projectFilter, categoryFilter, supplierFilter, invoiceFilter, projectsById]);

  const total = filtered.reduce((sum, e) => sum + e.totalAmount, 0);

  return (
    <div>
      <PageHeader
        title={t("expenses.title")}
        subtitle={t("expenses.subtitle", { shown: filtered.length, total: expenses.length, sum: formatAED(total) })}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> {t("expenses.newExpense")}
          </button>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative min-w-[220px] flex-1">
          <Search size={15} className="pointer-events-none absolute start-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder={t("expenses.searchPlaceholder")}
            className={`${inputClassName} ps-9`}
          />
        </div>
        <select value={projectFilter} onChange={(e) => setProjectFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>{t("expenses.allProjects")}</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        <select value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>{t("expenses.allCategories")}</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select value={supplierFilter} onChange={(e) => setSupplierFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>{t("expenses.allSuppliers")}</option>
          {suppliers.map((s) => (
            <option key={s.id} value={s.id}>
              {s.name}
            </option>
          ))}
        </select>
        <select
          value={invoiceFilter}
          onChange={(e) => setInvoiceFilter(e.target.value as "ALL" | "WITH" | "WITHOUT")}
          className={inputClassName}
        >
          <option value="ALL">{t("expenses.invoiceAll")}</option>
          <option value="WITH">{t("expenses.invoiceWith")}</option>
          <option value="WITHOUT">{t("expenses.invoiceWithout")}</option>
        </select>
      </div>

      <Card>
        <div className="divide-y divide-slate-100">
          {filtered.length === 0 && (
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("expenses.noneMatchFilters")}</p>
          )}
          {filtered.map((e) => (
            <div key={e.id} className="flex items-center justify-between px-5 py-3.5">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <p className="truncate text-sm font-medium text-slate-800">{e.description}</p>
                  {!e.hasInvoice && <Badge tone="amber">{t("badge.noInvoice")}</Badge>}
                  {e.invoiceNumber && <Badge tone="slate">{e.invoiceNumber}</Badge>}
                </div>
                <p className="mt-0.5 text-xs text-slate-400">
                  {formatDate(e.date)}
                  {e.projectId && ` · ${projectsById[e.projectId]?.name ?? ""}`}
                  {" · "}
                  {categoriesById[e.categoryId]?.name}
                  {e.supplierId && ` · ${partiesById[e.supplierId]?.name ?? ""}`}
                  {" · "}
                  {t("expenses.paidVia", { source: paidFromLabel(e) })}
                </p>
              </div>
              <div className="text-right shrink-0 ps-4">
                <p className="text-sm font-semibold text-slate-900">{formatAED(e.totalAmount)}</p>
                {e.vatAmount > 0 && (
                  <p className="text-xs text-slate-400">{t("expenses.inclVat", { amount: formatAED(e.vatAmount) })}</p>
                )}
              </div>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title={t("expenses.newExpense")} onClose={() => setShowForm(false)}>
          <ExpenseForm onDone={() => setShowForm(false)} />
        </Modal>
      )}
    </div>
  );
}
