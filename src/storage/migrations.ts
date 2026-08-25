// ============================================================================
// PHASE 2B.1 — backward-compatible schema migration.
//
// Existing browser installs may already hold Company/Project/AdvanceTransaction
// records shaped for Phase 1 / Phase 2A (no companyId, no funding-source
// split, etc.). This module patches those records additively, in place, so
// older data keeps working without a manual reset. It never touches already
// posted JournalEntry records — those stay exactly as posted; only the
// source master/transaction records gain the new fields they were missing.
// Safe to call on every app load: every step is a no-op once already applied.
// ============================================================================

import { db, newId } from "./database";
import { ACCOUNTS } from "../accounting/chartOfAccounts";
import type { Account, Company, Project, TreasuryAccount } from "../domain/types";

function nowIso(): string {
  return new Date().toISOString();
}

/** Ensures every company has the Phase 2B.1 master-data fields (code, status, timestamps). */
function migrateCompanies(): void {
  const companies = db.companies.getAll();
  companies.forEach((company, index) => {
    const c = company as Partial<Company> & { id: string; name: string };
    const patch: Partial<Company> = {};
    if (!c.code) patch.code = `CO-${String(index + 1).padStart(3, "0")}`;
    if (!c.status) patch.status = "ACTIVE";
    if (!c.createdAt) patch.createdAt = nowIso();
    if (!c.updatedAt) patch.updatedAt = nowIso();
    if (Object.keys(patch).length > 0) db.companies.update(company.id, patch);
  });
}

/** Ensures every project has a companyId (defaulting to the first company) and timestamps. */
function migrateProjects(): void {
  const defaultCompanyId = db.companies.getAll()[0]?.id;
  const projects = db.projects.getAll();
  for (const project of projects) {
    const p = project as Partial<Project> & { id: string };
    const patch: Partial<Project> = {};
    if (!p.companyId && defaultCompanyId) patch.companyId = defaultCompanyId;
    if (!p.createdAt) patch.createdAt = p.startDate ? new Date(p.startDate).toISOString() : nowIso();
    if (!p.updatedAt) patch.updatedAt = nowIso();
    if (Object.keys(patch).length > 0) db.projects.update(project.id, patch);
  }
}

/** Seeds the three baseline treasury accounts once, for installs created before Treasury existed. */
function migrateTreasuryAccounts(): void {
  if (!db.treasuryAccounts.isEmpty()) return;
  const companyId = db.companies.getAll()[0]?.id;
  if (!companyId) return;

  const now = nowIso();
  const accounts: TreasuryAccount[] = [
    {
      id: "treasury_main_cash",
      companyId,
      code: "CASH-01",
      name: "Main Cash",
      type: "CASH",
      glAccountId: ACCOUNTS.CASH,
      status: "ACTIVE",
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "treasury_petty_cash",
      companyId,
      code: "CASH-02",
      name: "Petty Cash",
      type: "PETTY_CASH",
      glAccountId: ACCOUNTS.CASH,
      status: "ACTIVE",
      createdAt: now,
      updatedAt: now,
    },
    {
      id: "treasury_main_bank",
      companyId,
      code: "BANK-01",
      name: "Main Bank",
      type: "BANK",
      glAccountId: ACCOUNTS.BANK,
      status: "ACTIVE",
      createdAt: now,
      updatedAt: now,
    },
  ];
  for (const account of accounts) db.treasuryAccounts.create(account);
}

/**
 * Existing AdvanceTransaction records from before Phase 2B.1 only have
 * fromPartyId (always an owner). They already posted correctly against Owner
 * Current Account, so only the source record needs the new fields — the
 * historical journal entry is untouched.
 */
function migrateAdvances(): void {
  const advances = db.advances.getAll();
  for (const advance of advances) {
    const a = advance as unknown as { fundingSourceType?: string; fromPartyId?: string };
    if (a.fundingSourceType) continue;
    if (!a.fromPartyId) continue;
    db.advances.update(advance.id, {
      fundingSourceType: "OWNER_CURRENT",
      fundingSourceId: a.fromPartyId,
    });
  }
}

/** Runs every Phase 2B.1 backward-compatibility patch, in dependency order. Idempotent. */
export function ensurePhase2B1Migrated(): void {
  migrateCompanies();
  migrateProjects();
  migrateTreasuryAccounts();
  migrateAdvances();
}

// ============================================================================
// PHASE 2B.1A — dedicated per-treasury-account GL accounts.
//
// Phase 2B.1 gave every treasury account a glAccountId, but all cash-family
// accounts shared "1000 Cash on Hand" and all bank-family accounts shared
// "1100 Bank Account" — so Main Cash and Petty Cash were not individually
// traceable. This migration mints one new, dedicated GL account per treasury
// account still on a pooled account and repoints glAccountId to it.
//
// CRITICAL: this never rewrites JournalEntry records. Any transaction posted
// before this migration ran stays posted against the pooled "1000"/"1100"
// account exactly as it always was — only transactions posted AFTER this
// migration will appear under the new dedicated account. A treasury account's
// balance shown in the Treasury screen is therefore only fully accurate for
// activity from this point forward; see PROJECT_ROADMAP.md Known Gaps.
// ============================================================================

function treasuryFamilyRootAccountId(type: TreasuryAccount["type"]): string {
  return type === "BANK" || type === "PROJECT_BANK" ? ACCOUNTS.BANK : ACCOUNTS.CASH;
}

function mintDedicatedTreasuryGlAccount(name: string, type: TreasuryAccount["type"]): Account {
  const rootId = treasuryFamilyRootAccountId(type);
  const rootCode = db.accounts.getById(rootId)?.code ?? "1000";
  const siblings = db.accounts.getAll().filter((a) => a.code.startsWith(`${rootCode}-`));
  const nextSeq = siblings.reduce((max, a) => Math.max(max, Number(a.code.split("-")[1]) || 0), 0) + 1;
  const account: Account = {
    id: newId("acc"),
    code: `${rootCode}-${String(nextSeq).padStart(3, "0")}`,
    name,
    type: "ASSET",
    parentId: rootId,
  };
  db.accounts.create(account);
  return account;
}

function migrateTreasuryAccountsToDedicatedGl(): void {
  const pooledIds = new Set<string>([ACCOUNTS.CASH, ACCOUNTS.BANK]);
  for (const treasury of db.treasuryAccounts.getAll()) {
    if (!pooledIds.has(treasury.glAccountId)) continue; // already migrated / already dedicated
    const account = mintDedicatedTreasuryGlAccount(treasury.name, treasury.type);
    db.treasuryAccounts.update(treasury.id, { glAccountId: account.id });
  }
}

/** Runs the Phase 2B.1A treasury-GL-account upgrade. Idempotent — safe on every boot. */
export function ensurePhase2B1AMigrated(): void {
  migrateTreasuryAccountsToDedicatedGl();
}

// ============================================================================
// PHASE 2B.2 — Subcontractor operationalization: Party.status backfill +
// contract-scoped journal-line dimension backfill.
//
// Every subcontractor-related JournalLine now carries an optional contractId
// dimension (see domain/types.ts, accounting/postingEngine.ts,
// accounting/ledger.ts contractXxx() functions) so two contracts belonging to
// the same subcontractor no longer blend together. This migration backfills
// that dimension onto journal entries posted before this phase, but ONLY
// where the contract can be determined with certainty from the source
// document (SubcontractorAdvance.contractId, SubcontractorCertificate.
// contractId, or SubcontractorPaymentTransaction.certificateId -> contract).
// A journal entry whose source record is missing or whose contract can't be
// resolved is left exactly as it was — it keeps working correctly as
// party-scoped activity (every subcontractor-scoped query still works via
// partyId), it just never appears in a contract-scoped total. No monetary
// amount is ever changed by this migration; only the dimension metadata is
// added. Idempotent — every step is a no-op once already applied.
// ============================================================================

/** Every party gets an explicit status once this migration has run; undefined was already
 * treated as ACTIVE everywhere, so this is purely making that default explicit and persistent. */
function migratePartyStatus(): void {
  for (const party of db.parties.getAll()) {
    if (party.status) continue;
    db.parties.update(party.id, { status: "ACTIVE" });
  }
}

/** Backfills contractId onto SubcontractorPaymentTransaction records created before Phase 2B.2 —
 * deterministic via the certificate they already reference. */
function migrateSubcontractorPaymentContractIds(): void {
  const certificatesById = new Map(db.subcontractorCertificates.getAll().map((c) => [c.id, c]));
  for (const payment of db.subcontractorPayments.getAll()) {
    if (payment.contractId) continue;
    const contractId = certificatesById.get(payment.certificateId)?.contractId;
    if (!contractId) continue; // certificate not found — leave as legacy party-scoped, never guess
    db.subcontractorPayments.update(payment.id, { contractId });
  }
}

/** Resolves the contractId a given subcontractor-sourced journal entry belongs to, from its
 * source document — the only place this migration is allowed to infer a contract from. */
function resolveHistoricalContractId(entry: { sourceType: string; sourceId: string }): string | undefined {
  if (entry.sourceType === "SUBCONTRACTOR_ADVANCE") {
    return db.subcontractorAdvances.getById(entry.sourceId)?.contractId;
  }
  if (entry.sourceType === "SUBCONTRACTOR_CERTIFICATE") {
    return db.subcontractorCertificates.getById(entry.sourceId)?.contractId;
  }
  if (entry.sourceType === "SUBCONTRACTOR_PAYMENT") {
    const payment = db.subcontractorPayments.getById(entry.sourceId);
    if (payment?.contractId) return payment.contractId;
    return payment ? db.subcontractorCertificates.getById(payment.certificateId)?.contractId : undefined;
  }
  return undefined;
}

/** Tags every line of every subcontractor-sourced journal entry with its contract, wherever the
 * source document makes that determination certain. Never touches debit/credit amounts. */
function migrateJournalLineContractIds(): void {
  const SUBCONTRACTOR_SOURCE_TYPES = new Set([
    "SUBCONTRACTOR_ADVANCE",
    "SUBCONTRACTOR_CERTIFICATE",
    "SUBCONTRACTOR_PAYMENT",
  ]);
  for (const entry of db.journalEntries.getAll()) {
    if (!SUBCONTRACTOR_SOURCE_TYPES.has(entry.sourceType)) continue;
    if (entry.lines.every((l) => l.contractId)) continue; // already fully tagged
    const contractId = resolveHistoricalContractId(entry);
    if (!contractId) continue; // can't be determined with certainty — leave as legacy
    const lines = entry.lines.map((l) => (l.contractId ? l : { ...l, contractId }));
    db.journalEntries.update(entry.id, { lines });
  }
}

/** Runs every Phase 2B.2 backward-compatibility patch, in dependency order. Idempotent. */
export function ensurePhase2B2Migrated(): void {
  migratePartyStatus();
  migrateSubcontractorPaymentContractIds();
  migrateJournalLineContractIds();
}
