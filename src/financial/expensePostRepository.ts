import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface TreasuryExpenseInput {
  date: string; projectId: string | null; categoryId: string; supplierId: string | null;
  treasuryId: string; description: string; netMinor: string;
  vatMode: "ZERO" | "AUTO_5" | "MANUAL"; manualVatMinor: string | null;
  paymentMethod: Database["public"]["Enums"]["payment_method"];
  hasInvoice: boolean; invoiceNumber: string | null; notes: string | null;
}
export interface ExpenseReceipt { expense_id: string; expense_reference: string; journal_entry_id: string; replayed: boolean; }
export const canPostExpense = (role: string) => role === "ACCOUNTING_ADMIN" || role === "ACCOUNTANT";
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const nullableId = (value: string | null) => value === null || (typeof value === "string" && uuid.test(value));
// Currency-unit conversion only. VAT and gross remain exclusively server-calculated.
export function parseAED(value: string): string {
  if (!/^\d+(\.\d{1,2})?$/.test(value.trim())) throw new Error("invalid");
  const [whole, fraction = ""] = value.trim().split(".");
  const minor = BigInt(whole) * 100n + BigInt(fraction.padEnd(2, "0"));
  if (minor < 1n || minor > 9000000000000000n) throw new Error("invalid");
  return minor.toString();
}
export function normalizeExpenseInput(input: TreasuryExpenseInput): TreasuryExpenseInput {
  const money = (s: string) => typeof s === "string" && /^\d+$/.test(s) && BigInt(s) >= 1n && BigInt(s) <= 9000000000000000n;
  if (!input || !/^\d{4}-\d{2}-\d{2}$/.test(input.date) || !Number.isFinite(Date.parse(input.date)) || new Date(input.date).toISOString().slice(0, 10) !== input.date
    || !uuid.test(input.categoryId) || !uuid.test(input.treasuryId) || !nullableId(input.projectId) || !nullableId(input.supplierId)
    || !money(input.netMinor) || !["ZERO", "AUTO_5", "MANUAL"].includes(input.vatMode)
    || (input.vatMode === "MANUAL" ? !money(input.manualVatMinor ?? "") : input.manualVatMinor !== null)
    || !["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"].includes(input.paymentMethod)
    || typeof input.hasInvoice !== "boolean" || typeof input.description !== "string"
    || (input.invoiceNumber !== null && typeof input.invoiceNumber !== "string") || (input.notes !== null && typeof input.notes !== "string")) throw new Error("invalid");
  const description = input.description.trim();
  const invoiceNumber = input.invoiceNumber?.trim() || null;
  const notes = input.notes?.trim() || null;
  if (!description || [...description].length > 1000 || (invoiceNumber && [...invoiceNumber].length > 100) || (notes && [...notes].length > 2000)
    || (input.hasInvoice ? !invoiceNumber : invoiceNumber !== null) || (input.vatMode !== "ZERO" && !input.hasInvoice)) throw new Error("invalid");
  return { date: input.date, projectId: input.projectId, categoryId: input.categoryId, supplierId: input.supplierId,
    treasuryId: input.treasuryId, description, netMinor: BigInt(input.netMinor).toString(), vatMode: input.vatMode,
    manualVatMinor: input.manualVatMinor === null ? null : BigInt(input.manualVatMinor).toString(),
    paymentMethod: input.paymentMethod, hasInvoice: input.hasInvoice, invoiceNumber, notes };
}
export function expensePayload(companyId: string, key: string, raw: TreasuryExpenseInput) {
  if (!uuid.test(companyId) || !uuid.test(key)) throw new Error("invalid");
  const input = normalizeExpenseInput(raw);
  return { target_company_id: companyId, target_expense_date: input.date, target_project_id: input.projectId,
    target_expense_category_id: input.categoryId, target_description: input.description, target_net_amount_minor: input.netMinor,
    target_vat_mode: input.vatMode, target_manual_vat_amount_minor: input.manualVatMinor, target_funding_mode: "TREASURY" as const,
    target_treasury_account_id: input.treasuryId, target_paid_by_party_id: null, target_supplier_id: input.supplierId,
    target_payment_method: input.paymentMethod, target_has_tax_invoice: input.hasInvoice, target_invoice_number: input.invoiceNumber,
    target_notes: input.notes, target_idempotency_key: key };
}
// Generated RPC types model BIGINT as number and omit SQL nullability. Correct only
// this wire contract; PostgREST accepts decimal strings for PostgreSQL BIGINT.
type PostDatabase = Omit<Database, "public"> & { public: Omit<Database["public"], "Functions"> & {
  Functions: Omit<Database["public"]["Functions"], "post_expense"> & {
    post_expense: { Args: ReturnType<typeof expensePayload>; Returns: ExpenseReceipt[] };
  };
} };
export function validReceipt(value: unknown): value is ExpenseReceipt {
  if (!value || typeof value !== "object") return false;
  const r = value as ExpenseReceipt;
  return uuid.test(r.expense_id) && uuid.test(r.journal_entry_id) && typeof r.expense_reference === "string" && !!r.expense_reference && typeof r.replayed === "boolean";
}
export class ExpensePostError extends Error {
  readonly rejected: boolean;
  constructor(rejected: boolean) { super("unresolved"); this.rejected = rejected; }
}
export async function postTreasuryExpense(client: SupabaseClient<Database>, companyId: string, key: string, input: TreasuryExpenseInput): Promise<ExpenseReceipt> {
  const payload = expensePayload(companyId, key, input);
  const { data, error } = await (client as unknown as SupabaseClient<PostDatabase>).rpc("post_expense", payload);
  // Treat every non-confirmation as unresolved. A replay may fail validation after
  // an earlier committed request, so errors never authorize a fresh key automatically.
  if (error) throw new ExpensePostError(["22003", "22023", "23503", "23514", "42501", "23502", "22P02", "22007"].includes(error.code));
  if (!data || data.length !== 1 || !validReceipt(data[0])) throw new ExpensePostError(false);
  return data[0];
}
