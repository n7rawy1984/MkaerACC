import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { SupplierPaymentPostError, normalizeSupplierPaymentInput, postSupplierPayment, supplierPaymentPayload, validSupplierPaymentReceipt, type SupplierPaymentInput, type SupplierPaymentReceipt } from "./supplierPaymentPostRepository";
export interface SupplierPaymentAttempt { version: 1; userId: string; companyId: string; key: string; input: SupplierPaymentInput; receipt?: SupplierPaymentReceipt; }
export const supplierPaymentAttemptStorageKey = (userId: string, companyId: string) => `makeracc:supplier-payment-post:${userId}:${companyId}`;
export function loadSupplierPaymentAttempt(storage: Storage, userId: string, companyId: string): SupplierPaymentAttempt | null {
  const text = storage.getItem(supplierPaymentAttemptStorageKey(userId, companyId)); if (!text) return null; const value = JSON.parse(text) as SupplierPaymentAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || (value.receipt !== undefined && !validSupplierPaymentReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeSupplierPaymentInput(value.input); supplierPaymentPayload(companyId, value.key, input);
  return { version: 1, userId, companyId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}
export function saveSupplierPaymentAttempt(storage: Storage, attempt: SupplierPaymentAttempt) { storage.setItem(supplierPaymentAttemptStorageKey(attempt.userId, attempt.companyId), JSON.stringify(attempt)); }
const inFlight = new Map<string, Promise<SupplierPaymentAttempt>>();
export function sendSupplierPaymentAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: SupplierPaymentAttempt, firstSend = false): Promise<SupplierPaymentAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt); const lock = supplierPaymentAttemptStorageKey(attempt.userId, attempt.companyId); const running = inFlight.get(lock); if (running) return running;
  const run = (async () => { saveSupplierPaymentAttempt(storage, attempt); const { data, error } = await client.auth.getSession(); if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: SupplierPaymentReceipt; try { receipt = await postSupplierPayment(client, attempt.companyId, attempt.key, attempt.input); }
    catch (error) { if (firstSend && error instanceof SupplierPaymentPostError && error.rejected) { storage.removeItem(lock); throw new Error("rejected"); } throw error; }
    const completed = { ...attempt, receipt }; try { saveSupplierPaymentAttempt(storage, completed); } catch { /* frozen request remains replayable */ } return completed; })();
  inFlight.set(lock, run); void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {}); return run;
}
