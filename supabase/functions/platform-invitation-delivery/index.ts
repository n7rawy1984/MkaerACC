// Deploy/configure only after separate approval. Credentials never enter Vite.
import { createClient } from "npm:@supabase/supabase-js@2.112.4";
import { deliveryHandler } from "./handler.mjs";

const url = Deno.env.get("SUPABASE_URL") ?? "";
const publicKey = Deno.env.get("SUPABASE_ANON_KEY") ?? "";
const privateKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
const appOrigin = Deno.env.get("PLATFORM_APP_ORIGIN") ?? "";
const additionalOrigins = Deno.env.get("PLATFORM_INVITATION_ADDITIONAL_ORIGINS") ?? "[]";
const caller = (authorization: string) => createClient(url, publicKey, {
  global: { headers: { Authorization: authorization } }, auth: { persistSession: false, autoRefreshToken: false },
});
const admin = () => createClient(url, privateKey, { auth: { persistSession: false, autoRefreshToken: false } });
const handler = deliveryHandler({
  appOrigin,
  additionalOrigins,
  authorize: async (authorization: string) => {
    const result = await caller(authorization).auth.getUser(authorization.slice(7));
    if (result.error || !result.data.user) throw Error("Denied");
  },
  claim: async (authorization: string, invitationId: string) => {
    const result = await caller(authorization).rpc("claim_platform_delivery", { invitation_id: invitationId });
    if (result.error) throw Error(result.error.code === "42501" && result.error.message === "MFA_REQUIRED" ? "MFA_REQUIRED" : "Denied"); return result.data;
  },
  deliver: async (email: string, redirectTo: string) => {
    const result = await admin().auth.admin.inviteUserByEmail(email, { redirectTo });
    if (result.error) throw Error(["email_exists", "user_already_exists"].includes(result.error.code ?? "") ? "EXISTING_USER_SIGN_IN_REQUIRED" : "Delivery failed");
  },
  finish: async (invitationId: string, leaseId: string, outcome: string) => {
    const result = await admin().rpc("finish_platform_delivery", { invitation_id: invitationId, lease_id: leaseId, outcome });
    if (result.error) throw Error("Delivery uncertain");
  },
});
Deno.serve(handler);
