import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readExpenses, type ExpenseRead } from "../financial/expenseRepository";
import { canReadSupplierPayments, readSupplierPayments, type SupplierCreditOutstanding } from "../financial/supplierPaymentRepository";
import { canReadSubcontractorPayments, readSubcontractorPayments, type CertificatePayableOutstanding } from "../financial/subcontractorPaymentRepository";
import { canReadRetentionReleases, readRetentionReleases, type CertificateRetentionAvailable } from "../financial/retentionReleaseRepository";
import { canReadRetentionPayments, readRetentionPayments, type RetentionReleaseOutstanding } from "../financial/retentionPaymentRepository";

export interface DashboardFinancialRead {
  expenses: ExpenseRead[];
  supplierOutstanding: SupplierCreditOutstanding[];
  certificateOutstanding: CertificatePayableOutstanding[];
  releasedRetentionOutstanding: RetentionReleaseOutstanding[];
  retentionHeld: CertificateRetentionAvailable[];
}

export function canReadDashboardFinancials(role: string) {
  return canReadSupplierPayments(role) && canReadSubcontractorPayments(role)
    && canReadRetentionReleases(role) && canReadRetentionPayments(role);
}

export async function readDashboardFinancials(client: SupabaseClient<Database>, userId: string, companyId: string, role: string, current: () => boolean): Promise<DashboardFinancialRead> {
  if (!canReadDashboardFinancials(role)) throw new Error("Dashboard financial read denied");
  const requireSession = async () => {
    const { data, error } = await client.auth.getSession();
    if (!current() || error || data.session?.user.id !== userId) throw new Error("Dashboard session changed");
  };
  await requireSession();
  const allExpenses = async () => {
    const expenses: ExpenseRead[] = [], ids = new Set<string>();
    for (let page = 0; ; page++) {
      if (!current()) throw new Error("Dashboard scope changed");
      const result = await readExpenses(client, companyId, page);
      await requireSession();
      for (const row of result.rows) {
        // A changing offset-paged dataset must not silently double-count a document.
        if (ids.has(row.id)) throw new Error("Expense paging changed; refresh required");
        ids.add(row.id);
        if (row.status === "POSTED") expenses.push(row);
      }
      if (!result.hasNext) return expenses;
    }
  };
  const [expenses, suppliers, subcontractors, retention, released] = await Promise.all([
    allExpenses(), readSupplierPayments(client, companyId), readSubcontractorPayments(client, companyId),
    readRetentionReleases(client, companyId), readRetentionPayments(client, companyId),
  ]);
  await requireSession();
  return { expenses, supplierOutstanding: suppliers.outstanding, certificateOutstanding: subcontractors.outstanding,
    releasedRetentionOutstanding: released.outstanding, retentionHeld: retention.available };
}
