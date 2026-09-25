import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { SubcontractorPaymentPostError, normalizeSubcontractorPaymentInput, postSubcontractorPayment, subcontractorPaymentPayload, validSubcontractorPaymentReceipt, type SubcontractorPaymentInput, type SubcontractorPaymentReceipt } from "./subcontractorPaymentPostRepository";
export interface SubcontractorPaymentAttempt { version: 1; userId: string; companyId: string; key: string; input: SubcontractorPaymentInput; receipt?: SubcontractorPaymentReceipt; }
export const subcontractorPaymentAttemptStorageKey = (userId: string, companyId: string) => `makeracc:subcontractor-payment-post:${userId}:${companyId}`;
export function loadSubcontractorPaymentAttempt(storage: Storage, userId: string, companyId: string): SubcontractorPaymentAttempt | null {
  const text = storage.getItem(subcontractorPaymentAttemptStorageKey(userId, companyId)); if (!text) return null; const value = JSON.parse(text) as SubcontractorPaymentAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || (value.receipt !== undefined && !validSubcontractorPaymentReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeSubcontractorPaymentInput(value.input); subcontractorPaymentPayload(companyId, value.key, input);
  return { version: 1, userId, companyId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}
export function saveSubcontractorPaymentAttempt(storage: Storage, attempt: SubcontractorPaymentAttempt) { storage.setItem(subcontractorPaymentAttemptStorageKey(attempt.userId, attempt.companyId), JSON.stringify(attempt)); }
const inFlight = new Map<string, Promise<SubcontractorPaymentAttempt>>();
export function sendSubcontractorPaymentAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: SubcontractorPaymentAttempt, firstSend = false): Promise<SubcontractorPaymentAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt); const lock = subcontractorPaymentAttemptStorageKey(attempt.userId, attempt.companyId); const running = inFlight.get(lock); if (running) return running;
  const run = (async () => { saveSubcontractorPaymentAttempt(storage, attempt); const { data, error } = await client.auth.getSession(); if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: SubcontractorPaymentReceipt; try { receipt = await postSubcontractorPayment(client, attempt.companyId, attempt.key, attempt.input); }
    catch (error) { if (firstSend && error instanceof SubcontractorPaymentPostError && error.rejected) { storage.removeItem(lock); throw new Error("rejected"); } throw error; }
    const completed = { ...attempt, receipt }; try { saveSubcontractorPaymentAttempt(storage, completed); } catch { /* frozen request remains replayable */ } return completed; })();
  inFlight.set(lock, run); void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {}); return run;
}
