import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { canReadDashboardFinancials, readDashboardFinancials, type DashboardFinancialRead } from "./dashboardRead";

type State = { phase: "LOADING" | "ERROR" | "DENIED" } | { phase: "READY"; data: DashboardFinancialRead };
export function useDashboardRead(client: SupabaseClient<Database>, userId: string, companyId: string, role: string, revision: number, enabled: boolean): State {
  const scope = JSON.stringify([userId, companyId, role, revision, enabled]);
  const [snapshot, setSnapshot] = useState<{ scope: string; value: State } | null>(null);
  useEffect(() => {
    if (!enabled || !canReadDashboardFinancials(role)) return;
    let current = true;
    const commit = (value: State) => { if (current) setSnapshot({ scope, value }); };
    const { data } = client.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) {
        commit({ phase: "ERROR" }); current = false;
      }
    });
    void readDashboardFinancials(client, userId, companyId, role, () => current)
      .then(result => commit({ phase: "READY", data: result }))
      .catch(() => commit({ phase: "ERROR" }));
    return () => { current = false; data.subscription.unsubscribe(); };
  }, [client, userId, companyId, role, enabled, scope]);
  if (!canReadDashboardFinancials(role)) return { phase: "DENIED" };
  return snapshot?.scope === scope ? snapshot.value : { phase: "LOADING" };
}
