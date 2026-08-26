# Maker Contracting Accounting System — Project Handoff

**Read this file and `PROJECT_ROADMAP.md` fully before writing any code.** This file is the complete orientation for a new Claude/AI/developer session. It should be enough, on its own, to understand what the system is, why it exists, what's actually implemented, what's known-incomplete, and what to do next.

Repository: `https://github.com/n7rawy1984/MkaerACC` · Local path: `/media/nagham/msn4ever/www.downloadly.ir/Maker`

---

## 1. Project Summary

**Maker Contracting Accounting System** — a purpose-built accounting system for a small/medium UAE contracting company, replacing a set of disconnected Excel/PDF records. It is not a generic expense tracker: it exists to model real contracting-industry accounting — project cost centers, custodian cash advances and settlements, supplier payables, subcontractor progress certificates and retention, and eventually payroll/WPS, client contracts, and financial statements.

## 2. Business Context

The company previously tracked project expenses, supplier bills, cash handed to custodians (Bareq, Sobhi), owner-paid costs, and subcontractor activity across disconnected spreadsheets for projects including Al Nakhil Building, Al Zorah, and Ajman Office. Historical 2025/2026 data exists and will eventually be imported (now Phase 2E) — through a staging/review process, never a direct dump into the live ledger. Owners are A. Rahim and Majid; Bareq is Manager/Custodian; Sobhi is Custodian.

## 3. Current Status

- **Phase 1 (Core Accounting MVP)** — Completed.
- **Phase 2A (Custody Settlements + Subcontractor Certificates)** — Completed.
- **Phase 2B.1 (Project Core + Company + Treasury Foundation)** — Completed.
- **Phase 2B.1A (Treasury Integration & Project Guard Completion)** — Completed.
- **Phase 2B.2 (Subcontractor Operationalization)** — Completed.
- **Phase 2B.3 (Arabic / English Foundation & Completion)** — Completed.
- **Phase 2C / P0 (Production Architecture Freeze)** — Completed as documentation/decision work only. No backend capability was implemented.
- **Phase 2C / P1 (Supabase Environments + Migration Foundation)** — Completed and repository-verified; no remote project or business schema was created.
- **Phase 2C / P2 (Auth, Profiles, Memberships and Roles)** — Not started. This is the immediate next implementation task.
- **Payroll + WPS** — Confirmed next functional module after Production Data Foundation.

See `PROJECT_ROADMAP.md` for the full phase breakdown, binding decisions, and decision log.

## 4. Technology Stack (verified from `package.json`)

- React 19, TypeScript ~6.0, Vite 8
- Tailwind CSS 4 (via `@tailwindcss/postcss`)
- React Router 7 (`react-router-dom`)
- Recharts 3 (Dashboard charts only)
- lucide-react (icons)
- `oxlint` for linting
- **Supabase CLI/migration foundation now exists, but there is still no running backend, authentication, remote project, or production schema.** Application persistence remains `localStorage`. The current abstraction helps isolate persistence but is not a drop-in production adapter (see Production Data Foundation Architecture below).

## 5. Repository Structure

```
src/
  domain/          # Pure types and money math — no React, no storage
    types.ts        # All domain models (Project, Party, Expense, Advance, Journal, Phase 2A models…)
    money.ts         # Decimal-safe helpers: toCents/fromCents/round2/addMoney/subtractMoney/calcVat/formatAED
    utils.ts         # indexById, formatDate
  accounting/       # The posting engine and all balance/query logic — the accounting "brain"
    chartOfAccounts.ts   # ACCOUNTS map + CHART_OF_ACCOUNTS seed list
    postingEngine.ts      # post* functions — the ONLY place journal entries are constructed
    ledger.ts             # Balance/aggregate queries over journal entries (read-only, pure)
    certificateCalc.ts    # Subcontractor certificate waterfall math + validation guards
  storage/          # Persistence abstraction
    storageDriver.ts      # LocalStorageDriver (StorageDriver interface)
    repository.ts          # Generic Repository<T> (CRUD over a StorageDriver)
    database.ts             # db = { projects, parties, expenses, treasuryAccounts, ... } — all repositories wired up
    migrations.ts            # ensurePhase2B1Migrated() + ensurePhase2B1AMigrated() (dedicated per-treasury GL accounts) + ensurePhase2B2Migrated() (Party.status backfill + contract-dimension backfill on historical journal lines) — all idempotent
  state/
    AppDataContext.tsx    # React context: loads all repos into state, exposes add*/update*/approve*/finalize* actions
  seed/
    seedData.ts            # Demo/seed dataset + ensureSeeded() + ensurePhase2ASeeded() + resetDemoData()
  i18n/             # Translation dictionaries + locale/RTL context — Phase 2B.3
    en.ts                   # English dictionary, source of the TranslationKey type
    ar.ts                    # Arabic dictionary, typed against TranslationKey (build fails if a key is missing)
    I18nContext.tsx           # I18nProvider, useI18n(), useT() — locale state, localStorage persistence, dir/lang side effect
  pages/            # One file per route (see §6 routing) — includes Companies.tsx, Treasury.tsx since Phase 2B.1; SubcontractorDetail.tsx since Phase 2B.2
  components/       # Forms and shared UI (components/ui/ for primitives) — includes ProjectForm, CompanyForm, TreasuryAccountForm since Phase 2B.1; SubcontractorForm, SubcontractForm since Phase 2B.2
  App.tsx            # Route table
  main.tsx            # Entry point, wraps App in I18nProvider + BrowserRouter
supabase/
  config.toml         # Official local CLI configuration; automatic DB seeding disabled
  migrations/        # One canonical forward-only migration history for Dev → Staging → Production
```

`vercel.json` (repo root, Phase 2B.3): SPA rewrite (`/(.*) → /index.html`) so a direct load or refresh of any client-side route works on Vercel's static hosting.

## 6. Important Files

| File | Why it matters |
|---|---|
| `src/domain/types.ts` | Every domain model. Read this first to know what exists. |
| `src/domain/money.ts` | All money math MUST go through here — never raw float arithmetic on currency. |
| `src/accounting/postingEngine.ts` | Every journal entry in the system is built by one of the `post*` functions here. `isBalanced`/`UnbalancedJournalError` enforce balance. |
| `src/accounting/ledger.ts` | Every balance shown anywhere in the UI (custodian balance, supplier payable, project cost, subcontractor retention…) is derived here from journal entries — never stored/cached as a mutable number. |
| `src/accounting/chartOfAccounts.ts` | The fixed GL account list. Party-specific sub-balances are carried via `JournalLine.partyId`, not by minting one account per party. |
| `src/storage/database.ts` | `db` — the single object exposing every repository. `isDatabaseEmpty()`, `clearAll()`. |
| `src/storage/migrations.ts` | `ensurePhase2B1Migrated()` — backward-compatible patcher for pre-2B.1 `Company`/`Project`/`AdvanceTransaction` records and the one-time `TreasuryAccount` seed. `ensurePhase2B1AMigrated()` — mints each pre-2B.1A treasury account its own dedicated GL account. `ensurePhase2B2Migrated()` — backfills `Party.status`, backfills `SubcontractorPaymentTransaction.contractId` from its certificate, and backfills the `contractId` dimension onto historical subcontractor-related journal lines wherever their source document resolves it with certainty. All idempotent; none ever rewrite a `JournalEntry`'s debit/credit amounts. |
| `src/state/AppDataContext.tsx` | The only place UI code touches `db` and `post*` together — every `add*`/`update*`/`approve*`/`finalize*` action here loads data, calls a posting function, persists, and refreshes React state. |
| `src/seed/seedData.ts` | Demo data + the seed entry points (`ensureSeeded`, `ensurePhase2ASeeded`) + `resetDemoData`. |
| `src/App.tsx` | Route table — the authoritative list of what pages exist. |
| `src/components/layout/Sidebar.tsx` | The authoritative nav list, the "Reset Demo Data" action, and (Phase 2B.3) the EN/عربي language toggle. |
| `src/i18n/en.ts` / `src/i18n/ar.ts` | Every UI string in the app, keyed identically in both files (TypeScript enforces this). New UI text always adds a key here first, in both files, never inline English. |
| `src/i18n/I18nContext.tsx` | `useT()` — the hook every page/component calls for translated strings; also owns locale persistence and the RTL `dir` side effect. |
| `supabase/config.toml` | P1 CLI/local configuration. No remote project identity or credential is committed. |
| `supabase/migrations/` | Canonical versioned SQL history. P1 contains only a schema-free foundation migration. |
| `.env.example` | Public placeholder convention only; explicitly warns that every `VITE_*` value is browser-visible. |
| `README.md` | Exact frontend and database migration workflow, environment promotion, secrets, and seed rules. |

Routes (from `App.tsx`): `/` (Dashboard), `/company`, `/projects`, `/projects/:id`, `/treasury`, `/expenses`, `/advances`, `/suppliers`, `/subcontractors` (subcontractor master list), `/subcontractors/:id` (subcontractor profile — **Phase 2B.2, new**), `/subcontracts/:id` (contract workspace — **Phase 2B.2, moved from `/subcontractors/:id`**), `/people` (Owners & Custodians), `/journal`.

## 7. Domain Model (verified from `src/domain/types.ts`)

**Phase 1 models**: `Party` (`id, name, type, phone?, taxRegistrationNumber?, contactPerson?, notes?`; `PartyType = OWNER|CUSTODIAN|SUPPLIER|EMPLOYEE|SUBCONTRACTOR|OTHER`), `ExpenseCategory`, `Account`, `ExpenseTransaction`, `SupplierPaymentTransaction`, `JournalEntry`/`JournalLine`.

**Phase 2A models**: `CustodySettlement` (DRAFT/SETTLED, `selectedExpenseIds`, cash-return fields), `Subcontract` (`originalContractValue, approvedVariations, retentionPercent` — revised value is *computed*, never stored), `SubcontractorAdvance`, `SubcontractorCertificate` (full waterfall fields — see §11), `CertificateDeduction`, `SubcontractorPaymentTransaction`.

**Phase 2B.2 model additions** (see §11 for the full accounting picture):
- `Party` gained `code?, email?, address?, status? (PartyStatus = ACTIVE|INACTIVE)`. Generic on every party type (not duplicated per type); `status: undefined` is treated as `ACTIVE` everywhere and gets explicitly backfilled by `ensurePhase2B2Migrated()`. Only the Subcontractor UI currently exposes `status` as an editable field.
- `JournalLine` gained `contractId?: ID` — an additive dimension alongside `partyId`/`projectId`, set on every line a subcontractor-related posting function produces. Absent on every non-subcontractor line.
- `SubcontractorPaymentTransaction` gained `contractId?: ID` — always set going forward (derived from `certificate.contractId` at creation time in `addSubcontractorPayment`); optional only so pre-2B.2 records without a resolvable contract link stay valid.
- No new fields were added to `Subcontract` itself — every field Phase 2B.2's New/Edit Subcontract form needed (`contractNumber, scopeOfWork, originalContractValue, approvedVariations, retentionPercent, startDate, endDate, status, notes`) already existed from Phase 2A.

**Phase 2B.1 models**:
- `Company`: `id, code, name, legalName?, trn?, address?, status (ACTIVE|INACTIVE), notes?, createdAt, updatedAt`.
- `Project`: `id, code, name, companyId, status, location?, client?, contractNumber?, originalContractValue?, startDate?, expectedCompletionDate?, budget?, notes?, dedicatedBankAccountId?, dedicatedCashBoxId?, createdAt, updatedAt`. `ProjectStatus = PLANNING|ACTIVE|ON_HOLD|COMPLETED|CLOSED`. Note: the field is `code`, not `projectCode` — kept the Phase 1 name, see Decision Log.
- `TreasuryAccount`: `id, companyId, projectId?, code, name, type (CASH|PETTY_CASH|BANK|PROJECT_CASH_BOX|PROJECT_BANK), glAccountId, status (ACTIVE|INACTIVE), bankName?, accountReference?, notes?, createdAt, updatedAt`. As of Phase 2B.1A, `glAccountId` points to a **dedicated** `Account` minted for this specific treasury account (not a shared pooled one) — see §8.
- `AdvanceTransaction` (reworked): `id, date, custodianId, amount, projectId?, fundingSourceType ("TREASURY"|"OWNER_CURRENT"), fundingSourceId, paymentMethod, reference?, notes?`. The old `fromPartyId` field is gone.

**Phase 2B.1A additions**: `ExpenseTransaction`, `SupplierPaymentTransaction`, `SubcontractorAdvance`, and `SubcontractorPaymentTransaction` each gained an optional `treasuryAccountId?: ID`, set only when their type/sourceType is `"TREASURY"`. `CustodySettlement` gained `cashReturnTreasuryAccountId?: ID`, same rule. Every one of these type unions (`PaidFromType`, `SupplierPaymentSourceType`, `SubcontractorFundingSourceType`, `SubcontractorPaymentSourceType`, `CashReturnDestinationType`) now includes `"TREASURY"` plus its original members — `"CASH"`/`"BANK"` remain in each union as **legacy-only** values (never produced by any form after this phase, but still valid/postable so historical records keep working). See §9 for exactly how `treasuryAccountId` resolves during posting.

`ExpenseTransaction.advanceId?` — optional, purely informational link to a specific `AdvanceTransaction`; the custodian's real balance is always the pooled total across all their advances, never per-advance.

## 8. Chart of Accounts / Accounting Architecture

Fixed GL accounts (`src/accounting/chartOfAccounts.ts`):

| Code | Account | Type | Party-scoped? |
|---|---|---|---|
| 1000 | Cash on Hand | ASSET | |
| 1100 | Bank Account | ASSET | |
| 1200 | Advance / Custody Account | ASSET | ✓ |
| 1210 | Subcontractor Advance | ASSET | ✓ |
| 1300 | Input VAT Recoverable | ASSET | |
| 2100 | Accounts Payable - Suppliers | LIABILITY | ✓ |
| 2110 | Subcontractor Retention Payable | LIABILITY | ✓ |
| 2120 | Subcontractor Accounts Payable | LIABILITY | ✓ |
| 2200 | Owner Current Account | LIABILITY | ✓ |
| 4100/4110/4120 | Recovery - Company Materials / Backcharges / Other | INCOME | |
| 5000 | Project Costs | EXPENSE | |
| 5010 | Project Cost - Subcontractors | EXPENSE | |
| 5100 | Company Expenses | EXPENSE | |

Party-scoped accounts don't get one GL account per party — they carry `partyId` on the `JournalLine`; per-party balances are derived on read (`ledger.ts`). This keeps the chart of accounts small while still supporting full sub-ledgers.

**Treasury accounts (Phase 2B.1A) each get their own dedicated GL account.** Creating a treasury account (`addTreasuryAccount` in `state/AppDataContext.tsx`, via `createTreasuryGlAccount()`) mints a brand-new `Account` under the cash family (`1000 Cash on Hand`, for types `CASH`/`PETTY_CASH`/`PROJECT_CASH_BOX`) or the bank family (`1100 Bank Account`, for types `BANK`/`PROJECT_BANK`), with a sequential code like `1000-001 Main Cash`, `1000-002 Petty Cash`, `1100-001 Main Bank`. That new account's id becomes the treasury account's `glAccountId`, permanently — `updateTreasuryAccount` never touches it, even if the treasury account's name/type/company changes later. `accounting/ledger.ts: treasuryAccountBalance(entries, glAccountId)` computes a live, journal-derived balance for one treasury account (debit-normal, like any asset) — the Treasury screen (`pages/Treasury.tsx`) shows this per row, never a cached number.

**Legacy pooled `1000`/`1100` GL accounts are retained forever, untouched.** Every transaction posted before a treasury account got its dedicated GL account (either before Phase 2B.1A shipped, or before an existing browser install's one-time `ensurePhase2B1AMigrated()` migration ran) stays posted against the shared pooled account exactly as it was. This means: a treasury account's balance is only fully accurate for activity from that migration point forward. Fresh installs / "Reset Demo Data" don't have this caveat — `seed/seedData.ts` seeds `TREASURY_GL_ACCOUNTS` (three dedicated accounts, fixed ids) from the very first boot, so even the demo data's Main Bank / Petty Cash figures are individually accurate.

**Persistence architecture**: `StorageDriver` (interface) → `LocalStorageDriver` → synchronous, cached, collection-wide `Repository<T>` → `db`. This is useful isolation for demo storage, but it cannot simply be replaced by Supabase: network access is asynchronous; production reads must be scoped/paginated; and accounting writes require multi-table database transactions. `AppDataContext` currently combines validation, ID generation, posting and several sequential repository writes, so it must be split into async queries and atomic domain commands. Pure calculators and posting rules can remain client/domain-side as previews and executable specifications, but PostgreSQL is authoritative.

## 9. Implemented Accounting Flows

Money math always goes through `domain/money.ts` (`toCents`/`fromCents`/`addMoney`/`subtractMoney`/`round2`/`calcVat`) — journal balance is checked in integer cents (`postingEngine.ts: isBalanced`).

**Centralized funding-source resolution (Phase 2B.1A).** Six flows below (Advance, Expense, Supplier Payment, Subcontractor Advance, Subcontractor Payment, Custody Cash Return) all need to turn a user's pick — a treasury account, a custodian, or an owner — into a GL account (and party, if the account is party-scoped) to actually post against. Instead of five copies of the same lookup, `state/AppDataContext.tsx` has one `resolveFundingSource(type, id, ctx)` helper (`type` is `"TREASURY" | "OWNER_CURRENT" | "CUSTODIAN"`) that: looks up the treasury account or party, checks it's active, and — for treasury accounts — checks it belongs to the transaction's project (if the account is project-specific) and to the same company as the transaction's project (if one is selected). It returns a small `ResolvedFundingSource = { glAccountId, partyId? }` (defined in `accounting/postingEngine.ts`) that every `post*` function below takes as a parameter — the posting engine itself never imports `db` or does any lookup; it just builds the line. `CUSTODIAN`/`OWNER` legacy-shaped call sites and the new `TREASURY` option both flow through the exact same resolver.

### Custodian funding (`postAdvance`)
```
Dr Advance/Custody Account (custodian, project dimension)
Cr [resolved.glAccountId] (resolved.partyId if party-scoped)
```
`resolveFundingSource("OWNER_CURRENT", ...)` → `ACCOUNTS.OWNER_CURRENT`, party-scoped to the owner. `resolveFundingSource("TREASURY", ...)` → that treasury account's own dedicated GL account (see §8), not party-scoped. Project is a dimension on both lines in every case — the credited account itself is never a project. The Advance form (`components/AdvanceForm.tsx`) presents a single grouped "Funding Source" `<select>` — a "Treasury" group (active, project/company-eligible treasury accounts) and an "Owners" group (dynamic list of `OWNER` parties).

### Custodian-paid / Owner-paid / Treasury-paid expense (`postExpense`, `paidFromType: "CUSTODIAN" | "OWNER" | "TREASURY"`)
```
Dr Project Cost / Company Expense
Dr Input VAT (if any)
Cr [resolved.glAccountId] (resolved.partyId if party-scoped)
```
Same `resolveFundingSource()` call as Advance, keyed off `paidFromPartyId` (CUSTODIAN/OWNER) or `treasuryAccountId` (TREASURY). `CASH`/`BANK` remain as legacy-only cases in the switch, posting straight to the pooled `ACCOUNTS.CASH`/`ACCOUNTS.BANK` — kept only so a pre-2B.1A `ExpenseTransaction` (there are two in the seed data, `exp_014`/`exp_015`) still posts/re-renders correctly; the Expense form never produces them anymore.

### Supplier credit purchase (`paidFromType: "SUPPLIER_CREDIT"`)
```
Dr Project Cost / Company Expense
Dr Input VAT (if any)
Cr Accounts Payable - Suppliers
```
Unchanged by Phase 2B.1A — no funding source involved, cost goes straight to a payable.

### Supplier payment (`postSupplierPayment`)
```
Dr Accounts Payable - Suppliers
Cr [resolved.glAccountId] (resolved.partyId if party-scoped)  — TREASURY / CUSTODIAN / OWNER
   — or —
Cr Cash / Bank (pooled, legacy)                                 — CASH / BANK
```
Never re-creates project cost. Not guarded against a closed project (see §15) — settling an existing payable isn't treated as "new cost."

### Custody settlement cash return (`postCashReturn`)
Only posted when a settlement with `cashReturnAmount > 0` is finalized — grouping expenses into a settlement itself posts nothing.
```
Dr [resolved.glAccountId] (resolved.partyId if party-scoped)  — TREASURY / OWNER
   — or —
Dr Cash / Bank (pooled, legacy)                                 — CASH / BANK
Cr Advance/Custody Account (custodian)
```

### Subcontractor advance (`postSubcontractorAdvance`)
```
Dr Subcontractor Advance (subcontractor, project, contract)
Cr [resolved.glAccountId] (resolved.partyId if party-scoped; project, contract)  — TREASURY / OWNER / CUSTODIAN
   — or —
Cr Cash / Bank (pooled, legacy; project, contract)               — CASH / BANK
```
Asset, not cost, until recovered through a certificate. **Phase 2B.2**: every line also carries `contractId: advance.contractId` — `SubcontractorAdvance` already stored `contractId` from Phase 2A, so no new parameter was needed on the posting function, only the extra dimension on the lines it builds.

### Subcontractor payment (`postSubcontractorPayment`)
```
Dr Subcontractor Accounts Payable (project, contract)
Cr [resolved.glAccountId] (resolved.partyId if party-scoped; project, contract)  — TREASURY / CUSTODIAN / OWNER
   — or —
Cr Cash / Bank (pooled, legacy; project, contract)                                — CASH / BANK
```
Scoped to one `certificateId` (not pooled across a subcontractor's certificates) specifically so certificate status (`APPROVED → PARTIALLY_PAID → PAID`) can be tracked per certificate. Never touches project cost, certified amount, or retention. Not guarded against a closed project, same reasoning as Supplier payment (but **is** guarded against a `CLOSED` contract being used to create a *new* payable — see §11; the payment itself, settling an existing payable, is never blocked). **Phase 2B.2 signature change**: `postSubcontractorPayment(payment, projectId, resolved, journalId, reference)` — gained a `projectId` parameter (the certificate's project, resolved by the caller and never stored redundantly on the payment record) so the payable debit line can carry a project dimension too, which it never did before 2B.2. Every line also carries `contractId: payment.contractId`.

### Subcontractor certificate approval (`postCertificateApproval`) — DRAFT posts nothing
```
Dr Project Cost - Subcontractors           (grossCurrentValue; project, contract)
Dr Input VAT                                (vatAmount, only if valid + tax-invoice-backed; project, contract)
   Cr Subcontractor Retention Payable       (retentionAmount, if > 0; project, contract)
   Cr Subcontractor Advance                 (advanceRecovery, if > 0; project, contract)
   Cr [mapped deduction account per line]   (each CertificateDeduction; project, contract)
   Cr Subcontractor Accounts Payable        (netPayable — the balancing remainder; project, contract)
```
Approval is one-shot: `approveCertificate()` throws if `status !== "DRAFT"`. After approval, the form locks all accounting-relevant fields. **Phase 2B.2**: every line also carries `contractId: certificate.contractId` — `SubcontractorCertificate` already stored `contractId`, so (like the advance) no new parameter was needed, only the extra dimension.

## 10. Custody / Advances

Page: `pages/Advances.tsx`. Per custodian: Total Funds Received, Total Expenses Charged, Cash Returned, Current Custody Balance (all derived live from journal entries via `ledger.ts`), Open Advances count, Last Settlement Date, plus expandable Advances / Expenses Charged / Settlements sub-lists. "New Advance" (`components/AdvanceForm.tsx`) posts immediately, capturing Custodian, Project/Purpose (optional, filtered to non-`CLOSED` projects), and Funding Source (Treasury account or Owner Current Account — see §9); `addAdvance` guards against a closed project id and an inactive/missing/out-of-scope treasury account via `resolveFundingSource()` and `assertProjectAcceptsTransactions()`, throwing an error the form surfaces via `submitError`. "New Settlement" creates a DRAFT (`CustodySettlementForm`) that groups already-posted expenses — finalizing it (`finalizeCustodySettlement`) validates (expenses belong to the right custodian, not already claimed by another finalized settlement, return amount ≤ current balance) and posts only the cash-return line, if any. As of Phase 2B.1A the cash-return destination (`CashReturnDestinationType = TREASURY|OWNER|CASH|BANK`) supports picking a specific treasury account (`CustodySettlementForm`'s "Return Destination" + "Cash / Bank Account" fields); `CASH`/`BANK` remain legacy-only for pre-2B.1A finalized settlements, which were never rewritten.

## 11. Subcontractors (Phase 2A + Phase 2B.2)

**Subcontractor master** (Phase 2B.2): `Party.type === "SUBCONTRACTOR"` remains the single source of truth — no separate `Subcontractor` entity was introduced. `pages/Subcontractors.tsx` is now the **subcontractor master list** — one row per subcontractor party, showing Active Contracts, Projects, Certified To Date, Outstanding Payable, Retention Held, and Advance Balance, all live-derived (never cached) — plus a "New Subcontractor" action (`components/SubcontractorForm.tsx`). `AppDataContext.addSubcontractor`/`updateSubcontractor` validate a required name and an optional code unique among subcontractors. Subcontractors support create/edit/deactivate only — **no delete** (same pattern as Company, see Decision Log): an inactive subcontractor (`status: "INACTIVE"`) keeps its full history everywhere but can't be assigned a new contract until reactivated (enforced in `addSubcontract`/`updateSubcontract` and filtered out of the New Subcontract form's subcontractor dropdown, except the one already assigned when editing).

`pages/SubcontractorDetail.tsx` (route `/subcontractors/:id`, **new in Phase 2B.2**) is the subcontractor profile: master info, Edit Subcontractor action, the same aggregate stats as the master list row, and a list of its contracts with a "New Subcontract" action (`components/SubcontractForm.tsx`).

**Subcontract (contract) master** (Phase 2B.2): New/Edit Subcontract UI, reachable from the subcontractor profile or the contract workspace's "Edit Contract" action. `AppDataContext.addSubcontract`/`updateSubcontract` validate: project exists and isn't `CLOSED` (`assertProjectAcceptsTransactions`); subcontractor is `ACTIVE`; contract number required and unique **per project** (the smallest uniqueness rule consistent with the seed data's `SC-<PROJECT>-<SEQ>` numbering); `originalContractValue ≥ 0`; revised value (`original + approvedVariations`) can't go negative; retention 0–100. Once a contract has any accounting activity (`subcontractHasActivity()` — any advance/certificate/payment/journal line tagged with its id), `subcontractorId`/`projectId`/`contractNumber` lock, and the revised value can't be edited below work already certified (`contractCertifiedCost`); everything else (scope, dates, retention, variations, status, notes) stays editable. `deleteSubcontract` mirrors `deleteProject`: blocked once the contract has activity, allowed for a genuinely empty one.

`pages/SubcontractDetail.tsx` (route **`/subcontracts/:id`** — moved here in Phase 2B.2, was `/subcontractors/:id`) is the **Contract Workspace** — the operational home for one subcontract: master info + Edit Contract; Contract Value (Revised/Certified/Remaining); Financial Position (Advance Paid/Recovered/Balance, Retention Held, Payable Created/Outstanding); a unified chronological "Contract Activity" feed merging advances, certificates, and payments; and inline actions (New Advance, New Certificate, Record Payment). A `CLOSED` contract disables New Advance/New Certificate (data-layer guard `assertContractAcceptsTransactions()`, mirrored as disabled buttons) but leaves Record Payment reachable, mirroring the Project `CLOSED`/payment exception. Record Payment is a picker over the contract's certificates that still have an outstanding balance — the underlying payment model is still certificate-scoped (see below), this is a UI convenience, not a new data shape.

Certificate waterfall (`accounting/certificateCalc.ts: calcCertificate`):

```
Current Work        = Work Value To Date − Previous Certified Work
Gross Current Value  = Current Work + Current Variations
Net Before VAT       = Gross − Retention − Advance Recovery − Σ Deductions
Net Payable          = Net Before VAT + VAT
```

`validateCertificate` enforces: current work ≥ 0; certified-to-date can't exceed the contract's revised value unless a variation on this certificate covers the excess; retention 0–100% and ≥ 0 resulting amount; advance recovery ≤ live available advance balance **for that contract** (Phase 2B.2 — see below); deduction amounts ≥ 0; net payable ≥ 0; if VAT > 0, `taxInvoiceReceived` + number + date are required. Every `CertificateDeduction` must have an `accountId` mapped from a small fixed set (`DEDUCTION_ACCOUNT_IDS`) before approval. "Previous Certified Work" already defaulted to the latest prior certificate **on the same contract** (`CertificateForm.tsx` filters `priorCertificates` by `contractId`) since Phase 2A — this was already correct and needed no change.

### Contract-scoped accounting (Phase 2B.2 — the core fix)

Before this phase, subcontractor payable/retention/advance balances in `ledger.ts` were scoped by `subcontractorId` (+ optional `projectId`), not `contractId` — correct only because the seed data gave each subcontractor exactly one contract. This is fixed:

- `JournalLine` gained an **additive, optional `contractId` dimension** (`domain/types.ts`) alongside the existing `partyId`/`projectId`. No new GL account was minted per contract — dimensional tracking was preferred over account explosion, per the phase's binding direction.
- Every subcontractor-related posting function (`postSubcontractorAdvance`, `postCertificateApproval`, `postSubcontractorPayment` in `accounting/postingEngine.ts`) now tags every line it produces with `contractId`. `SubcontractorAdvance` and `SubcontractorCertificate` already stored `contractId` from Phase 2A, so those two functions needed no new parameter. `SubcontractorPaymentTransaction` did **not** have `contractId` — it gained one (optional, always populated going forward from `certificate.contractId` when a payment is created), and `postSubcontractorPayment` gained a `projectId` parameter (the certificate's project, passed by the caller, never stored redundantly on the payment record) so its lines could carry a project dimension too (which they never did before this phase).
- `accounting/ledger.ts` gained contract-scoped query functions: `contractAdvancePaid`, `contractAdvanceRecovered`, `contractAdvanceBalance`, `contractRetentionHeld`, `contractPayableCreated`, `contractPayableBalance`, `contractCertifiedCost` — each filtered strictly by `contractId`, all built on a shared `accountTotals()` helper (raw debit/credit totals) that `accountBalance()` now composes from.
- `approveCertificate()`'s advance-recovery ceiling and `CertificateForm.tsx`'s live "available advance balance" hint were switched from `subcontractorAdvanceBalance(entries, subcontractorId, projectId)` to `contractAdvanceBalance(entries, contract.id)` — two contracts for the same subcontractor, even on the same project, can no longer share an advance balance.
- The **old party-scoped functions were not removed** — `subcontractorPayableBalance`, `subcontractorRetentionHeld`, `subcontractorAdvanceBalance` (called with no project filter) now serve exactly as the **subcontractor-level aggregate**, since `partyId` is still tagged on every line regardless of contract. This is what powers the master list / subcontractor profile totals, and is *by construction* the sum across that subcontractor's contracts (verified live — see §22).
- `pages/ProjectDetail.tsx`'s subcontractor payable/retention totals were switched from summing the party-scoped functions per contract (a latent double-count risk if one subcontractor ever had two contracts on the same project) to summing `contractPayableBalance`/`contractRetentionHeld` per contract — now correct by construction.

### Historical migration

`ensurePhase2B2Migrated()` (`storage/migrations.ts`, additive, idempotent, runs after the three earlier migrations on every boot):
1. Backfills `Party.status = "ACTIVE"` wherever unset.
2. Backfills `SubcontractorPaymentTransaction.contractId` from the certificate it already references (`certificateId → certificate.contractId`).
3. Backfills the `contractId` dimension onto every already-posted `SUBCONTRACTOR_ADVANCE`/`SUBCONTRACTOR_CERTIFICATE`/`SUBCONTRACTOR_PAYMENT` journal entry, resolving the contract from its source document.

**No monetary amount is ever changed** by this migration — only dimension metadata is added, and only where the source document makes the contract determination certain. An entry whose source record can't be found is left exactly as it was; it simply never appears in a contract-scoped query and remains readable only through the party-level aggregate ("legacy party-scoped activity" — a permanent, accepted fallback, same posture as the Phase 2B.1A treasury-account migration). On this codebase's actual data (seed dataset + this phase's own live testing) every subcontractor-related record was deterministically mappable; the fallback path exists for safety but was never actually exercised.

## 12. Projects

`Project` is a real operational master record (Phase 2B.1). `pages/Projects.tsx` has a "New Project" action (opens `components/ProjectForm.tsx`), status and company filters, and a company column. `pages/ProjectDetail.tsx` has an "Edit Project" action using the same form, plus (Phase 2B.1A) an amber banner when `status === "CLOSED"` explaining that new operational activity is blocked while historical activity stays visible. `AppDataContext`: `addProject`/`updateProject` validate a required name, a valid company, and a project code that's unique within that company; once a project has any accounting activity (`projectHasActivity()` checks expenses, advances, settlements, subcontracts, and journal lines by `projectId`), `updateProject` refuses to change `code` or `companyId`. `deleteProject` throws if the project has any activity — a genuinely empty, never-used project can be deleted. `assertProjectAcceptsTransactions(projectId)` (Phase 2B.1A) throws if the project is `CLOSED`; it's called from `addExpense`, `addAdvance`, `addCustodySettlement`, `addSubcontractorAdvance`, `addCertificateDraft`, `updateCertificateDraft`, and `approveCertificate` — see §15 for what it does *not* cover. All cost/VAT figures (`totalProjectCost`, `directExpenseCost`, `subcontractorCertifiedCost`, `totalInputVat`, etc.) are unchanged, still derived live from `ledger.ts`.

## 13. Demo Data

`src/seed/seedData.ts`. Company: "Al Rahim & Majid Contracting LLC" (`code: "CO-001"`, `status: "ACTIVE"`, timestamps). Parties: owners A. Rahim, Majid; custodians Bareq, Sobhi; 5 suppliers; subcontractors Al Falah MEP Contracting, Gulf Steel Works. Projects: Al Nakhil Building, Al Zorah, Ajman Office (each carries `companyId`, `createdAt`, `updatedAt`). Treasury accounts: Main Cash, Petty Cash, Main Bank — each with its own dedicated GL account baked directly into the seed (`TREASURY_GL_ACCOUNTS`: `1000-001`, `1000-002`, `1100-001`), so even a fresh install / "Reset Demo Data" has individually-accurate treasury balances from the start (Phase 2B.1A). 15 seeded expenses, 3 advances (`adv_001` owner-funded, `adv_002` Main-Bank-funded, `adv_003` owner-funded, tagged with its Al Zorah project id), 2 subcontracts, 1 subcontractor advance, 3 certificates (1 DRAFT, 2 APPROVED — covering retention, advance recovery, and a mapped deduction), 1 partial subcontractor payment. Two seeded expenses (`exp_014`, `exp_015`) deliberately still use the legacy `paidFromType: "CASH"`/`"BANK"` values, to keep exercising that backward-compatibility path.

`ensureSeeded()` runs once on a genuinely empty install. `ensurePhase2ASeeded()` is a **separate, additive, idempotent migration** — gated on `subcontracts` being empty — that backfills the Phase 2A chart-of-accounts entries, the two subcontractor parties, and the subcontractor demo dataset onto an *existing* Phase 1 install without touching real data already there. `ensurePhase2B1Migrated()` then backfills `Company`/`Project`/`AdvanceTransaction` shapes and seeds the three baseline treasury accounts for pre-2B.1 installs; `ensurePhase2B1AMigrated()` runs last and mints each of those a dedicated GL account (see §8). All four run on every app boot (`AppDataContext.tsx` module top level); `resetDemoData()` wipes everything (`clearAll()`) and reseeds from scratch. **This demo data is not approved opening balances** — see Binding Decision #11 in the roadmap.

## 14. Internationalization (i18n / RTL) — Phase 2B.3

`src/i18n/` (new, Phase 2B.3): `en.ts` and `ar.ts` each export a flat, dot-namespaced `Record<TranslationKey, string>` (`TranslationKey = keyof typeof en`, so `ar.ts` is typed against it — a missing Arabic key is a TypeScript build error, never a silent runtime gap), organized in sections that mirror the screens they serve (`dashboard.*`, `subcontractForm.*`, `contractWorkspace.*`, etc. — ~330 keys total). `I18nContext.tsx` exports `I18nProvider` (wraps the app in `main.tsx`, above `BrowserRouter`), `useI18n()` (`{ locale, setLocale, dir, t }`), and `useT()` (the `t` function alone — what almost every page/component actually imports). `t(key, vars?)` supports `{placeholder}` interpolation and falls back English → raw key if a lookup ever misses at runtime (defensive only; the type system prevents this in anything that compiles).

**Persistence**: `localStorage["cas:v1:locale"]` — same `cas:v1:` namespace as every other stored key even though locale is a UI preference, not accounting data. Read once on `I18nProvider` mount, written on every `setLocale()`; defaults to `"en"` if unset/unreadable.

**RTL/LTR**: `I18nProvider` sets `document.documentElement.lang`/`.dir` from the active locale. Tailwind CSS 4's logical-property utilities and `rtl:` variant do the rest: `Sidebar.tsx` uses `border-e` instead of `border-r` (flips to the correct side under `dir="rtl"`, and the sidebar itself flips via flexbox row reversal); `Expenses.tsx`'s search icon/input use `start-3`/`ps-9` instead of `left-3`/`pl-9`; a row gap in the same file uses `ps-4` instead of `pl-4`; `Suppliers.tsx` uses `ms-2` instead of `ml-2`. Every directional navigation icon (`ArrowLeft` on "Back to…" links, `ArrowRight` as a list-row chevron — `ProjectDetail.tsx`, `SubcontractorDetail.tsx`, `SubcontractDetail.tsx`, `Projects.tsx`) has `className="rtl:-scale-x-100"` so it mirrors instead of pointing the wrong way in Arabic. **Numbers and currency (`formatAED`, all counts) always render in Western Arabic/Latin digits in both locales** — a deliberate, permanent choice matching standard practice for financial UIs (including Arabic-locale accounting software) so AED figures are never ambiguous.

**Language toggle**: `Sidebar.tsx` footer — a two-button `EN | عربي` switch (`aria-pressed` on the active button), next to the existing "Currency: AED" / "Reset Demo Data" footer content.

**Coverage**: every page (`Dashboard`, `Companies`, `Projects`, `ProjectDetail`, `Treasury`, `Expenses`, `Advances`, `Suppliers`, `Subcontractors`, `SubcontractorDetail`, `SubcontractDetail`, `OwnersCustodians`, `Journal`) and every form/shared component (`CompanyForm`, `ProjectForm`, `TreasuryAccountForm`, `ExpenseForm`, `AdvanceForm`, `CustodySettlementForm`, `SupplierPaymentForm`, `SubcontractorForm`, `SubcontractForm`, `CertificateForm`, `SubcontractorAdvanceForm`, `SubcontractorPaymentForm`, `Sidebar`, `DemoDataBadge`, `Modal`) renders every static string — titles, subtitles, table headers, stat-card labels, status/badge text, buttons, field labels, placeholders, empty states, validation-error messages — through `t()`. Dynamic data (party/project/company/category names, dates, currency amounts, user-entered free text) is never translated — this is standard and correct for an accounting system, not a gap.

**Not touched by this phase, on purpose**: `accounting/`, `state/AppDataContext.tsx`, `storage/` — Phase 2B.3 is presentation-layer only; no business logic, validation rule, or posting behavior changed. Verified live (see §22) with the same categories of accounting regression run in every prior phase, confirming identical numbers before/after.

## 15. Known Limitations

- Production still has no backend/auth/RLS/audit/atomic transaction boundary; localStorage remains the only implemented persistence.
- `AppDataContext` writes a business row, journal and status in separate synchronous operations. A quota/browser failure can leave partial state; concurrent users are impossible; authorization is absent.
- The generic repository loads and rewrites whole collections, caches indefinitely, has no query/filter/pagination/concurrency contract, and is synchronous. It is not a viable direct Supabase adapter.
- Most current local business documents lack a direct `companyId`; company is inferred through project where present. P0 resolved the production rule: financially important records receive mandatory direct `company_id`, while ambiguous local rows go to migration review rather than inferred tenant ownership.
- Legacy pooled `CASH`/`BANK` postings and deterministic-only contract backfills must not be reinterpreted by guess.
- Existing lifecycle coverage is uneven: certificates have Draft/Approved/Paid variants, settlements Draft/Settled, expenses Posted/Void, while advances/payments post immediately. Production must preserve meanings and add reversal rather than force one enum everywhere.
- Current money values are JavaScript numbers protected by integer-cent helper comparisons; production persistence must eliminate float representation.
- Current IDs are browser-generated non-cryptographic strings and references derived from slices/counts; production needs UUIDs and concurrency-safe company-scoped numbering.
- Dynamic/free-text data is intentionally untranslated. Locale is browser-scoped until profiles exist.

## 16. Production Data Foundation Architecture — Approved, Not Implemented

### Production Architecture Freeze — P0 completed 2026-08-26

`PROJECT_ROADMAP.md` → **Production Architecture Freeze — P0 Approved** is the canonical, detailed freeze. P0 approved the architecture only; the running application remains the localStorage SPA described above.

Frozen outcomes:

- Company is mandatory on tenant-owned operational/accounting data; project is nullable only for real company-level activity. No fake general project.
- Project remains the job/cost dimension; TreasuryAccount remains the source/destination of cash and owns its dedicated GL.
- Permission keys sit behind roles. Certificate accounting approval requires `certificate.approve_post`, initially granted only to `ACCOUNTING_ADMIN`; `ACCOUNTANT` can prepare/review.
- Project managers see assigned-project operations, cost summaries, relevant parties/contracts/certificates/attachments, but not company GL, unrelated treasury, owner accounts, payroll, users or other projects.
- Posted accounting fields and journals are immutable. All eight current posted-flow categories use linked, dimension-preserving, idempotent reversal plus a new correcting document when needed.
- PostgreSQL allocates company/type/year human references atomically; UUID PKs remain independent.
- Money is `BIGINT` AED minor units. Percentage inputs use integer basis points, full-precision rational/`NUMERIC` intermediates and one round-half-away-from-zero conversion per posted component.
- Posting RPC balance validation plus a deferred database constraint trigger provide cross-row enforcement; browser clients cannot mutate journals.
- Financial commands require idempotency UUIDs/request hashes, unique source postings, posted-journal links, state predicates and locks.
- Ambiguous pooled legacy Cash/Bank stays provenance-preserved and unresolved until evidence supports an approved mapping.
- Development, Staging and Production are separate Supabase projects. Production has no demo seeds, service secrets in browsers, or localStorage accounting fallback.
- Auth is invite/admin-created only. SYSTEM_ADMIN is audited break-glass/server administration, not a browser RLS bypass; routine access still requires company membership.
- Audit is append-only and transaction-coupled. Attachments are private, company-scoped, signed-access and versioned/superseded.
- P1–P10 order is frozen; P1 is complete and P2 is next. Payroll follows completed Foundation; historical 2025/2026 import follows Payroll.

### P1 — Supabase Environments + Migration Foundation completed 2026-08-26

Implemented repository foundation only:

- Added `supabase@2.115.0` as a pinned project dev dependency (`package.json`/lockfile), plus working `db:version` and `db:new` scripts. No global CLI dependency is assumed.
- Initialized the official `supabase/config.toml` layout. Local ports target the Vite development origin, public/anonymous signup is disabled in configuration, and `db.seed.enabled = false`.
- Added `supabase/migrations/20260826193204_p1_migration_foundation.sql`. It intentionally creates no extension, schema, table, role, RLS policy, function, bucket, user or demo record; it documents conventions and establishes timestamped forward-only history.
- Added `.env.example` with public placeholders only and expanded root `.gitignore` to exclude real `.env*` files while retaining the example. Privileged database/service/management secrets are forbidden under `VITE_*`.
- Replaced the Vite template README with the exact CLI/migration workflow: one migration history promoted Development → Staging → Production, corrective forward migrations for shared environments, environment-safe linking, production approval, and no dashboard-only schema drift.
- Separate remote Development, Staging and Production projects remain the deployment design. None was created or linked in P1 because credentials do not exist and Production region/plan/data-location decisions remain external.
- Seed policy is fail-safe: automatic SQL seed is disabled; frontend `src/seed/seedData.ts` remains localStorage-only and is not connected to Supabase. Production never receives it automatically.
- Frontend code, Vercel rewrite and localStorage repositories were not changed. No partial Supabase data path exists.

Verification reality:

- **Repository/CLI verified:** clean start at commit `48dc6ec`; project-local CLI reports `2.115.0`; `supabase init` and `supabase migration new` completed; config parsing reached local lifecycle startup; the timestamped migration exists and contains no business/demo SQL.
- **Local database not applied:** `supabase start` was attempted and accurately failed because neither Docker nor Podman is installed/on PATH. No container runtime was installed and no local reset/status/application is claimed.
- **Remote not verified:** no Development/Staging/Production project was created, linked or migrated; no credentials were available. Remote lifecycle validation belongs after approved provisioning.
- **Application/repository checks:** `npm run build` passed (only Vite's existing large-chunk advisory); `npm run lint` passed with the four existing `react/only-export-components` warnings; `git diff --check` passed. Installation audit reported zero vulnerabilities.
- **Secret review:** credential-shaped token/URL/password patterns were scanned across every P1 file and produced no matches. Only empty public placeholders exist in `.env.example`; no real environment file is present or tracked.

### Architecture assessment and boundary

Keep React/Vite, i18n, UI workflows, pure domain types/calculators, certificate waterfall rules, ledger query semantics, chart/accounting mappings, and the posting engine's scenarios as client previews and regression specifications. Move authorization, authoritative validation, ID/reference allocation, lifecycle transitions, funding resolution, balance-sensitive checks, document+journal persistence, reversal, and audit into PostgreSQL transactions.

Use Supabase directly for authenticated reads governed by RLS and for non-accounting draft/master-data writes where policies allow. Use PostgreSQL RPCs for every accounting command. Edge Functions are optional for privileged administration, email/invitations, malware scanning, or external integrations; they must call the same database command and must not split document and journal work across network calls. A separate application server is not justified yet.

### Proposed PostgreSQL schema

All primary keys are UUID. Timestamps are `timestamptz`; business dates are `date`. Mutable rows carry `created_by/at`, `updated_by/at`; lifecycle rows also carry `approved_by/at`, `posted_by/at`, and reversal references as applicable. Operational financial rows carry a non-null `company_id` even when also derivable, with composite foreign keys/triggers validating consistency.

| Area | Tables and important relationships |
|---|---|
| Identity/security | `profiles(user_id -> auth.users, display_name, locale, status)`; `company_memberships(company_id, user_id, role, status)`; `project_access(company_id, project_id, user_id)` only for project-restricted roles |
| Masters | `companies`; `projects(company_id)`; `parties(company_id, type, status)`; `expense_categories(company_id nullable for controlled global seeds)`; `accounts(company_id, parent_id, requires_party)`; `treasury_accounts(company_id, project_id nullable, gl_account_id unique, status)` |
| Direct/custody | `expenses`; `advances`; `custody_settlements`; junction `custody_settlement_expenses(settlement_id, expense_id)` with uniqueness preventing one finalized expense in multiple settlements |
| Suppliers | `supplier_payments` linked to supplier party, company and optional project/source dimensions. Supplier credit purchases remain expenses with supplier/payable semantics; no unnecessary invoice table is introduced yet |
| Subcontracts | `subcontracts(company_id, project_id, subcontractor_id)`; `subcontractor_advances`; `subcontractor_certificates`; `certificate_deductions`; `subcontractor_payments(certificate_id, contract_id)` |
| Ledger | `journal_entries(company_id, source_type, source_id, status, idempotency_key, reversal_of_id)`; `journal_lines(journal_entry_id, line_no, account_id, amount_minor, side, project_id, party_id, subcontract_id)`. A debit/credit-column variant is acceptable, but both cannot be positive |
| Documents/audit | `attachments(company_id, project_id, entity_type, entity_id, bucket, object_path, original_name, mime_type, size_bytes, checksum, status)`; append-only `audit_log(company_id, actor_id, action, entity_type/id, before_data, after_data, request_id, occurred_at)` |
| Future import | `import_batches(company_id, source_file, checksum, status, imported_by, approved_by/at)`; `import_rows(batch_id, source_sheet, source_row, source_reference, raw_data, normalized_data, fingerprint, review_status, review_notes)`. Operational rows later receive nullable `import_batch_id/source_row_id` |

Do not create separate Owner, Custodian, Supplier, Employee or Subcontractor tables yet: `parties.type` remains the established master. Payroll may add an employee extension only when its real attributes are known.

### Database constraints and journal integrity

- Company codes and account codes are unique in the chosen scope; project codes are unique per company; subcontract numbers remain unique per project.
- Composite keys/FKs or constraint triggers ensure project, party, treasury, account, subcontract and document all belong to the journal/document company.
- Project-specific treasury must reference a project in the same company. Its dedicated GL account is unique/permanent. Status changes never rewrite history; inactive treasury is rejected by new posting commands.
- Store amounts as non-negative `BIGINT` fils. Choose this over `NUMERIC(18,2)` because the existing invariant is integer-cent arithmetic, AED currently has two minor digits, sums/comparisons are exact, and RPC/TypeScript boundaries avoid decimal-string ambiguity. If multi-currency/minor-unit variability becomes real, revisit deliberately.
- Journal entries are created as a complete unit inside posting functions. A deferred constraint trigger verifies at transaction end that each POSTED journal has at least two lines, valid line shapes, and sum(debit)=sum(credit)>0.
- Unique `(company_id, source_type, source_id)` for live/original postings and unique `(company_id, idempotency_key)` prevent duplicate posting. Retry returns the existing result only when the request fingerprint matches; key reuse with different input fails.
- Normal roles receive SELECT only on posted journals. Revoke direct INSERT/UPDATE/DELETE on journal/audit tables; only tightly scoped command functions and migration service roles write them.
- Posted journal entries/lines are immutable. Reversal creates a new entry with opposite lines and links both entries; it never modifies original amounts/dimensions.

### Authentication, roles, and permissions

Supabase Auth supplies email/password or approved enterprise login later. Administrators invite users; there is no anonymous/public signup. The frontend listens for token refresh/sign-out, clears company-scoped query caches when identity/company changes, and does not use localStorage accounting data after production cutover. Disabled profile or membership is rejected by both RLS helpers and RPCs.

| Role | Practical initial capability |
|---|---|
| `SYSTEM_ADMIN` | Platform/bootstrap administration across companies through a controlled server/service path; not a routine accounting role |
| `ACCOUNTING_ADMIN` | Company-wide view; masters; approve/post/reverse; manage company members/roles; no cross-company access |
| `ACCOUNTANT` | Company accounting view; create/edit/review drafts; post allowed routine documents and payments; no certificate approval initially and no user management. A later explicit permission grant may expand this |
| `PROJECT_MANAGER` | Assigned-project operational view; create project drafts/supporting documents; no arbitrary posting, journals outside assigned projects, treasury administration, or user management |
| `DATA_ENTRY` / `PROCUREMENT` | Create/edit permitted drafts and supplier/project source data; view limited operational records; cannot approve/post/reverse/manage users |
| `MANAGEMENT_VIEWER` | Read-only company reporting and approved/posted documents; no mutation |

Use this small role enum initially, with RPC helper functions translating roles to actions. Do not build a general permission-builder UI. UI hides/disables unavailable actions, but RLS/RPC checks remain authoritative.

### RLS strategy

- Every policy begins with an active `company_memberships` check. Company ID is derived inside commands from trusted parent rows, never accepted blindly from the browser.
- Project-restricted members must additionally match `project_access`; company-wide accounting/admin/viewer roles bypass the project restriction only within their member company.
- Master data SELECT follows company/project visibility. Controlled CREATE/UPDATE requires role and active state; identity/company fields lock after activity.
- Draft documents allow creator/role-appropriate updates. Approval/post/reversal occurs only via RPC. Posted rows are SELECT-only.
- Journals are readable only when membership/project visibility permits all intended reporting; direct client mutations have no policies/grants.
- `audit_log` is readable only to authorized accounting admins/auditors and insertable only by trusted functions. Nobody receives client DELETE.
- Security-definer helpers/functions set a safe fixed `search_path`, qualify objects, verify `auth.uid()`, and are granted only to intended authenticated roles. Service-role keys never ship to the browser.

### Atomic posting command

Example `post_expense(payload, idempotency_key)`: authenticate; resolve active membership/role; lock/check idempotency; derive company from project or explicit authorized company context; validate project/party/category/treasury and company consistency; recalculate VAT and totals in minor units; reject inactive/closed sources; allocate IDs/reference; insert the business document; build mapped journal lines; validate dimensions and balance; insert entry/lines; mark the document POSTED with actor/time; write audit; commit and return IDs. Any error rolls back. Certificate approval locks the draft certificate, contract and relevant advance/payment state before recalculation so two concurrent approvals/recoveries cannot overspend an advance. Settlement finalization locks the settlement and selected expense links. Payments lock the payable/certificate scope to prevent overpayment.

### Audit trail

Business tables hold current actor/timestamps for convenient reporting. An append-only audit event records create/edit/approval/post/reversal/status and membership/role changes, including safe before/after JSON, request/idempotency correlation and actor. Sensitive secrets/file URLs are excluded. Audit is written in the same transaction as the change. Corrections retain original and reversal/correcting links; financial rows are never hard-deleted.

### Private document storage

Use private buckets separated at least by environment (one private accounting-documents bucket per project is unnecessary). Object paths start with trusted company UUID, then optional project UUID, entity type/entity UUID and random file UUID; metadata is authoritative. Upload initialization/finalization validates membership, project scope, MIME/size/checksum and role. Reads use short-lived signed URLs after authorization. Storage policies validate the company path plus membership; document-state rules restrict replacement/deletion. Posted-document attachments are versioned/superseded, not silently overwritten. Never store public URLs.

### Environments, backup and recovery

Use separate Supabase Development, Staging and Production projects from P1. Staging is required for Auth/RLS, migration and cutover rehearsal. SQL migrations are immutable/versioned/reviewed and promoted unchanged in order; emergency fixes become new migrations. Demo seed scripts are dev-only and fail closed in production.

Before Production project creation, confirm region/data-location expectations, plan, automated backup/PITR availability and accepted RPO/RTO. Initial recommendation—not a legal/company commitment—is the nearest acceptable region, managed daily backups, PITR if affordable, RPO ≤24 hours without PITR or about 15 minutes with PITR, RTO ≤8 business hours, encrypted monthly logical exports and quarterly non-production restore tests reconciled by counts and trial balance.

### LocalStorage migration

The current abstraction helps enumerate entities but is not directly portable. First refactor read/query contracts and command contracts; then add a Supabase implementation. Preserve LocalStorage as an explicit demo adapter only.

Migration tooling exports every `cas:v1:*` collection plus schema/app version, timestamp, record counts, hashes and source browser identifier without modifying it. Import to staging using an `import_batch`; normalize money to minor units; validate referential integrity, company ownership, duplicate fingerprints, journal balance, unique source posting and project/party/contract dimensions. Produce exceptions for missing company/project, legacy pooled treasury attribution and unresolved contract dimensions—never guess. An accounting admin reviews and promotes a batch atomically. Reconcile per-entity counts, per-company trial balance, control-account party/contract balances and source-to-journal links. Keep the export and staging batch; cut over only after a rehearsal and write freeze.

### Historical 2025/2026 readiness

Foundation schema includes import batch/source row/fingerprint/review provenance, but no importer is implemented now. Suggested review states remain `READY`, `NEEDS_REVIEW`, `POSSIBLE_DUPLICATE`, `MISSING_PROJECT`, `MISSING_SUPPLIER`, `INVALID_VAT`, `APPROVED`, plus `REJECTED`. Large history and opening balances wait until Foundation is live and verified.

## 17. Current Roadmap and Immediate Next Task

Phase 1 ✅ → 2A ✅ → 2B.1 ✅ → 2B.1A ✅ → 2B.2 ✅ → 2B.3 ✅ → **2C/P0 Production Architecture Freeze ✅** → **2C/P1 Supabase Environments + Migration Foundation ✅** → **2C/P2 Auth, Profiles, Memberships and Roles (next; not started)** → P3–P10 Foundation → 2D Payroll/WPS → 2E Historical Import/Opening Balances → Phase 3 Client Contracts/Certificates/Receivables → 3B Revenue Accounting → Phase 4 Reporting.

P2 is the next implementation task. Do not begin it without a new explicit task, and do not begin Payroll or bulk import until Foundation exit criteria pass.

## 18. Remaining External Deployment Decisions

Only these require provider/company/legal/plan information and remain outside the architecture freeze:

1. Supabase region after confirming company/legal expectations for UAE data location.
2. Subscription plan and the automated-backup/PITR features actually available on that plan.
3. Company-approved RPO, RTO, backup/export retention and responsible recovery owners.
4. Final identity policy details such as required MFA and approved email domains, while no-public-signup remains binding.

Inventorying real localStorage datasets is required operational work in P9, not an unresolved architecture decision. Ambiguous pooled cash/bank treatment is already frozen: preserve provenance and review; never guess.

## 19. Deferred Work

Payroll/WPS implementation (confirmed immediately after Foundation), bulk historical import/opening balances, retention release, client certificates/receivables/revenue recognition, consolidation, and complex legacy corrections. Public signup and offline multi-master accounting are not planned.

## 20. Run / Build Instructions

```bash
npm install
npm run dev        # Vite dev server, default http://localhost:5173
npm run build       # tsc -b && vite build — must be clean before considering work done
npm run preview     # serve the production build locally
npm run lint         # oxlint
```
No environment variables, no backend to start, no database to provision. Data lives in the browser's `localStorage` under keys prefixed `cas:v1:...`. "Reset Demo Data" in the sidebar footer wipes and reseeds everything (confirmation-gated).

## 21. Development Rules

1. **All posted journal entries must balance** — enforced by `isBalanced`/`UnbalancedJournalError` in `postingEngine.ts`. Never bypass this.
2. **Money math uses the existing decimal-safe helpers** (`domain/money.ts`) — never raw `+`/`-`/`*` on currency floats.
3. **Draft business documents do not affect the GL** unless a phase explicitly designs otherwise (certificates, settlements: DRAFT = no journal entry).
4. **Payments never duplicate previously recognized project cost** (Supplier Payment, Subcontractor Payment both debit a payable, never re-debit cost).
5. **Advances are balance-sheet movements, not expenses** — never post an advance to an expense/cost account.
6. **Subcontractor advances are not project cost** until a certificate recovers them.
7. **Custody settlement grouping never reposts already-posted expenses** — only the cash-return line (if any) generates a new journal entry.
8. **Project is a dimension/cost center, not automatically a treasury (cash/bank) account.**
9. **Record the actual funding source** for every cash movement — don't default to a convenient placeholder.
10. **VAT is never recognized without the appropriate supporting-document rule** (see the certificate tax-invoice guard as the working example).
11. **Historical imports require a review/deduplication stage** — never write raw import rows straight into `journalEntries`.
12. **Do not generate financial statements from incomplete books.**
13. **Every new user-visible string goes through `t()`, added to both `i18n/en.ts` and `i18n/ar.ts`** (Phase 2B.3) — never inline English (or any) text in a page/component. `ar.ts`'s `Record<TranslationKey, string>` typing already makes a missing Arabic key a build error, so this is enforced, not just a convention. Dynamic data (names, dates, amounts, free text) is never translated.

Also: no Debit/Credit pickers in normal user-facing forms (Journal is the only place raw accounting entries are displayed); business logic is never inlined into page components. During Production Data Foundation, pure calculations remain in `accounting/` while authoritative validation/posting moves from `AppDataContext` to database commands. Schema changes are versioned, additive where practical, migration-safe, and must never wipe existing local or production data as a feature side effect.

## 22. Testing Expectations

There is no automated test suite (no `*.test.ts` files, no test runner configured) — verification so far has been: `npm run build` must be clean (zero TypeScript errors), `npm run lint` (oxlint) must show no new warnings, plus live, browser-driven functional testing (headless Chromium via Playwright, launched ad hoc — not checked into the repo) exercising each new flow end-to-end with hand-calculated expected numbers, checking `console` for zero errors, and confirming persistence across a page reload.

Phase 2B.1's verification run (after a full "Reset Demo Data"): created a real project (`PRJ-2026-001`, "Demo New Contract") through the new UI; gave it a AED 10,000 Main-Bank-funded advance to Bareq and confirmed Project Cost stayed exactly `AED 0.00`; posted a AED 2,000 + 5% VAT expense against it from Bareq's custody and confirmed Project Cost became exactly `AED 2,000.00`; returned AED 1,000 from Bareq to Main Cash via a finalized custody settlement and confirmed Bareq's custody balance dropped by exactly 1,000 while Project Cost stayed at `AED 2,000.00`; reloaded the browser and confirmed all of the above persisted. Bareq's custody balance was independently hand-reconciled against the full seed ledger at every step (35,000 in seeded advances − 26,150 in seeded charges + 10,000 new advance − 2,100 new expense − 1,000 cash return = 15,750, which is exactly what the UI showed). Regression-spot-checked afterward: Dashboard, the pre-existing Al Nakhil project's total cost (unchanged), an owner-paid expense, a supplier payment, a new subcontractor draft certificate through approval, the Journal page, and the Suppliers/Subcontractors pages — all with zero `console` errors throughout the whole run.

Phase 2B.1A's verification run (after a full "Reset Demo Data", then a new "Treasury Verification Project" created through the UI): every one of the six numbered scenario tests was run and hand-reconciled against the Treasury screen's live balances —
- Test 1: AED 10,000 advance, Main Bank → Bareq. Main Bank's dedicated balance moved by exactly −10,000; Main Cash and Petty Cash stayed at `AED 0.00`; Project Cost stayed `AED 0.00`.
- Test 2: AED 1,000 + 5% VAT expense, Petty Cash. Petty Cash moved by exactly −1,050; Main Cash and Main Bank were unaffected by this step; Project Cost became exactly `AED 1,000.00`.
- Test 3: a supplier-credit purchase followed by a AED 2,000 supplier payment from Main Bank. Main Bank moved by exactly −2,000; Project Cost stayed at exactly `AED 1,000.00` (payment does not add cost).
- Test 4: Bareq returns AED 500 to Main Cash via a finalized custody settlement. Main Cash moved by exactly +500; Petty Cash and Main Bank were unaffected.
- Test 5: AED 3,000 subcontractor advance, Main Bank, against Al Falah MEP's contract. Main Bank moved by exactly −3,000; the unrelated Al Nakhil project's Total Cost stayed at exactly `AED 122,200.00`.
- Test 6: AED 2,500 subcontractor payment, Main Bank, against certificate `PC-AN-01-01`. Main Bank moved by exactly −2,500; Retention Held on that contract stayed exactly unchanged before/after.
- Closed-project guard: set "Treasury Verification Project" to `CLOSED` via Edit Project, confirmed the amber closed-project banner appeared on both `ProjectDetail` and `SubcontractDetail`, and confirmed the Expense form's Project dropdown no longer lists it (so a user cannot select it to attempt a new expense).
- Regression-spot-checked afterward, with zero `console` errors throughout: Dashboard (including a hard page reload), Company page, Owners & Custodians, Journal, and the pre-existing Al Zorah project's total cost (unchanged at `AED 19,050.00`).

Phase 2B.2's verification run (after a full "Reset Demo Data", driven headlessly via Playwright/Chromium against the real UI — no seed data or manual `localStorage` editing):

- **New Subcontractor From Zero (mandatory)**: created "Multi Contract Testing LLC" through the UI → reloaded → confirmed it persisted → created a contract for it → reloaded → confirmed the contract persisted → added a AED 10,000 advance → created a draft certificate (Work Value 40,000, Advance Recovery 5,000, 10% retention) and confirmed, before approval, Certified To Date / Retention Held / Outstanding Payable all read exactly `AED 0.00` and Remaining Value stayed the full `AED 100,000.00` (draft posts nothing) → approved it → confirmed Certified To Date became `AED 40,000.00`, Retention Held `AED 4,000.00`, Outstanding Payable `AED 31,000.00` → recorded a AED 15,000 partial payment and confirmed Outstanding Payable became exactly `AED 16,000.00`.
- **Multi-Contract Isolation (mandatory)**: same subcontractor, two contracts — Contract A (`MCT-A`, Al Nakhil Building, AED 100,000) and Contract B (`MCT-B`, Al Zorah, AED 200,000). Contract A: AED 10,000 advance, certificate (gross 40,000, retention 4,000, advance recovery 5,000, net payable 31,000), AED 15,000 payment. Contract B: AED 20,000 advance, certificate (gross 60,000, retention 6,000, advance recovery 2,000, net payable 52,000), AED 25,000 payment. Hand-reconciled: Contract A showed Advance Balance `5,000.00` (10,000 − 5,000), Retention `4,000.00`, Outstanding Payable `16,000.00` (31,000 − 15,000), Certified `40,000.00`, Remaining `60,000.00` — **before and after** Contract B's activity was posted, byte-for-byte identical, confirming zero cross-contamination. Contract B independently showed Advance Balance `18,000.00`, Retention `6,000.00`, Outstanding Payable `27,000.00`, Certified `60,000.00`, Remaining `140,000.00`. Subcontractor-level aggregate for "Multi Contract Testing LLC" showed Certified `100,000.00` (40,000+60,000), Payable `43,000.00` (16,000+27,000), Retention `10,000.00` (4,000+6,000), Advance Balance `23,000.00` (5,000+18,000) — exactly the sum of its two contracts. Project A (Al Nakhil Building)'s total cost increased by exactly 40,000 (Contract A's certified work only); Project B (Al Zorah)'s total cost increased by exactly 60,000 (Contract B's only) — neither project's cost picked up the other contract's figure.
- **Guard rails**: closing Contract A's seeded contract (`SC-AN-01`) via Edit Contract → confirmed "New Advance"/"New Certificate" became disabled while "Record Payment" stayed reachable (settling an existing payable on a `CLOSED` contract remains allowed) → reopened it. Confirmed a `CLOSED` project (Ajman Office) is absent from the New Subcontract form's Project dropdown entirely (same pattern as the Expense form). Deactivated a subcontractor (Gulf Steel Works) and confirmed its "New Subcontract" action became disabled on its own profile while its existing contract (`SC-AZ-01`) remained fully visible.
- Zero `console` errors throughout every scenario above.
- Regression-spot-checked afterward, with zero `console` errors: Dashboard, Journal, Company, Cash & Banks, Expenses, Advances & Settlements, Suppliers, Owners & Custodians, and the subcontractor master list (all pre-existing seeded subcontractors — Al Falah MEP Contracting, Gulf Steel Works — still showed correct aggregate figures after the ledger-function changes).
- `npm run build` (`tsc -b && vite build`) and `npm run lint` (oxlint) both clean — zero errors, zero new warnings (the two pre-existing `only-export-components` fast-refresh warnings, present before this phase, are unchanged).

Phase 2B.3's verification run (Playwright/headless Chromium, after a full "Reset Demo Data"):

- **Locale switch + RTL**: confirmed `document.documentElement.dir`/`.lang` are `ltr`/`en` by default; clicking "عربي" flips both to `rtl`/`ar` immediately, with all ten sidebar nav labels and the active page's `<h1>` re-rendering in Arabic. Confirmed every one of the app's ten top-level routes (`/`, `/company`, `/projects`, `/treasury`, `/expenses`, `/advances`, `/suppliers`, `/subcontractors`, `/people`, `/journal`) plus the subcontractor profile and contract workspace drill-downs render fully in Arabic with zero `console` errors.
- **Persistence**: reloaded the browser after switching to Arabic — `dir` stayed `rtl` and `localStorage["cas:v1:locale"]` read back `"ar"`.
- **RTL layout, visually confirmed via screenshot**: sidebar renders on the right edge (border + flexbox both flip correctly), the "Back to …" arrow icon mirrors to point right, stat cards/badges/buttons all flow start-to-end correctly, and all AED figures render in Latin digits in both locales (by design).
- **Accounting regression** (same categories of check as every prior phase, to confirm the presentation-only refactor changed zero business logic): posted a new AED 5,000 custodian advance from Main Bank; posted a new AED 1,000 + Auto-5% VAT expense against Al Nakhil Building from Bareq's custody; drafted and approved a new certificate on the seeded Al Falah MEP contract (`SC-AN-01`, Work Value To Date 120,000) and hand-reconciled the result exactly: Certified To Date `120,000.00`, Retention Held `12,000.00` (prior `9,500.00` + this certificate's `2,500.00`), Outstanding Payable `74,950.00` (Created `94,950.00` − Paid `20,000.00`) — identical, character-for-character, before and after a hard page reload. Zero `console` errors across the entire run, in both locales.
- `npm run build` and `npm run lint` both clean throughout — zero errors, only the two pre-existing `only-export-components` warnings plus the same pattern newly appearing (expected, not a defect) on `i18n/I18nContext.tsx` for the same reason it already applied to `AppDataContext.tsx`/`Field.tsx`.
- **Vercel SPA rewrite**: verified locally (a Node static server replicating Vercel's documented rewrite-only-if-no-matching-file behavior) that `/expenses`, `/projects`, `/projects/:id`, `/subcontractors`, `/journal`, and `/` all return `200` with `index.html`'s content under the new `vercel.json`, while an actual built asset (`/assets/*.js`) still resolves directly rather than being swallowed by the catch-all rewrite. Without `vercel.json`, the same requests returned `404` (reproduced and confirmed before adding the fix).

Any future phase should be verified the same way before being marked "Completed" in the roadmap: build clean, lint clean, flow tested live with real numbers, no console errors, persists after reload, and existing flows re-checked for regressions.

## 23. Handoff Checklist for New Sessions

- [ ] Read `PROJECT_ROADMAP.md` in full (Binding Decisions, Completed, Current/Next Phase, Known Gaps, Decision Log).
- [ ] Read this file in full.
- [ ] Confirm current repo state matches what's documented here — inspect, don't assume (files move; this doc can drift).
- [ ] Check `git log` / `git status` for anything not yet reflected here.
- [ ] Before writing code: identify which files in §5/§6 the task actually touches; don't restructure working modules.
- [ ] After completing a phase or making a binding decision: update **both** `PROJECT_ROADMAP.md` (phase status, next action, decision log, known gaps) and this file (implementation state, new files/models, changed accounting rules, limitations, immediate next task). A feature is only "Completed" once it exists and has been verified running — not merely planned.
