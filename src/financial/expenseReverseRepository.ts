import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

export interface ExpenseReverseInput { date: string; reason: string; }
export interface ExpenseReverseReceipt {
  expense_id: string;
  expense_reference: string;
  reversal_journal_entry_id: string;
  replayed: boolean;
}

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export const canReverseExpense = (role: string, status: string) => role === "ACCOUNTING_ADMIN" && status === "POSTED";

export function normalizeExpenseReverseInput(input: ExpenseReverseInput): ExpenseReverseInput {
  if (!input || typeof input.reason !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(input.date)
    || !Number.isFinite(Date.parse(input.date)) || new Date(input.date).toISOString().slice(0, 10) !== input.date) throw new Error("invalid");
  const reason = input.reason.trim();
  if (!reason || [...reason].length > 1000) throw new Error("invalid");
  return { date: input.date, reason };
}

export function expenseReversePayload(companyId: string, expenseId: string, key: string, raw: ExpenseReverseInput) {
  if (!uuid.test(companyId) || !uuid.test(expenseId) || !uuid.test(key)) throw new Error("invalid");
  const input = normalizeExpenseReverseInput(raw);
  return { target_company_id: companyId, target_expense_id: expenseId, target_reversal_date: input.date,
    target_reason: input.reason, target_idempotency_key: key };
}

export function validExpenseReverseReceipt(value: unknown): value is ExpenseReverseReceipt {
  if (!value || typeof value !== "object") return false;
  const receipt = value as ExpenseReverseReceipt;
  return uuid.test(receipt.expense_id) && uuid.test(receipt.reversal_journal_entry_id)
    && typeof receipt.expense_reference === "string" && !!receipt.expense_reference
    && typeof receipt.replayed === "boolean";
}

export class ExpenseReverseError extends Error {
  readonly rejected: boolean;
  constructor(rejected: boolean) { super("unresolved"); this.rejected = rejected; }
}

export async function reverseExpense(client: SupabaseClient<Database>, companyId: string, expenseId: string, key: string, input: ExpenseReverseInput): Promise<ExpenseReverseReceipt> {
  const { data, error } = await client.rpc("reverse_expense", expenseReversePayload(companyId, expenseId, key, input));
  // A returned PostgreSQL error rolled the atomic command back. Missing/malformed
  // responses remain uncertain and must retain the same idempotency key.
  if (error) throw new ExpenseReverseError(true);
  if (!data || data.length !== 1 || !validExpenseReverseReceipt(data[0])) throw new ExpenseReverseError(false);
  return data[0];
}
