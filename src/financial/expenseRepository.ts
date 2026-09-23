import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

type ExpenseRow = Database["public"]["Tables"]["expenses"]["Row"];
export type ExpenseRead = Omit<ExpenseRow, "net_amount_minor" | "vat_amount_minor" | "gross_amount_minor"> & {
  net_amount_minor: string;
  vat_amount_minor: string;
  gross_amount_minor: string;
};
export const EXPENSE_PAGE_SIZE = 50;
const projection = "id,company_id,expense_reference,expense_date,project_id,expense_category_id,supplier_id,description,net_amount_minor::text,vat_mode,vat_amount_minor::text,gross_amount_minor::text,funding_mode,treasury_account_id,paid_by_party_id,payment_method,has_tax_invoice,invoice_number,notes,status,posted_journal_entry_id,reversal_journal_entry_id,created_at,created_by,updated_at,updated_by,posted_at,posted_by,reversed_at,reversed_by";
export function mapExpense(row: ExpenseRead): ExpenseRead {
  for (const value of [row.net_amount_minor, row.vat_amount_minor, row.gross_amount_minor]) {
    if (typeof value !== "string" || !/^\d+$/.test(value) || BigInt(value) > 9223372036854775807n) throw new Error("Invalid exact amount");
  }
  if (!["DRAFT", "POSTED", "REVERSED"].includes(row.status)) throw new Error("Invalid expense status");
  return { ...row };
}
// Presentation only: no VAT calculation, balance calculation or Number money conversion.
export function displayMinor(value: string): string {
  const digits = value.padStart(3, "0");
  return `${digits.slice(0, -2)}.${digits.slice(-2)}`;
}
export async function readExpenses(client: SupabaseClient<Database>, companyId: string, page = 0): Promise<{ rows: ExpenseRead[]; hasNext: boolean }> {
  if (!companyId || !Number.isSafeInteger(page) || page < 0 || !Number.isSafeInteger(page * EXPENSE_PAGE_SIZE + EXPENSE_PAGE_SIZE)) throw new Error("Invalid expense scope");
  const { data, error } = await client.from("expenses").select(projection)
    .eq("company_id", companyId).order("expense_date", { ascending: false }).order("id", { ascending: true })
    .range(page * EXPENSE_PAGE_SIZE, page * EXPENSE_PAGE_SIZE + EXPENSE_PAGE_SIZE);
  if (error || !data) throw new Error("Expense read unavailable");
  if (data.some(row => row.company_id !== companyId)) throw new Error("Invalid expense scope");
  const rows = data.map(mapExpense);
  return { rows: rows.slice(0, EXPENSE_PAGE_SIZE), hasNext: rows.length > EXPENSE_PAGE_SIZE };
}

export async function readExpenseById(client: SupabaseClient<Database>, companyId: string, expenseId: string): Promise<ExpenseRead> {
  const { data, error } = await client.from("expenses").select(projection).eq("company_id", companyId).eq("id", expenseId).maybeSingle();
  if (error || !data || data.company_id !== companyId || data.id !== expenseId) throw new Error("Expense readback unavailable");
  return mapExpense(data);
}
