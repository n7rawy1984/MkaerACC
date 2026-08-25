import type {
  CustodySettlement,
  ExpenseTransaction,
  JournalEntry,
  Project,
  SubcontractorPaymentTransaction,
} from "../domain/types";
import { addMoney, subtractMoney } from "../domain/money";
import { ACCOUNTS } from "./chartOfAccounts";

type NormalSide = "DEBIT" | "CREDIT";

interface AccountTotals {
  debit: number;
  credit: number;
}

/** Raw debit/credit totals for an account, optionally scoped by party, project, and/or contract
 * (Phase 2B.2) dimension. Exposed separately from accountBalance so callers that need the gross
 * one-sided total (e.g. "Advance Paid" vs. "Advance Recovered") don't have to net them themselves. */
function accountTotals(
  entries: JournalEntry[],
  accountId: string,
  opts: { partyId?: string; projectId?: string; contractId?: string } = {},
): AccountTotals {
  let debit = 0;
  let credit = 0;
  for (const entry of entries) {
    for (const l of entry.lines) {
      if (l.accountId !== accountId) continue;
      if (opts.partyId && l.partyId !== opts.partyId) continue;
      if (opts.projectId && l.projectId !== opts.projectId) continue;
      if (opts.contractId && l.contractId !== opts.contractId) continue;
      debit = addMoney(debit, l.debit);
      credit = addMoney(credit, l.credit);
    }
  }
  return { debit, credit };
}

/**
 * Balance of an account, optionally scoped to one party (custodian, owner,
 * or supplier), one project, and/or one subcontract (Phase 2B.2), expressed
 * on its natural side. Assets and expenses read naturally as debit
 * balances; liabilities read naturally as credit balances.
 */
function accountBalance(
  entries: JournalEntry[],
  accountId: string,
  normalSide: NormalSide,
  opts: { partyId?: string; projectId?: string; contractId?: string } = {},
): number {
  const { debit, credit } = accountTotals(entries, accountId, opts);
  return normalSide === "DEBIT" ? subtractMoney(debit, credit) : subtractMoney(credit, debit);
}

/** Remaining custody balance still held by a custodian (advances minus expenses charged). */
export function custodianBalance(entries: JournalEntry[], custodianPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.ADVANCE_CUSTODY, "DEBIT", { partyId: custodianPartyId });
}

/** Live balance of one treasury account, derived from the journal lines posted to its own GL
 * account (see Phase 2B.1A) — never from a cached/stored total. Cash/Bank are debit-normal assets.
 * For a treasury account still on a shared/legacy GL account, this returns that account's whole
 * pooled balance (see TreasuryAccount migration notes in storage/migrations.ts). */
export function treasuryAccountBalance(entries: JournalEntry[], glAccountId: string): number {
  return accountBalance(entries, glAccountId, "DEBIT");
}

export function totalOpenCustodianAdvances(entries: JournalEntry[], custodianPartyIds: string[]): number {
  return custodianPartyIds.reduce((sum, id) => addMoney(sum, custodianBalance(entries, id)), 0);
}

/** Amount the company currently owes an owner for expenses/advances funded personally. */
export function ownerCurrentBalance(entries: JournalEntry[], ownerPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.OWNER_CURRENT, "CREDIT", { partyId: ownerPartyId });
}

/** Amount currently owed to a supplier. */
export function supplierPayableBalance(entries: JournalEntry[], supplierPartyId: string): number {
  return accountBalance(entries, ACCOUNTS.ACCOUNTS_PAYABLE, "CREDIT", { partyId: supplierPartyId });
}

export function totalSupplierPayables(entries: JournalEntry[], supplierPartyIds: string[]): number {
  return supplierPartyIds.reduce((sum, id) => addMoney(sum, supplierPayableBalance(entries, id)), 0);
}

/** Direct (non-subcontractor) expense cost posted to a project. */
export function directExpenseCost(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.PROJECT_COST, "DEBIT", { projectId });
}

/** Subcontractor cost recognized on APPROVED certificates only — DRAFT certificates never post. */
export function subcontractorCertifiedCost(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.PROJECT_COST_SUBCONTRACTORS, "DEBIT", { projectId });
}

/** True total project cost = direct expenses + subcontractor certified work, recognized exactly
 * once each (subcontractor advances/payments never appear here — only certificate approval does). */
export function totalProjectCost(entries: JournalEntry[], projectId?: string): number {
  return addMoney(directExpenseCost(entries, projectId), subcontractorCertifiedCost(entries, projectId));
}

export function totalCompanyExpense(entries: JournalEntry[]): number {
  return accountBalance(entries, ACCOUNTS.COMPANY_EXPENSE, "DEBIT");
}

export function totalInputVat(entries: JournalEntry[], projectId?: string): number {
  return accountBalance(entries, ACCOUNTS.INPUT_VAT, "DEBIT", { projectId });
}

export function expensesWithoutInvoice(expenses: ExpenseTransaction[]): ExpenseTransaction[] {
  return expenses.filter((e) => !e.hasInvoice && e.status === "POSTED");
}

export interface CategoryCost {
  categoryId: string;
  amount: number;
}

/** Cost grouped by expense category, using net amount (VAT excluded — it is recoverable, not cost). */
export function costByCategory(expenses: ExpenseTransaction[], projectId?: string): CategoryCost[] {
  const map = new Map<string, number>();
  for (const e of expenses) {
    if (e.status !== "POSTED") continue;
    if (projectId && e.projectId !== projectId) continue;
    map.set(e.categoryId, addMoney(map.get(e.categoryId) ?? 0, e.netAmount));
  }
  return [...map.entries()].map(([categoryId, amount]) => ({ categoryId, amount }));
}

export interface LedgerLine {
  date: string;
  reference: string;
  description: string;
  debit: number;
  credit: number;
  balance: number;
}

/**
 * Chronological ledger for one party against one control account (Owner
 * Current or Advance/Custody), with a running balance on the account's
 * natural side. Used for the person-level ledger views.
 */
export function partyLedger(
  entries: JournalEntry[],
  accountId: string,
  partyId: string,
  normalSide: NormalSide,
): LedgerLine[] {
  const rows: Omit<LedgerLine, "balance">[] = [];
  for (const entry of [...entries].sort((a, b) => (a.date < b.date ? -1 : 1))) {
    for (const l of entry.lines) {
      if (l.accountId !== accountId || l.partyId !== partyId) continue;
      rows.push({
        date: entry.date,
        reference: entry.reference,
        description: entry.description,
        debit: l.debit,
        credit: l.credit,
      });
    }
  }
  let running = 0;
  return rows.map((row) => {
    running =
      normalSide === "DEBIT"
        ? addMoney(running, subtractMoney(row.debit, row.credit))
        : addMoney(running, subtractMoney(row.credit, row.debit));
    return { ...row, balance: running };
  });
}

export interface ProjectCostSummary {
  project: Project;
  totalCost: number;
}

export function costByProject(entries: JournalEntry[], projects: Project[]): ProjectCostSummary[] {
  return projects.map((project) => ({
    project,
    totalCost: totalProjectCost(entries, project.id),
  }));
}

// ============================================================================
// PHASE 2A — Subcontractors
// ============================================================================

export function subcontractorPayableBalance(entries: JournalEntry[], subcontractorId: string): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_PAYABLE, "CREDIT", { partyId: subcontractorId });
}

export function totalSubcontractorPayables(entries: JournalEntry[], subcontractorIds: string[]): number {
  return subcontractorIds.reduce((sum, id) => addMoney(sum, subcontractorPayableBalance(entries, id)), 0);
}

/** Available (unrecovered) advance balance for a subcontractor, optionally scoped to one project/contract. */
export function subcontractorAdvanceBalance(
  entries: JournalEntry[],
  subcontractorId: string,
  projectId?: string,
): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_ADVANCE, "DEBIT", { partyId: subcontractorId, projectId });
}

export function subcontractorRetentionHeld(
  entries: JournalEntry[],
  subcontractorId: string,
  projectId?: string,
): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE, "CREDIT", {
    partyId: subcontractorId,
    projectId,
  });
}

export function totalRetentionHeld(entries: JournalEntry[], subcontractorIds: string[]): number {
  return subcontractorIds.reduce((sum, id) => addMoney(sum, subcontractorRetentionHeld(entries, id)), 0);
}

/** Amount already paid against one certificate — derived from payment records, not the journal,
 * since payments are certificate-scoped for status tracking (PARTIALLY_PAID / PAID). */
export function certificatePaidAmount(
  payments: SubcontractorPaymentTransaction[],
  certificateId: string,
): number {
  return payments
    .filter((p) => p.certificateId === certificateId)
    .reduce((sum, p) => addMoney(sum, p.amount), 0);
}

// ============================================================================
// PHASE 2B.2 — Contract-scoped subcontractor accounting
//
// Every subcontractor-related journal line now carries a contractId dimension
// (see domain/types.ts JournalLine, accounting/postingEngine.ts) alongside the
// existing partyId dimension. These functions scope strictly by contractId so
// two contracts belonging to the same subcontractor never blend — the
// subcontractorId-only functions above remain valid as the PARTY-level
// aggregate (sum across all of that subcontractor's contracts), since partyId
// is still tagged on every line regardless of contract.
//
// A line with no contractId (a historical entry whose contract could not be
// determined with certainty during migration — see storage/migrations.ts) is
// excluded from every function below and only shows up in the party-level
// aggregate — "legacy party-scoped activity", by design, never guessed at.
// ============================================================================

/** Total advances paid to a subcontractor under one specific contract (gross, before recovery). */
export function contractAdvancePaid(entries: JournalEntry[], contractId: string): number {
  return accountTotals(entries, ACCOUNTS.SUBCONTRACTOR_ADVANCE, { contractId }).debit;
}

/** Total of that contract's advance recovered back through certificates so far. */
export function contractAdvanceRecovered(entries: JournalEntry[], contractId: string): number {
  return accountTotals(entries, ACCOUNTS.SUBCONTRACTOR_ADVANCE, { contractId }).credit;
}

/** Unrecovered advance balance for one contract — Advance Paid minus Advance Recovered. */
export function contractAdvanceBalance(entries: JournalEntry[], contractId: string): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_ADVANCE, "DEBIT", { contractId });
}

/** Retention currently held against one contract. */
export function contractRetentionHeld(entries: JournalEntry[], contractId: string): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_RETENTION_PAYABLE, "CREDIT", { contractId });
}

/** Total payable ever created (credited) for one contract by approved certificates, before payments. */
export function contractPayableCreated(entries: JournalEntry[], contractId: string): number {
  return accountTotals(entries, ACCOUNTS.SUBCONTRACTOR_PAYABLE, { contractId }).credit;
}

/** Outstanding payable for one contract — Payable Created minus Payments Made against it. */
export function contractPayableBalance(entries: JournalEntry[], contractId: string): number {
  return accountBalance(entries, ACCOUNTS.SUBCONTRACTOR_PAYABLE, "CREDIT", { contractId });
}

/** Certified work (Project Cost - Subcontractors) recognized for one contract — APPROVED certificates only. */
export function contractCertifiedCost(entries: JournalEntry[], contractId: string): number {
  return accountBalance(entries, ACCOUNTS.PROJECT_COST_SUBCONTRACTORS, "DEBIT", { contractId });
}

// ============================================================================
// PHASE 2A — Custody Settlements
// ============================================================================

export function cashReturnedByCustodian(settlements: CustodySettlement[], custodianId: string): number {
  return settlements
    .filter((s) => s.custodianId === custodianId && s.status === "SETTLED")
    .reduce((sum, s) => addMoney(sum, s.cashReturnAmount), 0);
}

export function lastSettlementDate(settlements: CustodySettlement[], custodianId: string): string | undefined {
  const dates = settlements
    .filter((s) => s.custodianId === custodianId && s.status === "SETTLED" && s.settledAt)
    .map((s) => s.settledAt as string);
  if (dates.length === 0) return undefined;
  return dates.reduce((latest, d) => (d > latest ? d : latest));
}
