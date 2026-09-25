# Maker Contracting Accounting System — Project Handoff

**Read this file and `PROJECT_ROADMAP.md` fully before writing any code.** This file is the complete orientation for a new Claude/AI/developer session. It should be enough, on its own, to understand what the system is, why it exists, what's actually implemented, what's known-incomplete, and what to do next.

Repository: `https://github.com/n7rawy1984/MkaerACC` · Local path: `/media/nagham/msn4ever/www.downloadly.ir/Maker`

---

## P6D current checkpoint — Subcontractor Payments

**P6D IN PROGRESS; Checkpoints 1–8 COMPLETE for Development.** Expense READ, Treasury-funded Expense POST, Expense Reversal, Supplier Payment, Supplier Credit Expense POST, Subcontractor Advance, Subcontractor Certificates, and Subcontractor Payment READ/POST/Reversal are complete. Production `/subcontractor-payments` reuses canonical P5H commands with exact BIGINT strings, explicit same-Subcontract Certificate allocations, frozen same-key recovery, authoritative readback, and unchanged role/RLS/locking/dependency boundaries. Focused automated and rollback-only Development evidence passes. No migration. See [Checkpoint 8](docs/P6D_SUBCONTRACTOR_PAYMENTS.md) and deferred [PRE_DEMO_UAT](docs/PRE_DEMO_UAT.md).

P6C COMPLETE; P6E NOT STARTED; Production readiness DEFERRED. Retention flows, Corrected Replacement Expense, and all other financial workflows remain NOT STARTED in P6D. One local Checkpoint 8 closure commit is authorized; no push or Staging/Production action.

## Historical P6C closeout checkpoint — 2026-09-23

**P6C — COMPLETE (Development). P6D/P6E — NOT STARTED. Production readiness — DEFERRED.** The final integrated boundary audit and narrow forward grant correction passed. Migration `20260923130000_p6c_closeout_grant_hardening.sql` removes browser TRUNCATE/REFERENCES/TRIGGER/MAINTAIN only from project_assignments; all 32 public application tables pass the residual-grant audit. Intended grants, trusted provisioning, RLS/policies, ownership and role behavior are preserved. All 41 Development migrations align; DB lint is clean, final linked dry-run is a no-op and Companies/settings remain 14/14 with missing/orphan 0/0. Consolidated build/lint/boundary/behavior gates pass.

See [P6C final closeout](docs/P6C_FINAL_CLOSEOUT.md) for exact evidence and limits. This checkpoint supersedes historical P6C-in-progress, another-master-slice, mutation-pending and temporary-fixture notes below; dated implementation evidence remains historical. There is no Slice 17. [Pre-Demo UAT](docs/PRE_DEMO_UAT.md) remains separate and non-blocking; no new browser/Auth fixture or historical acceptance rerun occurred. Development completion is not Production readiness. No Staging/Production, commit or push.

## 1. Project Summary

**MakerACC** is the current internal codename for a reusable bilingual, multi-tenant contracting-accounting platform. It may be licensed to multiple independent contracting companies from one codebase. It is not a generic expense tracker: it models project cost centers, custody, supplier payables, subcontract certificates/retention, and eventually payroll/WPS, client contracts, and financial statements. `Company` is the tenant boundary and customer-specific behavior must be configuration, never accounting-code forks.

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
- **Phase 2C / P2 (Auth, Profiles, Memberships and Roles)** — Completed. Applied and verified remotely on the approved synthetic-only Development project.
- **Phase 2C / P3 (Core Production Schema and Master Data)** — Completed. Applied and verified remotely on the approved synthetic-only Development project.
- **Phase 2C / P4 (RLS and Authorization)** — Completed. Applied and verified remotely on the approved synthetic-only Development project.
- **Phase 2C / P5A (Accounting Kernel and Journal Core)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5B (Expense Documents and Commands)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5C (Supplier Payments)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5D (Custody Advance Funding)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5E (Custody Settlement and Cash Return)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5F (Subcontractor Advance)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5G (Subcontractor Certificates)** — Completed. Applied and verified remotely on Development; P5 overall remains in progress.
- **Phase 2C / P5H (Subcontractor Payments)** — Completed. Applied and verified remotely on Development; followed by completed P5I and formal P5 closure.
- **Phase 2C / P5I-A (Retention Release Foundation)** — Completed. Applied and verified remotely on Development; followed by completed P5I-B.
- **Phase 2C / P5I-B (Retention Payment)** — Completed. Applied and verified remotely on Development; P5I integration/reconciliation and formal P5 closure are complete.
- **Phase 2C / P5 (Atomic Accounting Commands / Production Financial Command Layer)** — Completed through P5I. Closure review accepted; no P5J/P5K exists or is required.
- **Post-P5 Focused Engineering and Accounting Integrity Review** — Completed. P5H/P5I combined dependency, separated-source settlement, reconciliation, tenant and authorization checks passed; P6A is ready to begin separately.
- **Phase 2C / P6A (Auth Session and Tenant Context)** — Verified complete on 2026-09-04. Automated gates and the full risk-proportionate browser/Auth smoke matrix pass with no confirmed defect; Development-only synthetic fixture and temporary browser-state cleanup was verified complete on 2026-09-05.
- **Phase 2C / P6B (Tenant Settings and White-Label Foundation)** — Verified complete on Development through `20260911123000`; hosted constraint/RLS, complete browser branding/isolation, and post-fix canonical-route matrices pass. Development-only fixture and browser-state cleanup is verified complete.
- **Phase 2C / P6C (Master Data Async Repository Cutover)** — COMPLETE; see the authoritative final checkpoint above. Historical slice evidence follows. Slice 1 is verified complete: the production-only async foundation and read-only active-Company profile plus tenant-scoped Projects passed authenticated browser, tenant-isolation, focus/revalidation, and fail-closed revocation acceptance. Slice 2 Parties/Expense Categories reads are VERIFIED COMPLETE, including accepted authenticated role/tenant/focus checks and complete fixture/Auth cleanup. Slice 3 Accounts/Treasury READ-ONLY is VERIFIED COMPLETE, including representative authenticated acceptance and complete fixture/Auth cleanup. Slice 4 Subcontracts READ-ONLY is VERIFIED COMPLETE, including authenticated acceptance and fixture/Auth cleanup; Slice 5 — Expense Categories MUTATION — VERIFIED COMPLETE, including accepted authenticated browser checks and full disposable database/Auth cleanup. Slice 6 — Supplier Party MUTATION — VERIFIED COMPLETE, including 104/104 hosted checks, concurrency, authenticated acceptance and full fixture/Auth cleanup. Slice 7 — Company Profile Metadata UPDATE — VERIFIED COMPLETE, including accepted automated/hosted checks, user-completed authenticated browser acceptance and final fixture cleanup. P6C remains IN PROGRESS; P6D/P6E remain NOT STARTED. Slice 8 — Project Descriptive Metadata UPDATE — VERIFIED COMPLETE, including user-completed authenticated browser acceptance and final cleanup. Slice 9 — Account Display Name UPDATE — VERIFIED COMPLETE. Development migration `20260917120000` applied; hosted 99/99, concurrency 1/0 and automated gates pass; 32 migrations aligned, cleanup/global 14/14 verified. User-completed authenticated acceptance and exact guarded fixture/Auth cleanup PASS; final fixture counts zero, global 14/14, missing/orphan 0/0. Slice 10 — Treasury Display Name UPDATE — VERIFIED COMPLETE. Development-only migration `20260921120000`, hosted 108/108, concurrency 1/0 and focused automated gates PASS; 33 migrations aligned. User-completed authenticated acceptance and guarded cleanup PASS; all fixture/Auth counts 0, global 14/14 and missing/orphan 0/0. See `docs/P6C_SLICE_10_TREASURY_DISPLAY_NAME.md` for the latest verified closure. Slice 11 — OTHER Party Display Name UPDATE — VERIFIED COMPLETE; Development migrations `20260921130000` and `20260921133000`, 35 migrations aligned; authenticated browser acceptance and guarded cleanup PASS with final global 14/14 integrity. See `docs/P6C_SLICE_11_OTHER_PARTY_NAME.md`.
- **Phase 2C / P6C Slice 12 (EMPLOYEE Party Display Name UPDATE)** — VERIFIED COMPLETE. ACCOUNTING_ADMIN-only existing EMPLOYEE name update, Development forward migration `20260922120000`; hosted 115/115, concurrent exact-token 1/0, focused repository/provider and isolated Chromium PASS; 36 migrations aligned and final linked dry-run no-op. User-completed authenticated browser acceptance PASS: ACTIVE/INACTIVE EMPLOYEE edits, validation/normalization, controlled stale conflict, Alpha/Beta isolation, complete documented role matrix, open-edit downgrade, membership/Company/profile revocation and restoration, draft/keyboard/focus, EN/AR/RTL 390px responsive long-name wrapping, type boundaries and unchanged financial/P6D holding routes. Exact guarded cleanup and final verification PASS: all Slice 12 fixture/Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. See `docs/P6C_SLICE_12_EMPLOYEE_PARTY_NAME.md` and `docs/verification/p6c-slice12/README.md`. P6C remains IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 13.
- **Payroll + WPS** — Confirmed next functional module after Production Data Foundation.

- **Phase 2C / P6C Slice 13 (CUSTODIAN Party Display Name UPDATE)** — VERIFIED COMPLETE. ACCOUNTING_ADMIN-only existing ACTIVE/INACTIVE CUSTODIAN name update under unchanged P4 authorization; Development migration `20260922130000` applied. Focused hosted 115/115, concurrent exact-token 1/0, repository/provider and isolated Custodian/Supplier/OTHER/EMPLOYEE Chromium PASS; 37 migrations aligned, linked dry-run no-op and public DB lint clean. User-completed authenticated browser acceptance PASS: ACTIVE/INACTIVE CUSTODIAN name mutation, validation/normalization, controlled stale conflict, Alpha/Beta isolation, documented role matrix, open-edit downgrade, Company/membership/profile revocation and restoration, draft/focus/keyboard, EN/AR/RTL 390px responsive long-name wrapping, Party type boundaries and unchanged financial/P6D holding behavior. Exact guarded cleanup/final verification PASS: all Slice 13 fixture/Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. See `docs/P6C_SLICE_13_CUSTODIAN_PARTY_NAME.md` and `docs/verification/p6c-slice13/README.md`. P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 14.
- **Phase 2C / P6C Slice 14 (OWNER Party Display Name UPDATE)** — VERIFIED COMPLETE. ACCOUNTING_ADMIN-only existing ACTIVE/INACTIVE OWNER name update under unchanged P4 authorization; Development migration `20260922140000` applied. Focused hosted 115/115, concurrent exact-token 1/0, repository/provider and isolated Owner plus Supplier/OTHER/EMPLOYEE/CUSTODIAN Chromium PASS; 38 migrations aligned, linked dry-run no-op and public DB lint clean. User-completed authenticated browser acceptance PASS: ACTIVE/INACTIVE OWNER name mutation, validation/normalization, controlled stale conflict, Alpha/Beta isolation, documented role matrix, open-edit downgrade, Company/membership/profile revocation and restoration, draft/focus/keyboard, EN/AR/RTL 390px responsive long-name wrapping, Party type boundaries and unchanged owner-current-account/equity/payment/journal/P6D holding behavior. Exact guarded cleanup/final verification PASS: all Slice 14 fixture/Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. See `docs/P6C_SLICE_14_OWNER_PARTY_NAME.md` and `docs/verification/p6c-slice14/README.md`. P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 15.
- **Phase 2C / P6C Slice 15 (SUBCONTRACTOR Party Display Name UPDATE)** — VERIFIED COMPLETE. Existing ACTIVE/INACTIVE SUBCONTRACTOR name-only mutation for ACCOUNTING_ADMIN and PROCUREMENT under unchanged P4 authorization; Development migration `20260922150000` applied. Hosted 117/117, concurrent exact-token 1/0, repository/provider and isolated Chromium plus Supplier/OTHER/EMPLOYEE/CUSTODIAN/OWNER/Subcontracts regressions PASS; 39 migrations aligned, final dry-run no-op and public DB lint clean. Authenticated browser acceptance PASS, including validation, controlled stale conflict, tenant isolation, role/revocation/restoration, draft/focus/keyboard and EN/AR/RTL 390px behavior. The Subcontract displayed the renamed current Party identity without changing contract or financial truth. Closure found a verification-kit-only Project status mismatch: setup default PLANNING versus cleanup guard ACTIVE. Failed cleanup rolled back, guard was corrected to PLANNING, and exact cleanup/final verify PASSed. All Slice 15 fixture/Auth/profile counts 0; global Companies/settings 14/14, missing/orphan 0/0. P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 16.
- **Phase 2C / P6C Slice 16 (Subcontract Descriptive Metadata UPDATE)** — VERIFIED COMPLETE; Development gate closed. Existing `scope_of_work`, nullable start/end dates and notes only for ACCOUNTING_ADMIN and PROCUREMENT under unchanged `subcontract.manage`; ACTIVE/COMPLETED/CLOSED share the same descriptive boundary. Contract number, Company/Project/Subcontractor identity, economics, retention, status, provenance and every financial command/history surface remain protected. Development migration `20260923120000` applied. Hosted 41/41 rollback checks, exact-token concurrency 1/0, repository/provider, isolated Chromium, Slice 4/Party regressions, financial-history invariants, build/lint/boundaries, migration/DB checks and cleanup PASS; 40 migrations aligned and final automated integrity returned Companies/settings 14/14, missing/orphan 0/0. The operator accepted the primary real-browser smoke. Remaining extended manual role/UI coverage is recorded in `docs/PRE_DEMO_UAT.md` as non-blocking pre-demo UAT rather than a Development gate. No further required frozen P6C master-data operation is identified. Final checkpoint: **P6C Final Closeout / Boundary Audit COMPLETE** (see `docs/P6C_FINAL_CLOSEOUT.md`). P6C COMPLETE; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 17.

See `PROJECT_ROADMAP.md` for the full phase breakdown, binding decisions, and decision log.

Repository-root `AGENTS.md` is the binding engineering constitution for all future AI-agent and human work. Read it before meaningful changes; it defines source-of-truth precedence, frozen accounting invariants, financial-command/migration standards, proportional security priorities, stop conditions, and verification workflow.

## 4. Technology Stack (verified from `package.json`)

- React 19, TypeScript ~6.0, Vite 8
- Supabase JS 2.112 for the isolated P6A browser Auth/tenant path
- Tailwind CSS 4 (via `@tailwindcss/postcss`)
- React Router 7 (`react-router-dom`)
- Recharts 3 (Dashboard charts only)
- lucide-react (icons)
- `oxlint` for linting
- **The approved Development Supabase backend now has verified P2–P4 identity/master authorization and P5A–P5I accounting commands through Retention Release and Retention Payment.** Application accounting persistence remains `localStorage`; no frontend Supabase data path exists yet.

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
| `AGENTS.md` | Binding engineering constitution for every future agent/developer and batch. |
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
| `supabase/migrations/` | Canonical forward-only SQL history. P1–P5I are applied to Development. |
| `docs/P2_AUTHORIZATION.md` | P2 provisioning/system-admin design, authoritative active/inactive rules, frontend boundary, and remote Development authorization test matrix. |
| `docs/P3_MASTER_DATA.md` | P3 tables, code scopes, system-account strategy, cross-dimensional enforcement, security baseline, and Development verification. |
| `docs/P4_AUTHORIZATION.md` | P4 role/project policy matrix, assignment model, mutation boundaries, trusted pathways, and hosted verification. |
| `docs/P5A_ACCOUNTING_KERNEL.md` | P5A journal schema, invariants, private primitives, concurrency model, RLS/grants, and hosted verification. |
| `docs/P5B_EXPENSE_COMMANDS.md` | P5B expense lifecycle, funding/VAT rules, commands, authorization, and 64-case hosted verification. |
| `docs/P5C_SUPPLIER_PAYMENTS.md` | P5C payment/allocation schema, AP settlement rules, concurrency/reversal, RLS, and hosted verification. |
| `docs/P5D_CUSTODY_ADVANCES.md` | P5D pooled Custody Advance model, funding/reversal commands, Expense overspend guard, authorization, and hosted verification. |
| `docs/P5E_CUSTODY_SETTLEMENTS_RETURNS.md` | P5E Settlement grouping/no-repost rules, Cash Return accounting/reversal, pooled concurrency, RLS, and hosted verification. |
| `docs/P5F_SUBCONTRACTOR_ADVANCES.md` | P5F contract-scoped Advance accounting, lifecycle, recovery-aware reversal, RLS, and hosted verification. |
| `docs/P5G_SUBCONTRACTOR_CERTIFICATES.md` | P5G Certificate lifecycle, calculations, mapped deductions, recovery/concurrency, reversal, RLS, and hosted verification. |
| `docs/P5H_SUBCONTRACTOR_PAYMENTS.md` | P5H contract-scoped Payments/allocations, payable settlement, concurrency, Certificate dependency, reversal, RLS, and hosted verification. |
| `docs/P5I_SUBCONTRACTOR_RETENTION.md` | P5I Release and Retention Payment documents/allocations, accounting, concurrency, dependency chain, reversal, RLS, and hosted verification. |
| `docs/ENGINEERING_ACCOUNTING_RETROSPECTIVE_P0_P5G.md` | Focused constitution-based review, one P5F correction, accounting-treatment classifications, and P5H readiness. |
| `docs/MULTI_TENANT_WHITE_LABEL_ARCHITECTURE.md` | Binding one-codebase tenant isolation, white-label configuration, slug/context, deployment, and commercial-platform boundary. |
| `src/types/database.generated.ts` | Supabase CLI-generated TypeScript types for the verified public Development schema; do not edit manually. |
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

- Production Auth/session and active-tenant context are implemented in P6A. P6C exposes read-only active-Company profile and tenant-scoped Projects (Slice 1 verified), plus Parties and Expense Categories (Slice 2 VERIFIED COMPLETE), and Accounts/Treasury (Slice 3 VERIFIED COMPLETE), plus Subcontracts (Slice 4 VERIFIED COMPLETE) and Expense Categories mutations (Slice 5 VERIFIED COMPLETE), Supplier mutations (Slice 6 VERIFIED COMPLETE), and Company profile metadata updates (Slice 7 VERIFIED COMPLETE) in `supabase-auth`; remaining master work and all financial frontend flows remain unavailable pending later P6C/P6D work. The legacy accounting UI still uses localStorage only in development `local-demo` mode. Audit and remaining production cutover work are not implemented.
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
- P1–P10 order is frozen; P1–P5 are complete. A focused post-P5 financial retrospective is the next checkpoint before P6. Payroll follows completed Foundation; historical 2025/2026 import follows Payroll.
- P5I Retention Release and Retention Payment are complete. Any later flow requires separate review and has not started.
- The P0–P5G focused retrospective is complete. One P5F active-status locking race was corrected by `20260907120000_p5f_active_contract_lock.sql`; no other material pre-P5H blocker was found.
- A read-only Production Security & Accounting Integrity Audit is a binding future pre-go-live gate. It has not been performed and is not ordinary per-batch work.

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

Phase 1 ✅ → 2A ✅ → 2B.1 ✅ → 2B.1A ✅ → 2B.2 ✅ → 2B.3 ✅ → **P0–P5 ✅** → **post-P5 focused financial retrospective** → P6–P10 Foundation → 2D Payroll/WPS → 2E Historical Import/Opening Balances → later phases.

P6C is COMPLETE. P6D Checkpoint 1 Expense READ Foundation is Development-complete; P6D remains IN PROGRESS. Expense POST remains NOT STARTED and requires a separately bounded checkpoint. See `docs/P6D_EXPENSE_READ_FOUNDATION.md`. P6E NOT STARTED; Production readiness DEFERRED.

## 18. Remaining External Deployment Decisions

Only these require provider/company/legal/plan information and remain outside the architecture freeze:

1. Supabase region after confirming company/legal expectations for UAE data location.
2. Subscription plan and the automated-backup/PITR features actually available on that plan.
3. Company-approved RPO, RTO, backup/export retention and responsible recovery owners.
4. Final identity policy details such as required MFA and approved email domains, while no-public-signup remains binding.

Inventorying real localStorage datasets is required operational work in P9, not an unresolved architecture decision. Ambiguous pooled cash/bank treatment is already frozen: preserve provenance and review; never guess.

## 19. Deferred Work

Payroll/WPS implementation (confirmed immediately after Foundation), bulk historical import/opening balances, client certificates/receivables/revenue recognition, consolidation, automatic Retention Release eligibility or alternative/direct retention-settlement models, finalized Custody Settlement correction, and complex legacy corrections. Optional future funding extensions include Supplier Payment from Owner Current/Custody, Custody Advance from Owner Current, Custody Cash Return to Owner Current, and a dedicated Owner Current settlement/reimbursement command. Public signup and offline multi-master accounting are not planned.

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

## 22. P2 Identity and Authorization Implementation (2026-08-27)

P2 is complete. The approved `MakerACC-Development` project is linked, all four P1/P2 migrations are applied, hosted public signup and anonymous sign-ins are disabled, the synthetic Auth/RLS matrix passes, and CLI-generated public database types are committed at `src/types/database.generated.ts`. No Staging, Production, real employee, or accounting data was used.

- **Profiles:** `public.profiles` is a 1:1, delete-restricted child of `auth.users`, containing only display name, email snapshot, `ACTIVE|INACTIVE` status, `en|ar` locale and timestamps. An `AFTER INSERT` Auth trigger creates it in the Auth transaction, normalizing untrusted metadata and copying no credentials. A user can select only their own profile and cannot write it directly.
- **Company parent at P2:** P2 initially created only `id`, `code`, `name`, status and timestamps. P3 has now extended that same authorization parent; no duplicate company table exists.
- **Memberships:** `public.company_memberships` carries company, Auth user, frozen role, status and actor/timestamp columns. A partial unique index prevents two active memberships for one user/company while preserving inactive history. Browser roles can select only their own membership rows and receive no INSERT/UPDATE/DELETE grants or policies.
- **Roles/permissions:** all seven frozen roles are a PostgreSQL enum. Ten stable permissions are rows in `permissions`, with the role mapping in protected `role_permissions`. `certificate.approve_post` maps only to `ACCOUNTING_ADMIN`, not `ACCOUNTANT` or `SYSTEM_ADMIN`. `SYSTEM_ADMIN` is limited to `company.manage`/`users.manage`. The mapping is server-owned; no browser write path exists.
- **Active rule:** normal company access requires an authenticated caller, `ACTIVE` profile, `ACTIVE` membership, and `ACTIVE` company. `is_active_user`, `is_company_member`, `has_company_role`, and `has_permission` are stable `SECURITY DEFINER` helpers with an empty fixed search path and minimal authenticated EXECUTE grants. They derive the actor from `auth.uid()`.
- **RLS/privileges:** every P2 public table has RLS forced. Profiles and memberships expose only the caller's row(s); companies require active membership; permission definitions require an active profile; role mappings are available only through `has_permission`. `anon` receives no table/function privileges. Security tables have no direct browser mutation grants.
- **System admin:** the browser-visible `SYSTEM_ADMIN` role never bypasses company membership. The separate `private.system_administrators` registry has no browser schema/table access and is reserved for an explicit trusted service/Edge Function pathway with MFA and P7 audit. No service credential enters the browser.
- **Invitations:** public signup and anonymous sign-ins are disabled in local and hosted Development configuration. Admin create/invite remains a trusted server/operator operation; the exact lifecycle and partial-failure handling are documented in `docs/P2_AUTHORIZATION.md`.
- **Project access:** P3 supplied the real production project parent; P4 now supplies the FK-backed assignment model and Project Manager policy enforcement. No dummy project or broad membership-only production policy remains.
- **Frontend:** deliberately unchanged. Accounting continues through the localStorage demo adapter and locale remains local. A login shell without a verified backend would misleadingly associate local demo books with a real tenant; Auth/session UI and profile-locale synchronization are deferred to the async integration boundary.
- **Types:** `src/types/database.generated.ts` was generated from the successfully applied linked public schema using Supabase CLI 2.115.0. It is not yet consumed by the localStorage frontend.

Remote verification used nine synthetic `example.invalid` Auth identities across all frozen roles and two synthetic companies. Admin Auth creation, 9/9 profile triggers/defaults, own-profile access, active membership, cross-company UUID guessing denial, membership/role write denial, duplicate-active rejection, inactive profile/membership revocation, certificate permission for every role, anonymous denial, public-signup denial and System Admin isolation all passed. Linked migration status contains `20260826193204`, `20260827120000`, `20260828120000`, and `20260828123000`; a final dry-run is up to date and database lint reports no schema errors.

The first live run found that new-project privilege defaults left the trusted `service_role` provisioning pathway unable to insert tenant identity records. The forward-only `20260828120000` migration grants server-only SELECT/INSERT/UPDATE while withholding DELETE and permission-map mutation. Security advisors also found the provider-managed `rls_auto_enable()` event-trigger helper browser-callable by default; `20260828123000` revokes that unnecessary access. Remaining advisor warnings are expected for the four authenticated authorization helpers; leaked-password protection is recommended but not a frozen P2 exit requirement.

P2's original next task was P3, which is now complete. Current next task is P4 — RLS and Authorization.

## 23. P3 Core Production Master Data (2026-08-27)

P3 is complete through `supabase/migrations/20260829120000_p3_core_master_data.sql`, applied only to `MakerACC-Development` with synthetic data.

- Extended the P2 `companies` table with legal name, TRN, address, notes and actor UUIDs. Company codes are globally case-insensitive unique.
- Added `projects`, `parties`, `expense_categories`, `accounts`, `treasury_accounts`, and `subcontracts`, with database timestamps and nullable Auth actor metadata. No transaction, certificate, payment, journal or audit-event table was added.
- Project status is `PLANNING|ACTIVE|ON_HOLD|COMPLETED|CLOSED`; party type is `OWNER|CUSTODIAN|SUPPLIER|EMPLOYEE|SUBCONTRACTOR|OTHER`; treasury type and subcontract status match the current frontend domain.
- Project contract value/budget and subcontract original value/variations are `BIGINT` minor units. Retention is 0–10,000 integer basis points. Revised subcontract value is derived and constrained non-negative.
- Account classification is `ASSET|LIABILITY|EQUITY|REVENUE|EXPENSE`. Optional per-company unique `system_key` is the stable future posting resolver; display names and hardcoded UUIDs are never authoritative. Treasury rows instead have their own immutable one-to-one ASSET GL links.
- Composite FKs enforce company consistency across projects, parties, account parents, treasury GL/project and subcontract project/party. Fixed-search-path triggers freeze treasury company/GL identity, validate ASSET mapping, require valid active subcontractors/open projects for new contracts and protect referenced party type.
- Codes are trimmed/case-insensitive unique: company globally; project/party/category/account/treasury within company; contract number within project. Important parents use `ON DELETE RESTRICT`; server DELETE grants are withheld.
- Every P3 table shipped with forced RLS and an active-membership read baseline. P4 has now replaced it with role/project-aware reads and explicit narrow browser writes; anon access and browser DELETE remain absent.
- Synthetic verification passed every requested master-data constraint, wrong-company/type/retention case, distinct/immutable treasury mapping, tenant-isolation smoke test, browser/anon denial and service-delete denial. Final migration dry-run is current and database lint has no errors.
- Generated public types were refreshed at `src/types/database.generated.ts`. The React/localStorage application and accounting logic remain unchanged; build and lint pass.

Full field/strategy documentation is in `docs/P3_MASTER_DATA.md`. P4 authorization is documented separately in `docs/P4_AUTHORIZATION.md`.

## 24. P4 RLS and Authorization (2026-08-27)

P4 is complete through `20260830120000_p4_rls_authorization.sql` and two forward corrections, applied only to `MakerACC-Development`.

- Added `project_assignments` with same-company project enforcement, one-active-assignment uniqueness, active target profile/membership validation, and administrator-only mutation.
- Replaced P3's broad member-read baseline with role-aware company/project policies. Project Managers are assignment-scoped; Accounting Admin, Accountant, Data Entry, Procurement, Management Viewer, and System Admin have the documented distinct boundaries.
- Added narrow permissions for party, category, account, subcontract, and project-assignment administration. Permission maps remain protected and all identity derives from `auth.uid()`.
- Tenant ownership is immutable after creation, browser DELETE remains absent, and cross-company project/party/account/treasury/subcontract relationships continue to be rejected by database constraints and triggers.
- The first hosted run found assignment validation could not inspect protected target identity rows; `20260830123000` makes that trigger lookup fixed-search-path security-definer while keeping browser EXECUTE revoked. The next run found a newly inserted project could not satisfy its return-row helper snapshot; `20260830124500` makes the project row policy equivalent and row-local while preserving strict direct-helper semantics.
- The final hosted matrix passed all 46 required tenant, role, project, mutation, escalation, and dimensional checks plus four helper/profile hardening checks. Only synthetic Development data was used. Generated public types were refreshed.

Full policy, role, trusted-pathway, and matrix documentation is in `docs/P4_AUTHORIZATION.md`. P5A now supplies the journal kernel without changing P4 authorization.

## 25. P5A Accounting Kernel and Journal Core (2026-08-28)

P5A is complete through `20260831120000_p5a_accounting_kernel.sql` and two forward corrections, applied only to `MakerACC-Development`.

- Added immutable posted `journal_entries` and `journal_lines` using `BIGINT` AED minor units and account/project/party/treasury/subcontract dimensions.
- Added immediate private balance validation plus independently deferred transaction-end constraint triggers.
- Added private atomic company/type/year reference counters, SHA-256 idempotency reservations, source-posting uniqueness, row locking, completion invariants, and dimension-preserving reversal.
- Generic primitives are in `private`, have fixed empty search paths, and have no browser/service EXECUTE grants. Browser and service roles receive journal SELECT only; accounting-role RLS limits raw reads.
- Hosted tests passed all 42 required journal, balance, dimension, immutability, reversal, idempotency, concurrency, source, reference, role, anonymous, and write-denial checks.
- `20260831123000` corrected a deferred-trigger row-shape issue found before synthetic data committed. `20260831124500` removed provider-default service `TRUNCATE/TRIGGER/REFERENCES` privileges, leaving SELECT only.
- No business transaction table, specialized posting command, frontend integration, Payroll, or import work was added.

Full implementation and verification details are in `docs/P5A_ACCOUNTING_KERNEL.md`. P5A's private kernel now supports the completed P5B expense boundary; P5 overall remains in progress.

## 26. P5B Expense Documents and Commands (2026-08-28)

P5B is complete through `20260901120000_p5b_expense_commands.sql`, applied only to `MakerACC-Development`.

- Added company-scoped immutable `expenses` with `DRAFT`, `POSTED`, and `REVERSED` states. Draft is an internal atomic transition only; browser draft CRUD was not introduced.
- Added specialized `post_expense` and `reverse_expense` RPCs. Generic P5A primitives remain private and browser/service execution remains revoked.
- Posting supports Treasury, Custodian, Owner, and Supplier Credit funding. It resolves expense, recoverable VAT, treasury, custodian control, owner current, and supplier payable accounts by stable `system_key`/master identity.
- Recoverable VAT requires an invoice flag and invoice number. Without qualifying evidence VAT must be zero; non-recoverable tax is included in expense cost. Auto 5% and manual VAT are validated and calculated server-side in integer minor units.
- `ACCOUNTING_ADMIN` and `ACCOUNTANT` may post; only `ACCOUNTING_ADMIN` may reverse. Management viewers receive company-wide read-only access; project managers see assigned-project expenses only; all other roles and anonymous users receive no rows.
- Hosted verification passed all 64 posting, funding, VAT, validation, cross-tenant, idempotency, concurrency, reference, immutability, reversal, role/RLS, anonymous, journal-write, and private-RPC checks. Trusted SQL confirmed no orphan, duplicate-source, or unbalanced P5B journals.
- Supplier payments, custody funding/settlements/returns, subcontract flows, frontend cutover, Payroll, and import remain outside this batch.

Full implementation and verification details are in `docs/P5B_EXPENSE_COMMANDS.md`. P5B now provides the Supplier Credit sources settled by completed P5C; P5 overall remains in progress.

## 27. P5C Supplier Payments (2026-08-28)

P5C is complete through `20260902120000_p5c_supplier_payments.sql` and forward correction `20260902123000_p5c_explicit_payment_total.sql`, applied only to `MakerACC-Development`.

- Added immutable company-scoped `supplier_payments` and `supplier_payment_allocations`. Allocations link only live posted P5B Supplier Credit expenses for the same company and supplier.
- Supplier Payment is Treasury-only liability settlement: debit Supplier Payable by source-project grouping and credit the selected Treasury's permanent GL. It never posts cost or VAT.
- Source-expense locks and active posted-allocation sums prevent concurrent overpayment. Reversed payments retain allocation history but restore outstanding payable.
- Existing liabilities remain payable after a Project is closed or Supplier becomes inactive. New P5B Supplier Credit cost remains subject to P5B active/open rules. An allocated Supplier Credit expense cannot be reversed until its active payments are reversed.
- Accounting Admin and Accountant may post; only Accounting Admin may reverse. Management Viewer is read-only. Project Manager, Procurement, Data Entry, System Admin, and anonymous users receive no raw payment access or command authority.
- All required 64 hosted cases plus four hardening cases passed across two synthetic tenants. Trusted reconciliation found no amount mismatches, overallocations, invalid sources, orphan/duplicate/unbalanced journals, or cost/VAT payment lines.
- Frontend supplier-payment behavior remains localStorage-only; no Auth UI, tenant selector, white-label UI, custody, subcontract, Payroll, AR/revenue, or import work was added.

Full details are in `docs/P5C_SUPPLIER_PAYMENTS.md`. P5 remains in progress; the next custody-related command batch requires separate review.

## 28. P5D Custody Advance Funding (2026-08-28)

P5D is complete through `20260903120000_p5d_custody_advances.sql`, applied only to `MakerACC-Development`.

- Added immutable company-scoped `custody_advances` and atomic post/reverse commands. Funding is Treasury-only: Dr Custody Advance control / Cr Treasury permanent GL, with no cost or VAT.
- Production custody is pooled by `(company, Custodian)`. Project is an analytic journal/document dimension, not an advance allocation bucket; multiple advances and Custodian Expenses reconcile through the party-scoped control balance.
- The compatible P5B `post_expense` boundary now locks the Custodian and rejects gross Custodian Expenses above the pooled balance, including competing concurrent calls.
- A posted Advance may reverse only while the current pooled balance can absorb its full inversion. This prevents a consumed sole Advance from driving custody negative while retaining exact P5A reversal provenance.
- Accounting Admin and Accountant may post; only Accounting Admin may reverse; Management Viewer is read-only. All other browser roles and anonymous callers are denied, with forced RLS and no direct financial writes.
- All 66 hosted funding, accounting, validation, idempotency, concurrency, immutability, reversal, authorization, and two-tenant cases passed. Database lint added no P5D warning; generated types were refreshed.
- P5E settlement/cash return, Owner Current funding, Custody-funded Supplier Payments, subcontracts, frontend cutover, Payroll, AR/revenue, and import remain outside P5D.

Full details are in `docs/P5D_CUSTODY_ADVANCES.md`. P5E subsequently completed the custody cycle described below.

## 29. P5E Custody Settlement and Cash Return (2026-08-28)

P5E is complete through `20260904120000_p5e_custody_settlements_returns.sql` and forward correction `20260904123000_p5e_settlement_expense_variable.sql`, applied only to `MakerACC-Development`.

- Added immutable `custody_settlements` and `custody_settlement_items`. The atomic finalization command groups eligible posted P5B Custodian Expenses across Projects, derives the exact gross total, prevents double settlement, and creates zero journals.
- Added immutable Treasury-only `custody_cash_returns`: Dr Treasury permanent GL / Cr Custody Advance control. Returns have no Project, cost, Company Expense, or VAT line.
- Pooled balance remains journal-derived by company/Custodian. Cash Return and P5B Custodian Expense use the same Custodian-row lock, preventing Return/Return and Return/Expense concurrency from overdrawing custody.
- Inactive Custodians can settle and return existing balances; closed-Project Expenses remain settleable. New Advances/Expenses retain their earlier active/open guards.
- Cash Return reversal is exact P5A inversion and safely restores custody without a downstream dependency guard. Settlement has no financial reversal; cancellation/correction remains deferred and finalized history is immutable.
- The first hosted Settlement call exposed an ambiguous PL/pgSQL variable; the transaction rolled back and the forward correction renamed/qualified it. The definitive hosted matrix passed 82/82 cases.
- Trusted reconciliation found zero Settlement total mismatches or Settlement journals and zero Return orphan/unbalanced/cost/VAT/duplicate-source or pooled-balance mismatches. Types were refreshed and P5E added no frontend path.

Full details are in `docs/P5E_CUSTODY_SETTLEMENTS_RETURNS.md`. P5F subsequently added the separately reviewed Subcontractor Advance command described below.

## 30. P5F Subcontractor Advance (2026-08-29)

P5F is complete through `20260905120000_p5f_subcontractor_advances.sql` and forward correction `20260905123000_p5f_advance_account_compatibility.sql`, applied only to `MakerACC-Development`.

- Added immutable `subcontractor_advances`, atomic `post_subcontractor_advance` and Accounting Admin-only `reverse_subcontractor_advance`, forced RLS, read-only browser grants, stable-key account resolution, P5A reference/idempotency integration, and exact journal inversion.
- Advances are recoverable Assets: Dr `SUBCONTRACTOR_ADVANCE`, Cr selected Treasury permanent GL. They create no Project cost, VAT, retention, payable, Certificate, deduction, or recovery.
- Company, Project, Subcontractor Party, Subcontract, and Treasury relationships are structurally constrained. Balance and reversal dependency are derived from journals by company plus Subcontract, never pooled only by party. Future recovery must credit that same control account and Subcontract scope.
- Original P5F preserved local `ACTIVE`/`COMPLETED` Advance behavior. Pre-P5G review found no approved reason for new funding after completion, so forward migration `20260906120000` now requires an `ACTIVE` Subcontract. Existing Advances and final accounting remain valid. Active Subcontractor and active Asset Treasury/GL are mandatory. No unapproved contract-value cap was invented.
- A narrow forward correction removed an unnecessary generic `requires_party` master-flag prerequisite; the command still always writes the mandatory Party dimension. The missing synthetic Company A stable-key account was added only as hosted fixture data.
- The definitive hosted matrix passed 108/108 posting, contract-isolation, lifecycle, validation, idempotency, reversal, authorization, RLS, tenant, and reconciliation cases. The mandatory same-Subcontractor/two-contract balances remained 12,001 and 23,002 minor units independently, with a 35,003 party aggregate.
- Trusted reconciliation found zero orphan, unbalanced, non-two-line, missing-Subcontract, cost, VAT, payable, or retention journal defects. Generated types were refreshed; no frontend Supabase path was added.

Full details are in `docs/P5F_SUBCONTRACTOR_ADVANCES.md`. P5G subsequently completed the separately reviewed Certificate command described below.

## 31. P5G Subcontractor Certificates (2026-08-29)

P5G is complete through pre-P5G correction `20260906120000_p5f_active_contract_advances.sql` and `20260906123000_p5g_subcontractor_certificates.sql`, applied only to `MakerACC-Development`.

- New Advance funding now requires an `ACTIVE` Subcontract. This forward-only correction changes no historical P5F document and preserves final Certificate/recovery/payment cleanup on `COMPLETED` contracts.
- Added immutable no-GL Certificate drafts, normalized immutable deductions, trusted company/type deduction-account mappings, Accounting Admin-only approval/posting, and Accounting Admin-only exact reversal.
- Posting debits Subcontract Project Cost and evidence-qualified Input VAT; it credits Retention, same-contract Advance recovery, mapped deduction Revenue, and residual Subcontractor Payable. It creates no Treasury movement.
- The database derives prior work, current/gross work, contract retention bps, deductions, VAT, recovery availability, and payable. Live cumulative gross cannot exceed revised Subcontract value. The Subcontract row lock serializes cumulative certification and recovery.
- `ACTIVE` and `COMPLETED` contracts may be certified; `CLOSED` contracts and closed Projects cannot. Inactive Subcontractors with existing contracts may still have real obligations recognized.
- P5G reversal restores cost, VAT, Retention, Advance, deductions, and payable by exact inversion. P5H now blocks Certificate reversal while live Certificate payments exist.
- The definitive hosted matrix passed 134/134 cases. Trusted reconciliation found zero orphan links, unbalanced journals, duplicate sources, Treasury lines, or missing contract dimensions. Types were refreshed and the frontend remained localStorage-only.

Full details are in `docs/P5G_SUBCONTRACTOR_CERTIFICATES.md`. P5H subsequently added the separately reviewed Payment settlement and dependency below.

## 32. Engineering Constitution and Focused P0–P5G Retrospective (2026-08-29)

- Added binding repository-root `AGENTS.md` and reconciled roadmap/handoff/architecture memory.
- Focused actual code/migration review covered tenant ownership and RLS, financial grants/permissions, P5A journal invariants, P5B–P5G command locking/idempotency/dependencies, dimensions, white-label readiness, migration history, and documented accounting treatments.
- Confirmed one reachable P5F race: the active-only wrapper did not lock before delegating to the older implementation. `20260907120000_p5f_active_contract_lock.sql` now locks the Subcontract and validates `ACTIVE` in the same serialized boundary. Existing history is unchanged; focused hosted regression passed 9/9.
- P5G deduction Revenue mapping is verified current product policy: all three local fixed deduction accounts were Recovery/Income credits and SQL preserves that policy through trusted per-company Revenue mappings. Retention basis, VAT waterfall, cumulative certification, and pre-P5H reversal assumptions are internally consistent with the accepted P5G model.
- At retrospective completion, no Critical/High finding or decision-required accounting ambiguity remained and P5H was ready for separate authorization; P5H was subsequently completed as documented below.
- The future Production Security & Accounting Integrity Audit remains mandatory before real production data/go-live and was not performed here.

## 33. P5H Subcontractor Payments (2026-08-29)

P5H is complete through `20260908120000_p5h_subcontractor_payments.sql`, applied only to `MakerACC-Development`.

- Added immutable one-Subcontract `subcontractor_payments` and Certificate-level `subcontractor_payment_allocations`. Multiple partial Payments and one Payment across multiple same-contract Certificates are supported without pooling contracts for the same Party.
- Posting is exactly Dr stable-key `SUBCONTRACTOR_PAYABLE` / Cr the selected Treasury's permanent GL. It repeats no Project Cost, VAT, Retention, Advance recovery or deduction and never settles Retention.
- Outstanding is derived from immutable Certificate payable less allocations of live POSTED Payments. A Subcontract-first lock plus deterministic Certificate locks prevents competing Payments from overpaying; P5A idempotency handles identical concurrency and atomic `SCPAY` references.
- Existing liabilities remain settleable after Project/Subcontract closure/completion or Subcontractor inactivation. Active same-company Treasury and Project-Treasury compatibility remain mandatory.
- Payment reversal is exact P5A inversion and retains allocation history while restoring outstanding. Certificate reversal now shares the Subcontract-first lock order and is blocked while any live Payment allocation exists; eligibility returns after all consuming Payments reverse.
- Forced RLS permits company-scoped reads only to Accounting Admin, Accountant and Management Viewer. Accounting Admin/Accountant may post; only Accounting Admin may reverse. Direct financial writes, operational roles, System Admin bypass, other tenants, anonymous callers and private-kernel execution remain denied.
- The definitive hosted matrix passed 95/95. Its first 94/95 run exposed only an incorrect reconciliation assumption about P5A `JOURNAL_REVERSAL` classification; the query was corrected without a schema change. Trusted reconciliation then found zero orphan, balance, forbidden-account, duplicate-source, allocation-total or contract-dimension defects. Generated types were refreshed and the frontend remained unchanged.

Full details are in `docs/P5H_SUBCONTRACTOR_PAYMENTS.md`. P5I-A subsequently added the separately reviewed Retention Release foundation below.

## 34. P5I-A Retention Release Foundation (2026-08-30)

P5I-A is complete through `20260909120000_p5i_retention_releases.sql`, applied only to `MakerACC-Development`.

- Added immutable one-Subcontract Retention Releases and Certificate-level allocations. Live availability is authoritative Certificate retention less allocations of live POSTED Releases; partial, staged and same-contract multi-Certificate allocation shapes are supported.
- Posting is exactly Dr `SUBCONTRACTOR_RETENTION_PAYABLE` / Cr `SUBCONTRACTOR_PAYABLE`, preserving Project, Party and Subcontract dimensions with no Treasury, Cost, VAT, Advance recovery or deduction reposting.
- Subcontract-first locking plus deterministic Certificate locks prevents concurrent over-release. P5A request hashing/idempotency and atomic `SCREL` references provide retry and numbering safety.
- Existing retention remains releasable through Project closure, Subcontract completion/closure and Subcontractor inactivation. Accounting Admin alone may release/reverse; Accountant and Management Viewer are company-scoped read-only.
- Exact reversal retains allocations and restores availability. A live Release allocation blocks Certificate reversal; after Release reversal that dependency clears while P5H dependencies remain independently enforced.
- Forced RLS, read-only browser grants, immutable history triggers and private-kernel grants were verified. Focused hosted synthetic runs passed all executed assertions, including concurrent consumption, exact journals/reversal, idempotency, authorization and direct-write denial. DB lint, generated types, build and lint were refreshed/clean except unchanged frontend warnings.

P5I-B adds immutable Retention Payments and Release-level allocations. Posting is Dr Subcontractor Payable / Cr selected active Treasury; it repeats no Retention, Cost, VAT, Advance recovery or deductions. Subcontract-first/deterministic Release locks enforce authoritative released-but-unpaid balances, and P5A supplies atomic `SRPAY` references, idempotency and exact reversal. Live Payments block Release reversal; reversing all consumers restores Release eligibility. Accounting Admin and Accountant may post; only Accounting Admin may reverse. Forced RLS and direct-write denial preserve the established read-only role boundary.

Focused hosted verification passed all executed posting, allocation, concurrency, idempotency, reference, journal, reversal, dependency, authorization, RLS and immutability assertions. Final whole-scope P5I reconciliation found no orphan, unbalanced, duplicate-source, allocation-total, forbidden-account or dimension defects. Generated types were refreshed and the frontend remained unchanged.

Full details are in `docs/P5I_SUBCONTRACTOR_RETENTION.md`. The P5I integration/reconciliation and P5 closure reviews are complete. P5 is formally closed; the focused post-P5 financial retrospective is next before P6.

### Post-P5 focused review (2026-08-30)

The required P5H/P5I checkpoint is complete. Static review plus a 42-assertion hosted combined interaction matrix verified that ordinary Certificate Payments and Retention Releases independently block Certificate reversal, reversing only one chain does not clear the other, live Retention Payments block Release reversal, and full downstream reversal restores eligibility in order. An 18-check whole-scope reconciliation covered 48 Certificates, 23 P5H Payments, 21 Releases, 24 Retention Payments and 107 linked journals with no source, balance, orphan, over-settlement, forbidden-account, dimension or control-account mismatch.

No material defect, migration correction or new accounting-policy decision was required. The known P5C unused-variable lint warning remains non-blocking. Full evidence and classifications are in `docs/POST_P5_FOCUSED_REVIEW.md`. The full Production Security & Accounting Integrity Audit remains a future pre-production gate.

### P6A Auth session and tenant context (2026-08-31)

P6A is implemented with explicit `local-demo` and `supabase-auth` modes. The demo route tree is development-only and lazy; the production Auth dependency graph cannot import the local accounting context, repositories, migrations, seed path, or accounting pages. Production configuration fails closed. Supabase password Auth restores and synchronizes sessions, validates JWT claims, and loads the active profile/memberships/Companies through existing P2 RLS. Zero/one/multiple membership resolution, revalidated per-user tenant preference, switching, protected routes, local-scope logout, bilingual states, focus/retry revalidation, and stale-request invalidation are present. Auth mode deliberately exposes only a tenant-ready cutover-pending shell and performs no master/financial writes.

No database migration was added. Automated build, lint and static import-boundary verification pass. The hosted browser smoke matrix completed on 2026-09-04 using synthetic Development-only users and verified Auth/routing, zero/one/multiple tenant resolution, inactive profile/membership/Company exclusion, tenant switching and preference validation, logout/session behavior, focus revalidation, language/RTL/keyboard smoke behavior, localStorage/demo isolation, and absence of master/financial requests or privileged browser secrets. Duplicate submission and invalid persisted-session behavior also passed. The deliberately timed stale-response race remains best-effort/not practically reproducible, with deterministic generation/user/session guards confirmed in source and supporting runtime revocation/logout evidence. No confirmed P6A defect remains. On 2026-09-05, the five P6A memberships, three Companies, four profiles and four Auth users were removed only from Development and verified absent; targeted temporary P6A browser keys were also removed while all `cas:v1:*` data remained. See `docs/P6A_AUTH_TENANT_CONTEXT.md`.

### P6B tenant settings and white-label foundation (2026-09-05)

P6B is implemented through `supabase/migrations/20260911120000_p6b_company_settings.sql` and forward correction `20260911123000_p6b_collision_safe_slugs.sql`, applied only to `MakerACC-Development`. The Company-owned one-to-one settings row has a deterministic collision-safe slug, optional presentation name and HTTPS asset references, profile-compatible default locale, bounded color tokens, forced active-membership RLS, and authenticated SELECT only. Existing Companies were backfilled by the migration; settings deletion cascades only from a legitimately deleted Company, while actor metadata uses `ON DELETE SET NULL`.

The production Auth branch loads settings only after P6A resolves an authorized tenant. Its separate provider has loading/ready/missing/error states, session/user/Company/request guards, synchronous neutral presentation reset, and no settings mutation. Title, favicon, logo/fallback, shared identity, and fixed CSS variables are driven by the normalized model. The demo uses a separate provider with no Supabase or new localStorage repository. No master/financial repository or P5 behavior changed.

Migration alignment, linked no-op dry-run, generated public types, database lint, build, lint and static boundary checks pass. The controlled hosted constraint/RLS matrix and complete Auth/demo branding/isolation smoke pass. Repeated recovery/selection testing confirmed that `TENANT_READY` could render at stale `/no-company` or `/select-company` paths because its wildcard accepted obsolete Auth-state URLs. The ready route table now declaratively replaces all special Auth-state paths with `/`; ordinary protected accounting URLs still render only the holding shell, and the focused post-fix route re-smoke passed. Valid/broken assets, missing settings, locale/RTL, transitions, revocation/recovery, local-demo isolation, and final network/console boundaries are verified. P6B is verified complete. Post-closure cleanup removed only the exact P6B Development fixtures and temporary `makeracc:p6a:*` browser keys; all 15 `cas:v1:*` keys remain, and final database integrity is 14 Companies/14 settings with zero missing or orphan rows. See `docs/P6B_TENANT_SETTINGS_WHITE_LABEL.md`. P6C subsequently began; P6D–P6E have not started.

### P6C Slice 1 — Company and Projects production reads (2026-09-06)

P6C is in progress. A separate `src/master` production graph now defines mapped Company/Project view models, explicit tenant-scoped Supabase read functions, normalized query errors, and a keyed/scoped provider with request-generation, mount, live-session, authenticated-user, and active-Company checks. Its visible state becomes `LOADING` immediately whenever the user/Company scope differs, so old tenant data cannot render while a new request starts; late results cannot commit after switching, logout, invalidation, or unmount.

The production `/` and `/projects` routes show loading, populated, valid-empty, missing-Company, and query-failure states. The header uses the loaded Company business profile when ready while retaining P6B branding. Other protected routes—including `/expenses` and `/journal`—remain explicit cutover-deferred shells and import no demo financial behavior. The local-demo graph and all `cas:v1:*` repositories are unchanged.

No migration, RLS/grant change, mutation, financial query/RPC, localStorage fallback, hosted data change, or Staging/Production action occurred. Build, lint, the existing P6A boundary check, the new P6C boundary check, and source review pass; lint reports only established Fast Refresh warnings. Hosted Development and browser/Auth tenant-switch verification remain pending, so neither this slice nor all P6C is marked verified complete. The next controlled slice should first verify this read path, then add only the separately authorized P6C entities.

The subsequent verification-only pass repeated build/lint/P6A/P6C/diff and focused source checks successfully. The local browser-safe configuration was confirmed to match the linked Development project; anonymous Data API requests to `companies` and `projects` both returned HTTP 401. An isolated signed-out Chromium load of `/projects` settled at the production sign-in screen and did not expose the demo shell. Prior test identities were cleaned up and `.env.local` contains no test-user credential, so authorized Company/Project reads, role-filtered visibility/empty state, A→B switching, revocation, and authenticated network/console cases remain pending manual verification. No fixture was created and no Slice 1 defect was found in the evidence completed so far.

On 2026-09-12, the explicitly authorized temporary P6C Slice 1 browser fixture was added only to `MakerACC-Development` for final manual verification. Auth user `b432e44f-f0c9-4689-8527-ffacaef5bbfb` has an active profile and `MANAGEMENT_VIEWER` memberships in deterministic Companies `70000000-0000-4000-8000-0000000000a1` (P6C Alpha, one deterministic Project `70000000-0000-4000-8000-0000000000c1`) and `70000000-0000-4000-8000-0000000000a2` (P6C Beta, zero Projects), with distinct P6B settings. Post-creation checks returned exact 1/2/2/2 profile/Company/membership/settings counts, 1/0 Alpha/Beta Project counts, zero fixture financial rows, and global 16 Companies/16 settings with no missing/orphan row. A read-only authenticated-role RLS simulation saw only those two Companies/settings/memberships and Alpha's Project; final password-based browser verification remains pending. Do not delete this fixture before Prompt 5 verification; afterward use explicit guarded cleanup and remove the Auth user manually only after its profile is deleted. No password is stored in repository documentation.

The first authenticated Slice 1 browser pass verified Alpha's mapped Company/Project data, Beta's tenant-isolated empty state, tenant switching without stale data, branding/locale direction, Beta session restoration, deferred financial routes, logout clearing, and production/demo isolation. It also exposed a confirmed P6A interaction defect: routine focus/visibility revalidation changed global Auth state from `TENANT_READY` to blocking `LOADING_IDENTITY`, unmounting the keyed P6B/P6C provider tree and visibly reloading branding and master data despite unchanged authority. The focused remediation keeps valid `TENANT_READY` state mounted during background revalidation, while claims/profile/membership/active-Company checks still run and discovered invalid authority still transitions fail-closed. Explicit retry and Company selection remain foreground transitions; a changed Company still changes the provider scope key and invalidates old master state. Build, lint (only the four established Fast Refresh warnings), P6A/P6C boundary checks, and diff checks pass. Final authenticated browser re-test of the focus/visibility behavior is still pending, so Slice 1 remains in progress and its Development fixture is preserved.

The first remediation was incomplete in runtime: one tab return could dispatch both application `visibilitychange` and `focus` handlers, while Supabase Auth's own visibility recovery re-emitted `SIGNED_IN` for the already-known user. The duplicate application triggers were not coalesced, and the same-user `SIGNED_IN` was still classified as a new foreground login. That later transition to `LOADING_IDENTITY` unmounted P6B/P6C, explaining the observed settings/master reload followed by blocking secure loading. The second focused remediation gives background authority checks one shared in-flight generation, ignores only redundant same-known-user `SIGNED_IN` events, and retains the existing foreground paths for initial/different-user sign-in and `USER_UPDATED`. An unchanged successful authority result now also preserves the existing Auth state object. Local Supabase Auth source confirms that `SIGNED_IN` is intentionally emitted when a tab is refocused. Automated gates pass again, but authenticated browser proof remains pending; the fixture remains intact.

Final authenticated post-fix acceptance passed on 2026-09-12. Repeated tab-away/return produced only the P6A profile, membership, and Company authority reads: no blocking Auth or settings loader, branding flash, Project disappearance, `company_settings` request, P6C Company-profile request, or Projects request occurred. A controlled Development-only `ACTIVE` → `INACTIVE` profile transition was detected on focus and immediately removed tenant branding/master data and routed fail-closed to `/no-company`; after restoring `ACTIVE`, Retry safely rebuilt Company selection with both memberships. This verifies that background UX preservation did not weaken authority revocation.

P6C Slice 1 is **VERIFIED COMPLETE**; overall P6C remains in progress. Exact guarded cleanup then removed the synthetic P6C Companies, settings, memberships, Project, and profile, with zero fixture rows remaining. Global Development integrity returned to 14 Companies/14 settings, zero Companies missing settings, and zero orphan settings. The synthetic Auth user `b432e44f-f0c9-4689-8527-ffacaef5bbfb` was manually removed from Authentication. No P6C fixture remains. No migration, RLS/grant change, master mutation, financial-flow cutover, Staging/Production action, or P6C Slice 2 work occurred.

### Future contracting operations module — documentation only

The roadmap records a future **Construction Materials / Site Stores + Tool Custody** module without assigning it a phase or changing the existing execution order. Site Materials covers item registers, main/site stores, receipts, Project issues, transfers, returns, physical counts/adjustments, on-hand quantities, and later separately reviewed accounting integration. Tool Custody covers reusable tools/equipment issued to employees, custodians, or Projects with issue/return dates, condition, and in-custody/returned/damaged/lost states. Physical Tool Custody is explicitly separate from financial Custody Advances, and the proposed scope is contracting operations rather than a full retail/distribution inventory ERP. No schema or application implementation exists.

## 35. Testing Expectations

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

## 36. Handoff Checklist for New Sessions

- [ ] Read `PROJECT_ROADMAP.md` in full (Binding Decisions, Completed, Current/Next Phase, Known Gaps, Decision Log).
- [ ] Read this file in full.
- [ ] Confirm current repo state matches what's documented here — inspect, don't assume (files move; this doc can drift).
- [ ] Check `git log` / `git status` for anything not yet reflected here.
- [ ] Before writing code: identify which files in §5/§6 the task actually touches; don't restructure working modules.
- [ ] After completing a phase or making a binding decision: update **both** `PROJECT_ROADMAP.md` (phase status, next action, decision log, known gaps) and this file (implementation state, new files/models, changed accounting rules, limitations, immediate next task). A feature is only "Completed" once it exists and has been verified running — not merely planned.


### P6C Slice 2 — Parties and Expense Categories read-only (2026-09-12)

Status: **VERIFIED COMPLETE**. The implementation/setup-stage notes below are historical; final acceptance and cleanup are recorded at the end of this section. Slice 1 remains verified complete; overall P6C is not complete. P6D/P6E and the next entity slice have not started. This entry supersedes earlier statements that Slice 2 has not started. Historical architecture/P6B documents contain dated planned-state statements; the implemented P6B/P6C records and actual code/migrations remain authoritative. Construction Materials / Site Stores + Tool Custody stays future-only.

#### Schema and authorization evidence

Canonical P3/P4 migrations, P5B's category composite-key addition, generated public types, and hosted Development metadata were inspected. All 27 local/remote migration versions align through `20260911123000`; linked `db push --dry-run` returned up-to-date with no migrations/seeds/roles to apply. HEAD and the live remote `main` were both `d0687f2769a3c8694465754f726192c3a0ae949e` before this uncommitted batch.

- `parties`: UUID `id` PK; mandatory UUID `company_id`; mandatory `type`, `name`, `status`; nullable text `code`, `trn`, `contact_person`, `phone`, `email`, `address`, `notes`; mandatory timestamptz `created_at`/`updated_at`; nullable UUID `created_by`/`updated_by`. Party type is exactly OWNER/CUSTODIAN/SUPPLIER/EMPLOYEE/SUBCONTRACTOR/OTHER. Status is ACTIVE/INACTIVE, default ACTIVE. Trimmed name length is 1–200; optional trimmed code length is 1–50. Code uniqueness is Company-scoped, case-insensitive and trimmed, excluding NULL codes; `(company_id,id)` is unique. TRN is nullable text with no additional format constraint. No inferred numeric conversion or validation is applied during reads.
- `expense_categories`: UUID `id` PK; mandatory UUID `company_id`; mandatory text `code`/`name`; nullable text `description`; mandatory ACTIVE/INACTIVE `status` default ACTIVE; mandatory timestamptz creation/update timestamps and nullable UUID actors. Trimmed code/name bounds are 1–50/1–200. Trimmed, case-insensitive code is Company-unique. P5B added unique `(company_id,id)` without changing the read model.
- Both tables have Company/actor FKs using ON DELETE RESTRICT, enabled and forced RLS, P4 tenant-reassignment prevention, and update-timestamp triggers. Party type is protected when referenced by a Subcontract. No schema blocker was found.
- SELECT policies are `parties_read_sensitive_roles` and `categories_read_operational`. Existing role helpers derive `auth.uid()` and require active profile, membership and Company. No status filter is imposed on the master rows themselves: authorized inactive records remain visible.

| Active Company role | Parties SELECT | Categories SELECT |
|---|---|---|
| ACCOUNTING_ADMIN, ACCOUNTANT, MANAGEMENT_VIEWER | All six types | Company categories |
| PROCUREMENT, DATA_ENTRY | CUSTODIAN, SUPPLIER, SUBCONTRACTOR, OTHER; excludes OWNER/EMPLOYEE | Company categories |
| PROJECT_MANAGER | No direct Party rows | Only with at least one own ACTIVE Company project assignment |
| SYSTEM_ADMIN | No rows | No rows |
| Anonymous or inactive profile/membership/Company | No authorized read | No authorized read |

Authenticated grants on both tables are SELECT/INSERT/UPDATE, not DELETE. Existing INSERT/UPDATE policies permit Accounting Admin Party/category management and Procurement Party management for SUPPLIER/SUBCONTRACTOR/OTHER only (plus the existing permission checks). This frontend slice exposes none of those writes. Anonymous has no table grants.

**Hardening opportunity, non-blocking:** actual hosted `service_role` grants include SELECT/INSERT/UPDATE plus TRUNCATE/TRIGGER/REFERENCES on both tables, with DELETE absent. This corrects older P3/P4 prose claiming trusted grants were SELECT/INSERT/UPDATE only. These trusted-only extras are not browser-reachable and are unchanged; reviewing them belongs to a separately scoped least-privilege batch/pre-production review, not this read-only frontend slice.

#### Implemented architecture and behavior

The existing production-only `src/master` graph now includes `ProductionParty` and `ProductionExpenseCategory`, explicit projections/mappers, and `readActiveCompanyParties`/`readActiveCompanyExpenseCategories`. Both use `.eq("company_id", activeCompanyId)` and reject out-of-scope returned rows defensively. Parties sort by name then ID; categories by code then ID. RLS results, including partial and empty arrays, are accepted without expected-type counts, hidden-row lookups, or fabricated relationships.

The Party mapper preserves all 16 selected fields, intentionally mapping `trn` to nullable string `taxRegistrationNumber` and `contact_person` to `contactPerson`, plus Company/actor/timestamp metadata. Leading zeros and NULL are preserved. Status is required from the database, unlike the demo model's optional ACTIVE fallback. Categories preserve all ten fields, including description, status and metadata absent from the smaller demo type. No demo domain/model import is introduced.

The same provider loads Company, Projects, Parties and Categories concurrently once per mounted user/Company/role scope. It retains generation, mount, live-session and synchronous visible-scope guards. A detected authoritative role change invalidates loaded master data; P6B remains keyed to user/Company. Genuine tenant changes, logout and P6A authority revocation unmount the protected tree. Unchanged focus/visibility authority revalidation and redundant same-user SIGNED_IN handling retain Slice 1 behavior and do not reload masters. No new global cache or persistence exists.

Routes `/parties` and `/expense-categories`, plus minimal master navigation, expose localized loading, populated, role-aware valid empty, generic safe query-error, and missing-Company states. P6B branding and EN/AR/RTL remain in the existing shell. Contact/TRN fields render as plain text; no HTML or external action is generated. All resources share the existing fail-closed aggregate state: a query error withholds the whole master snapshot, with refresh as retry. Merely navigating between the three master views does not initiate another load.

A Project Manager may legitimately see an assigned Project while its Party list is empty. The UI does not resolve hidden Parties or infer authorization from Projects. **Expected/intentional behavior**, not a missing-data application error. Lists are read snapshots, not realtime subscriptions or completeness/count assertions; provider/API row limits and later pagination remain a limitation of this minimal proof UI. Assignment-only changes are enforced by RLS on the next query; P6A currently revalidates identity/membership/Company, not project-assignment snapshots.

#### Exact files and verification at implementation stage

Added: `scripts/verify-p6c-behavior.mjs`.

Changed: `src/master/masterTypes.ts`, `src/master/masterRepositories.ts`, `src/master/ProductionMasterDataProvider.tsx`, `src/auth/ProtectedApplication.tsx`, `src/app/TenantReadyApplication.tsx`, `src/i18n/en.ts`, `src/i18n/ar.ts`, `scripts/verify-p6c-boundary.mjs`, `PROJECT_ROADMAP.md`, `PROJECT_HANDOFF.md`.

- `npm run build`: PASS; existing demo chunk-size advisory only.
- `npm run lint`: PASS; four established Fast Refresh warnings only.
- `npm run verify:p6a-boundary`: PASS.
- `npm run verify:p6c-boundary`: PASS; now includes the focused behavioral script using installed TypeScript/Node and controlled query/hook adapters, without a new framework/dependency. It checks exact mapping, NULL/TRN preservation, all Party types, inactive records, tenant filters, partial/empty results, normalized query errors, populated/empty provider readiness, query/rejection failures, missing Company, unchanged-scope load count, immediate role/Company invalidation, late A response after B, unmount and session rejection. These are deterministic controlled lifecycle tests, not mounted React/browser evidence.
- Static boundary checks cover production/demo import isolation, no master localStorage, allowed tables only, no mutation/RPC, no privileged secret markers, provider scope/session guards, and existing coalesced focus/visibility/same-user SIGNED_IN safeguards. Focus/visibility runtime regression remains in the manual plan.
- Hosted Development verification: metadata-only read-only transactions checked columns, enums, constraints/indexes, forced RLS, policies and grants. No business-row/Auth fixture was created, changed or deleted. Migration alignment and linked no-op dry-run passed.
- `git diff --check` and focused changed-file credential-pattern scan: PASS. No privileged values entered source/output.
- Not performed: authenticated Slice 2 Data API role matrix, browser navigation/network/console/RTL verification, timed browser stale-response races, or hosted synthetic mutation-denial testing. No authenticated test identity was provisioned. No material implementation blocker found.

No Party/category mutation, Accounts/Treasury/Subcontracts implementation, migration, RLS/grant change, financial-flow cutover, localStorage fallback, Staging/Production action, commit or push occurred. No P5 file/command changed.

#### Original manual/browser verification plan — final acceptance recorded below

1. Use only MakerACC-Development with browser-safe Auth configuration. Reuse suitable explicitly authorized synthetic identities/data if available; otherwise separately prepare a narrowly scoped fixture before this plan, with exact cleanup IDs. Need Companies A/B with distinct branding; A has all six Party types, active/inactive rows, a leading-zero TRN and NULL business fields, and categories with/without descriptions; B has empty Party/category results. Cover all seven roles and Project Manager assignment/no-assignment. Do not use real accounting records or alter historical fixtures without authorization.
2. Signed out, open `/parties` and `/expense-categories`: expect login and no protected data. Sign in; verify A's exact authorized records, IDs/company filters in Network, NULL/leading-zero/status mapping, category descriptions and P6B branding. Visit `/projects`, `/parties`, `/expense-categories` and refresh each direct URL.
3. Exercise every role against the matrix above. Check Procurement/Data Entry include Custodians but never Owner/Employee rows; Project Manager sees assigned Projects with a valid empty Party list; System Admin sees empty lists. Verify Company B empty states without an error. Do not bypass RLS to retrieve missing dependent Parties.
4. Throttle reads to see loading; delay A responses, switch to B, then release A. Expect neutral tenant transition and no A record/branding flash under B. Repeat B→A and logout during pending requests. Refresh restores only the authorized selected Company. Test another user's login without retaining the first user's records.
5. Repeatedly switch tabs/focus while authority is unchanged: only P6A authority revalidation should occur; no settings/master reload, blocking loader, disappearing list or duplicate resource request. Separately revoke/restore synthetic profile, membership and Company, triggering focus each time: detected revocation clears the protected tree; restore and Retry recovers safely. Test a role downgrade from Accounting Admin to Procurement: revalidation must clear the old Party snapshot and requery the restricted subset. Test Project Manager assignment removal with a fresh read/refresh.
6. Block/fail Party and category requests separately; expect a safe error, no prior snapshot/demo data and no raw server message. Remove the fault and refresh to recover. Verify EN/AR, document lang/dir, keyboard navigation, narrow viewport, mixed Arabic/Latin contact fields, and long names/descriptions.
7. Verify no create/edit/delete control, financial request/RPC, or newly enabled financial route. `/expenses`, `/journal`, `/advances`, and other deferred paths remain holding views. Network must contain only Auth/P6A, settings and the four allowed master resources; no privileged credentials. Check console for unexpected errors.
8. Check local-demo separately: its accounting data and `cas:v1:*` collections remain unchanged and it imports/loads no production master modules. After acceptance, remove only newly authorized verification fixtures and temporary browser Auth state, retain demo data, record evidence and exact cleanup. Do not mark all P6C complete.

#### Proportional lifecycle classification at implementation stage

- Business/accounting: **VERIFIED** — read-only reference behavior; no accounting policy or P5 change.
- Security/authorization: **VERIFIED** for schema/policy/source and controlled scope evidence; authenticated browser/role acceptance **DEFERRED**.
- Database: **VERIFIED** — actual hosted metadata and canonical history align; no schema work needed.
- Deployment: **NOT APPLICABLE** to this local implementation batch; Staging/Production rollout **DEFERRED**, configuration unchanged.
- Testing: automated and hosted metadata checks **VERIFIED**; browser/runtime acceptance **DEFERRED**.
- Documentation: **VERIFIED** — Slice 2 implementation and remaining gates recorded without closing P6C.

### P6C Slice 2 temporary fixture creation history (2026-09-12; now cleaned up)

The user manually created confirmed Auth identity `74e36291-172a-44e7-95be-f6c1283c315b` / `p6c-slice2-user@example.test`; its automatic ACTIVE profile and exact identity were verified read-only. The explicitly authorized Development-only fixture was then created in one guarded transaction after zero ID/code/slug/user collision checks. Full exact manifest, creation/verification SQL, seven guarded Alpha role-switch scripts, active/inactive assignment scripts and unexecuted cleanup are in `docs/verification/p6c-slice2/README.md`.

Companies `72000000-0000-4000-8000-0000000000a1` (P6C Slice 2 Alpha) and `72000000-0000-4000-8000-0000000000a2` (P6C Slice 2 Beta) have distinct settings and ACTIVE/MANAGEMENT_VIEWER memberships for this user. Post-commit checks verified profile 1, Companies 2, memberships 2, settings 2, Alpha Project 1, active assignment 1, Alpha Parties 6 (all valid types, inactive OTHER, Supplier TRN `001234567890123`), Alpha Categories 3 (active/inactive/NULL-description cases), and Beta Projects/Parties/Categories 0. Financial/other out-of-scope Company-owned rows, unrelated user memberships/assignments and orphan fixture rows are all zero. Global integrity is now 16 Companies/16 settings with zero missing/orphan settings, up from the verified 14/14 baseline.

No role switching, assignment toggling or cleanup was executed. At setup time the fixture was preserved for manual verification; the subsequent acceptance and cleanup below supersede this temporary state. No password is stored. This supersedes the earlier no-fixture status only; browser acceptance remains pending and P6C is not complete. No application logic, migration, RLS/grant, financial flow, other entity slice, Staging/Production, commit or push change occurred in this fixture batch.


### P6C Slice 2 final acceptance and checkpoint (2026-09-12)

**P6C Slice 2 — VERIFIED COMPLETE.** Overall P6C remains incomplete; the next entity slice, P6D and P6E have not started. The user supplied authenticated manual acceptance evidence in this session: MANAGEMENT_VIEWER displayed all six Party types and all three Categories; inactive OTHER/category status, NULL optional fields/description, exact Supplier TRN `001234567890123`, and Arabic contact text rendered correctly. PROCUREMENT displayed only CUSTODIAN/SUPPLIER/SUBCONTRACTOR/OTHER (4 Parties, 3 Categories), removing OWNER/EMPLOYEE during the existing session. This is representative browser evidence for the shared DATA_ENTRY policy branch, not a separate DATA_ENTRY login test. ACCOUNTING_ADMIN/ACCOUNTANT use the inspected unrestricted policy branches; separate browser runs for those roles were not reported.

PROJECT_MANAGER displayed 0 Parties/3 Categories with ACTIVE assignment and 0/0 with INACTIVE assignment; the assignment was restored ACTIVE. SYSTEM_ADMIN displayed 0/0, confirming no browser bypass. Alpha was restored to ACTIVE/MANAGEMENT_VIEWER, then Alpha→Beta showed Beta branding and 0 Projects/Parties/Categories without Alpha records. Repeated Beta tab-away/return caused no secure/presentation loading interruption or stale master flash, accepting the Slice 1 focus/visibility regression boundary.

The user reported successful guarded SQL cleanup, zero fixture database counts, global 14 Companies/14 settings with zero missing/orphan settings, then manual deletion of Auth user `74e36291-172a-44e7-95be-f6c1283c315b` / `p6c-slice2-user@example.test`. Final read-only Development checks independently reconfirm these zero counts, Auth absence, and global one-to-one integrity. No fixture remains. `docs/verification/p6c-slice2/` is retained as historical/reusable operational documentation; it is not a live fixture or an automatically executed migration.

Final build, lint, P6A boundary, P6C boundary (including the controlled mapper/query/provider behavior checks), focused credential/boundary scans and diff checks pass. Lint retains only four established Fast Refresh warnings; build retains the existing large demo-chunk advisory. All 27 local/Development migrations remain aligned through `20260911123000`. No migration, RLS/grant change, financial-flow cutover, Accounts/Treasury/Subcontracts implementation, or Staging/Production action occurred. One checkpoint commit is authorized; pushing remains the user's action.

No blocking issue remains in the accepted read-only slice. Trusted service_role TRUNCATE/TRIGGER/REFERENCES privileges remain an unchanged, non-blocking future hardening/audit item. Pagination/realtime snapshots remain deferred. Detailed timed browser races, query-failure browser injection, full RTL/keyboard/network/console matrices and separate per-role browser runs beyond the supplied evidence are not newly claimed; existing source/controlled tests and representative manual acceptance form the proportionate closure evidence.

Final lifecycle: business/accounting VERIFIED (read-only); security/authorization VERIFIED for the accepted policy and representative browser boundaries; database VERIFIED (aligned history and cleaned fixture); deployment NOT APPLICABLE to this checkpoint, Staging/Production DEFERRED; testing VERIFIED with the explicit evidence limits above; documentation VERIFIED. Development slice completion is not production readiness.


### P6C Slice 3 — Accounts and Treasury read-only (2026-09-12)

Status: **VERIFIED COMPLETE**. The implementation-stage evidence below is historical; final acceptance and cleanup follow. Slices 1/2 remain VERIFIED COMPLETE; overall P6C is NOT COMPLETE. This supersedes earlier next-slice-not-started statements. P6D/P6E, Subcontracts and all master mutations remain unstarted/deferred. The starting checkpoint was `f40956a8bcb3dd0164ef730b78ac593413fae96f` with a clean working tree. One final checkpoint is authorized; no push.

The existing production provider now reads six master resources concurrently per user/Company/role scope, with explicit Accounts/Treasury projections and mappers. `/accounts` presents a flat list with authoritative parent references, type, status, system key and party requirement. `/treasury-accounts` preserves the permanent GL UUID, resolving labels only from the same authorized Account snapshot. Project Manager Treasury visibility with no Account detail is valid. No balances or financial records are queried or synthesized. Shared loading/error/missing-Company behavior, EN/AR/RTL, P6B branding, tenant/role invalidation and focus safeguards are retained.

Read-only Development catalog verification confirmed columns, enums, constraints, indexes, triggers, RLS helpers, forced RLS, grants and the exact role matrix. All 27 canonical migration versions align through `20260911123000`; linked dry-run returned up-to-date, no migrations/seeds/roles. No hosted business or Auth data was changed or fixture created. The existing trusted grant hardening note above remains unchanged; the same trusted-only privileges were observed on these two resources.

The exact schema, role matrix, file manifest, automated evidence, limitations, lifecycle classifications and authenticated browser plan are recorded in [P6C Slice 3](docs/P6C_SLICE_3_ACCOUNTS_TREASURY.md). Representative browser acceptance and cleanup are complete as recorded below; this does not close overall P6C or establish production readiness. Construction Materials / Site Stores + Tool Custody remains future-only.

### P6C Slice 3 final acceptance and cleanup — 2026-09-12

**P6C Slice 3 — VERIFIED COMPLETE.** The user supplied authenticated manual acceptance: MANAGEMENT_VIEWER saw 8 Accounts / 5 Treasury; root/child UUID and labels, CUSTODY_ADVANCE system key, requires_party=true, inactive ASSET/EXPENSE, NULL parent/system fields and Arabic text passed. All five Treasury types, permanent GL UUID/authorized labels, inactive petty cash, correct Project references, absent nullable bank fields and leading-zero references `001234567890` / `000987654321` passed without invented balances.

PROJECT_MANAGER with ACTIVE assignment saw 0 Accounts / 2 project Treasury; real GL UUIDs remained while hidden Account codes/names did not leak. INACTIVE assignment yielded 0/0; ACTIVE was restored. SYSTEM_ADMIN saw 0/0. Restoring MANAGEMENT_VIEWER recovered 8/5; Alpha→Beta showed Beta branding and 0 Projects/Accounts/Treasury without Alpha leakage. Repeated Beta tab-away/return retained the Company and presentation without secure-loading interruption, presentation-loading interruption, branding flash or stale Alpha content.

The user executed the guarded cleanup successfully, verified zero fixture database counts and global 14 Companies/14 settings with zero missing/orphan rows, then manually removed Auth user `dc9ad1f5-804d-4f33-ab65-5e796fec0616` / `p6c-slice3-user@example.test`. Final read-only Development verification independently reconfirmed all fixture counts zero and Auth absence. No fixture is currently present; operational scripts are retained as historical/reusable documentation, not live setup or migrations.

Final build, lint, P6A/P6C boundaries (including existing controlled behavior and list-rendering verification), focused credential/boundary scans and diff checks pass. Lint retains four established Fast Refresh warnings; build retains its demo chunk-size advisory. All 27 local/Development migrations align through `20260911123000`; linked dry-run is a no-op. No unrelated change or blocking defect was found. One local checkpoint is authorized; pushing remains the user's action.

Evidence limits: acceptance uses the supplied representative browser cases plus existing controlled tests and schema/source review. Separate Accounting Admin/Accountant/Data Entry/Procurement browser runs, timed browser races, error injection, exhaustive RTL/keyboard/direct-route tests and detailed network-request counts were not supplied and are not newly claimed. Pagination/realtime and assignment-only snapshot refresh limitations remain documented. The trusted service_role grant hardening note remains unchanged and non-blocking. Overall P6C remains incomplete; the next slice, Subcontracts, P6D and P6E have not started. No migration, RLS/grant change, financial-flow cutover or Staging/Production action occurred; no push.

Final lifecycle: business/accounting **VERIFIED** (read-only); security/authorization **VERIFIED** for inspected boundaries and representative authenticated acceptance; database **VERIFIED** (aligned history and cleaned fixture); testing **VERIFIED** with the explicit evidence limits above; documentation **VERIFIED**. Deployment **NOT APPLICABLE** to this checkpoint; Staging/Production and full production readiness **DEFERRED**. Development slice completion is not production readiness.


### P6C Slice 4 — Subcontracts read-only (2026-09-13)

**VERIFIED COMPLETE.** The implementation-stage notes below are historical; final acceptance and cleanup follow. The roadmap explicitly leaves Subcontracts and all master mutations after Slice 3. The next smallest slice is Subcontracts READ-ONLY; financial command integration remains P6D. This supersedes historical Subcontracts-not-started statements. Slices 1–3 remain VERIFIED COMPLETE; overall P6C remains incomplete. All master mutations, P6D/P6E, Site Materials / Stores and reusable Tool Custody remain deferred/future-only.

Added the explicit 17-column Subcontract model/mapper/Company-filtered reader and `/subcontracts` EN/AR read-only list to the existing seven-resource scoped provider. BIGINT amounts are projected as text before JSON decoding and preserved as exact strings; numeric/malformed amount responses fail safely. UI labels minor units, shows actual status/scope/references/dates/retention, and resolves labels only from current authorized Project/Party snapshots. Hidden Party details remain unavailable while authoritative UUIDs remain visible. No totals, currency, balance, mutation or financial command is invented.

Inspected canonical migrations/generated types and actual MakerACC-Development columns, enums, constraints, incoming/outgoing FKs, indexes, triggers, RLS/helper definitions, permission rows and grants in a read-only transaction. Subcontracts SELECT permits Accounting Admin/Accountant/Procurement/Management Viewer Company-wide, Project Manager only on own ACTIVE assignments, and no Data Entry/System Admin rows. All paths require active authoritative identity/membership/Company. No schema blocker found. All 27 local/remote migrations align through `20260911123000`; linked dry-run is a no-op.

Build, lint, P6A/P6C boundaries, existing and extended controlled behavior/static-render tests, focused credential scan and diff checks pass. Existing four Fast Refresh warnings and demo chunk advisory remain. Tests cover exact BIGINT strings, signed/zero/null/status/date/actor mapping, partial/empty/error results, delayed tenant/role/user responses, session loss/unmount, hidden labels and unchanged-scope snapshots. Auth/focus/visibility code is unchanged. Authenticated browser/Data API role acceptance and hosted text-cast response proof remain pending; no fixture/Auth identity was created and no browser acceptance is claimed.

The exact schema/RLS/grant report, file manifest, evidence limits and eight-step authenticated browser plan are in `docs/P6C_SLICE_4_SUBCONTRACTS.md`. Existing trusted service_role grant extras remain a non-blocking hardening opportunity. Pagination/realtime and assignment-only refresh limitations remain. No unapproved mutation, financial cutover, journal/posting RPC, migration, RLS/grant weakening, production localStorage fallback, Staging/Production action, commit or push occurred.

Lifecycle: read-only business/accounting **VERIFIED**; schema/source/controlled security **VERIFIED**, authenticated acceptance **DEFERRED**; applied database/alignment **VERIFIED**, schema change **NOT APPLICABLE**; local automated testing **VERIFIED**, browser/runtime **DEFERRED**; deployment **NOT APPLICABLE**, production readiness **DEFERRED**; documentation **VERIFIED**. This is not final P6C completion or production readiness.

### P6C Slice 4 final authenticated acceptance and cleanup — 2026-09-13

**P6C Slice 4 — Subcontracts READ-ONLY is VERIFIED COMPLETE.** The user supplied completed authenticated browser acceptance and guarded fixture cleanup evidence. Implementation/setup-stage statements above are historical; this closure supersedes their pending/live-fixture status.

- MANAGEMENT_VIEWER: Alpha displayed exactly three Subcontracts; authorized Project/Party labels, actual statuses/amounts/dates/notes and safe NULL handling passed. `9007199254740993` rendered exactly, without rounding or scientific notation. No mutation or financial action UI appeared.
- PROCUREMENT: three Subcontracts remained visible; foreground/focus revalidation detected the role change without manual refresh or a “Loading securely...” regression.
- PROJECT_MANAGER with ACTIVE Project A assignment: only `P6C-S4-A-001` and `P6C-S4-A-002` appeared; Project B's contract remained hidden. Authorized Project label and authoritative Subcontractor UUID remained visible, while Party code/name/details did not leak. The unavailable-details message and exact BIGINT display passed.
- PROJECT_MANAGER with INACTIVE assignment: refresh yielded zero Subcontracts; assignment was restored ACTIVE afterward.
- SYSTEM_ADMIN: zero Subcontracts, confirming no browser tenant-data bypass.
- Restoring MANAGEMENT_VIEWER returned Alpha to three. Alpha→Beta yielded zero with no stale Alpha flash. Repeated tab-away/return preserved Beta with no blocking secure loader or branding flash.

Guarded Development cleanup succeeded. The user verified zero fixture Companies/settings/memberships/Projects/assignments/Parties/Subcontracts/profile, then manually removed Auth identity `9dbcfe8d-0333-4d3c-8b1b-3acc4b9b47d3` / `p6c-slice4-user@example.test`. Final independent read-only `docs/verification/p6c-slice4/verify.sql` confirms all fixture counts and Auth identity zero, no unexpected Company-scoped rows or unrelated user memberships/assignments, global 14 Companies/14 settings, and zero missing/orphan settings. No fixture remains. Operational SQL is retained as historical support, not live setup or migrations.

Evidence limits: closure uses the supplied representative authenticated cases, exact runtime BIGINT display, existing controlled lifecycle/rendering tests and applied schema/RLS review. Separate Accounting Admin/Accountant/Data Entry browser runs, timed browser race interception, fault injection, exhaustive EN/AR/RTL/keyboard/direct-route checks and detailed network counts/raw JSON capture were not separately supplied and are not newly claimed. The implementation's `::text` projection and string-only mapper plus exact rendered value support end-to-end precision; this does not manufacture a separate captured Network response.

Final checks: build, lint, P6A boundary, P6C boundary, standalone P6C behavior, focused credential scan and diff checks pass. Lint retains exactly four `react(only-export-components)` warnings at `src/components/ui/Field.tsx:29:14`, `src/i18n/I18nContext.tsx:93:17`, `src/i18n/I18nContext.tsx:100:17`, and `src/state/AppDataContext.tsx:1397:17`: “Fast refresh only works when a file only exports components. Use a new file to share constants or functions between components.” Build retains the existing demo chunk-size advisory. All 27 local/Development migrations align through `20260911123000`; linked dry-run is a no-op. No blocking defect or unrelated change found.

No production localStorage fallback, frontend financial/master mutation, journal/posting path, migration or RLS/grant weakening was introduced. No fixture password/private credential is present in the reviewed change set. Staging/Production were untouched. One final local checkpoint commit is authorized after passing checks; no push is authorized or performed.

Overall P6C is **NOT COMPLETE**. The next documented remaining item is **P6C master-data mutation cutover**; the roadmap does not yet specify the first entity/command sequence, which must be established before implementation. P6D specialized financial RPC integration and P6E have not started. Site Materials / Stores and reusable Tool Custody remain future-only. Existing pagination/realtime and assignment-only snapshot refresh limits remain; trusted service_role grant extras remain a non-blocking hardening opportunity.

Final lifecycle: business/accounting **VERIFIED** for read-only semantics and exact values; security/authorization **VERIFIED** for inspected boundaries and accepted representative browser evidence; database **VERIFIED** for aligned history and cleaned fixture; testing **VERIFIED** with the explicit evidence limits above; documentation **VERIFIED**. Deployment **NOT APPLICABLE** to the local checkpoint; Staging/Production and full production readiness **DEFERRED**. Development slice completion is not production readiness.


### P6C Slice 5 — Expense Categories MUTATION — VERIFIED COMPLETE (2026-09-13)

Overall **P6C — IN PROGRESS**. Slices 1–5 are verified complete; other master mutations remain pending. P6D/P6E have not started. Starting HEAD was `a9ca416fe4e471a50f17900b74af5cce1ad0339f`.

Category-only create, metadata edit, deactivate/reactivate use direct authenticated RLS writes, authorized only by ACCOUNTING_ADMIN / `category.manage`. No delete/upsert/bulk/generic CRUD, expense recategorization, SYSTEM_ADMIN bypass, other master mutation or P6D/financial mutation path was introduced.

Canonical migration `20260913120000_p6c_category_mutations.sql` was applied via linked db push to positively verified MakerACC-Development only. INSERT grants are limited to company_id/code/name/description; UPDATE grants to code/name/description/status. UUID and ACTIVE are database defaults. One category-specific invoker trigger owns normalization, authenticated actor stamping, immutable creation provenance and strictly advancing updated_at while preserving trusted/import provenance. Shared timestamp function, RLS policies, permissions, tenant guard, indexes and restrictive FKs remain unchanged.

The dedicated repository rebuilds allowed payloads and filters updates by Company/UUID/exact timestamp, requiring one authoritative row. Bilingual role-gated category forms/status confirmations refresh categories only. Provider session/scope/generation guards and in-flight locking protect asynchronous results; stale/uncertain outcomes require refresh.

Hosted verification passed 70/70 rollback assertions. Concurrent creates produced one success/one expected 23505; concurrent conditional edits affected 1/0 rows. Rollback and concurrency fixtures were removed. These SQL-role and automated results remain distinct from accepted browser evidence.

#### Final accepted browser evidence — 2026-09-13

The user completed and accepted authenticated manual acceptance:

- ACCOUNTING_ADMIN list/create/edit/deactivate/reactivate: PASS.
- Normalized duplicate-code rejection: PASS.
- Optimistic concurrency stale-edit conflict: PASS.
- Beta tenant / MANAGEMENT_VIEWER read-only behavior: PASS.
- Alpha role downgrade to MANAGEMENT_VIEWER observed after revalidation; mutation controls disappeared: PASS.
- Tab-away/tab-return regression: PASS, without blocking “Loading securely” or stale tenant flash.
- Arabic/RTL: PASS.

Cross-tab locale persistence is a **non-blocking UX observation**: one tab retained English until refresh, then converged to Arabic. No Slice 5 fix is required or introduced.

#### Final Development cleanup

The disposable database fixture was fully removed. Auth user `e6cac418-6739-4b66-a1ab-f7cd98bf89fc` was deleted through Supabase Authentication. Final accepted cleanup counts:

- `auth_user=0`, `profile=0`, `fixture_companies=0`, `memberships=0`.
- `global_companies=14`, `global_settings=14`.
- No missing/orphan Company settings.
- All inspected financial/out-of-scope fixture tables were zero before cleanup.

#### Final accepted local and migration checks

These are the user's final accepted results, recorded during documentation closure without rerunning build/lint/database verification:

- `npm run build`: PASS; only the existing Vite >500 kB demo chunk advisory.
- `npm run lint`: PASS; 0 errors, 4 pre-existing Fast Refresh warnings.
- P6A boundary, P6C boundary, P6C behavior: PASS.
- `git diff --check`: PASS.
- All 28 local/remote migration versions aligned, including `20260913120000`.
- Linked `db push --dry-run`: Remote database is up to date.
- Focused real-secret scan: PASS.

Business/accounting, security/authorization, Development database, risk-proportionate automated/hosted/browser testing and documentation: **VERIFIED**. Development migration/local Auth-mode acceptance: **VERIFIED**. Frontend release, Staging/Production and production readiness: **DEFERRED**; other-environment database changes: **NOT APPLICABLE**. No build/lint/database checks were rerun for this documentation-only closure.

The final cleanup above supersedes earlier live-fixture/prepared-only notes. Full implementation manifest, database contract and evidence limits are in `docs/P6C_SLICE_5_EXPENSE_CATEGORIES_MUTATION.md`; archived fixture evidence is in `docs/verification/p6c-slice5/README.md`. One local checkpoint commit is authorized; no push or next-slice work is authorized.


### P6C Slice 6 — Supplier Party MUTATION — VERIFIED COMPLETE (2026-09-16)

Only Supplier create, metadata edit, deactivate/reactivate on `/parties`; no delete. ACCOUNTING_ADMIN/PROCUREMENT require existing party.manage and active authority; all other roles remain denied. Restrictive Supplier policies and exact column grants preserve tenant/provenance boundaries. Updates retain exact loaded updated_at and refresh only Parties. P5 and non-Supplier reads remain unchanged.

Row handlers originally opened Edit/status panels above the viewport. Inline selected-row panels plus focus/scroll fixed the defect; Create remained intact. Real Chromium interaction/layout coverage now exercises the actual UI/provider/repository using isolated in-memory transport. Playwright 1.62.1 is pinned as a development-only dependency with declared browser setup; the two fixture warnings were corrected. Both cleanup scripts retain `fixture_companies`.

#### Final accepted evidence — 2026-09-16

The user completed the final database, authenticated browser and local verification externally and supplied the accepted results below. This documentation closure records that evidence; it does not claim a new execution of those checks.

- **Hosted database: 104/104 PASS.** Migration `20260913123000_p6c_supplier_party_mutations.sql` is applied to MakerACC-Development only. Local/remote migration history is aligned; final linked dry-run: **Remote database is up to date**.
- **Concurrency: PASS.** Competing creates produced one success and one SQLSTATE `23505`; competing edits from the same exact token affected **1** and **0** rows. Final state was verified and the concurrency fixture fully cleaned.
- **Authenticated browser: PASS.** ACCOUNTING_ADMIN create/edit/deactivate/reactivate; PROCUREMENT controls/deactivate/reactivate; MANAGEMENT_VIEWER read-only; non-Supplier rows without controls; Alpha/Beta isolation; duplicate rejection; two-tab stale-edit conflict; refresh recovery; role downgrade during open edit; membership revocation fail-closed; profile revocation to `/no-company`; focus/tab return without blocking “Loading securely”, unnecessary master reloads or stale tenant/branding flash; Arabic/RTL and Supplier-only rendering.
- **Local gates: PASS.** Build (only the existing Vite >500k demo-chunk advisory); lint (exactly four pre-existing Fast Refresh warnings, zero errors); Supplier Chromium interaction regression; P6A boundary; P6C boundary; P6C behavior; `git diff --check`; focused real-secret scan.
- **Cleanup: VERIFIED.** Fixture Companies/settings/memberships/Parties/profile/Auth user are all **0**. Global Companies **14**, settings **14**, missing settings **0**, orphan settings **0**. Browser cleanup used the exact generated Party UUID manifest; no broad deletes or CASCADE cleanup. Both cleanup scripts retain the PL/pgSQL ambiguity correction from `companies` to `fixture_companies`. No fixture remains live.

Business/accounting scope, security/authorization, Development database/migration, testing and documentation: **VERIFIED**. Development environment boundary and migration acceptance: **VERIFIED**. Staging/Production action: **NOT APPLICABLE** (none occurred). Frontend release, production readiness and the full pre-production audit: **DEFERRED** to their later gates. No P6D/financial mutation path was introduced; P6D remains **NOT STARTED**. Overall P6C remains **IN PROGRESS**; Slice 7 was not started at Slice 6 closure; its subsequent completion is recorded below.

This final record supersedes prior implementation-only, pending-acceptance and live-fixture notes. The complete contract and verification record are in `docs/P6C_SLICE_6_SUPPLIER_PARTY_MUTATION.md` and `docs/verification/p6c-slice6/README.md`. Closure authorizes one local checkpoint commit only; no push or next-slice work.


### P6C Slice 7 — Company Profile Metadata UPDATE — VERIFIED COMPLETE (2026-09-16)

**VERIFIED COMPLETE**, including user-completed authenticated hosted browser acceptance and final fixture cleanup. This supersedes historical Slice-7-not-started and pending-acceptance statements. P6C remains IN PROGRESS; Slices 1–7 are VERIFIED COMPLETE. P6D/P6E and Slice 8 have not started.

Recovered the existing partial work on `main` at `6b18823535bbd4f9cfba77c7c94fd5b69ca8b3fd`; nine modified tracked files and four new files were preserved. Fresh Development migration/catalog checks proved the single existing Slice 7 migration was not applied at resume. It was subsequently dry-run reviewed and canonically applied unchanged as `20260916120000_p6c_company_profile_metadata.sql`; no duplicate migration or reset/rewrite of existing work.

Only existing active Company legal_name, trn, address and notes may be updated/cleared. Trim/NULL normalization preserves internal text/Unicode/case/TRN zeros with no invented jurisdiction/uniqueness/length rules. Existing company.manage permits ACCOUNTING_ADMIN and same-Company SYSTEM_ADMIN with active profile/membership/Company. Forced RLS/policy semantics remain; exact column grants and Company-local provenance/monotonic token trigger protect the boundary. Shared timestamp function/FKs/trusted provisioning remain intact. No identity/status/branding/settings/financial mutation is introduced.

The dedicated `/company-profile` form/repository uses exact id + loaded updated_at and one returned row. Independent Company-only refresh preserves other master/settings snapshots and synchronizes Auth/shell legal identity without provider remounts. Conflicts/uncertainty require explicit review; known commit + failed refresh remains distinct. A Chromium-confirmed Close-focus timing defect was fixed after render; existing Supplier inline panels/cleanup fixes remain unchanged.

Executed: Slice 7 hosted 96/96 PASS; concurrency affected rows 1/0 with verified actor/token; Supplier hosted 104/104 and Category hosted 70/70 PASS; repository/provider lifecycle and actual Company/Supplier Chromium suites PASS with isolated transport; public DB lint no schema errors; build PASS with existing demo chunk advisory; lint four pre-existing warnings/zero errors. SQL fixture cleanup verified all exact fixture counts zero and global Companies/settings 14/14, missing/orphans 0/0. Final gate details and file-by-file recovery classification are in `docs/P6C_SLICE_7_COMPANY_PROFILE_METADATA.md` and `docs/verification/p6c-slice7/README.md`.

The user subsequently completed and accepted authenticated hosted browser verification: ACCOUNTING_ADMIN mutation; SYSTEM_ADMIN same-Company mutation; denied-role UI; metadata update/clear and leading-zero TRN; stale two-tab conflict; Alpha/Beta isolation; authority downgrade/revocation fail-closed; profile revocation to no-company; focus/tab return; Arabic/RTL/keyboard/narrow layout; final fixture cleanup and no stale tenant data. These supplied results close the previous credential/browser/fixture gate. No additional individual tests or fresh cleanup counts are claimed. No credentials are stored.

Final accepted local gates: build PASS; lint 0 errors/4 existing warnings; P6A/P6C boundaries and behavior, secret scan and diff check PASS. All 30 migrations align; linked dry-run is up to date; public DB lint reports no schema errors. These checks were not rerun during documentation closure.

Final lifecycle: business/accounting, security/authorization, database, testing and documentation VERIFIED for the accepted slice. Development migration acceptance VERIFIED. Frontend release, production readiness and the full pre-production audit DEFERRED; Staging/Production action NOT APPLICABLE. P6C remains IN PROGRESS; P6D/P6E remain NOT STARTED. No P6D/financial behavior, Staging/Production action or Slice 8 work. One local commit is authorized with message `Complete P6C Slice 7 company profile metadata`; no push.


### P6C Slice 8 — Project Descriptive Metadata UPDATE — VERIFIED COMPLETE (2026-09-17)

**VERIFIED COMPLETE**, including user-completed authenticated hosted browser acceptance and exact-manifest cleanup. Started from clean `865d2bd4591dc67f962fa709b7b86bda4ddb29b4`. This supersedes historical Slice-8-not-started notes. Slices 1–8 are VERIFIED COMPLETE; P6C IN PROGRESS; P6D/P6E NOT STARTED.

Existing Project name, client_name, location, contract_number, notes only. Required normalized name 1–200 Unicode characters; optional blanks NULL; exact loaded update token. Accounting Admin and assigned Project Manager use unchanged authoritative P4 role/assignment RLS. Closed descriptions remain editable without lifecycle/accounting effects. No create/delete/code/status/date/amount/financial mutation. Canonical `20260916140000_p6c_project_metadata.sql` applied only to MakerACC-Development after aligned baseline/live catalog/dry-run. Least-privilege UPDATE columns, immutable creation provenance, identity-derived actor and monotonic Project-local token; trusted INSERT/shared helper/constraints/P5 untouched.

Inline populated Project form on `/projects` and `/`, bilingual keyboard/focus/narrow layout; independent operation state, scoped late-result guards, Projects-only refresh and known-commit/read-failure recovery. No Auth/provider-key/settings changes. Assignment revocation is immediately authoritative in DB; existing UI snapshots clear on query/Projects refresh, not a new realtime subscription.

Actual evidence: hosted 108/108 PASS; competing exact-token updates 1/0 PASS, actor/token/winner verified; Project isolated Chromium PASS; Company/Supplier Chromium and Category/Supplier/Company behavior regressions PASS; build PASS, lint 0 errors/4 existing warnings, P6A/P6C boundaries/behavior, diff check and real-secret scan PASS. All 31 migrations align, dry-run up to date, public DB lint no errors. Hosted rollback suite reused an existing synthetic actor without Auth creation; concurrency fixture cleaned, existing actor/profile retained. Final fixture Companies/Projects/memberships/assignments/browser Auth 0; global Companies/settings 14/14, missing/orphan 0/0.

The user completed authenticated hosted browser acceptance successfully and supplied these accepted results:

- ACCOUNTING_ADMIN in Alpha: descriptive edits on ACTIVE and CLOSED Projects; optional clear-to-NULL; leading-zero contract number preservation; no code/status/date/financial mutation controls.
- Two-tab stale conflict protection; Alpha/Beta isolation and Beta Project mutation.
- PROJECT_MANAGER assigned-P1-only visibility/edit; assignment revocation denial and refresh removal; assignment restore.
- Denied roles: ACCOUNTANT, PROCUREMENT, DATA_ENTRY, MANAGEMENT_VIEWER and SYSTEM_ADMIN. Downgrade with an edit open removes the mutation form.
- Membership revocation fail-closed and restore; profile revocation fail-closed/no-company and restore.
- Unchanged-authority focus/tab-return; Arabic/RTL; keyboard/focus restoration; narrow viewport.
- Exact-manifest browser cleanup and final verification: fixture Companies 0, Projects 0, memberships 0, assignments 0, browser Auth 0; Companies 14, settings 14, missing 0, orphan 0.

These are user-supplied accepted results, distinct from the previously executed automated/hosted SQL and isolated Chromium evidence. No additional browser cases, measurements or traces are claimed. Closure reran no automated verification or hosted queries; final browser cleanup counts are accepted from the user. No credentials are stored. No P6D/financial behavior, Staging/Production action or Slice 9 work occurred.

Full contract, file manifest and evidence: `docs/P6C_SLICE_8_PROJECT_METADATA.md`; historical fixture procedure: `docs/verification/p6c-slice8/README.md`.

Final lifecycle: business/accounting, security/authorization, database, testing and documentation VERIFIED for the accepted slice. Development migration acceptance VERIFIED. Frontend release, production readiness and full pre-production audit DEFERRED; Staging/Production action NOT APPLICABLE. P6C IN PROGRESS; P6D/P6E NOT STARTED. One local commit authorized: `Complete P6C Slice 8 project metadata`. No push or Slice 9.


### P6C Slice 9 — Account Display Name UPDATE — VERIFIED COMPLETE (2026-09-21)

**VERIFIED COMPLETE.** Resumed the existing internally consistent working tree; no reset or scope reselect. Account name only for ACCOUNTING_ADMIN under existing account.manage RLS; no configuration, Treasury or financial mutation. Applied the existing `20260917120000` migration to Development only. Hosted 99/99, concurrency 1/0, isolated Account and directly affected Project/Company/Supplier Chromium, repository/provider regressions and local gates PASS; 32 migrations aligned, final dry-run no-op, public DB lint clean. Exact automated cleanup leaves global Companies/settings 14/14 and missing/orphan 0/0.

User-completed authenticated acceptance and exact guarded cleanup PASS (2026-09-21): admin ACTIVE/INACTIVE name edits, normalization/protected fields, stale two-tab conflict without overwrite/retry, independent Alpha/Beta mutation, full denied-role matrix, open-edit downgrade, membership/profile revocation and restore, focus/drafts/keyboard/cancel/RTL/390px checks. Treasury stayed read-only and no financial route became writable. Final fixture Companies/Accounts/memberships/assignments/browser Auth 0; global Companies/settings 14/14, missing/orphan 0/0. Full accepted evidence: `docs/P6C_SLICE_9_ACCOUNT_DISPLAY_NAME.md`; historical fixture reference: `docs/verification/p6c-slice9/README.md`.

Lifecycle: business/accounting, security/authorization, database, testing and documentation VERIFIED for this slice; Development migration acceptance VERIFIED. Production readiness and frontend release DEFERRED; Staging/Production action NOT APPLICABLE. P6C IN PROGRESS; P6D/P6E NOT STARTED. Closure reran no automated verification or hosted queries. No financial/P6D behavior, credentials stored or Slice 10 work. One local closure commit authorized: `Complete P6C Slice 9 account display name`; no push.


### P6C Slice 10 — Treasury Display Name UPDATE — VERIFIED COMPLETE (2026-09-21)

**VERIFIED COMPLETE.** Selected one-field descriptive UPDATE using Slice 9's pattern without reopening shared Party contracts. Only ACCOUNTING_ADMIN/treasury.manage can rename existing ACTIVE/INACTIVE Treasury rows. No create/delete/status/code/type/Project/GL/bank/reference/notes or financial writes. Permanent GL validator and existing role/tenant RLS stay authoritative.

Canonical `20260921120000_p6c_treasury_display_name.sql` applied only to Development after exact selected-table catalog inspection, aligned baseline and single-migration dry-run. Hosted 108/108, concurrency 1/0 (actor/token verified), Treasury and directly affected Account Chromium, existing master behavior regressions, build, P6A/P6C boundaries/behavior PASS; lint 0 errors/4 existing warnings. DB lint clean; 33 migrations aligned, final dry-run up to date. Exact automated cleanup/global 14 Companies/14 settings, missing/orphan 0/0 verified. Diff/secret review PASS; no credentials stored.

User-completed authenticated browser acceptance and exact guarded cleanup PASS: admin ACTIVE/INACTIVE name-only edits and protected configuration; stale two-tab conflict; Alpha/Beta isolation; complete read-only/denied-role matrix; assigned Project Manager visibility and assignment revoke/restore; open-edit downgrade, membership/profile revocation/no-company; focus/tab/draft/keyboard/RTL/390px; Account name regression and unwritable financial routes. Final fixture Companies/Accounts/Treasuries/Projects/memberships/assignments/browser Auth 0; global Companies/settings 14/14, missing/orphan 0/0. Closure reran no verification.

Lifecycle: business/accounting, security/authorization, database, testing and documentation VERIFIED for the accepted slice; Development migration acceptance VERIFIED. Frontend release/production readiness DEFERRED; Staging/Production action NOT APPLICABLE. P6C IN PROGRESS; P6D/P6E NOT STARTED. No financial/P6D behavior, stored credentials or Slice 11 work. One local closure commit authorized: `Complete P6C Slice 10 treasury display name`; no push. Full evidence: `docs/P6C_SLICE_10_TREASURY_DISPLAY_NAME.md`; historical fixture: `docs/verification/p6c-slice10/README.md`.


### P6C Slice 11 — OTHER Party Display Name UPDATE

**P6C Slice 11 — OTHER Party Display Name UPDATE — VERIFIED COMPLETE (2026-09-22).** Existing OTHER name only for ACCOUNTING_ADMIN/PROCUREMENT under unchanged party.manage; no create/status/contact/other-type or financial behavior. Development migrations `20260921130000` and forward correction `20260921133000` applied only to Development. Hosted 108/108, concurrency 1/0, Slice 11/Supplier Chromium, provider/shared-Party serialization and local gates PASS; lint 0 errors/4 existing warnings; DB lint clean; 35 migrations aligned and linked dry-run no-op. Authenticated browser acceptance PASS including ACTIVE/INACTIVE admin and Procurement name mutation, stale conflict, tenant isolation, complete role/revocation matrix, focus/tab/keyboard and Arabic/RTL responsive manual verification. The synthetic Playwright overflow measurement was not reproduced in real Chrome at 394px with the same long name; no CSS fix was made. Guarded cleanup PASS; all fixture/Auth counts 0, global Companies/settings 14/14, missing/orphan 0/0. P6C remains IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED. No Staging/Production or Slice 12. See `docs/P6C_SLICE_11_OTHER_PARTY_NAME.md`.

Lifecycle: business/accounting, security/authorization, database, testing and documentation VERIFIED for Slice 11, including authenticated browser acceptance and guarded cleanup; Development boundary VERIFIED; release/production readiness DEFERRED. No financial behavior or full production audit performed.

Slice 11 forward correction `20260921133000_p6c_other_party_trusted_token.sql` preserves monotonic OTHER update tokens for trusted writes too. A focused rollback test reproduced the initial trusted future-token regression; the correction preserves trusted provisioning privileges/INSERT and browser name-only rules. Final hosted suite 108/108; 35 migrations aligned. See the Slice 11 phase record.
