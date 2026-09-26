import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { RetentionReleasePostError, normalizeRetentionReleaseInput, postRetentionRelease, retentionReleasePayload, validRetentionReleaseReceipt, type RetentionReleaseInput, type RetentionReleaseReceipt } from "./retentionReleasePostRepository";
export interface RetentionReleaseAttempt { version: 1; userId: string; companyId: string; key: string; input: RetentionReleaseInput; receipt?: RetentionReleaseReceipt; }
export const retentionReleaseAttemptStorageKey = (userId: string, companyId: string) => `makeracc:retention-release-post:${userId}:${companyId}`;
export function loadRetentionReleaseAttempt(storage: Storage, userId: string, companyId: string): RetentionReleaseAttempt | null {
  const text = storage.getItem(retentionReleaseAttemptStorageKey(userId, companyId)); if (!text) return null; const value = JSON.parse(text) as RetentionReleaseAttempt;
  if (value.version !== 1 || value.userId !== userId || value.companyId !== companyId || (value.receipt !== undefined && !validRetentionReleaseReceipt(value.receipt))) throw new Error("recovery");
  const input = normalizeRetentionReleaseInput(value.input); retentionReleasePayload(companyId, value.key, input);
  return { version: 1, userId, companyId, key: value.key, input, ...(value.receipt ? { receipt: value.receipt } : {}) };
}
export function saveRetentionReleaseAttempt(storage: Storage, attempt: RetentionReleaseAttempt) { storage.setItem(retentionReleaseAttemptStorageKey(attempt.userId, attempt.companyId), JSON.stringify(attempt)); }
const inFlight = new Map<string, Promise<RetentionReleaseAttempt>>();
export function sendRetentionReleaseAttempt(client: SupabaseClient<Database>, storage: Storage, attempt: RetentionReleaseAttempt, firstSend = false): Promise<RetentionReleaseAttempt> {
  if (attempt.receipt) return Promise.resolve(attempt); const lock = retentionReleaseAttemptStorageKey(attempt.userId, attempt.companyId); const running = inFlight.get(lock); if (running) return running;
  const run = (async () => { saveRetentionReleaseAttempt(storage, attempt); const { data, error } = await client.auth.getSession(); if (error || data.session?.user.id !== attempt.userId) throw new Error("denied");
    let receipt: RetentionReleaseReceipt; try { receipt = await postRetentionRelease(client, attempt.companyId, attempt.key, attempt.input); }
    catch (error) { if (firstSend && error instanceof RetentionReleasePostError && error.rejected) { storage.removeItem(lock); throw new Error("rejected"); } throw error; }
    const completed = { ...attempt, receipt }; try { saveRetentionReleaseAttempt(storage, completed); } catch { /* frozen request remains replayable */ } return completed; })();
  inFlight.set(lock, run); void run.finally(() => { if (inFlight.get(lock) === run) inFlight.delete(lock); }).catch(() => {}); return run;
}
