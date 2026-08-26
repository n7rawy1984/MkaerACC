import { useMemo, useState } from "react";
import { ChevronDown, ChevronUp, Truck } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { Modal } from "../components/ui/Modal";
import { SupplierPaymentForm } from "../components/SupplierPaymentForm";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { supplierPayableBalance } from "../accounting/ledger";
import { useT } from "../i18n/I18nContext";
import type { Party } from "../domain/types";

function SupplierRow({
  supplier,
  balance,
  onPay,
}: {
  supplier: Party;
  balance: number;
  onPay: () => void;
}) {
  const t = useT();
  const { expenses, supplierPayments } = useAppData();
  const [open, setOpen] = useState(false);

  const purchases = useMemo(
    () =>
      expenses
        .filter((e) => e.supplierId === supplier.id)
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    [expenses, supplier.id],
  );
  const payments = useMemo(
    () =>
      supplierPayments
        .filter((p) => p.supplierId === supplier.id)
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    [supplierPayments, supplier.id],
  );

  return (
    <div>
      <div
        role="button"
        tabIndex={0}
        onClick={() => setOpen((v) => !v)}
        onKeyDown={(e) => {
          if (e.key === "Enter" || e.key === " ") setOpen((v) => !v);
        }}
        className="flex w-full cursor-pointer items-center justify-between px-5 py-4 text-left hover:bg-slate-50"
      >
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
            <Truck size={18} />
          </div>
          <div>
            <p className="text-sm font-semibold text-slate-900">{supplier.name}</p>
            <p className="text-xs text-slate-400">
              {t(purchases.length === 1 ? "suppliers.purchaseCount" : "suppliers.purchaseCountPlural", {
                count: purchases.length,
              })}
              {payments.length > 0 &&
                ` · ${t(payments.length === 1 ? "suppliers.paymentCount" : "suppliers.paymentCountPlural", {
                  count: payments.length,
                })}`}
            </p>
          </div>
        </div>
        <div className="flex items-center gap-4">
          <div className="text-right">
            <p className="text-xs text-slate-400">{t("suppliers.outstandingBalance")}</p>
            <p className="text-sm font-semibold text-slate-900">{formatAED(balance)}</p>
          </div>
          {balance > 0 ? (
            <button
              type="button"
              onClick={(e) => {
                e.stopPropagation();
                onPay();
              }}
              className="rounded-lg border border-slate-300 px-3 py-1.5 text-xs font-medium text-slate-600 hover:bg-white"
            >
              {t("suppliers.recordPayment")}
            </button>
          ) : (
            <Badge tone="green">{t("suppliers.settled")}</Badge>
          )}
          {open ? <ChevronUp size={16} className="text-slate-400" /> : <ChevronDown size={16} className="text-slate-400" />}
        </div>
      </div>

      {open && (
        <div className="border-t border-slate-100 bg-slate-50/50 px-5 py-3">
          {purchases.length === 0 && payments.length === 0 && (
            <p className="py-2 text-sm text-slate-400">{t("suppliers.noTransactionsYet")}</p>
          )}
          {purchases.length > 0 && (
            <div className="mb-3">
              <p className="mb-1.5 text-xs font-medium uppercase tracking-wide text-slate-400">
                {t("suppliers.purchasesHeader")}
              </p>
              <div className="space-y-1.5">
                {purchases.map((p) => (
                  <div key={p.id} className="flex items-center justify-between text-sm">
                    <span className="text-slate-600">
                      {formatDate(p.date)} · {p.description}
                      {!p.hasInvoice && (
                        <span className="ms-2">
                          <Badge tone="amber">{t("badge.noInvoice")}</Badge>
                        </span>
                      )}
                    </span>
                    <span className="font-medium text-slate-800">{formatAED(p.totalAmount)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
          {payments.length > 0 && (
            <div>
              <p className="mb-1.5 text-xs font-medium uppercase tracking-wide text-slate-400">
                {t("suppliers.paymentsMadeHeader")}
              </p>
              <div className="space-y-1.5">
                {payments.map((p) => (
                  <div key={p.id} className="flex items-center justify-between text-sm">
                    <span className="text-slate-600">
                      {formatDate(p.date)} · {p.reference || t("common.payment")}
                    </span>
                    <span className="font-medium text-emerald-700">− {formatAED(p.amount)}</span>
                  </div>
                ))}
              </div>
            </div>
          )}
        </div>
      )}
    </div>
  );
}

export function Suppliers() {
  const t = useT();
  const { parties, journalEntries } = useAppData();
  const [payingSupplierId, setPayingSupplierId] = useState<string | null>(null);

  const suppliers = useMemo(() => parties.filter((p) => p.type === "SUPPLIER"), [parties]);

  const rows = useMemo(
    () =>
      suppliers.map((s) => ({
        supplier: s,
        balance: supplierPayableBalance(journalEntries, s.id),
      })),
    [suppliers, journalEntries],
  );

  const payingSupplier = suppliers.find((s) => s.id === payingSupplierId);

  return (
    <div>
      <PageHeader title={t("suppliers.title")} subtitle={t("suppliers.subtitle")} />

      <Card>
        <div className="divide-y divide-slate-100">
          {rows.map(({ supplier, balance }) => (
            <SupplierRow
              key={supplier.id}
              supplier={supplier}
              balance={balance}
              onPay={() => setPayingSupplierId(supplier.id)}
            />
          ))}
        </div>
      </Card>

      {payingSupplier && (
        <Modal
          title={t("suppliers.paymentModalTitle", { name: payingSupplier.name })}
          onClose={() => setPayingSupplierId(null)}
        >
          <SupplierPaymentForm supplierId={payingSupplier.id} onDone={() => setPayingSupplierId(null)} />
        </Modal>
      )}
    </div>
  );
}
