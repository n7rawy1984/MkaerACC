import { useEffect, useRef, useState, type ReactNode } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readActiveCompanyProfile, readActiveCompanyProjects, readActiveCompanyParties, readActiveCompanyExpenseCategories, readActiveCompanyAccounts, readActiveCompanyTreasuryAccounts, readActiveCompanySubcontracts } from "./masterRepositories";
import type { ProductionMasterDataState } from "./masterTypes";
import { ProductionMasterDataContext } from "./productionMasterDataContext";

export function ProductionMasterDataProvider({ client, userId, activeCompanyId, role, children }: {
  client: SupabaseClient<Database>;
  userId: string;
  activeCompanyId: string;
  role: Database["public"]["Enums"]["company_role"];
  children: ReactNode;
}) {
  const scopeKey = `${userId}:${activeCompanyId}:${role}`;
  const [scopedState, setScopedState] = useState<{ scopeKey: string; state: ProductionMasterDataState }>({
    scopeKey,
    state: { phase: "LOADING" },
  });
  const requestGeneration = useRef(0);

  useEffect(() => {
    const generation = ++requestGeneration.current;
    let mounted = true;

    const isCurrent = () => mounted && requestGeneration.current === generation;
    const commit = (state: ProductionMasterDataState) => {
      if (isCurrent()) setScopedState({ scopeKey, state });
    };
    const load = async () => {
      const { data: initialSession, error: sessionError } = await client.auth.getSession();
      if (!isCurrent()) return;
      if (sessionError || initialSession.session?.user.id !== userId) {
        commit({
          phase: "ERROR",
          error: { source: "session", code: null, message: "The authenticated session could not be verified." },
        });
        return;
      }

      const [companyResult, projectsResult, partiesResult, categoriesResult, accountsResult, treasuryResult, subcontractsResult] = await Promise.all([
        readActiveCompanyProfile(client, activeCompanyId),
        readActiveCompanyProjects(client, activeCompanyId),
        readActiveCompanyParties(client, activeCompanyId),
        readActiveCompanyExpenseCategories(client, activeCompanyId),
        readActiveCompanyAccounts(client, activeCompanyId),
        readActiveCompanyTreasuryAccounts(client, activeCompanyId),
        readActiveCompanySubcontracts(client, activeCompanyId),
      ]);
      const { data: liveSession } = await client.auth.getSession();
      if (!isCurrent() || liveSession.session?.user.id !== userId) return;
      if (!companyResult.ok) {
        commit({ phase: "ERROR", error: companyResult.error });
        return;
      }
      if (!projectsResult.ok) {
        commit({ phase: "ERROR", error: projectsResult.error });
        return;
      }
      if (!partiesResult.ok) {
        commit({ phase: "ERROR", error: partiesResult.error });
        return;
      }
      if (!categoriesResult.ok) {
        commit({ phase: "ERROR", error: categoriesResult.error });
        return;
      }
      if (!accountsResult.ok) {
        commit({ phase: "ERROR", error: accountsResult.error });
        return;
      }
      if (!treasuryResult.ok) {
        commit({ phase: "ERROR", error: treasuryResult.error });
        return;
      }
      if (!subcontractsResult.ok) {
        commit({ phase: "ERROR", error: subcontractsResult.error });
        return;
      }
      if (!companyResult.data) {
        commit({ phase: "MISSING_COMPANY" });
        return;
      }
      commit({ phase: "READY", company: companyResult.data, projects: projectsResult.data, parties: partiesResult.data, expenseCategories: categoriesResult.data, accounts: accountsResult.data, treasuryAccounts: treasuryResult.data, subcontracts: subcontractsResult.data });
    };

    void load().catch(() => commit({
      phase: "ERROR",
      error: { source: "session", code: null, message: "Protected master data could not be loaded." },
    }));
    return () => {
      mounted = false;
      requestGeneration.current += 1;
    };
  }, [activeCompanyId, client, scopeKey, userId]);

  const visibleState = scopedState.scopeKey === scopeKey ? scopedState.state : { phase: "LOADING" } as const;
  return <ProductionMasterDataContext.Provider value={visibleState}>{children}</ProductionMasterDataContext.Provider>;
}
