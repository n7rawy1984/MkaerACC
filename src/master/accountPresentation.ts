import type { ProductionAccount } from "./masterTypes";

// Only resolve labels from the current RLS-filtered snapshot. A reference ID
// does not authorize fetching or synthesizing the referenced Account.
export function findVisibleAccount(accounts: readonly ProductionAccount[], companyId: string, accountId: string | null): ProductionAccount | null {
  if (accountId === null) return null;
  return accounts.find((account) => account.companyId === companyId && account.id === accountId) ?? null;
}
