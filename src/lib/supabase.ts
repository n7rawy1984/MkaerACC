import { supabaseBrowserConfig } from "../config/productionConfig";
import { createClient, type SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";

let client: SupabaseClient<Database> | null = null;

export function getSupabaseClient(): SupabaseClient<Database> {
  if (client) return client;
  const {url, key: publishableKey} = supabaseBrowserConfig(import.meta.env, import.meta.env.DEV);

  client = createClient<Database>(url, publishableKey, {
    auth: {
      persistSession: true,
      autoRefreshToken: true,
      detectSessionInUrl: false,
      storageKey: "makeracc:p6a:auth",
    },
  });
  return client;
}
