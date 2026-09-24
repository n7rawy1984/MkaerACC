import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface SupplierPaymentRead {
  id: string; company_id: string; payment_reference: string; payment_date: string; supplier_id: string;
  treasury_account_id: string; total_amount_minor: string; payment_method: Database["public"]["Enums"]["payment_method"];
  external_reference: string | null; notes: string | null; status: "DRAFT" | "POSTED" | "REVERSED";
  posted_journal_entry_id: string | null; reversal_journal_entry_id: string | null;
}
export interface SupplierPaymentAllocationRead { id: string; company_id: string; supplier_payment_id: string; expense_id: string; allocated_amount_minor: string; }
export interface SupplierCreditOutstanding {
  id: string; company_id: string; expense_reference: string; expense_date: string; project_id: string | null;
  supplier_id: string; description: string; gross_amount_minor: string; allocated_amount_minor: string; outstanding_amount_minor: string;
}
export interface SupplierPaymentSnapshot { payments: SupplierPaymentRead[]; allocations: SupplierPaymentAllocationRead[]; outstanding: SupplierCreditOutstanding[]; }

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const exact = (value: unknown) => {
  if (typeof value !== "string" || !/^\d+$/.test(value) || BigInt(value) > 9223372036854775807n) throw new Error("Invalid exact amount");
  return value;
};
const paymentProjection = "id,company_id,payment_reference,payment_date,supplier_id,treasury_account_id,total_amount_minor::text,payment_method,external_reference,notes,status,posted_journal_entry_id,reversal_journal_entry_id";
const allocationProjection = "id,company_id,supplier_payment_id,expense_id,allocated_amount_minor::text";
const expenseProjection = "id,company_id,expense_reference,expense_date,project_id,supplier_id,description,gross_amount_minor::text";

async function allRows<T>(load: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += 500) {
    const { data, error } = await load(from, from + 499);
    if (error || !data) throw new Error("Supplier Payment read unavailable");
    rows.push(...data);
    if (data.length < 500) return rows;
  }
}

export function canReadSupplierPayments(role: string) {
  return role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT" || role === "MANAGEMENT_VIEWER";
}

export async function readSupplierPayments(client: SupabaseClient<Database>, companyId: string): Promise<SupplierPaymentSnapshot> {
  if (!uuid.test(companyId)) throw new Error("Invalid Supplier Payment scope");
  const payments = await allRows<any>((from, to) => client.from("supplier_payments").select(paymentProjection)
    .eq("company_id", companyId).order("payment_date", { ascending: false }).order("id", { ascending: true }).range(from, to));
  const allocations = await allRows<any>((from, to) => client.from("supplier_payment_allocations").select(allocationProjection)
    .eq("company_id", companyId).order("id", { ascending: true }).range(from, to));
  const expenses = await allRows<any>((from, to) => client.from("expenses").select(expenseProjection)
    .eq("company_id", companyId).eq("status", "POSTED").eq("funding_mode", "SUPPLIER_CREDIT")
    .order("expense_date", { ascending: true }).order("id", { ascending: true }).range(from, to));
  if ([...payments, ...allocations, ...expenses].some(row => row.company_id !== companyId)) throw new Error("Invalid Supplier Payment scope");
  const mappedPayments = payments.map(row => {
    if (!uuid.test(row.id) || !uuid.test(row.supplier_id) || !uuid.test(row.treasury_account_id) || !["DRAFT", "POSTED", "REVERSED"].includes(row.status)) throw new Error("Invalid Supplier Payment row");
    return { ...row, total_amount_minor: exact(row.total_amount_minor) } as SupplierPaymentRead;
  });
  const status = new Map(mappedPayments.map(row => [row.id, row.status]));
  const mappedAllocations = allocations.map(row => ({ ...row, allocated_amount_minor: exact(row.allocated_amount_minor) } as SupplierPaymentAllocationRead));
  const activeAllocated = new Map<string, bigint>();
  for (const row of mappedAllocations) if (status.get(row.supplier_payment_id) === "POSTED") activeAllocated.set(row.expense_id, (activeAllocated.get(row.expense_id) ?? 0n) + BigInt(row.allocated_amount_minor));
  const outstanding = expenses.map(row => {
    const gross = exact(row.gross_amount_minor); const allocated = activeAllocated.get(row.id) ?? 0n; const balance = BigInt(gross) - allocated;
    if (balance < 0n || !uuid.test(row.supplier_id)) throw new Error("Invalid Supplier Payment outstanding");
    return { ...row, gross_amount_minor: gross, allocated_amount_minor: allocated.toString(), outstanding_amount_minor: balance.toString() } as SupplierCreditOutstanding;
  }).filter(row => BigInt(row.outstanding_amount_minor) > 0n);
  return { payments: mappedPayments, allocations: mappedAllocations, outstanding };
}

export async function readSupplierPaymentById(client: SupabaseClient<Database>, companyId: string, paymentId: string): Promise<SupplierPaymentRead> {
  if (!uuid.test(companyId) || !uuid.test(paymentId)) throw new Error("Invalid Supplier Payment scope");
  const { data, error } = await client.from("supplier_payments").select(paymentProjection).eq("company_id", companyId).eq("id", paymentId).maybeSingle();
  if (error || !data || data.company_id !== companyId || data.id !== paymentId) throw new Error("Supplier Payment readback unavailable");
  return { ...data, total_amount_minor: exact(data.total_amount_minor) } as SupplierPaymentRead;
}
