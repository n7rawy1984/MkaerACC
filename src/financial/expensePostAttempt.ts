import { ExpensePostError, expensePayload, normalizeExpenseInput, postTreasuryExpense, validReceipt, type ExpenseReceipt, type TreasuryExpenseInput } from "./expensePostRepository";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
export interface ExpenseAttempt { version: 1; userId: string; companyId: string; key: string; input: TreasuryExpenseInput; receipt?: ExpenseReceipt; }
export const attemptStorageKey = (userId: string, companyId: string) => `makeracc:expense-post:${userId}:${companyId}`;
export function loadAttempt(storage: Storage, userId: string, companyId: string): ExpenseAttempt | null {
  const text = storage.getItem(attemptStorageKey(userId, companyId));
  if (!text) return null;
  const value = JSON.parse(text) as ExpenseAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || (value.receipt !== undefined && !validReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeExpenseInput(value.input);
  expensePayload(companyId, value.key, input);
  return { version: 1, userId, companyId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}
export function saveAttempt(storage: Storage, attempt: ExpenseAttempt) {
  storage.setItem(attemptStorageKey(attempt.userId, attempt.companyId), JSON.stringify(attempt));
}
// Serialize duplicate clicks across remounts in this tab. Only a frozen attempt
// can be retried; a successful response is persisted even if its view unmounted.
const inFlight = new Map<string, Promise<ExpenseAttempt>>();
export function sendAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: ExpenseAttempt, firstSend = false): Promise<ExpenseAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt);
  const lock = attemptStorageKey(attempt.userId, attempt.companyId);
  const running = inFlight.get(lock);
  if (running) return running;
  const run = (async () => {
    saveAttempt(storage, attempt); // Storage failure must prevent the first send.
    const { data, error } = await client.auth.getSession();
    if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: ExpenseReceipt;
    try { receipt = await postTreasuryExpense(client, attempt.companyId, attempt.key, attempt.input); }
    catch (error) {
      // Only a known rollback on the first transmission permits editing anew.
      // Restored/retried attempts may already have committed and remain locked.
      if (firstSend && error instanceof ExpensePostError && error.rejected) {
        storage.removeItem(lock);
        throw new Error("rejected");
      }
      throw error;
    }
    const completed = { ...attempt, receipt };
    // If persistence fails, keep the frozen original request; replay is safe.
    try { saveAttempt(storage, completed); } catch { /* caller still knows the commit */ }
    return completed;
  })();
  inFlight.set(lock, run);
  void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {});
  return run;
}
