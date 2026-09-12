import { useEffect, useRef, useState, type ReactNode } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readActiveCompanyProfile, readActiveCompanyProjects } from "./masterRepositories";
import type { ProductionMasterDataState } from "./masterTypes";
import { ProductionMasterDataContext } from "./productionMasterDataContext";

export function ProductionMasterDataProvider({ client, userId, activeCompanyId, children }: {
  client: SupabaseClient<Database>;
  userId: string;
  activeCompanyId: string;
  children: ReactNode;
}) {
  const scopeKey = `${userId}:${activeCompanyId}`;
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

      const [companyResult, projectsResult] = await Promise.all([
        readActiveCompanyProfile(client, activeCompanyId),
        readActiveCompanyProjects(client, activeCompanyId),
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
      if (!companyResult.data) {
        commit({ phase: "MISSING_COMPANY" });
        return;
      }
      commit({ phase: "READY", company: companyResult.data, projects: projectsResult.data });
    };

    void load();
    return () => {
      mounted = false;
      requestGeneration.current += 1;
    };
  }, [activeCompanyId, client, scopeKey, userId]);

  const visibleState = scopedState.scopeKey === scopeKey ? scopedState.state : { phase: "LOADING" } as const;
  return <ProductionMasterDataContext.Provider value={visibleState}>{children}</ProductionMasterDataContext.Provider>;
}
