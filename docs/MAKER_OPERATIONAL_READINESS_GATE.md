# Maker operational readiness gate

> 2026-11-05 follow-up: P0-01/02 are now implemented and locally verified (47 database, five native concurrency, ten browser checks and Production build). Migration82 remains NOT APPLIED because automatic approval review requires direct user authorization; hosted operational readiness is unchanged. This preserves the assessment below as historical evidence. See [bounded implementation and release boundary](EXISTING_COMPANY_ACCOUNTING_SETUP.md). Phase1 closure still awaits activation/postflight and matching Production publication/acceptance.

> Foundation82 release update,2026-11-05: both confirmed P0 setup gaps now have locally verified implementation and canonical82 is APPLIED with strict preservation postflight PASS. No Maker setup or financial data was created. Matching frontend publication/acceptance remains pending the owner; recommend Phase1 closure after that acceptance. Original Auth discrepancy remains unrecoverable and retained under the explicitly approved independent criterion. Earlier local-only/blocker text below is historical; see [actual release](EXISTING_COMPANY_ACCOUNTING_SETUP.md).

Assessment date: 2026-11-05. Scope: the authorized read-only gate from essential software development to preparation of Maker's original Excel data. No Excel file was opened or processed.

**Decision: PHASE 2 READY for data preparation. Phase 3 import/operational acceptance remains BLOCKED by the two bounded software setup gaps below.** No confirmed defect prevents examining, classifying and reconciling original source data without importing it. This decision does not certify Phase 1 unconditionally complete, authorize operational postings, or certify Maker's books.

The approved sequence remains: essential software → Excel preparation → import/verification → daily operation → broader ERP. No implementation, setup, import, migration, commit, push or deployment was performed in this assessment. Only this report was added; canonical documents and existing dirty development work were preserved.

## Verified baseline and evidence boundaries

| Item | Actual evidence / disposition |
|---|---|
| GitHub main | Read-only `git ls-remote` resolves to `e7fa1a83df0ff42ca9e1d8b98a4af5db5b8a8845`. |
| Local development | `release/platform-owner-console`, HEAD `652bc37ba372bf4fa8bbf454da0bba921f5758fa`, with existing legitimate dirty work. No synchronization or reset. All 391 checked application/migration/package/Vite/Vercel files byte-match the isolated approved release. A stale local HEAD does not mean these source changes are missing. |
| Isolated approved release | `/tmp/narvo-hr-payroll-release-20261105`, clean at `e7fa1a83df0ff42ca9e1d8b98a4af5db5b8a8845`. |
| Hosted database | Linked `eqnzueginpkskbnqvgoc`, `ACTIVE_HEALTHY`. All 81 hosted versions, names and stored SQL match the canonical local files after whitespace normalization. No pending canonical migration. |
| Migration 81 | `20261105120000_hr_operational_foundation.sql`; SHA256 `b60e0bee43d16a5b7c7f6a5fef225582db0c84085dd9e914608b0ee35046f44f`. |
| Provider deployment evidence | GitHub deployment `7572576456` associates the exact approved SHA with environment label `Production`; latest status is `success`, “Deployment has completed,” 2026-11-05 11:38:51 UTC. GitHub's separate `production_environment` boolean is false; the environment label is not a verified Vercel project setting. GitHub commit status also reports Vercel success. |
| Current Production alias | `https://maker-eosin.vercel.app` returns HTTP 200 with the application bootstrap. **Exact alias-to-commit binding, formal Vercel Ready state and authenticated Production screen acceptance: NOT VERIFIED.** The SHA-associated unique deployment redirects to Vercel SSO; comparing that login HTML/assets cannot establish an application mismatch or the alias's deployed SHA. No denied Vercel API authentication was retried. |
| Existing Maker access | Read-only snapshot at 11:49:16 UTC: active legacy access retained, commercial readiness true without a subscription; one active Accounting Admin and one Management Viewer membership. Existing protections were not changed. The prior 81 preservation postflight verified all 75 existing business/financial/access/Auth/MFA/Owner table fingerprints unchanged. This gate did not repeat that full inventory or claim a new fingerprint comparison. |
| Financial consistency | Current read-only aggregate finds zero unbalanced Maker journals. This is not proof of opening completeness or source authenticity. No posted data was changed. |

The historical “owner publication pending” entries in handoff/release documents describe their recording time. Current GitHub main and provider completion observations above supersede that limited historical publication status; authenticated Production acceptance is still unverified. Canonical documentation was intentionally not rewritten.

## Essential workflow matrix

Statuses distinguish working product engines from their usability in Maker's current configuration. `GENUINE SOFTWARE BLOCKER` below concerns Phase 3; none prevents non-mutating Phase 2 preparation.

| Workflow | Classification | Supported cycle and precise boundary |
|---|---|---|
| A. Treasury and funding | **GENUINE SOFTWARE BLOCKER** for additional money locations/direct Custody handover; existing cash funding **READY AFTER COMPANY CONFIGURATION** | Classified capital, partner current account and documented loan funding; permitted withdrawals, evidence/review/post/reversal; physical Treasury receipt or one cash-neutral direct-to-holder journal. Existing cash location works after classified mappings and evidenced funds. Additional bank/cash GL provisioning and Custody control adoption are blocked by P0-01/02. |
| B. Custody | **GENUINE SOFTWARE BLOCKER** | Advance, holder-paid expense, return, settlement and reconciliation engines are verified. Maker lacks `CUSTODY_ADVANCE` and cannot configure it through the existing setup path: P0-01. Settlement does not repost expenses; returns do not reverse project cost. |
| C. Opening balances | **READY AFTER COMPANY CONFIGURATION** for existing Treasury/approved partner controls; **GENUINE SOFTWARE BLOCKER** for Custody opening | Evidenced, balanced, scoped opening certification, uniqueness/stale-source guards, physical counts and immutable difference reviews exist. Custody scope depends on P0-01; new bank scope on P0-02. No difference journal or fabricated balancing amount. Full Company trial-balance carry-forward is outside the implemented scoped opening workflow. |
| D. Projects and contracts | Project masters **READY AFTER COMPANY CONFIGURATION**; financial contract cycle **GENUINE SOFTWARE BLOCKER** | Creation/edit/activation and audit, amendments, fixed/unit-rate contracts, signed uncapped measurements, certifications, supported VAT/retention/advances, actual payments, statements and project-cost reports exist. Maker's missing subcontract control mappings block financial certification/payment: P0-01. |
| E. Expenses | Drafts/existing cash operating expense **READY AFTER COMPANY CONFIGURATION**; Custody/supplier-credit/recoverable-VAT posting **GENUINE SOFTWARE BLOCKER** | Durable incomplete drafts, versioned editing, review, posting, cancellation, canonical reversal and source trace exist. Personal payments create reimbursement liabilities through approved configuration. Custody, supplier payable and input VAT depend on P0-01; bank source on P0-02. HR setup can create `PROJECT_COST` without changing historical amounts. |
| F. Employees and attendance | **READY AFTER COMPANY CONFIGURATION** | Employee/person master, payroll profiles, dated terms, approved schedules/calendar, explicit monthly facts, absence/leave/partial minutes, review and payroll locking exist. Maker has no HR policy, terms or profiles yet. Single Accounting Admin operates the explicit mode. |
| G. Payroll | **READY AFTER COMPANY CONFIGURATION** | Preview/review, earned salary accrual, project labor allocation, approved advance receivables/recovery, partial/full actual Treasury payments and dependency-aware reversal exist. HR setup can explicitly create missing salary/project/advance mappings. No automatic cutover or historical Lite conversion. |
| H. Reporting | **READY** within documented coverage | Bilingual Excel and printable/Save-PDF Treasury, Custody, partner/contract statements, expenses/project costs, attendance, payroll register and payslips are verified. Empty or incomplete Maker books cannot produce certified balances. Payroll-restricted reports disclose their coverage; broader statutory statements are not claimed. |

## P0 — confirmed software setup blockers

### P0-01: Existing Company cannot adopt missing essential control mappings

**Affected:** A direct-to-Custody funding, B Custody, C Custody openings, D contract financial processing, E Custody/supplier-credit/VAT expenses.

**Reproducible evidence:** the live aggregate of Maker's active system keys contains only `COMPANY_EXPENSE`. Missing controls include `CUSTODY_ADVANCE`, `SUPPLIER_PAYABLE`, `INPUT_VAT`, `SUBCONTRACTOR_ADVANCE`, `SUBCONTRACTOR_PAYABLE`, `SUBCONTRACTOR_RETENTION_PAYABLE` and `PROJECT_COST_SUBCONTRACTORS`. These are not hypothetical optional features: the required Custody and contract posting engines require these keys. Existing API validation correctly rejects their absence.

- [Custody advance command](../supabase/migrations/20260903120000_p5d_custody_advances.sql), lines 210–215: missing `CUSTODY_ADVANCE` produces SQLSTATE 23514, “Custody Advance system account is unavailable.”
- [Current certificate command](../supabase/migrations/20261105100000_operational_subcontract_measurements.sql), lines 217–230: required subcontract cost/payable and applicable VAT/retention/advance mappings are resolved by stable keys; absence produces “Required Certificate system account is unavailable.”
- [Expense command](../supabase/migrations/20260901120000_p5b_expense_commands.sql), lines 298–319: posting requires the relevant cost, input VAT and funding control.
- [Foundation provisioner](../supabase/migrations/20261102120000_commercial_company_onboarding.sql), lines 125–134: deliberately permits only a new platform-created empty Company and rejects existing Company-owned records. Maker has existing accounts and a Treasury; invoking it cannot safely repair this legacy foundation. The legacy commercial exemption authorizes access, not account creation.
- [Account screen](../src/master/AccountNamesPanel.tsx) supports display-name edits, not control creation/adoption. Partner/reimbursement setup creates only its approved classified controls. HR81 setup creates `SALARY_PAYABLE`, `PROJECT_COST`, `COMPANY_EXPENSE` and optional employee advance receivable; it does not supply these missing Custody/contract/supplier/VAT controls.

No hosted posting or provisioning was attempted to demonstrate the failure. The current data plus the aligned canonical function preconditions establish it without financial mutation.

**Smallest safe correction:** a bounded authenticated, authorized existing-Company foundation setup path for approved missing controls. Reuse stable keys and existing canonical account types/dimensions; explicitly approve creation or adoption of unused suitable accounts; preserve used mappings, all old amounts and account identities; audit and serialize the action. Add no opening journal, overwrite, automatic reclassification or weakened provisioner guard. This is reusable product capability, not a Maker-specific patch. Implementation/release needs separate authorization.

**Boundary:** blocks final Phase 3 operational acceptance of these essential financial cycles. Does **not** block Phase 2 source preparation. It cannot honestly be labelled P1 until a supported setup path exists.

### P0-02: No usable GL provisioning path for an additional bank/cash Treasury

**Affected:** A money-location setup and bank-funded E/G operations when a bank location is required.

**Reproducible evidence:** Maker currently has one active general `CASH` Treasury with active mapped GL, no Bank Treasury, and **zero** active unused non-system/non-Party ASSET accounts eligible for another Treasury. [Eligible-account filter](../src/master/treasuryMasterRepository.ts), lines 5–7, excludes every other account; [Treasury form](../src/master/TreasuryMasterPanel.tsx), lines 65–66, disables Save with no eligible account. [Treasury RPC](../supabase/migrations/20261008120000_v1_treasury_master_provisioning.sql), lines 25–38, requires an existing suitable GL and creates no account. The account screen cannot create one. This limitation is explicitly documented in [Treasury provisioning](V1_TREASURY_MASTER_PROVISIONING.md).

**Smallest safe correction:** a narrowly authorized non-system, non-Party ASSET GL provisioning option, preferably integrated atomically with existing Treasury creation; retain Company consistency, permanent one-to-one mapping, duplicate/concurrency protection and audit provenance. It must create no balance or journal and must not repurpose Maker's existing cash GL. No manual SQL workaround, duplicate Company, or relabelling cash as bank is proposed.

**Boundary:** does not prevent operation of the existing cash location or Phase 2 preparation. Blocks Phase 3 acceptance of an additional bank/cash location; Phase 2 should identify the actual required bank/location master data. No claim is made that an unexamined Maker spreadsheet contains bank transactions.

## P1 — Company configuration, data and acceptance requirements

1. **Approved funding policy/mappings and identities:** currently zero operational liability configuration rows. The existing Accounting Admin workflow can create separate approved capital/current/loan/reimbursement controls, and Parties supports custody holders and employees. Choose classifications from actual evidence; never default all funding to loans, treat withdrawals as expense/dividends, or invent office cash for direct handovers.
2. **Opening completeness and physical evidence:** zero certified opening postings and zero cash-count records. Prepare supported cutover schedules, partner/holder obligations, actual location evidence and reconciled originals. Existing historical negative balances are not automatically errors or available cash; no artificial funding, zeroing or backfill. This gate did not repeat the completed five-balance investigation. Unsupported opening dimensions must be isolated before any import/posting.
3. **Operational masters:** verify actual Projects/statuses, contracts/counterparties, quantities, signed measurement approvals, retention, original invoices and tax evidence. Existing creation/amendment workflows are available; financial account prerequisites remain P0-01, not ordinary data entry. Do not re-recognize certified work as an ordinary expense.
4. **Payroll onboarding:** live Maker counts are zero policy events, employment-term events, payroll setup events and payroll profiles. Accounting Admin must explicitly approve the supported scheduled-minute cutover policy, create/reuse approved `SALARY_PAYABLE`/`PROJECT_COST` mappings, establish any dedicated advance receivable, and enter actual employees, terms, schedules and recovery approvals. These setup paths exist; no salary, attendance or employee was seeded. Policy/legal approval and factual data cannot be inferred from a tested formula.
5. **Single operator and confidentiality:** Maker's active Accounting Admin can perform the supported complete cycle without a second approver. Ordinary Accountant permissions are intentionally narrower and do not include every administrative/attendance action. Management Viewer remains report-only and is denied payroll. Explicit salary-free Foreman entry is not required for the supported single-operator model.
6. **Production acceptance evidence:** obtain confirmation that the existing maker Production alias serves the exact approved SHA/Ready deployment and complete authorized non-mutating signed-in checks of the relevant screens. Current provider success and an HTTP 200 are insufficient proof of authenticated operational acceptance. This missing evidence does not prevent Phase 2 preparation and is not classified as a demonstrated software regression.

## P2 — deferred functionality; no established Phase 2 dependency

- WPS submission, statutory wage/leave/termination automation, legal deduction caps, multi-shift/multi-site intraday allocation and salary-free explicit Foreman delegation. No statutory compliance is claimed. A specific real requirement discovered in source preparation must be assessed before operational use, rather than silently presumed supported.
- Full fiscal closing, Company-wide opening trial-balance/carry-forward, automatic bank statement matching, consumed-opening forward correction, advanced assets/inventory, hybrid contracts/final uncapped closeout and attachment redesign. These do not delay preparation absent a demonstrated Maker dependency; unsupported real transactions must not be posted as ordinary expenses.
- General Treasury-to-Treasury transfer entry is not established by the inspected authenticated routes. Supported cash/bank receipts, settlements, payments and reversals must not be described as a general transfer command. No actual Maker inter-Treasury transfer dependency was established without examining source data; do not fabricate an indirect transfer through Custody. Reassess only if Phase 2 establishes that requirement.
- Final comprehensive integrity audit and disaster-recovery validation remain separate required operational-readiness gates, deferred **from this assessment**, not waived. Existing encrypted migration75 backup integrity/scope evidence predates migrations76–81; restoration has not been demonstrated and current81 recovery is not claimed. The risk-based policy in AGENTS.md does not require another restoration experiment for this data-preparation gate.

## Accounting, security and reporting evidence reused

| Existing evidence | Completed coverage reused; no suite rerun |
|---|---|
| [Financial Operations](financial-operations-verification.json) | 24 + 43 database checks; 3 + 6 concurrency scenarios; 16 + 9 browser checks; 4 + 4 export checks; successful build. Distinct classifications, canonical liability/cash movements, direct handover, balances, recorded-funds guards and reversals. |
| [Certified openings](certified-opening-verification.json) | 32 database/report/schema checks, 7 concurrency, 14 browser, 4 artifact checks and successful build. Exact deltas, duplicate/stale prevention, count reviews and preserved history. |
| [Contracts](operational-contract-verification.json) | 47 database, 4 concurrency, 11 browser, 4 export checks and successful build. Measurements/certifications, contract-scoped payables/advances/retention, authorized payment and immutable lineage. |
| [Expenses](expense-lifecycle-verification.json) | 43 database, 5 concurrency, 13 browser, 8 artifact checks and successful build. Partial drafts, review versions, once-only Treasury/Custody consumption, personal/supplier liabilities, source uniqueness and reversals. |
| [HR](hr-operational-verification.json) | 60 database checks including 4 excluded-employee recovery regressions, 5 concurrency, 18 browser, 14 artifact checks and successful build/focused lint. Exact earnings, salary accrual versus settlement, separate advance recovery, labor allocation and reversal dependencies. |
| [HR read compatibility](hr-readonly-rpc-verification.json) | 21 actual local PostgREST GET/POST and native PostgreSQL checks: no 25006, role/tenant/privacy enforcement, original write locks, legacy Lite reads and balanced posting/payment/reversal. |

These tests establish supported engines with valid fixture setup, not completeness of Maker's live chart. That distinction explains P0-01/02 despite passing milestone tests.

Additional read-only checks in this gate used forced repeatable-read READ ONLY transactions: exact canonical81 alignment; live role-scoped HR/profile reads; historical payroll visibility; Company setup aggregates; journal balance aggregate. Maker Accounting Admin successfully reads HR/profiles and the retained 25 historical payroll sources/one audit row. Maker Management Viewer has no `payroll.manage` and sees zero such source/audit rows. An existing Accountant in another authorized Company also reads HR successfully; this does not imply Maker has an Accountant membership. Cross-tenant denial, read-only RPC transport, private grants and write-lock behavior are reused from the focused release evidence, not falsely reported as retested here.

Authenticated screens are mounted in `src/app/TenantReadyApplication.tsx`, `src/attendance/AttendanceApplication.tsx` and `src/payroll/PayrollApplication.tsx`, with role-filtered navigation in `src/workspace/workspaceNavigation.ts` and authoritative database permission checks. Browser/export evidence covers English LTR, Arabic RTL, desktop and narrow responsive views. Printable PDF uses the existing browser print/Save PDF workflow. Project-cost totals derive from posted expense-account journal lines: commitments, transfers, advances, reimbursement/salary settlements and partner withdrawals are not recreated as operating/project cost. Payroll-restricted totals are explicitly scoped; no misleading full financial statement is certified.

Private read-only evidence is retained in `/tmp/narvo-readiness-gate` with restricted local permissions. Company/Auth UUIDs, salary amounts and credentials are intentionally excluded from this report. No authenticated Production browser session or financial command was exercised, and no full project audit, suite, build, restoration rehearsal or Excel import was repeated.

## Lifecycle disposition and exact next step

| Category | Disposition |
|---|---|
| Business/accounting | VERIFIED for documented engines; Maker configuration/data DEFERRED; two existing-Company setup gaps confirmed. |
| Security/authorization | VERIFIED from focused existing evidence plus current read-only role/privacy probes; comprehensive final audit DEFERRED. |
| Database | VERIFIED canonical1–81 alignment and zero current Maker journal imbalances; no schema/data change required or authorized by this assessment. |
| Deployment | VERIFIED GitHub SHA and provider-reported completed Production-labelled deployment; exact current alias binding/Ready and signed-in acceptance NOT VERIFIED. |
| Testing | Existing local automated/native/browser/export/build evidence reused; new checks READ ONLY. Broader audits and live business acceptance DEFERRED. |
| Documentation | This focused gate records current evidence and limits; historical canonical roadmap/handoff intentionally preserved. |

**Recommend proceeding to Phase 2: prepare Maker's original Excel data under a separate explicit task.** Preserve originals; identify real source documents, parties/projects/contracts, cash/bank locations, dates/cutover, balances and exceptions for reconciliation, without importing or posting. Do not begin that work automatically. Resolve P0-01 and any required P0-02 location setup before Phase 3 financial import/operational acceptance; do not bypass them with manual ledger writes, duplicate Companies, or invented opening balances.
