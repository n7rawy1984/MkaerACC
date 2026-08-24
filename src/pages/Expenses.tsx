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

const ALL = "ALL";

export function Expenses() {
  const { expenses, projects, categories, parties } = useAppData();
  const [showForm, setShowForm] = useState(false);
  const [search, setSearch] = useState("");
  const [projectFilter, setProjectFilter] = useState(ALL);
  const [categoryFilter, setCategoryFilter] = useState(ALL);
  const [supplierFilter, setSupplierFilter] = useState(ALL);
  const [invoiceFilter, setInvoiceFilter] = useState<"ALL" | "WITH" | "WITHOUT">("ALL");

  const projectsById = useMemo(() => indexById(projects), [projects]);
  const categoriesById = useMemo(() => indexById(categories), [categories]);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);

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
        title="Expenses"
        subtitle={`${filtered.length} of ${expenses.length} transactions · ${formatAED(total)}`}
        action={
          <button
            onClick={() => setShowForm(true)}
            className="flex items-center gap-2 rounded-lg bg-slate-900 px-4 py-2 text-sm font-medium text-white hover:bg-slate-800"
          >
            <Plus size={16} /> New Expense
          </button>
        }
      />

      <div className="mb-4 flex flex-wrap items-center gap-3">
        <div className="relative min-w-[220px] flex-1">
          <Search size={15} className="pointer-events-none absolute left-3 top-1/2 -translate-y-1/2 text-slate-400" />
          <input
            value={search}
            onChange={(e) => setSearch(e.target.value)}
            placeholder="Search description or invoice #"
            className={`${inputClassName} pl-9`}
          />
        </div>
        <select value={projectFilter} onChange={(e) => setProjectFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>All projects</option>
          {projects.map((p) => (
            <option key={p.id} value={p.id}>
              {p.name}
            </option>
          ))}
        </select>
        <select value={categoryFilter} onChange={(e) => setCategoryFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>All categories</option>
          {categories.map((c) => (
            <option key={c.id} value={c.id}>
              {c.name}
            </option>
          ))}
        </select>
        <select value={supplierFilter} onChange={(e) => setSupplierFilter(e.target.value)} className={inputClassName}>
          <option value={ALL}>All suppliers</option>
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
          <option value="ALL">Invoice: all</option>
          <option value="WITH">Has invoice</option>
          <option value="WITHOUT">No invoice</option>
        </select>
      </div>

      <Card>
        <div className="divide-y divide-slate-100">
          {filtered.length === 0 && <p className="px-5 py-8 text-center text-sm text-slate-400">No expenses match these filters.</p>}
          {filtered.map((e) => (
            <div key={e.id} className="flex items-center justify-between px-5 py-3.5">
              <div className="flex-1 min-w-0">
                <div className="flex items-center gap-2">
                  <p className="truncate text-sm font-medium text-slate-800">{e.description}</p>
                  {!e.hasInvoice && <Badge tone="amber">No invoice</Badge>}
                  {e.invoiceNumber && <Badge tone="slate">{e.invoiceNumber}</Badge>}
                </div>
                <p className="mt-0.5 text-xs text-slate-400">
                  {formatDate(e.date)}
                  {e.projectId && ` · ${projectsById[e.projectId]?.name ?? ""}`}
                  {" · "}
                  {categoriesById[e.categoryId]?.name}
                  {e.supplierId && ` · ${partiesById[e.supplierId]?.name ?? ""}`}
                  {" · Paid via "}
                  {e.paidFromType === "CUSTODIAN" || e.paidFromType === "OWNER"
                    ? partiesById[e.paidFromPartyId ?? ""]?.name ?? e.paidFromType
                    : e.paidFromType.replace("_", " ")}
                </p>
              </div>
              <div className="text-right shrink-0 pl-4">
                <p className="text-sm font-semibold text-slate-900">{formatAED(e.totalAmount)}</p>
                {e.vatAmount > 0 && <p className="text-xs text-slate-400">incl. VAT {formatAED(e.vatAmount)}</p>}
              </div>
            </div>
          ))}
        </div>
      </Card>

      {showForm && (
        <Modal title="New Expense" onClose={() => setShowForm(false)}>
          <ExpenseForm onDone={() => setShowForm(false)} />
        </Modal>
      )}
    </div>
  );
}
