import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { ExpenseReverseError, expenseReversePayload, normalizeExpenseReverseInput, reverseExpense, validExpenseReverseReceipt,
  type ExpenseReverseInput, type ExpenseReverseReceipt } from "./expenseReverseRepository";

export interface ExpenseReverseAttempt {
  version: 1; userId: string; companyId: string; expenseId: string; key: string;
  input: ExpenseReverseInput; receipt?: ExpenseReverseReceipt;
}
export const expenseReverseStorageKey = (userId: string, companyId: string, expenseId: string) => `makeracc:expense-reverse:${userId}:${companyId}:${expenseId}`;

export function loadExpenseReverseAttempt(storage: Storage, userId: string, companyId: string, expenseId: string): ExpenseReverseAttempt | null {
  const text = storage.getItem(expenseReverseStorageKey(userId, companyId, expenseId));
  if (!text) return null;
  const value = JSON.parse(text) as ExpenseReverseAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || value.expenseId !== expenseId
    || (value.receipt !== undefined && !validExpenseReverseReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeExpenseReverseInput(value.input);
  expenseReversePayload(companyId, expenseId, value.key, input);
  return { version: 1, userId, companyId, expenseId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}

export function saveExpenseReverseAttempt(storage: Storage, attempt: ExpenseReverseAttempt) {
  storage.setItem(expenseReverseStorageKey(attempt.userId, attempt.companyId, attempt.expenseId), JSON.stringify(attempt));
}

const inFlight = new Map<string, Promise<ExpenseReverseAttempt>>();
export function sendExpenseReverseAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: ExpenseReverseAttempt, firstSend = false): Promise<ExpenseReverseAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt);
  const lock = expenseReverseStorageKey(attempt.userId, attempt.companyId, attempt.expenseId);
  const running = inFlight.get(lock);
  if (running) return running;
  const run = (async () => {
    saveExpenseReverseAttempt(storage, attempt);
    const { data, error } = await client.auth.getSession();
    if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: ExpenseReverseReceipt;
    try { receipt = await reverseExpense(client, attempt.companyId, attempt.expenseId, attempt.key, attempt.input); }
    catch (error) {
      if (firstSend && error instanceof ExpenseReverseError && error.rejected) {
        storage.removeItem(lock);
        throw new Error("rejected");
      }
      throw error;
    }
    const completed = { ...attempt, receipt };
    try { saveExpenseReverseAttempt(storage, completed); } catch { /* the original frozen request remains safe to replay */ }
    return completed;
  })();
  inFlight.set(lock, run);
  void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {});
  return run;
}
