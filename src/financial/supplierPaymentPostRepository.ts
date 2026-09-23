import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface SupplierPaymentAllocationInput { expenseId: string; amountMinor: string; }
export interface SupplierPaymentInput {
  date: string; supplierId: string; treasuryId: string; totalMinor: string;
  method: Database["public"]["Enums"]["payment_method"]; externalReference: string | null; notes: string | null;
  allocations: SupplierPaymentAllocationInput[];
}
export interface SupplierPaymentReceipt { supplier_payment_id: string; payment_reference: string; journal_entry_id: string; replayed: boolean; }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const money = (value: unknown) => typeof value === "string" && /^\d+$/.test(value) && BigInt(value) >= 1n && BigInt(value) <= 9000000000000000n;
export const canPostSupplierPayment = (role: string) => role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT";
export function parseSupplierPaymentAED(value: string): string {
  if (!/^\d+(\.\d{1,2})?$/.test(value.trim())) throw new Error("invalid");
  const [whole, fraction = ""] = value.trim().split("."); const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"));
  if (minor < 1n || minor > 9000000000000000n) throw new Error("invalid"); return minor.toString();
}
export function normalizeSupplierPaymentInput(input: SupplierPaymentInput): SupplierPaymentInput {
  if (!input || !/^\d{4}-\d{2}-\d{2}$/.test(input.date) || !Number.isFinite(Date.parse(input.date)) || new Date(input.date).toISOString().slice(0, 10) !== input.date
    || !uuid.test(input.supplierId) || !uuid.test(input.treasuryId) || !money(input.totalMinor)
    || !["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"].includes(input.method) || !Array.isArray(input.allocations) || input.allocations.length < 1 || input.allocations.length > 999) throw new Error("invalid");
  const externalReference = input.externalReference?.trim() || null; const notes = input.notes?.trim() || null;
  if ((externalReference && [...externalReference].length > 200) || (notes && [...notes].length > 2000)) throw new Error("invalid");
  const allocations = input.allocations.map(row => {
    if (!uuid.test(row.expenseId) || !money(row.amountMinor)) throw new Error("invalid");
    return { expenseId: row.expenseId, amountMinor: BigInt(row.amountMinor).toString() };
  }).sort((a, b) => a.expenseId.localeCompare(b.expenseId));
  if (new Set(allocations.map(row => row.expenseId)).size !== allocations.length
    || allocations.reduce((sum, row) => sum + BigInt(row.amountMinor), 0n) !== BigInt(input.totalMinor)) throw new Error("invalid");
  return { date: input.date, supplierId: input.supplierId, treasuryId: input.treasuryId, totalMinor: BigInt(input.totalMinor).toString(), method: input.method, externalReference, notes, allocations };
}
export function supplierPaymentPayload(companyId: string, key: string, raw: SupplierPaymentInput) {
  if (!uuid.test(companyId) || !uuid.test(key)) throw new Error("invalid"); const input = normalizeSupplierPaymentInput(raw);
  return { target_company_id: companyId, target_payment_date: input.date, target_supplier_id: input.supplierId,
    target_treasury_account_id: input.treasuryId, target_total_amount_minor: input.totalMinor, target_payment_method: input.method,
    target_external_reference: input.externalReference, target_notes: input.notes,
    target_allocations: input.allocations.map(row => ({ expense_id: row.expenseId, amount_minor: row.amountMinor })), target_idempotency_key: key };
}
type PostDatabase = Omit<Database, "public"> & { public: Omit<Database["public"], "Functions"> & { Functions: Omit<Database["public"]["Functions"], "post_supplier_payment"> & { post_supplier_payment: { Args: ReturnType<typeof supplierPaymentPayload>; Returns: SupplierPaymentReceipt[] } } } };
export function validSupplierPaymentReceipt(value: unknown): value is SupplierPaymentReceipt {
  if (!value || typeof value !== "object") return false; const row = value as SupplierPaymentReceipt;
  return uuid.test(row.supplier_payment_id) && uuid.test(row.journal_entry_id) && typeof row.payment_reference === "string" && !!row.payment_reference && typeof row.replayed === "boolean";
}
export class SupplierPaymentPostError extends Error { readonly rejected: boolean; constructor(rejected: boolean) { super("unresolved"); this.rejected = rejected; } }
export async function postSupplierPayment(client: SupabaseClient<Database>, companyId: string, key: string, input: SupplierPaymentInput): Promise<SupplierPaymentReceipt> {
  const { data, error } = await (client as unknown as SupabaseClient<PostDatabase>).rpc("post_supplier_payment", supplierPaymentPayload(companyId, key, input));
  if (error) throw new SupplierPaymentPostError(true);
  if (!data || data.length !== 1 || !validSupplierPaymentReceipt(data[0])) throw new SupplierPaymentPostError(false);
  return data[0];
}
