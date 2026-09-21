import { updateTreasuryName, type TreasuryNameCommand } from "./treasuryNameMutations";
import { updateAccountName, type AccountNameCommand } from "./accountNameMutations";
import { updateProjectMetadata, type ProjectMetadataCommand } from "./projectMetadataMutations";
import { updateCompanyProfile, type CompanyProfileCommand } from "./companyProfileMutations";
import { useEffect, useLayoutEffect, useRef, useState, type ReactNode } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import { readActiveCompanyProfile, readActiveCompanyProjects, readActiveCompanyParties, readActiveCompanyExpenseCategories, readActiveCompanyAccounts, readActiveCompanyTreasuryAccounts, readActiveCompanySubcontracts } from "./masterRepositories";
import type { CategoryActions, SupplierActions, CompanyProfileActions, ProjectMetadataActions, AccountNameActions, TreasuryNameActions, ProductionMasterDataState } from "./masterTypes";
import { mutateExpenseCategory, type ExpenseCategoryCommand } from "./expenseCategoryMutations";
import { mutateSupplierParty, type SupplierPartyCommand } from "./supplierPartyMutations";
import { ProductionMasterDataContext } from "./productionMasterDataContext";

export function ProductionMasterDataProvider({ client, userId, activeCompanyId, role, onCompanyProfileRefreshed, children }: {
  client: SupabaseClient<Database>;
  userId: string;
  activeCompanyId: string;
  role: Database["public"]["Enums"]["company_role"];
  onCompanyProfileRefreshed?: (userId: string, companyId: string, role: Database["public"]["Enums"]["company_role"], legalName: string | null) => void;
  children: ReactNode;
}) {
  const scopeKey = `${userId}:${activeCompanyId}:${role}`;
  const [scopedState, setScopedState] = useState<{ scopeKey: string; state: ProductionMasterDataState }>({
    scopeKey,
    state: { phase: "LOADING" },
  });
  const requestGeneration = useRef(0);
  const liveScope = useRef(scopeKey);
  const mutationLock = useRef(false);
  const categoryGeneration = useRef(0);
  const [mutationState, setMutationState] = useState<{ scopeKey: string; value: CategoryActions["categoryMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  const supplierLock = useRef(false);
  const supplierGeneration = useRef(0);
  const [supplierState, setSupplierState] = useState<{ scopeKey: string; value: SupplierActions["supplierMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  const companyLock = useRef(false);
  const companyGeneration = useRef(0);
  const [companyState, setCompanyState] = useState<{ scopeKey: string; value: CompanyProfileActions["companyProfileMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  const projectLock = useRef(false);
  const projectGeneration = useRef(0);
  const [projectState, setProjectState] = useState<{ scopeKey: string; value: ProjectMetadataActions["projectMetadataMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  const accountLock = useRef(false);
  const accountGeneration = useRef(0);
  const [accountState, setAccountState] = useState<{ scopeKey: string; value: AccountNameActions["accountNameMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  const treasuryLock = useRef(false);
  const treasuryGeneration = useRef(0);
  const [treasuryState, setTreasuryState] = useState<{ scopeKey: string; value: TreasuryNameActions["treasuryNameMutation"] }>({ scopeKey, value: { phase: "IDLE" } });

  useLayoutEffect(() => {
    liveScope.current = scopeKey;
    return () => { categoryGeneration.current += 1; supplierGeneration.current += 1; companyGeneration.current += 1; projectGeneration.current += 1; accountGeneration.current += 1; treasuryGeneration.current += 1; };
  }, [scopeKey]);

  useEffect(() => {
    const generation = ++requestGeneration.current;
    mutationLock.current = false;
    supplierLock.current = false;
    companyLock.current = false;
    projectLock.current = false;
    accountLock.current = false;
    treasuryLock.current = false;
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
  const categoryMutation = mutationState.scopeKey === scopeKey ? mutationState.value : { phase: "IDLE" } as const;

  const supplierMutation = supplierState.scopeKey === scopeKey ? supplierState.value : { phase: "IDLE" } as const;

  // Explicit category operations never trigger the seven-resource initial loader.
  const runCategoryOperation = async (command?: ExpenseCategoryCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || mutationLock.current || liveScope.current !== scopeKey
      || (command && (role !== "ACCOUNTING_ADMIN" || categoryMutation.phase === "ERROR" || categoryMutation.phase === "REFRESH_ERROR"))) return false;
    mutationLock.current = true;
    const generation = requestGeneration.current;
    const categoryRequest = ++categoryGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && categoryGeneration.current === categoryRequest;
    const feedback = (value: CategoryActions["categoryMutation"]) => { if (current()) setMutationState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = false;
    try {
      if (!await validSession()) { feedback({ phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await mutateExpenseCategory(client, activeCompanyId, command);
        if (!await validSession()) { feedback({ phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
        saved = true;
      }
      const refreshed = await readActiveCompanyExpenseCategories(client, activeCompanyId);
      if (!await validSession()) { feedback({ phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok) { feedback({ phase: "REFRESH_ERROR" }); return false; }
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, expenseCategories: refreshed.data } } : previous);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) mutationLock.current = false;
    }
  };
  // Explicit supplier operations never trigger the seven-resource initial loader.
  const runSupplierOperation = async (command?: SupplierPartyCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || supplierLock.current || liveScope.current !== scopeKey
      || (command && ((role !== "ACCOUNTING_ADMIN" && role !== "PROCUREMENT") || supplierMutation.phase === "ERROR" || supplierMutation.phase === "REFRESH_ERROR"))) return false;
    supplierLock.current = true;
    const generation = requestGeneration.current;
    const supplierRequest = ++supplierGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && supplierGeneration.current === supplierRequest;
    const feedback = (value: SupplierActions["supplierMutation"]) => { if (current()) setSupplierState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = !command && supplierMutation.phase === "REFRESH_ERROR";
    try {
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await mutateSupplierParty(client, activeCompanyId, command);
        if (result.ok) saved = true;
        if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
      }
      const refreshed = await readActiveCompanyParties(client, activeCompanyId);
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" }); return false; }
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, parties: refreshed.data } } : previous);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) supplierLock.current = false;
    }
  };
  const companyProfileMutation = companyState.scopeKey === scopeKey ? companyState.value : { phase: "IDLE" } as const;
  const runCompanyOperation = async (command?: CompanyProfileCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || companyLock.current || liveScope.current !== scopeKey
      || (command && ((role !== "ACCOUNTING_ADMIN" && role !== "SYSTEM_ADMIN")
        || companyProfileMutation.phase === "ERROR" || companyProfileMutation.phase === "REFRESH_ERROR"))) return false;
    companyLock.current = true;
    const generation = requestGeneration.current;
    const operation = ++companyGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && companyGeneration.current === operation;
    const feedback = (value: CompanyProfileActions["companyProfileMutation"]) => { if (current()) setCompanyState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = !command && companyProfileMutation.phase === "REFRESH_ERROR";
    try {
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await updateCompanyProfile(client, activeCompanyId, command);
        if (result.ok) saved = true;
        if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
      }
      // Refresh only Company, leaving settings, other masters and their operations intact.
      const refreshed = await readActiveCompanyProfile(client, activeCompanyId);
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok || !refreshed.data || refreshed.data.status !== "ACTIVE") {
        feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" }); return false;
      }
      const company = refreshed.data;
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, company } } : previous);
      onCompanyProfileRefreshed?.(userId, activeCompanyId, role, company.legalName);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) companyLock.current = false;
    }
  };
  const projectMetadataMutation = projectState.scopeKey === scopeKey ? projectState.value : { phase: "IDLE" } as const;
  const runProjectOperation = async (command?: ProjectMetadataCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || projectLock.current || liveScope.current !== scopeKey
      || (command && ((role !== "ACCOUNTING_ADMIN" && role !== "PROJECT_MANAGER")
        || projectMetadataMutation.phase === "ERROR" || projectMetadataMutation.phase === "REFRESH_ERROR"))) return false;
    projectLock.current = true;
    const generation = requestGeneration.current;
    const operation = ++projectGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && projectGeneration.current === operation;
    const feedback = (value: ProjectMetadataActions["projectMetadataMutation"]) => { if (current()) setProjectState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = !command && projectMetadataMutation.phase === "REFRESH_ERROR";
    try {
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await updateProjectMetadata(client, activeCompanyId, command);
        if (result.ok) saved = true;
        if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
      }
      // Refresh only Projects; RLS removes revoked assignments from the next snapshot.
      const refreshed = await readActiveCompanyProjects(client, activeCompanyId);
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok) {
        feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" }); return false;
      }
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, projects: refreshed.data } } : previous);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) projectLock.current = false;
    }
  };
  const accountNameMutation = accountState.scopeKey === scopeKey ? accountState.value : { phase: "IDLE" } as const;
  const runAccountOperation = async (command?: AccountNameCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || accountLock.current || liveScope.current !== scopeKey
      || (command && (role !== "ACCOUNTING_ADMIN"
        || accountNameMutation.phase === "ERROR" || accountNameMutation.phase === "REFRESH_ERROR"))) return false;
    accountLock.current = true;
    const generation = requestGeneration.current;
    const operation = ++accountGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && accountGeneration.current === operation;
    const feedback = (value: AccountNameActions["accountNameMutation"]) => { if (current()) setAccountState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = !command && accountNameMutation.phase === "REFRESH_ERROR";
    try {
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await updateAccountName(client, activeCompanyId, command);
        if (result.ok) saved = true;
        if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
      }
      // Refresh only Accounts; Retain all other resource snapshots and operation states.
      const refreshed = await readActiveCompanyAccounts(client, activeCompanyId);
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok) {
        feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" }); return false;
      }
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, accounts: refreshed.data } } : previous);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) accountLock.current = false;
    }
  };
  const treasuryNameMutation = treasuryState.scopeKey === scopeKey ? treasuryState.value : { phase: "IDLE" } as const;
  const runTreasuryOperation = async (command?: TreasuryNameCommand): Promise<boolean> => {
    if (visibleState.phase !== "READY" || treasuryLock.current || liveScope.current !== scopeKey
      || (command && (role !== "ACCOUNTING_ADMIN"
        || treasuryNameMutation.phase === "ERROR" || treasuryNameMutation.phase === "REFRESH_ERROR"))) return false;
    treasuryLock.current = true;
    const generation = requestGeneration.current;
    const operation = ++treasuryGeneration.current;
    const current = () => liveScope.current === scopeKey && requestGeneration.current === generation && treasuryGeneration.current === operation;
    const feedback = (value: TreasuryNameActions["treasuryNameMutation"]) => { if (current()) setTreasuryState({ scopeKey, value }); };
    const validSession = async () => {
      const { data, error } = await client.auth.getSession();
      return current() && !error && data.session?.user.id === userId;
    };
    feedback({ phase: "PENDING" });
    let saved = !command && treasuryNameMutation.phase === "REFRESH_ERROR";
    try {
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (command) {
        const result = await updateTreasuryName(client, activeCompanyId, command);
        if (result.ok) saved = true;
        if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
        if (!result.ok) { feedback({ phase: "ERROR", error: result.error }); return false; }
      }
      // Refresh only Treasury; Retain all other resource snapshots and operation states.
      const refreshed = await readActiveCompanyTreasuryAccounts(client, activeCompanyId);
      if (!await validSession()) { feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "denied" }); return false; }
      if (!refreshed.ok) {
        feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" }); return false;
      }
      setScopedState((previous) => previous.scopeKey === scopeKey && previous.state.phase === "READY"
        ? { scopeKey, state: { ...previous.state, treasuryAccounts: refreshed.data } } : previous);
      feedback({ phase: saved ? "SAVED" : "IDLE" });
      return true;
    } catch {
      feedback(saved ? { phase: "REFRESH_ERROR" } : { phase: "ERROR", error: "uncertain" });
      return false;
    } finally {
      if (current()) treasuryLock.current = false;
    }
  };
  return <ProductionMasterDataContext.Provider value={{ ...visibleState, categoryMutation, supplierMutation, companyProfileMutation, projectMetadataMutation, accountNameMutation, treasuryNameMutation,
    saveTreasuryName: runTreasuryOperation,
    refreshTreasuryAccounts: () => runTreasuryOperation(),
    saveAccountName: runAccountOperation,
    refreshAccounts: () => runAccountOperation(),
    saveProjectMetadata: runProjectOperation,
    refreshProjects: () => runProjectOperation(),
    saveCompanyProfile: runCompanyOperation,
    refreshCompanyProfile: () => runCompanyOperation(),
    saveSupplierParty: runSupplierOperation,
    refreshParties: () => runSupplierOperation(),
    saveExpenseCategory: runCategoryOperation,
    refreshExpenseCategories: () => runCategoryOperation(),
  }}>{children}</ProductionMasterDataContext.Provider>;
}
