import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { ExpensePostError, validReceipt, type ExpenseReceipt } from "./expensePostRepository";
import { normalizeSupplierCreditExpenseInput, postSupplierCreditExpense, supplierCreditExpensePayload, type SupplierCreditExpenseInput } from "./supplierCreditExpensePostRepository";
export interface SupplierCreditExpenseAttempt { version: 1; userId: string; companyId: string; key: string; input: SupplierCreditExpenseInput; receipt?: ExpenseReceipt; }
export const supplierCreditExpenseAttemptStorageKey = (userId: string, companyId: string) => `makeracc:supplier-credit-expense-post:${userId}:${companyId}`;
export function loadSupplierCreditExpenseAttempt(storage: Storage, userId: string, companyId: string): SupplierCreditExpenseAttempt | null {
  const text = storage.getItem(supplierCreditExpenseAttemptStorageKey(userId, companyId)); if (!text) return null; const value = JSON.parse(text) as SupplierCreditExpenseAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || (value.receipt !== undefined && !validReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeSupplierCreditExpenseInput(value.input); supplierCreditExpensePayload(companyId, value.key, input);
  return { version: 1, userId, companyId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}
export function saveSupplierCreditExpenseAttempt(storage: Storage, attempt: SupplierCreditExpenseAttempt) { storage.setItem(supplierCreditExpenseAttemptStorageKey(attempt.userId, attempt.companyId), JSON.stringify(attempt)); }
const inFlight = new Map<string, Promise<SupplierCreditExpenseAttempt>>();
export function sendSupplierCreditExpenseAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: SupplierCreditExpenseAttempt, firstSend = false): Promise<SupplierCreditExpenseAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt); const lock = supplierCreditExpenseAttemptStorageKey(attempt.userId, attempt.companyId); const running = inFlight.get(lock); if (running) return running;
  const run = (async () => { saveSupplierCreditExpenseAttempt(storage, attempt); const { data, error } = await client.auth.getSession(); if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: ExpenseReceipt; try { receipt = await postSupplierCreditExpense(client, attempt.companyId, attempt.key, attempt.input); }
    catch (error) { if (firstSend && error instanceof ExpensePostError && error.rejected) { storage.removeItem(lock); throw new Error("rejected"); } throw error; }
    const completed = { ...attempt, receipt }; try { saveSupplierCreditExpenseAttempt(storage, completed); } catch { /* frozen original remains replayable */ } return completed; })();
  inFlight.set(lock, run); void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {}); return run;
}
