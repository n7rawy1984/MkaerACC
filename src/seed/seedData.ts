// ============================================================================
// DEMO SEED DATA — for management demonstration and system-validation
// purposes only. This is NOT a real historical import. It is a small,
// realistic dataset illustrating every transaction type the posting engine
// supports, including the Phase 2A subcontractor certificate workflow.
// Safe to delete/reset; the app re-seeds automatically when localStorage is
// empty, and additively backfills the Phase 2A slice on existing installs.
// See state/AppDataContext.tsx for the seed trigger.
// ============================================================================

import type {
  Account,
  AdvanceTransaction,
  Company,
  ExpenseCategory,
  ExpenseTransaction,
  Party,
  Project,
  Subcontract,
  SubcontractorAdvance,
  SubcontractorCertificate,
  SubcontractorPaymentTransaction,
  TreasuryAccount,
} from "../domain/types";
import { calcVat } from "../domain/money";
import { clearAll, db, isDatabaseEmpty } from "../storage/database";
import { ACCOUNTS, CHART_OF_ACCOUNTS } from "../accounting/chartOfAccounts";
import {
  postAdvance,
  postCertificateApproval,
  postExpense,
  postSubcontractorAdvance,
  postSubcontractorPayment,
} from "../accounting/postingEngine";
import { calcCertificate } from "../accounting/certificateCalc";

const COMPANY: Company = {
  id: "company_main",
  code: "CO-001",
  name: "Al Rahim & Majid Contracting LLC",
  trn: "100123456700003",
  address: "Sharjah, United Arab Emirates",
  status: "ACTIVE",
  createdAt: "2026-06-01T00:00:00.000Z",
  updatedAt: "2026-06-01T00:00:00.000Z",
};

// Phase 2B.1A: each seeded treasury account gets its own dedicated GL account
// (not the pooled 1000/1100 control accounts) so Main Cash, Petty Cash, and
// Main Bank are independently traceable from a fresh install / demo reset —
// see accounting/chartOfAccounts.ts and PROJECT_ROADMAP.md Phase 2B.1A.
const TREASURY_GL_ACCOUNTS: Account[] = [
  { id: "acc_treasury_main_cash", code: "1000-001", name: "Main Cash", type: "ASSET", parentId: ACCOUNTS.CASH },
  { id: "acc_treasury_petty_cash", code: "1000-002", name: "Petty Cash", type: "ASSET", parentId: ACCOUNTS.CASH },
  { id: "acc_treasury_main_bank", code: "1100-001", name: "Main Bank", type: "ASSET", parentId: ACCOUNTS.BANK },
];

const TREASURY_ACCOUNTS: TreasuryAccount[] = [
  {
    id: "treasury_main_cash",
    companyId: COMPANY.id,
    code: "CASH-01",
    name: "Main Cash",
    type: "CASH",
    glAccountId: "acc_treasury_main_cash",
    status: "ACTIVE",
    createdAt: "2026-06-01T00:00:00.000Z",
    updatedAt: "2026-06-01T00:00:00.000Z",
  },
  {
    id: "treasury_petty_cash",
    companyId: COMPANY.id,
    code: "CASH-02",
    name: "Petty Cash",
    type: "PETTY_CASH",
    glAccountId: "acc_treasury_petty_cash",
    status: "ACTIVE",
    createdAt: "2026-06-01T00:00:00.000Z",
    updatedAt: "2026-06-01T00:00:00.000Z",
  },
  {
    id: "treasury_main_bank",
    companyId: COMPANY.id,
    code: "BANK-01",
    name: "Main Bank",
    type: "BANK",
    glAccountId: "acc_treasury_main_bank",
    status: "ACTIVE",
    createdAt: "2026-06-01T00:00:00.000Z",
    updatedAt: "2026-06-01T00:00:00.000Z",
  },
];

const PARTIES: Party[] = [
  { id: "owner_rahim", name: "A. Rahim", type: "OWNER" },
  { id: "owner_majid", name: "Majid", type: "OWNER" },
  { id: "custodian_bareq", name: "Bareq", type: "CUSTODIAN", notes: "Manager / Cash Custodian" },
  { id: "custodian_sobhi", name: "Sobhi", type: "CUSTODIAN" },
  { id: "sup_media_general", name: "Media General Trading", type: "SUPPLIER" },
  { id: "sup_noor_building", name: "Noor Building Materials", type: "SUPPLIER" },
  { id: "sup_colors_lake", name: "Colors Lake", type: "SUPPLIER" },
  { id: "sup_qasim_transport", name: "Qasim Transport", type: "SUPPLIER" },
  { id: "sup_tareeq_alhayat", name: "Tareeq Al Hayat", type: "SUPPLIER" },
];

// Kept separate from PARTIES so the Phase 2A upgrade path (an existing Phase 1
// install with no subcontractor data yet) can append just these two without
// touching a user's real party records. See ensurePhase2ASeeded() below.
const SUBCONTRACTOR_PARTIES: Party[] = [
  {
    id: "sub_alfalah_mep",
    name: "Al Falah MEP Contracting",
    type: "SUBCONTRACTOR",
    taxRegistrationNumber: "100987654300003",
    contactPerson: "Eng. Yousef Hamdan",
    phone: "+971-50-123-4567",
    status: "ACTIVE",
  },
  {
    id: "sub_gulf_steel",
    name: "Gulf Steel Works",
    type: "SUBCONTRACTOR",
    taxRegistrationNumber: "100876543200003",
    contactPerson: "Hassan Al Marri",
    phone: "+971-50-765-4321",
    status: "ACTIVE",
  },
];

const PROJECTS: Project[] = [
  {
    id: "proj_alnakhil",
    code: "AN-01",
    name: "Al Nakhil Building",
    companyId: COMPANY.id,
    status: "ACTIVE",
    location: "Sharjah",
    client: "Al Nakhil Real Estate",
    startDate: "2026-06-01",
    budget: 400000,
    createdAt: "2026-06-01T00:00:00.000Z",
    updatedAt: "2026-06-01T00:00:00.000Z",
  },
  {
    id: "proj_alzorah",
    code: "AZ-01",
    name: "Al Zorah",
    companyId: COMPANY.id,
    status: "ACTIVE",
    location: "Ajman",
    client: "Al Zorah Development",
    startDate: "2026-06-15",
    budget: 350000,
    createdAt: "2026-06-15T00:00:00.000Z",
    updatedAt: "2026-06-15T00:00:00.000Z",
  },
  {
    id: "proj_ajman",
    code: "AJ-01",
    name: "Ajman Office",
    companyId: COMPANY.id,
    status: "ACTIVE",
    location: "Ajman",
    client: "Internal / HQ Fit-out",
    startDate: "2026-07-20",
    budget: 60000,
    createdAt: "2026-07-20T00:00:00.000Z",
    updatedAt: "2026-07-20T00:00:00.000Z",
  },
];

const CATEGORIES: ExpenseCategory[] = [
  { id: "cat_materials", code: "MAT", name: "Materials" },
  { id: "cat_labor", code: "LAB", name: "Labor" },
  { id: "cat_transport", code: "TRN", name: "Transport" },
  { id: "cat_equipment", code: "EQP", name: "Equipment Rental" },
  { id: "cat_fuel", code: "FUEL", name: "Fuel" },
  { id: "cat_subcontractor", code: "SUB", name: "Subcontractor" },
  { id: "cat_misc", code: "MISC", name: "Miscellaneous" },
];

interface SeedAdvanceInput {
  id: string;
  date: string;
  fundingSourceType: AdvanceTransaction["fundingSourceType"];
  fundingSourceId: string;
  custodianId: string;
  amount: number;
  projectId?: string;
  reference: string;
}

const ADVANCES_SEED: SeedAdvanceInput[] = [
  {
    id: "adv_001",
    date: "2026-06-05",
    fundingSourceType: "OWNER_CURRENT",
    fundingSourceId: "owner_rahim",
    custodianId: "custodian_bareq",
    amount: 20000,
    reference: "Initial custody funding",
  },
  {
    id: "adv_002",
    date: "2026-07-01",
    fundingSourceType: "TREASURY",
    fundingSourceId: "treasury_main_bank",
    custodianId: "custodian_bareq",
    amount: 15000,
    reference: "Top-up funding from Main Bank",
  },
  {
    id: "adv_003",
    date: "2026-07-10",
    fundingSourceType: "OWNER_CURRENT",
    fundingSourceId: "owner_majid",
    custodianId: "custodian_sobhi",
    projectId: "proj_alzorah",
    amount: 10000,
    reference: "Custody funding for Al Zorah",
  },
];

interface SeedExpenseInput {
  id: string;
  date: string;
  projectId?: string;
  supplierId?: string;
  categoryId: string;
  description: string;
  invoiceNumber?: string;
  netAmount: number;
  vatMode: "ZERO" | "MANUAL" | "AUTO_5";
  manualVat?: number;
  paidFromType: ExpenseTransaction["paidFromType"];
  paidFromPartyId?: string;
  paymentMethod: ExpenseTransaction["paymentMethod"];
  hasInvoice: boolean;
}

const EXPENSES_SEED: SeedExpenseInput[] = [
  {
    id: "exp_001",
    date: "2026-06-08",
    projectId: "proj_alnakhil",
    supplierId: "sup_noor_building",
    categoryId: "cat_materials",
    description: "Cement & blocks - Noor Building Materials",
    invoiceNumber: "INV-1001",
    netAmount: 8000,
    vatMode: "AUTO_5",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_002",
    date: "2026-06-15",
    projectId: "proj_alnakhil",
    categoryId: "cat_labor",
    description: "Daily labor wages",
    netAmount: 3500,
    vatMode: "ZERO",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: false,
  },
  {
    id: "exp_003",
    date: "2026-06-20",
    projectId: "proj_alnakhil",
    supplierId: "sup_qasim_transport",
    categoryId: "cat_transport",
    description: "Material transport - Qasim Transport",
    invoiceNumber: "INV-Q-220",
    netAmount: 1200,
    vatMode: "MANUAL",
    manualVat: 60,
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_004",
    date: "2026-06-25",
    projectId: "proj_alnakhil",
    categoryId: "cat_equipment",
    description: "Scaffolding rental",
    invoiceNumber: "EQ-77",
    netAmount: 2500,
    vatMode: "AUTO_5",
    paidFromType: "OWNER",
    paidFromPartyId: "owner_rahim",
    paymentMethod: "TRANSFER",
    hasInvoice: true,
  },
  {
    id: "exp_005",
    date: "2026-07-02",
    projectId: "proj_alnakhil",
    supplierId: "sup_media_general",
    categoryId: "cat_materials",
    description: "Steel purchase (credit) - Media General Trading",
    invoiceNumber: "MGT-3391",
    netAmount: 12000,
    vatMode: "AUTO_5",
    paidFromType: "SUPPLIER_CREDIT",
    paymentMethod: "OTHER",
    hasInvoice: true,
  },
  {
    id: "exp_006",
    date: "2026-07-05",
    projectId: "proj_alzorah",
    supplierId: "sup_noor_building",
    categoryId: "cat_materials",
    description: "Building materials - Noor Building Materials",
    invoiceNumber: "NBM-552",
    netAmount: 6000,
    vatMode: "AUTO_5",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_007",
    date: "2026-07-12",
    projectId: "proj_alzorah",
    categoryId: "cat_labor",
    description: "Site labor",
    netAmount: 2800,
    vatMode: "ZERO",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_sobhi",
    paymentMethod: "CASH",
    hasInvoice: false,
  },
  {
    id: "exp_008",
    date: "2026-07-18",
    projectId: "proj_alzorah",
    categoryId: "cat_fuel",
    description: "Diesel for site generator",
    netAmount: 450,
    vatMode: "ZERO",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_sobhi",
    paymentMethod: "CASH",
    hasInvoice: false,
  },
  {
    id: "exp_009",
    date: "2026-07-22",
    projectId: "proj_alzorah",
    supplierId: "sup_colors_lake",
    categoryId: "cat_misc",
    description: "Paints & finishing supplies - Colors Lake",
    invoiceNumber: "CL-90",
    netAmount: 1800,
    vatMode: "AUTO_5",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_010",
    date: "2026-07-28",
    projectId: "proj_alzorah",
    categoryId: "cat_equipment",
    description: "Excavator rental (vehicle/equipment expense)",
    invoiceNumber: "EQ-201",
    netAmount: 5000,
    vatMode: "MANUAL",
    manualVat: 250,
    paidFromType: "OWNER",
    paidFromPartyId: "owner_majid",
    paymentMethod: "TRANSFER",
    hasInvoice: true,
  },
  {
    id: "exp_011",
    date: "2026-08-01",
    projectId: "proj_ajman",
    categoryId: "cat_materials",
    description: "Office fit-out materials",
    invoiceNumber: "INV-AJ-10",
    netAmount: 4000,
    vatMode: "AUTO_5",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_012",
    date: "2026-08-05",
    projectId: "proj_ajman",
    supplierId: "sup_tareeq_alhayat",
    categoryId: "cat_transport",
    description: "Delivery - Tareeq Al Hayat Transport",
    netAmount: 600,
    vatMode: "ZERO",
    paidFromType: "CUSTODIAN",
    paidFromPartyId: "custodian_bareq",
    paymentMethod: "CASH",
    hasInvoice: false,
  },
  {
    id: "exp_013",
    date: "2026-08-10",
    projectId: "proj_ajman",
    categoryId: "cat_misc",
    description: "Miscellaneous office supplies",
    netAmount: 350,
    vatMode: "ZERO",
    paidFromType: "OWNER",
    paidFromPartyId: "owner_rahim",
    paymentMethod: "CASH",
    hasInvoice: false,
  },
  {
    id: "exp_014",
    date: "2026-08-12",
    categoryId: "cat_misc",
    description: "Head office admin expense",
    invoiceNumber: "ADM-5",
    netAmount: 900,
    vatMode: "AUTO_5",
    paidFromType: "CASH",
    paymentMethod: "CASH",
    hasInvoice: true,
  },
  {
    id: "exp_015",
    date: "2026-08-15",
    projectId: "proj_alzorah",
    categoryId: "cat_subcontractor",
    description: "Partial subcontractor payment - direct bank transfer",
    invoiceNumber: "SUB-9",
    netAmount: 3000,
    vatMode: "ZERO",
    paidFromType: "BANK",
    paymentMethod: "BANK",
    hasInvoice: true,
  },
];

// ----------------------------------------------------------------------------
// Phase 2A demo data — subcontracts, one mobilization advance, three
// certificates (one DRAFT, two APPROVED — covering retention, advance
// recovery, and a mapped deduction), and one partial certificate payment.
// ----------------------------------------------------------------------------

const SUBCONTRACTS_SEED: Subcontract[] = [
  {
    id: "contract_alfalah_nakhil",
    projectId: "proj_alnakhil",
    subcontractorId: "sub_alfalah_mep",
    contractNumber: "SC-AN-01",
    scopeOfWork: "Full MEP installation (electrical, HVAC, plumbing) for the residential tower",
    originalContractValue: 150000,
    approvedVariations: 5000,
    retentionPercent: 10,
    startDate: "2026-06-10",
    status: "ACTIVE",
  },
  {
    id: "contract_gulfsteel_alzorah",
    projectId: "proj_alzorah",
    subcontractorId: "sub_gulf_steel",
    contractNumber: "SC-AZ-01",
    scopeOfWork: "Structural steel fabrication and erection",
    originalContractValue: 90000,
    approvedVariations: 0,
    retentionPercent: 5,
    startDate: "2026-07-15",
    status: "ACTIVE",
  },
];

const SUBCONTRACTOR_ADVANCES_SEED: SubcontractorAdvance[] = [
  {
    id: "subadv_001",
    contractId: "contract_alfalah_nakhil",
    date: "2026-06-20",
    amount: 20000,
    paymentSourceType: "BANK",
    paymentMethod: "TRANSFER",
    reference: "Mobilization advance",
  },
];

interface SeedCertificateInput {
  id: string;
  certificateNumber: string;
  certificateDate: string;
  contractId: string;
  workValueToDate: number;
  previousCertifiedWork: number;
  currentVariationAmount: number;
  retentionPercent: number;
  advanceRecovery: number;
  deductionLines: SubcontractorCertificate["deductionLines"];
  vatMode: SubcontractorCertificate["vatMode"];
  manualVat?: number;
  taxInvoiceReceived: boolean;
  taxInvoiceNumber?: string;
  taxInvoiceDate?: string;
  status: "DRAFT" | "APPROVED";
  approvedAt?: string;
}

const CERTIFICATES_SEED: SeedCertificateInput[] = [
  {
    id: "cert_001",
    certificateNumber: "PC-AN-01-01",
    certificateDate: "2026-07-20",
    contractId: "contract_alfalah_nakhil",
    workValueToDate: 60000,
    previousCertifiedWork: 0,
    currentVariationAmount: 0,
    retentionPercent: 10,
    advanceRecovery: 10000,
    deductionLines: [],
    vatMode: "AUTO_5",
    taxInvoiceReceived: true,
    taxInvoiceNumber: "TINV-AF-001",
    taxInvoiceDate: "2026-07-21",
    status: "APPROVED",
    approvedAt: "2026-07-22",
  },
  {
    id: "cert_002",
    certificateNumber: "PC-AZ-01-01",
    certificateDate: "2026-08-18",
    contractId: "contract_gulfsteel_alzorah",
    workValueToDate: 25000,
    previousCertifiedWork: 0,
    currentVariationAmount: 0,
    retentionPercent: 5,
    advanceRecovery: 0,
    deductionLines: [],
    vatMode: "ZERO",
    taxInvoiceReceived: false,
    status: "DRAFT",
  },
  {
    id: "cert_003",
    certificateNumber: "PC-AN-01-02",
    certificateDate: "2026-08-15",
    contractId: "contract_alfalah_nakhil",
    workValueToDate: 95000,
    previousCertifiedWork: 60000,
    currentVariationAmount: 0,
    retentionPercent: 10,
    advanceRecovery: 5000,
    deductionLines: [
      {
        id: "ded_001",
        description: "Cement supplied by company (20 bags)",
        amount: 1500,
        type: "COMPANY_MATERIALS",
        accountId: ACCOUNTS.DEDUCTION_COMPANY_MATERIALS,
      },
    ],
    vatMode: "AUTO_5",
    taxInvoiceReceived: true,
    taxInvoiceNumber: "TINV-AF-002",
    taxInvoiceDate: "2026-08-16",
    status: "APPROVED",
    approvedAt: "2026-08-17",
  },
];

const SUBCONTRACTOR_PAYMENTS_SEED: SubcontractorPaymentTransaction[] = [
  {
    id: "subpay_001",
    date: "2026-08-01",
    subcontractorId: "sub_alfalah_mep",
    certificateId: "cert_001",
    contractId: "contract_alfalah_nakhil",
    amount: 20000,
    sourceType: "BANK",
    reference: "Partial certificate payment",
  },
];

let seedCounter = 0;
function seedJournalId(): string {
  seedCounter += 1;
  return `je_seed_${String(seedCounter).padStart(3, "0")}`;
}

let phase2ASeedCounter = 0;
function phase2ASeedJournalId(): string {
  phase2ASeedCounter += 1;
  return `je_seed_p2a_${String(phase2ASeedCounter).padStart(3, "0")}`;
}

/** Loads the demo dataset unconditionally, overwriting whatever is currently stored. */
function seedDemoData(): void {
  seedCounter = 0;

  db.companies.replaceAll([COMPANY]);
  db.parties.replaceAll([...PARTIES, ...SUBCONTRACTOR_PARTIES]);
  db.projects.replaceAll(PROJECTS);
  db.categories.replaceAll(CATEGORIES);
  db.accounts.replaceAll([...CHART_OF_ACCOUNTS, ...TREASURY_GL_ACCOUNTS]);
  db.treasuryAccounts.replaceAll(TREASURY_ACCOUNTS);

  const treasuryById = Object.fromEntries(TREASURY_ACCOUNTS.map((t) => [t.id, t]));

  const advances: AdvanceTransaction[] = [];
  const expenses: ExpenseTransaction[] = [];
  const journalEntries = [];

  for (const a of ADVANCES_SEED) {
    const advance: AdvanceTransaction = {
      id: a.id,
      date: a.date,
      fundingSourceType: a.fundingSourceType,
      fundingSourceId: a.fundingSourceId,
      custodianId: a.custodianId,
      amount: a.amount,
      projectId: a.projectId,
      paymentMethod: "TRANSFER",
      reference: a.reference,
    };
    advances.push(advance);
    const resolved =
      a.fundingSourceType === "TREASURY"
        ? { glAccountId: treasuryById[a.fundingSourceId]?.glAccountId ?? ACCOUNTS.BANK }
        : { glAccountId: ACCOUNTS.OWNER_CURRENT, partyId: a.fundingSourceId };
    journalEntries.push(postAdvance(advance, resolved, seedJournalId(), `ADV-${a.id.slice(-3)}`));
  }

  for (const e of EXPENSES_SEED) {
    const vat = calcVat({ netAmount: e.netAmount, vatMode: e.vatMode, manualVatAmount: e.manualVat });
    const expense: ExpenseTransaction = {
      id: e.id,
      date: e.date,
      projectId: e.projectId,
      supplierId: e.supplierId,
      categoryId: e.categoryId,
      description: e.description,
      invoiceNumber: e.invoiceNumber,
      netAmount: vat.netAmount,
      vatAmount: vat.vatAmount,
      totalAmount: vat.totalAmount,
      paidFromType: e.paidFromType,
      paidFromPartyId: e.paidFromPartyId,
      paymentMethod: e.paymentMethod,
      hasInvoice: e.hasInvoice,
      status: "POSTED",
    };
    expenses.push(expense);
    const resolved =
      e.paidFromType === "CUSTODIAN"
        ? { glAccountId: ACCOUNTS.ADVANCE_CUSTODY, partyId: e.paidFromPartyId }
        : e.paidFromType === "OWNER"
          ? { glAccountId: ACCOUNTS.OWNER_CURRENT, partyId: e.paidFromPartyId }
          : undefined;
    journalEntries.push(postExpense(expense, resolved, seedJournalId(), `EXP-${e.id.slice(-3)}`));
  }

  db.advances.replaceAll(advances);
  db.expenses.replaceAll(expenses);
  db.journalEntries.replaceAll(journalEntries);

  seedPhase2ADemoData();
}

/**
 * Seeds the Phase 2A subcontractor demo data (contracts, one mobilization
 * advance, three certificates, one partial payment). Journal entries are
 * appended (create), never replaceAll'd, because this must be safe to call
 * both right after a fresh seedDemoData() and on top of an existing Phase 1
 * install's real journal history — see ensurePhase2ASeeded().
 */
function seedPhase2ADemoData(): void {
  phase2ASeedCounter = 0;

  db.subcontracts.replaceAll(SUBCONTRACTS_SEED);

  const contractsById = Object.fromEntries(SUBCONTRACTS_SEED.map((c) => [c.id, c]));

  const advances: SubcontractorAdvance[] = [];
  for (const a of SUBCONTRACTOR_ADVANCES_SEED) {
    const contract = contractsById[a.contractId];
    advances.push(a);
    db.journalEntries.create(
      postSubcontractorAdvance(
        a,
        contract.subcontractorId,
        contract.projectId,
        undefined, // legacy "BANK" seed value — posts directly, no resolution needed
        phase2ASeedJournalId(),
        `SADV-${a.id.slice(-3)}`,
      ),
    );
  }
  db.subcontractorAdvances.replaceAll(advances);

  const certificates: SubcontractorCertificate[] = [];
  for (const c of CERTIFICATES_SEED) {
    const contract = contractsById[c.contractId];
    const calc = calcCertificate({
      workValueToDate: c.workValueToDate,
      previousCertifiedWork: c.previousCertifiedWork,
      currentVariationAmount: c.currentVariationAmount,
      retentionPercent: c.retentionPercent,
      advanceRecovery: c.advanceRecovery,
      deductionAmounts: c.deductionLines.map((d) => d.amount),
      vatMode: c.vatMode,
      manualVatAmount: c.manualVat,
    });
    const certificate: SubcontractorCertificate = {
      id: c.id,
      certificateNumber: c.certificateNumber,
      certificateDate: c.certificateDate,
      contractId: c.contractId,
      projectId: contract.projectId,
      subcontractorId: contract.subcontractorId,
      workValueToDate: c.workValueToDate,
      previousCertifiedWork: c.previousCertifiedWork,
      currentWorkValue: calc.currentWorkValue,
      currentVariationAmount: c.currentVariationAmount,
      grossCurrentValue: calc.grossCurrentValue,
      retentionPercent: c.retentionPercent,
      retentionAmount: calc.retentionAmount,
      advanceRecovery: c.advanceRecovery,
      deductionLines: c.deductionLines,
      vatMode: c.vatMode,
      vatAmount: calc.vatAmount,
      taxInvoiceReceived: c.taxInvoiceReceived,
      taxInvoiceNumber: c.taxInvoiceNumber,
      taxInvoiceDate: c.taxInvoiceDate,
      netBeforeVat: calc.netBeforeVat,
      netPayable: calc.netPayable,
      status: c.status,
      approvedAt: c.approvedAt,
    };

    if (c.status === "APPROVED") {
      const journalId = phase2ASeedJournalId();
      const entry = postCertificateApproval(certificate, journalId, `CERT-${c.id.slice(-3)}`);
      db.journalEntries.create(entry);
      certificate.journalEntryId = journalId;
    }

    certificates.push(certificate);
  }

  const payments: SubcontractorPaymentTransaction[] = [];
  for (const p of SUBCONTRACTOR_PAYMENTS_SEED) {
    payments.push(p);
    const projectId = p.contractId ? contractsById[p.contractId]?.projectId : undefined;
    db.journalEntries.create(
      // legacy "BANK" seed value — posts directly, no resolution needed
      postSubcontractorPayment(p, projectId, undefined, phase2ASeedJournalId(), `SPAY-${p.id.slice(-3)}`),
    );
  }
  db.subcontractorPayments.replaceAll(payments);

  // Certificate payment status reflects payments already seeded above.
  const withStatus = certificates.map((cert) => {
    if (cert.status !== "APPROVED") return cert;
    const paid = payments
      .filter((p) => p.certificateId === cert.id)
      .reduce((sum, p) => sum + p.amount, 0);
    if (paid <= 0) return cert;
    return { ...cert, status: paid >= cert.netPayable - 0.01 ? "PAID" : "PARTIALLY_PAID" } as SubcontractorCertificate;
  });
  db.subcontractorCertificates.replaceAll(withStatus);

  db.custodySettlements.replaceAll([]);
}

/**
 * Additive migration for existing Phase 1 installs: adds the Phase 2A chart
 * of accounts, the two demo subcontractor parties, and the subcontractor
 * demo dataset — without touching any real project/expense/party data
 * already in the user's browser. Gated on subcontracts being empty, so it
 * runs at most once per browser profile.
 */
export function ensurePhase2ASeeded(): void {
  if (!db.subcontracts.isEmpty()) return;

  const existingAccountIds = new Set(db.accounts.getAll().map((a) => a.id));
  for (const account of CHART_OF_ACCOUNTS) {
    if (!existingAccountIds.has(account.id)) db.accounts.create(account);
  }

  const existingPartyIds = new Set(db.parties.getAll().map((p) => p.id));
  for (const party of SUBCONTRACTOR_PARTIES) {
    if (!existingPartyIds.has(party.id)) db.parties.create(party);
  }

  seedPhase2ADemoData();
}

/** Loads the demo dataset on first run only — leaves real data untouched on later visits. */
export function ensureSeeded(): void {
  if (!isDatabaseEmpty()) return;
  seedDemoData();
}

/** Wipes all stored data and reloads the demo dataset (base + Phase 2A). Used by "Reset Demo Data". */
export function resetDemoData(): void {
  clearAll();
  seedDemoData();
}
