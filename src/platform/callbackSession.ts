import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { callbackInput } from "./callbackInput.ts";

export type PasswordSession = { userId: string; accessToken: string };

// Only a successfully consumed recovery/invite credential authorizes this form.
// An ordinary stored session or a URL claiming type=recovery is insufficient.
export async function establishCallbackSession(client: SupabaseClient<Database>, url: URL): Promise<PasswordSession | null> {
  const input = callbackInput(url);
  if (input.kind === "session") {
    const current = await client.auth.getUser();
    if (current.error || !current.data.user) throw new Error("Invalid callback");
    return null; // Existing-user invitation acceptance only; never password recovery.
  }
  const result = input.kind === "token"
    ? await client.auth.verifyOtp({ token_hash: input.tokenHash, type: input.type })
    : await client.auth.exchangeCodeForSession(input.code);
  if (result.error || !result.data.session?.access_token || !result.data.user) throw new Error("Invalid callback");
  if (input.kind === "code" && (!("redirectType" in result.data) || result.data.redirectType !== "recovery")) return null;
  const proof = { userId: result.data.user.id, accessToken: result.data.session.access_token };
  await assertPasswordSession(client, proof);
  return proof;
}

export async function assertPasswordSession(client: SupabaseClient<Database>, proof: PasswordSession) {
  const current = await client.auth.getSession();
  if (current.error || !current.data.session || current.data.session.access_token !== proof.accessToken || current.data.session.user.id !== proof.userId) throw new Error("Session changed");
  const verified = await client.auth.getUser(proof.accessToken);
  if (verified.error || verified.data.user?.id !== proof.userId) throw new Error("Invalid session");
}
