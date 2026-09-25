import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface SubcontractorPaymentAllocationInput { certificateId: string; amountMinor: string; }
export interface SubcontractorPaymentInput {
  date: string; subcontractId: string; treasuryId: string; totalMinor: string;
  method: Database["public"]["Enums"]["payment_method"]; externalReference: string | null; notes: string | null;
  allocations: SubcontractorPaymentAllocationInput[];
}
export interface SubcontractorPaymentReceipt { subcontractor_payment_id: string; payment_reference: string; journal_entry_id: string; replayed: boolean; }
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const money = (value: unknown) => typeof value === "string" && /^\d+$/.test(value) && BigInt(value) >= 1n && BigInt(value) <= 9000000000000000n;
export const canPostSubcontractorPayment = (role: string) => role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT";
export function parseSubcontractorPaymentAED(value: string): string {
  if (!/^\d+(\.\d{1,2})?$/.test(value.trim())) throw new Error("invalid");
  const [whole, fraction = ""] = value.trim().split("."); const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"));
  if (minor < 1n || minor > 9000000000000000n) throw new Error("invalid"); return minor.toString();
}
export function normalizeSubcontractorPaymentInput(input: SubcontractorPaymentInput): SubcontractorPaymentInput {
  if (!input || !/^\d{4}-\d{2}-\d{2}$/.test(input.date) || !Number.isFinite(Date.parse(input.date)) || new Date(input.date).toISOString().slice(0, 10) !== input.date
    || !uuid.test(input.subcontractId) || !uuid.test(input.treasuryId) || !money(input.totalMinor)
    || !["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"].includes(input.method) || !Array.isArray(input.allocations) || input.allocations.length < 1 || input.allocations.length > 999) throw new Error("invalid");
  const externalReference = input.externalReference?.trim() || null; const notes = input.notes?.trim() || null;
  if ((externalReference && [...externalReference].length > 200) || (notes && [...notes].length > 2000)) throw new Error("invalid");
  const allocations = input.allocations.map(row => {
    if (!uuid.test(row.certificateId) || !money(row.amountMinor)) throw new Error("invalid");
    return { certificateId: row.certificateId, amountMinor: BigInt(row.amountMinor).toString() };
  }).sort((a, b) => a.certificateId.localeCompare(b.certificateId));
  if (new Set(allocations.map(row => row.certificateId)).size !== allocations.length
    || allocations.reduce((sum, row) => sum + BigInt(row.amountMinor), 0n) !== BigInt(input.totalMinor)) throw new Error("invalid");
  return { date: input.date, subcontractId: input.subcontractId, treasuryId: input.treasuryId, totalMinor: BigInt(input.totalMinor).toString(), method: input.method, externalReference, notes, allocations };
}
export function subcontractorPaymentPayload(companyId: string, key: string, raw: SubcontractorPaymentInput) {
  if (!uuid.test(companyId) || !uuid.test(key)) throw new Error("invalid"); const input = normalizeSubcontractorPaymentInput(raw);
  return { target_company_id: companyId, target_payment_date: input.date, target_subcontract_id: input.subcontractId,
    target_treasury_account_id: input.treasuryId, target_total_amount_minor: input.totalMinor, target_payment_method: input.method,
    target_external_reference: input.externalReference, target_notes: input.notes,
    target_allocations: input.allocations.map(row => ({ certificate_id: row.certificateId, amount_minor: row.amountMinor })), target_idempotency_key: key };
}
type PostDatabase = Omit<Database, "public"> & { public: Omit<Database["public"], "Functions"> & { Functions: Omit<Database["public"]["Functions"], "post_subcontractor_payment"> & { post_subcontractor_payment: { Args: ReturnType<typeof subcontractorPaymentPayload>; Returns: SubcontractorPaymentReceipt[] } } } };
export function validSubcontractorPaymentReceipt(value: unknown): value is SubcontractorPaymentReceipt {
  if (!value || typeof value !== "object") return false; const row = value as SubcontractorPaymentReceipt;
  return uuid.test(row.subcontractor_payment_id) && uuid.test(row.journal_entry_id) && typeof row.payment_reference === "string" && !!row.payment_reference && typeof row.replayed === "boolean";
}
export class SubcontractorPaymentPostError extends Error { readonly rejected: boolean; constructor(rejected: boolean) { super("unresolved"); this.rejected = rejected; } }
export async function postSubcontractorPayment(client: SupabaseClient<Database>, companyId: string, key: string, input: SubcontractorPaymentInput): Promise<SubcontractorPaymentReceipt> {
  const { data, error } = await (client as unknown as SupabaseClient<PostDatabase>).rpc("post_subcontractor_payment", subcontractorPaymentPayload(companyId, key, input));
  if (error) throw new SubcontractorPaymentPostError(true);
  if (!data || data.length !== 1 || !validSubcontractorPaymentReceipt(data[0])) throw new SubcontractorPaymentPostError(false);
  return data[0];
}
