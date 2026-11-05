# HR, Attendance & Payroll — focused Go-Live discovery

2026-11-05. **Discovery complete; implementation NOT authorized or started.** Existing Lite accounting should be extended, not rebuilt. Essential operational readiness is **BLOCKED** by missing employee/payroll setup, explicit attendance/employment policy integration, and a confirmed historical-payroll confidentiality gap.

## 1. Scope, baseline and evidence

- Product Owner reports Production baseline `1fac514`; the relevant working source and canonical documents match local release commit `1fac514ab4e9bfc5d208cee0d3acc943ea00429b` byte-for-byte. Local development remains `release/platform-owner-console` at652bc37 with the preserved expense-release working files. No checkout, synchronization, commit, push or Vercel verification was performed in this discovery.
- **VERIFIED:** focused hosted READ-ONLY queries against `eqnzueginpkskbnqvgoc`:80 applied migrations, latest `20261105110000`; all15 relevant public attendance/payroll tables have ENABLE/FORCE RLS.18 inspected HR/payroll/person/funds function bodies match canonical source, have empty search paths and deny anonymous execution. These are catalog/source checks, not fresh posting tests or a full security audit.
- **VERIFIED:** real Management Viewer RLS SELECT within a read-only transaction, configuration counts and existing permissions; no names, employee Auth UUIDs, salary values or credentials are reproduced here. Maker was resolved by its previously verified Company UUID, not a display-name match.
- **DOCUMENTED:** historical Development test results, approved policies and prior isolated browser/export checks. Test files were inspected; their old passes are not newly executed passes.
- **NOT VERIFIED:** current signed-in Production UI/visual acceptance, actual payroll run/payments, bank settlement, employment evidence, statutory applicability, comprehensive fiscal close, WPS format/submission or current full accounting reconciliation. No tests with writes, including rollback fixtures, were executed. No build or restoration rehearsal was run.

Only this report is created. No other source, migration, canonical roadmap/handoff, business data or existing working file is changed.

## 2. Approved requirements retained

Read AGENTS.md; canonical master roadmap, accounting requirements register and handoff/roadmap; Attendance Lite and Payroll Lite Steps1–3; and the available historical `/home/nagham/Downloads/NARVO_HR_ATTENDANCE_PAYROLL_ROADMAP_PROMPT.md`. No required historical HR source was missing.

Current authority remains HR-01/02/03 and existing H1–H4: effective-dated employment/salary policies; explicit calendar/minute attendance with unknowns; monthly review/corrections/locks; deterministic payroll with separate accrual/payment/recovery; project labor allocation; restricted bilingual reports/payslips. Preserve the single-accountant operator model, existing employee identities, Company RLS and immutable posted snapshots. Historical instructions to create a successor master roadmap are requirements context only; the current request permits this report alone.

The Lite approval is narrower: monthly salary divided by actual calendar days, deductible half/full absence exceptions, supported manual earned additions/current-entitlement reductions, one Project or overhead per employee, Admin posting/reversal and Accountant/Admin preparation/payment. This is an approved product calculation, **not certification of UAE legal compliance**. Empty-day semantics must change only under HR-03's explicit effective-date/mode policy; old reviewed/posted periods must not be reinterpreted.

## 3. Capability matrix

COMPLETE below means complete **within the named Lite capability**, supported by source plus recorded tests; it does not mean Maker is configured or freshly operationally accepted. Evidence keys are resolved in section13.

| Employee capability | Classification | Actual coverage / gap | Evidence |
|---|---|---|---|
| Company-owned Employee registration | COMPLETE | `/parties` Admin creation supports Employee, Custodian and dual roles; reuse stable Party IDs | E1 |
| Name/status and personnel lifecycle | PARTIAL | Create with status and edit Employee name; salary profile has independent status. No hire/termination/rejoin workflow with dated employment history | E1, P1 |
| Salary profile and audit | COMPLETE — Lite | Unique Payroll ID, descriptive profession/station/type/payment type, one salary/default Project, versions and audit; these are not employment contracts | P1 |
| Employment terms/contracts/effective dates | MISSING | No effective salary schedule, employment interval, contract terms/documents or automatic join/exit proration | P1, E1 |
| Basic salary, recurring allowance/component structure | PARTIAL | One monthly amount and manual supported additions; no separately versioned basic/allowance rules | P1, P2 |
| Proration, paid/unpaid and overtime interpretation | BLOCKED BY POLICY | Effective dates, wage basis, schedule, leave and compensation rules require approval before calculation | R1–R3 |

| Attendance capability | Classification | Actual coverage / gap | Evidence |
|---|---|---|---|
| Site/date eligibility and transfers | COMPLETE — Lite | Dated nonoverlapping single-site assignments; original identity/start retained, end corrections reason/version-bound; dual Employee roles supported | A1, E1 |
| Daily attendance facts | PARTIAL | Half/full salary-deductible absence exceptions only. Current label is “No recorded absence”; scope still infers presence from missing exceptions | A1, A2 |
| Monthly review | COMPLETE — Lite | Assignment roster, exception list, totals, revision-bound confirmation; does not prove daily submission/completeness | A1 |
| Editable employee × real-date monthly matrix | MISSING | No calendar grid, cell selection, keyboard-grid or bulk preview/commit | A1, R1 |
| Explicit Present/Unrecorded and approved leave/rest/holiday | MISSING | No distinct facts or approval objects; an absence note is not approved leave | A1 |
| Partial-hour absence, late/early/interruption | MISSING | Only integer half-day units; arbitrary minutes cannot be recorded | A1, A2 |
| Work calendars/shifts/breaks/overnight/overtime | MISSING | No expected-minute calendar or actual-time intervals; timezone/day-boundary policy unresolved | A1, R1–R3 |
| Multiple sites within a day / labor time split | MISSING | Existing assignment overlap guard deliberately prevents this | A1, E1 |
| Open-month corrections and audit | COMPLETE — Lite | Admin corrections; scoped Foreman own-entry corrections; reason/version/void history and review invalidation | A1 |
| Locks and post-lock correction | COMPLETE — Lite | Lock is atomic with payroll posting; payroll/payment reversal dependencies reopen correction. No arbitrary unlock or separate pre-payroll lock UI | A1, P2 |
| New explicit-attendance mode/cutover | BLOCKED BY POLICY | Define Company timezone, effective date, unknown handling and draft conversion; preserve all old inference/snapshots | R1–R3 |

| Payroll capability | Classification | Actual coverage / gap | Evidence |
|---|---|---|---|
| Monthly calculation/preview | COMPLETE — Lite | Calendar days28–31; exact absence rounding; explicit refresh, source hashes and stale review rejection | P1 |
| Additions/deductions | PARTIAL | Earned addition and current-month entitlement reduction only; not arbitrary accounting classifications | P1, P2 |
| Employee loans/advances and payroll recovery | BLOCKED BY POLICY | No employee-loan/recovery subledger or repayment schedule/commands; approved classification, authority and recovery limits needed | P2, R2 |
| Preparation, approval and posting | COMPLETE — Lite | Accountant/Admin prepare; Admin explicitly approves/posts reviewed completed month; no separate approver staffing required | P2 |
| Salary payable and actual payments | COMPLETE — Lite | Entitlement-based Treasury/bank partial payments, authoritative outstanding, date/reference and overpayment controls; no new expense on payment | P2 |
| Custody-funded salary settlement | MISSING | `pay_salary` accepts Treasury only. Never substitute a custody Expense, which would recognize payroll cost again | P2, D1 |
| Corrections/reversals/replacement | COMPLETE — Lite | Reverse live payments before payroll; exact inverse journals; replacement links previous posting; attendance/draft re-review | P2 |
| Duplicate/race prevention | COMPLETE — Lite | Company serialization, kernel request hashes/idempotency, private one-live-period index and source uniqueness; historical race evidence | P2 |
| General fiscal-period closure enforcement | PARTIAL | Completed payroll month and payment-date/dependency checks exist; not a complete Company fiscal close/reopen policy or common closed-period guard | P2, D1 |
| Project labor costs | PARTIAL | Exactly one Project/overhead per employee, explicit plan, same journal-derived cost reporting; no worked-time/percentage split | P2, O1 |
| Payroll privacy | PARTIAL — confirmed gap | Live profiles/postings/journals restricted; historical PAYROLL sources/audit/export path admits Viewer | F1 below |
| WPS processing | DEFERRED / NON-BLOCKING for application expansion | No validated format, submission or bank acknowledgment; actual legal payment-channel dependency must be checked separately | R3, section9 |

## 4. Actual UI/database readiness and Maker setup

Authenticated routes exist: `/parties`, `/attendance`, `/payroll`, Treasury and accounting reports. Payroll currently defaults to the historical Source Payroll tab; operational profiles/register are separate tabs. Payroll profile creation **is not** Employee registration; the correct order starts at `/parties`.

Hosted READ-ONLY snapshot at approximately `2026-11-05T07:51:45Z`:

| Maker readiness item | Observed |
|---|---|
| Active persons with Employee capability | 1 |
| Payroll profiles / draft periods / postings / salary payments | 0 / 0 / 0 / 0 |
| Employee site assignments / absence exceptions / attendance periods | 0 / 0 / 0 |
| Active stable `SALARY_PAYABLE` mapping | Missing |
| Active stable `PROJECT_COST` mapping | Missing |
| Active stable `COMPANY_EXPENSE` mapping | Present |
| Active Accounting Admin / active Treasury | 1 / 1 |

These counts are **configuration/evidence gaps**, not proof that Maker has only one real employee or no wages payable. No employee roster import, opening certification or historical reconciliation occurred. Missing `SALARY_PAYABLE` blocks all payroll accrual; missing `PROJECT_COST` blocks project-allocated payroll. A similarly named unkeyed account does not satisfy canonical mapping. Current account/payable balances and available cash were not assessed here.

New-Company provisioning defines the stable mappings, but that does not prove safe adoption for an existing Company. Use accountant-approved existing-chart mapping and an authorized controlled configuration procedure; do not blindly rerun foundation provisioning, replace accounts, create arbitrary journal lines or patch hosted SQL outside canonical discipline.

## 5. Accounting integration

Current deterministic calculation uses monthly salary S, absence half-units U, calendar days D: deduction = `round(S × U / (2 × D))` once in PostgreSQL numeric arithmetic; gross-after-absence = S−deduction; net earned = gross + approved earned additions − approved current-entitlement reductions. Persisted financial values are BIGINT minor units; browser/RPC money is exact decimal strings/BigInt.

`post_payroll` recognizes that **supported net earned entitlement**, Dr `PROJECT_COST` or `COMPANY_EXPENSE`, Cr `SALARY_PAYABLE`, retaining employee/Project. It atomically writes immutable snapshot, entitlements and one-live-period link, posts via `private.create_journal`, and locks reviewed Attendance. This matches the frozen Lite contract; it is not a gross-pay/recovery accounting engine.

`pay_salary` Drs the entitlement's recorded payable account and Crs the actual Treasury permanent GL. Partial settlements cannot exceed authoritative unpaid entitlement. Later inactive Employee/closed Project does not trap settlement. Existing77 journal-line funds guard applies to salary Treasury outflows as well; sufficient evidenced funding is required. No Treasury/Custody rewrite is needed.

Expanded recovery must **not** merely add a generic deduction: gross earned compensation and expense must remain distinct from settlement of an employee receivable. Custody advances represent Company funds held, and personal reimbursements represent Company liabilities; neither is automatically a salary loan/recovery. New recovery classifications require approved business evidence, separate subledger effects, bounded recovery/reversal dependencies and the existing kernel. Unknown classifications must remain unposted.

Posting/payment reversals use canonical exact inversion and immutable history. Existing Payroll costs already reach authorized Project-cost/Party salary-payable reports. Payments are not cost again. General fiscal closing and employee-specific salary proration/component policies remain unimplemented; do not claim the Lite date checks implement them.

## 6. End-to-end workflow gaps

`Employee registration ✓ → effective employment terms ✗ → calendar ✗ → attendance exceptions only △ → revision review ✓ → leave/minutes/overtime ✗ → Lite calculation ✓ → Admin approval/accrual + lock ✓ → Treasury settlement ✓ → register ✓ / individual payslip ✗`

Genuine broken/missing handoffs:

1. Employment dates/salary versions do not produce the expected calendar or approved payroll policy snapshot.
2. Attendance review cannot validate explicit daily completeness, minute facts or approved leave/overtime; missing exceptions can still yield a full-month salary.
3. New facts cannot yet feed a reproducible minute/leave/overtime calculation without approved denominators and effective-date semantics.
4. No employee receivable/recovery workflow exists; misuse of current salary reduction would understate earned payroll cost.
5. Maker lacks required configuration/data before even the supported Lite chain can operate.
6. Individual payslips and attendance reports are absent; current register does not carry payment/recovery/component detail.

This does not justify rebuilding the existing accrual, payment or reversal engine.

## 7. Authorization and confidentiality

Hosted permissions confirm:

| Role | Attendance | Payroll |
|---|---|---|
| Accounting Admin | Record, manage assignments, review | Prepare/review, post, pay, reverse |
| Accountant | Review only | Prepare/review and pay; cannot post/reverse |
| Foreman | Assigned-site entry/own correction only | Denied |
| Management Viewer | No operational attendance route/commands | Live Payroll denied; historical-source exception below |
| SYSTEM_ADMIN / other roles | No implicit bypass | No implicit payroll access |

Maker has an active Accounting Admin, so no two-person staffing requirement blocks the single operator. If the intended operator has only ACCOUNTANT role, Admin posting authority must be resolved explicitly; do not weaken permission checks. Employee identity visibility in masters is distinct from salary visibility.

**F1 — confirmed confidentiality coverage defect relative to HR-03.** `PayrollApplication.tsx` explicitly routes Viewer to `HistoricalImports recordType="PAYROLL"`. Migration `20261008160000_historical_active_review_ux.sql` grants Viewer SELECT visibility on historical sources/audit without excluding PAYROLL. The component reads salary/source fields and offers export. In a READ-ONLY transaction with an existing active Maker Viewer identity and real `authenticated` RLS, `payroll.manage=false`, visible live profiles/postings=0, **visible historical PAYROLL records=25**. No salary values were retrieved/output for this discovery. This is an actual same-Company salary-source disclosure, not cross-tenant access and not a mutation privilege.

The historical reporting policy deliberately introduced broad management source access; whether this exception is intended requires explicit reconciliation with the canonical no-payroll-disclosure requirement. Recommended safe scope: keep general historical management reports readable, restrict PAYROLL sources **and their audit/export/read paths** to approved payroll roles, then test existing Viewer/Foreman/journal/report boundaries. Hiding a tab alone is insufficient. No permissions or data were changed here.

## 8. UI and reporting coverage

| Output / experience | Classification | Evidence and limits |
|---|---|---|
| Attendance daily/review EN/AR, mobile cards | PARTIAL | Source supports locale/RTL and responsive layouts; historic390px interactions documented. No new Production browser acceptance |
| Matrix, minute editor, keyboard bulk operations | MISSING | No actual calendar grid or bulk command/preview |
| Attendance XLSX/PDF | MISSING | Source payroll attendance text/export is not a structured monthly attendance report |
| Payroll register XLSX | COMPLETE — Lite | 13 columns, Company/month/source ID, exact text money/totals, DRAFT/POSTED/REVERSED, formula-text safety and RTL |
| Payroll register PDF | COMPLETE — Lite | Actual browser Print/Save PDF, A4 landscape, repeated headers and captured reviewed/frozen data; not a standalone payslip engine |
| Expanded register/payment/recovery details | PARTIAL | Actual payments/outstanding shown in UI, but13-column output lacks component/recovery and paid/part-paid detail |
| Individual bilingual payslip PDF | MISSING | Register Print is not an employee payslip |
| Project labor-cost report XLSX/PDF | PARTIAL | Existing journal-derived Project-cost report includes authorized Payroll and reversals; no minute/split allocation; Viewer salary coverage intentionally restricted |

The register's “No. of Days Worked” is calendar days minus deductible absence, **not measured worked days/hours**. Preserve legacy numeric meaning and correct that distinction in expanded output. Current UI/print source and prior tests support EN/AR/desktop/mobile intent; fresh visual/keyboard/pagination acceptance remains NOT VERIFIED. No new design or theme changes are required.

## 9. UAE policy and regulatory dependencies

Keep four boundaries separate:

- **Supported:** the frozen Lite rules above, without a statutory-compliance claim.
- **Company policy requiring approval:** effective employment/salary dates; basic/allowance components; working/rest/holiday schedules, breaks and overnight attribution; paid/unpaid leave; minute deduction denominator/rounding; overtime approval/compensation; recovery authorization/caps; allocation basis and cutover; payroll operator authority.
- **Regulatory/provider verification:** applicable employment regime and worker category, contract requirements, lawful leave/overtime/deductions and final settlement, current WPS obligations/exemptions/dates, and the selected agent/bank format and reconciliation. Do not infer these from a generic payroll profile or use configurable policy to override applicable law.
- **Deferred commercial scope:** automated WPS file/submission/acknowledgment integration, biometric devices, employee self-service, recruitment, benefits and advanced HR automation, unless a verified operational dependency is established.

A focused official-source check was performed; it is not comprehensive legal acceptance. [CBUAE UAEWPS](https://centralbank.ae/en/our-operations/payments-and-settlements/uae-wages-protection-system-uaewps) describes employer-to-agent wage information/fund flows, disbursement confirmations and refunds. It does not establish that NARVO's ordinary bank-payment record or XLSX is compliant. The [UAE Government wages guidance](https://u.ae/en/information-and-services/jobs/employment-in-the-private-sector/payment-of-wages) identifies WPS obligations for Ministry-registered establishments; applicability/exemptions and current instruments need qualified confirmation. [Official working-hours guidance](https://u.ae/en/information-and-services/jobs/employment-in-the-private-sector/working-hours) is a verification input, not an implemented rule set. No legal rate, deduction formula or WPS deadline is invented here.

Confirm Maker's actual authorized wage-payment channel. If an approved external agent handles WPS, internal payroll can reconcile its actual payments without building WPS integration first. If no compliant required channel exists, that is a **business Go-Live dependency**, not permission to call a generic export WPS. Full statutory/provider acceptance remains NOT VERIFIED.

## 10. Genuine blockers and deferrals

**GO-LIVE BLOCKER** for the requested essential HR/payroll scope:

- F1 historical salary-source confidentiality must be resolved before asserting protected payroll reporting; already observable, not hypothetical.
- Maker's approved roster/profiles/attendance assignments and stable Salary Payable/Project Cost mapping are not configured. Do not fabricate employees, openings or wage obligations to pass readiness.
- Effective terms/calendar and explicit absence/leave/minute-to-payroll interpretation are missing; approve the specific policies and legacy/new cutover before recognizing expanded payroll.
- Attendance operational output and individual payslip are absent from the requested workflow. Reuse output infrastructure, not an additional ledger.
- Employee advance/recovery is a blocker **for transactions that require it**; unclassified recoveries must remain blocked rather than using salary reductions. Split labor allocation is similarly conditional on actual multi-site cost requirements.
- Real operator, payroll reconciliation and applicable wage-payment-channel acceptance remain unverified. No general Production audit is performed here.

**IMPORTANT BUT NON-BLOCKING:** improve operational tab discoverability/readiness messages, distinguish payable/calendar from actually worked days, include payment/GL references and clear paid states in expanded output; prove current responsive/keyboard/export acceptance. Full Company fiscal close is separate, but any claimed closed-period payroll behavior needs an approved bounded guard before use.

**DEFERRED COMMERCIAL SCOPE:** full HR overview/analytics, departments beyond available data, recruitment, self-service, biometric integration, advanced rota/leave automation, optional attendance import, automated WPS integration where an approved external channel suffices. No change to canonical priorities is proposed.

## 11. Minimum implementation sequence

One focused extension under existing H1–H3, delivered in this order; no replacement roadmap or unnecessary new milestones:

1. **Close F1 and establish setup readiness while adding effective Employee terms.** Reuse Party/dual-role creation and Payroll profiles/audit. Add only employment/salary effective versions and approved components needed for real payroll, plus mapping/readiness checks. Preserve IDs/snapshots; obtain separate approval for actual Company configuration or data entry.
2. **Calendar + explicit attendance + review in one coherent slice.** Version the Company policy/cutover; record scheduled/actual/absence/leave/approved overtime facts in integer minutes. Provide daily/mobile entry and monthly matrix with bounded bulk preview, conflict handling and immutable audit. Support overnight/break facts without inventing pay treatment. Keep legacy inferred periods identifiable and unchanged; unresolved new facts remain unrecorded and block payroll completeness.
3. **Adapt calculation/preparation to that frozen source.** Snapshot the approved salary/leave/minute rules, deterministic rounding and components. Separate earned additions/current-pay reductions from approved employee receivable recovery. Add split allocation only where required, conserving the single recognized cost. Reuse existing draft refresh/version/review/approval and single-accountant roles.
4. **Reuse posting and settlement; extend only the necessary journal composition/dependencies.** Keep canonical journal/idempotency/entitlement/payment/reversal infrastructure. If recoveries are included, preserve gross earned cost and clear the approved receivable separately. Add only approved payroll period guards needed for supported dates. Continue Treasury sufficiency controls; never turn custody transfers or salary settlement into ordinary Expenses.
5. **Finish outputs and focused acceptance together.** Attendance XLSX/landscape PDF, expanded register/payment states and individual payslip PDF from reviewed/frozen sources, using existing exact-money writers/print infrastructure. Prove leap/month edges, minutes, overnight/leave conflicts, policy changes, stale/bulk/locked edits, allocation and recovery reconciliation, duplicate run/payment races, reversals, tenant/role/export privacy, EN/AR keyboard/mobile, real isolated SQL and browser workflows, then Production build. Hosted mutations/publication require their own authorization.

Core facts/setup can progress independently of undecided compensation rules; do not generate financial results for unresolved categories. No need to restart Treasury, Custody, Projects, Contracts, Openings or Expenses, or finish every advanced H4/WPS feature first.

## 12. Recommended immediate next task

Authorize the **essential HR/Attendance-to-Payroll extension above**, starting with the confirmed historical PAYROLL privacy boundary and Company readiness checks, effective-dated Employee terms, and explicit scheduled/minute attendance with review/exports. Include the narrow payroll source/calculation adapter and payslip/register completion after the relevant policies are approved; keep existing accrual/payment/reversal machinery. Request only the underivable policy decisions listed in section9, with no guessed payroll defaults. This discovery does not authorize that implementation or hosted setup.

## 13. Supporting evidence and verification limits

| Key | Inspected sources |
|---|---|
| R1 | `NARVO_ERP_MASTER_ROADMAP_V2.0.md`: H1–H4, HR target/mode transition and report acceptance; `NARVO_ERP_ACCOUNTING_REQUIREMENTS_REGISTER.md`: HR-01/02/03 |
| R2 | `AGENTS.md`, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`; frozen accounting, privacy and scope decisions |
| R3 | Available historical `NARVO_HR_ATTENDANCE_PAYROLL_ROADMAP_PROMPT.md` in Downloads; current request takes precedence over old execution instructions |
| E1 | `src/master/PersonMasterCreationPanel.tsx`, `personMasterRepository.ts`, `PartiesList.tsx`, `EmployeePartyNameControl.tsx`, `employeePartyNameMutations.ts`; `20260922120000_p6c_employee_party_name.sql`, `20261007140000_v1_party_person_roles_project_creation.sql` |
| A1 | `src/attendance/AttendanceApplication.tsx`, `attendanceRepository.ts`; `20260927120000_attendance_foreman_role.sql`, `20260927121000_attendance_lite.sql`, later person-role adapters in E1 |
| A2 | `src/attendance/attendanceText.ts`, `docs/ATTENDANCE_LITE.md` |
| P1 | `src/payroll/PayrollApplication.tsx`, `payrollRepository.ts`; `20260928120000_payroll_lite_drafts.sql`; `docs/PAYROLL_LITE_STEP_1.md` |
| P2 | `src/payroll/PayrollPosting.tsx`, `payrollPostingRepository.ts`, `payrollPostingAttempt.ts`; `20260928130000_payroll_salary_payable_key.sql`, `20260928131000_payroll_lite_posting.sql`, `20260928132000_payroll_posting_alias_correction.sql`; `docs/PAYROLL_LITE_STEP_2.md` |
| O1 | `src/payroll/{PayrollRegisterOutput.tsx,payrollRegister.ts,payrollRegisterRepository.ts,payrollRegisterXlsx.ts,payrollRegister.css}`, `docs/PAYROLL_LITE_STEP_3.md`; `src/reports/{projectCostLedger.ts,ProjectCostLedger.tsx,partyStatement.ts}` |
| D1 | `20260831120000_p5a_accounting_kernel.sql`, `20261101120000_company_accounting_provisioning.sql`, `20261104190000_operational_liability_posting.sql`, `20261105090000_certified_opening_cash_reconciliation.sql`; existing Treasury/Custody integration |
| F1 | `src/payroll/PayrollApplication.tsx:29`, `src/workspace/workspaceNavigation.ts`, `src/historical/{HistoricalImports.tsx,useHistoricalSources.ts}`; `20261008140000_historical_source_records.sql`, `20261008152000_historical_payroll_trace.sql`, `20261008160000_historical_active_review_ux.sql`; current hosted policy and Viewer RLS count |

Historical evidence reviewed, **not rerun**: `scripts/verify-attendance.mjs`, `verify-attendance-interactions.mjs`, attendance SQL hosted/final checks (documented84); Payroll Step1 verifier/interactions and SQL (documented127); Step2 verifier/interactions/concurrency and SQL (documented114 and four race schedules); `scripts/verify-payroll-step3.mjs` verifies actual generated XLSX/print PDF with isolated synthetic transport. Their limitations remain: old Development checkpoints, some in-memory browser transports, no new real payroll acceptance. Current discovery adds only the read-only catalog/configuration/function/RLS observations recorded above.

Lifecycle disposition: requirements/source/database discovery **VERIFIED**; historical test/visual passes **DOCUMENTED**; current Production business/UI/legal acceptance **NOT VERIFIED**; implementation/deployment **NOT AUTHORIZED**. Stop here for Product Owner direction.
