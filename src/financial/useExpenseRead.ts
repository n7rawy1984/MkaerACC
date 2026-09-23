import { useEffect, useState } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readExpenses, type ExpenseRead } from "./expenseRepository";

type State = { phase: "LOADING" | "ERROR" } | { phase: "READY"; rows: ExpenseRead[]; hasNext: boolean };
export function useExpenseRead(client: SupabaseClient<Database>, userId: string, companyId: string, role: string, page: number, revision: number): State {
  const scope = JSON.stringify([userId, companyId, role, page, revision]);
  const [snapshot, setSnapshot] = useState<{ scope: string; state: State } | null>(null);
  useEffect(() => {
    let current = true;
    const commit = (state: State) => { if (current) setSnapshot({ scope, state }); };
    commit({ phase: "LOADING" });
    const { data: subscription } = client.auth.onAuthStateChange((event, session) => {
      if (event === "SIGNED_OUT" || !session || session.user.id !== userId) {
        commit({ phase: "ERROR" });
        current = false;
      }
    });
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current && !error && data.session?.user.id === userId;
    };
    void (async () => {
      if (!await validSession()) { commit({ phase: "ERROR" }); return; }
      const result = await readExpenses(client, companyId, page);
      if (!await validSession()) { commit({ phase: "ERROR" }); return; }
      commit({ phase: "READY", ...result });
    })().catch(() => commit({ phase: "ERROR" }));
    return () => { current = false; subscription.subscription.unsubscribe(); };
  }, [client, userId, companyId, scope, page]);
  return snapshot?.scope === scope ? snapshot.state : { phase: "LOADING" };
}
