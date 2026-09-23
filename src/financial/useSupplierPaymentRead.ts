import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readSupplierPayments, type SupplierPaymentSnapshot } from "./supplierPaymentRepository";

type State = { phase: "LOADING" | "ERROR" } | ({ phase: "READY" } & SupplierPaymentSnapshot);
export function useSupplierPaymentRead(client: SupabaseClient<Database>, userId: string, companyId: string, role: string, revision: number): State {
  const scope = JSON.stringify([userId, companyId, role, revision]);
  const [snapshot, setSnapshot] = useState<{ scope: string; state: State } | null>(null);
  useEffect(() => {
    let current = true;
    const commit = (state: State) => { if (current) setSnapshot({ scope, state }); };
    commit({ phase: "LOADING" });
    const { data: subscription } = client.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) { commit({ phase: "ERROR" }); current = false; }
    });
    const valid = async () => { const { data, error } = await client.auth.getSession(); return current && !error && data.session?.user.id === userId; };
    void (async () => {
      if (!await valid()) { commit({ phase: "ERROR" }); return; }
      const result = await readSupplierPayments(client, companyId);
      if (!await valid()) { commit({ phase: "ERROR" }); return; }
      commit({ phase: "READY", ...result });
    })().catch(() => commit({ phase: "ERROR" }));
    return () => { current = false; subscription.subscription.unsubscribe(); };
  }, [client, userId, companyId, scope]);
  return snapshot?.scope === scope ? snapshot.state : { phase: "LOADING" };
}
