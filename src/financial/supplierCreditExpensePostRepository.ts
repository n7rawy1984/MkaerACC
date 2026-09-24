import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { ExpensePostError, type ExpenseReceipt, validReceipt } from "./expensePostRepository";

export interface SupplierCreditExpenseInput {
  date: string; projectId: string | null; categoryId: string; supplierId: string;
  description: string; netMinor: string; vatMode: "ZERO" | "AUTO_5" | "MANUAL";
  manualVatMinor: string | null; paymentMethod: Database["public"]["Enums"]["payment_method"];
  hasInvoice: boolean; invoiceNumber: string | null; notes: string | null;
}
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const nullableId = (value: string | null) => value === null || uuid.test(value);
const money = (value: unknown) => typeof value === "string" && /^\d+$/.test(value) && BigInt(value) >= 1n && BigInt(value) <= 9000000000000000n;

export function normalizeSupplierCreditExpenseInput(input: SupplierCreditExpenseInput): SupplierCreditExpenseInput {
  if (!input || !/^\d{4}-\d{2}-\d{2}$/.test(input.date) || !Number.isFinite(Date.parse(input.date)) || new Date(input.date).toISOString().slice(0, 10) !== input.date
    || !nullableId(input.projectId) || !uuid.test(input.categoryId) || !uuid.test(input.supplierId) || !money(input.netMinor)
    || !["ZERO", "AUTO_5", "MANUAL"].includes(input.vatMode)
    || (input.vatMode === "MANUAL" ? !money(input.manualVatMinor) : input.manualVatMinor !== null)
    || !["CASH", "BANK", "TRANSFER", "CHEQUE", "OTHER"].includes(input.paymentMethod)
    || typeof input.hasInvoice !== "boolean" || typeof input.description !== "string"
    || (input.invoiceNumber !== null && typeof input.invoiceNumber !== "string") || (input.notes !== null && typeof input.notes !== "string")) throw new Error("invalid");
  const description = input.description.trim(); const invoiceNumber = input.invoiceNumber?.trim() || null; const notes = input.notes?.trim() || null;
  if (!description || [...description].length > 1000 || (invoiceNumber && [...invoiceNumber].length > 100) || (notes && [...notes].length > 2000)
    || (input.hasInvoice ? !invoiceNumber : invoiceNumber !== null) || (input.vatMode !== "ZERO" && !input.hasInvoice)) throw new Error("invalid");
  return { date: input.date, projectId: input.projectId, categoryId: input.categoryId, supplierId: input.supplierId,
    description, netMinor: BigInt(input.netMinor).toString(), vatMode: input.vatMode,
    manualVatMinor: input.manualVatMinor === null ? null : BigInt(input.manualVatMinor).toString(),
    paymentMethod: input.paymentMethod, hasInvoice: input.hasInvoice, invoiceNumber, notes };
}

export function supplierCreditExpensePayload(companyId: string, key: string, raw: SupplierCreditExpenseInput) {
  if (!uuid.test(companyId) || !uuid.test(key)) throw new Error("invalid"); const input = normalizeSupplierCreditExpenseInput(raw);
  return { target_company_id: companyId, target_expense_date: input.date, target_project_id: input.projectId,
    target_expense_category_id: input.categoryId, target_description: input.description, target_net_amount_minor: input.netMinor,
    target_vat_mode: input.vatMode, target_manual_vat_amount_minor: input.manualVatMinor, target_funding_mode: "SUPPLIER_CREDIT" as const,
    target_treasury_account_id: null, target_paid_by_party_id: null, target_supplier_id: input.supplierId,
    target_payment_method: input.paymentMethod, target_has_tax_invoice: input.hasInvoice, target_invoice_number: input.invoiceNumber,
    target_notes: input.notes, target_idempotency_key: key };
}
type PostDatabase = Omit<Database, "public"> & { public: Omit<Database["public"], "Functions"> & {
  Functions: Omit<Database["public"]["Functions"], "post_expense"> & { post_expense: { Args: ReturnType<typeof supplierCreditExpensePayload>; Returns: ExpenseReceipt[] } };
} };
export async function postSupplierCreditExpense(client: SupabaseClient<Database>, companyId: string, key: string, input: SupplierCreditExpenseInput): Promise<ExpenseReceipt> {
  const { data, error } = await (client as unknown as SupabaseClient<PostDatabase>).rpc("post_expense", supplierCreditExpensePayload(companyId, key, input));
  if (error) throw new ExpensePostError(["22003", "22023", "23503", "23514", "42501", "23502", "22P02", "22007"].includes(error.code));
  if (!data || data.length !== 1 || !validReceipt(data[0])) throw new ExpensePostError(false); return data[0];
}
