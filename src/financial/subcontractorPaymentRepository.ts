import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface SubcontractorPaymentRead {
  id: string; company_id: string; payment_reference: string; payment_date: string; project_id: string; subcontractor_id: string; subcontract_id: string;
  treasury_account_id: string; total_amount_minor: string; payment_method: Database["public"]["Enums"]["payment_method"];
  external_reference: string | null; notes: string | null; status: "DRAFT" | "POSTED" | "REVERSED";
  posted_journal_entry_id: string | null; reversal_journal_entry_id: string | null; created_at: string; created_by: string | null; posted_at: string | null; posted_by: string | null; reversed_at: string | null; reversed_by: string | null; reversal_reason: string | null;
}
export interface SubcontractorPaymentAllocationRead { id: string; company_id: string; subcontractor_payment_id: string; subcontractor_certificate_id: string; allocated_amount_minor: string; }
export interface CertificatePayableOutstanding {
  id: string; company_id: string; certificate_reference: string; certificate_date: string; project_id: string;
  subcontractor_id: string; subcontract_id: string; payable_amount_minor: string; allocated_amount_minor: string; outstanding_amount_minor: string;
}
export interface SubcontractorPaymentSnapshot { payments: SubcontractorPaymentRead[]; allocations: SubcontractorPaymentAllocationRead[]; outstanding: CertificatePayableOutstanding[]; }

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const exact = (value: unknown) => {
  if (typeof value !== "string" || !/^\d+$/.test(value) || BigInt(value) > 9223372036854775807n) throw new Error("Invalid exact amount");
  return value;
};
const paymentProjection = "id,company_id,payment_reference,payment_date,project_id,subcontractor_id,subcontract_id,treasury_account_id,total_amount_minor::text,payment_method,external_reference,notes,status,posted_journal_entry_id,reversal_journal_entry_id,created_at,created_by,posted_at,posted_by,reversed_at,reversed_by,reversal_reason";
const allocationProjection = "id,company_id,subcontractor_payment_id,subcontractor_certificate_id,allocated_amount_minor::text";
const expenseProjection = "id,company_id,certificate_reference,certificate_date,project_id,subcontractor_id,subcontract_id,payable_amount_minor::text";

async function allRows<T>(load: (from: number, to: number) => PromiseLike<{ data: T[] | null; error: unknown }>): Promise<T[]> {
  const rows: T[] = [];
  for (let from = 0; ; from += 500) {
    const { data, error } = await load(from, from + 499);
    if (error || !data) throw new Error("Subcontractor Payment read unavailable");
    rows.push(...data);
    if (data.length < 500) return rows;
  }
}

export function canReadSubcontractorPayments(role: string) {
  return role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT" || role === "MANAGEMENT_VIEWER";
}

export async function readSubcontractorPayments(client: SupabaseClient<Database>, companyId: string): Promise<SubcontractorPaymentSnapshot> {
  if (!uuid.test(companyId)) throw new Error("Invalid Subcontractor Payment scope");
  const payments = await allRows<any>((from, to) => client.from("subcontractor_payments").select(paymentProjection)
    .eq("company_id", companyId).order("payment_date", { ascending: false }).order("id", { ascending: true }).range(from, to));
  const allocations = await allRows<any>((from, to) => client.from("subcontractor_payment_allocations").select(allocationProjection)
    .eq("company_id", companyId).order("id", { ascending: true }).range(from, to));
  const subcontractor_certificates = await allRows<any>((from, to) => client.from("subcontractor_certificates").select(expenseProjection)
    .eq("company_id", companyId).eq("status", "POSTED")
    .order("certificate_date", { ascending: true }).order("id", { ascending: true }).range(from, to));
  if ([...payments, ...allocations, ...subcontractor_certificates].some(row => row.company_id !== companyId)) throw new Error("Invalid Subcontractor Payment scope");
  const mappedPayments = payments.map(row => {
    if (!uuid.test(row.id) || !uuid.test(row.project_id) || !uuid.test(row.subcontractor_id) || !uuid.test(row.subcontract_id) || !uuid.test(row.treasury_account_id) || !["DRAFT", "POSTED", "REVERSED"].includes(row.status)) throw new Error("Invalid Subcontractor Payment row");
    return { ...row, total_amount_minor: exact(row.total_amount_minor) } as SubcontractorPaymentRead;
  });
  const status = new Map(mappedPayments.map(row => [row.id, row.status]));
  const mappedAllocations = allocations.map(row => ({ ...row, allocated_amount_minor: exact(row.allocated_amount_minor) } as SubcontractorPaymentAllocationRead));
  const activeAllocated = new Map<string, bigint>();
  for (const row of mappedAllocations) if (status.get(row.subcontractor_payment_id) === "POSTED") activeAllocated.set(row.subcontractor_certificate_id, (activeAllocated.get(row.subcontractor_certificate_id) ?? 0n) + BigInt(row.allocated_amount_minor));
  const outstanding = subcontractor_certificates.map(row => {
    const gross = exact(row.payable_amount_minor); const allocated = activeAllocated.get(row.id) ?? 0n; const balance = BigInt(gross) - allocated;
    if (balance < 0n || !uuid.test(row.project_id) || !uuid.test(row.subcontractor_id) || !uuid.test(row.subcontract_id)) throw new Error("Invalid Subcontractor Payment outstanding");
    return { ...row, payable_amount_minor: gross, allocated_amount_minor: allocated.toString(), outstanding_amount_minor: balance.toString() } as CertificatePayableOutstanding;
  }).filter(row => BigInt(row.outstanding_amount_minor) > 0n);
  return { payments: mappedPayments, allocations: mappedAllocations, outstanding };
}

export async function readSubcontractorPaymentById(client: SupabaseClient<Database>, companyId: string, paymentId: string): Promise<SubcontractorPaymentRead> {
  if (!uuid.test(companyId) || !uuid.test(paymentId)) throw new Error("Invalid Subcontractor Payment scope");
  const { data, error } = await client.from("subcontractor_payments").select(paymentProjection).eq("company_id", companyId).eq("id", paymentId).maybeSingle();
  if (error || !data || data.company_id !== companyId || data.id !== paymentId) throw new Error("Subcontractor Payment readback unavailable");
  return { ...data, total_amount_minor: exact(data.total_amount_minor) } as SubcontractorPaymentRead;
}
