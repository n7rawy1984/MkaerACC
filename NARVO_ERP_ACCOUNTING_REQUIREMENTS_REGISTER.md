# NARVO ERP — Accounting Requirements Register

Canonical detailed register, 2026-11-02, Asia/Dubai. Companion: [Master Roadmap V2.0](NARVO_ERP_MASTER_ROADMAP_V2.0.md). This register preserves intent, design questions and acceptance; milestone execution order belongs only to the roadmap. Documentation review does not authorize implementation, financial mutation or release.

R0 visual checkpoint,2026-11-02: **local review PASS, human visual approval PENDING**. [Report](docs/R0_COMMERCIAL_ONBOARDING_VISUAL_ACCEPTANCE.md) and [gallery](docs/release/r0-commercial-onboarding-visual/index.html): 147 assertions,41 screenshots,31 focused axe scans/0 violations. Two local UI/CSS files changed only; earlier E1 hash-match statements below record the preceding historical review, not a current identical-source claim.35 stable IDs and91 milestone associations retained. Hosted migration/frontend activation and genuine hosted acceptance remain deferred; Maker unchanged.

## Register contract and accounting controls

Stable source IDs FIN-01 through QA-01 below are preserved exactly from source S4. Twelve supplemental IDs preserve obligations from V1.6, the older project roadmap and the HR/inventory specifications that the 23-row summary did not separately identify. Total: **35 requirement records: 23 source-normalized and 12 supplemental**. These are requirement families, not a count of every sentence or original office observation. The original October22 file is now supplied as S6 and has been read completely (216 lines); the former unavailable-original limitation is resolved for this source. Final reconciliation covers60 material source units, separately enumerated below, without inventing new requirement IDs or treating the35-family count as proof of coverage.

Provenance uses roadmap S1–S7 and evidence E1–E7, defined with paths in [the roadmap](NARVO_ERP_MASTER_ROADMAP_V2.0.md). S6 sections0–8 and V1.6 section references below identify the historical business problem. S6 is historical requirements evidence; the current pasted reconciliation request governs edits and execution boundaries. S2/S3 are expanded product requirements, not proof of implementation or legal policy. Each record links a roadmap milestone; that milestone references the same ID in return.

Implementation status: IMPLEMENTED, PARTIAL, PLANNED, or NEEDS_VERIFICATION. Policy gate: DECISION REQUIRED separately identifies an unresolved affected treatment; a partial feature may also have a policy gate. Verification must name the layer: source inspection, recorded local fixture, disposable SQL, historical hosted synthetic/rollback/concurrency, Preview, Production read-only, genuine financial execution, or expert signoff. No bare COMPLETE/VERIFIED means all layers. Hosted/release currency is the dated recorded baseline, not a fresh query.

Disposition describes normalization, not completion: retained = valid reusable requirement preserved; generalized = company observation converted to reusable scope; revised = treatment/assumption qualified; superseded = original repair replaced by demonstrated scoped fix while residual coverage is retained. A DECISION REQUIRED tag can accompany any disposition; it is not an exclusive accounting correctness verdict.

All financial acceptance inherits AGENTS.md: server-derived actor and explicit active Company permission; authoritative master/lifecycle validation; Company-consistent dimensions/RLS; BIGINT money/integer basis points and declared rounding; normalized idempotency and source uniqueness; deterministic locks; atomic document+journal; immutable posted truth; exact authorized reversal and dependency rules; direct-write/private-helper denial; cross-tenant and competing-request tests. Each new event must have recognized assets/liabilities/cost/revenue, required dimensions and settlement rules approved before implementation. An inactive/closed master must not trap a legitimate existing payable/receivable. Browser command inputs describe business events, never arbitrary journal lines/accounts.

Accountant/domain expert owns financial treatment approval; product owner owns company-policy choices and acceptance; engineer owns design/implementation; verifier owns reproducible evidence; release operator owns approved environment/recovery. Named personal assignees and due dates are not established. No IFRS/UAE/labor/WPS certification is asserted.

## Source requirement normalization ledger — 23 records

| ID | Class and disposition | Actual implementation/evidence limit | Roadmap milestone | Decision gate |
|---|---|---|---|---|
| FIN-01 | Universal exact-money control; superseded original raw-fils repair | M1 fix and recorded local tests; accepted package promoted E2/E3; all future export surfaces still need coverage | M3, M5B | None for formatting; no monetary data rewrite |
| FIN-02 | Universal event/source completeness; retained | PARTIAL: source review/linking and expense route; explicit unsupported nature guidance E7 | M5A | Event-specific policy and source evidence |
| FIN-03 | Universal foundation plus company fiscal choices; revised | PARTIAL: 11-account/one-Treasury baseline exists E6; no complete openings/fiscal setup | F0, M5A | Openings, fiscal calendar, entity/equity facts |
| FIN-04 | Universal reporting/reconciliation; retained | PARTIAL: posted journal/expense and source exports E7; complete statements unverified | M5B | Opening completeness, statement basis, classification |
| PRJ-01 | Reusable project lifecycle; generalized | PARTIAL: creation/metadata E7 plus audited Planning→Active locally implemented; migration66 observed applied; hosted workflow verification pending | M3 | Remaining transitions, closure/reopen authority |
| PRJ-02 | Reusable allocation control; revised | PARTIAL: atomic whole-source unposted Project/Company assignment locally implemented; migration67 observed applied, hosted workflow verification pending; correction review/audit implemented with migration68 applied; bounded current-period cash allocation execution locally verified (migration69 applied); mixed-destination whole-source batch UI/review/exports implemented (local verification in latest checkpoint); bounded posted shared allocation implemented (migration70 status in latest checkpoint); eligible cash pre-posting split integrated (migration71; latest checkpoint); originally split posted-cost corrections locally verified (migration72; latest checkpoint); prior-period/settled/bank/classification expansion incomplete | M3 | Bounded reclassification approved; wider correction/allocation policies unresolved |
| PRJ-03 | Cost-accounting policy; generalized | PARTIAL cost/overhead keys and payroll E4/E5; posted Project-cost ledger locally verified; bounded posted shared allocation implemented; eligible cash pre-posting split and cash-neutral posted split corrections integrated; WIP/expanded recognition policy incomplete | F0, M3, C2, I4 | Direct/indirect allocation and capitalization |
| EXP-01 | Historical Save/date UX bug and lifecycle clarity; superseded scoped repair | M1 labels/date evidence implemented and accepted package E2/E3; universal draft workflow remains PARTIAL | M3 | Preserve source save versus actual financial post |
| EXP-02 | Universal event classification; revised | PARTIAL specialized commands; many nonexpense source types unsupported E7 | F0, M4, M5A | Loans/funding/drawings/deposit and recovery meanings |
| EXP-03 | Universal dimensions plus tax/company policy; retained | PARTIAL Treasury/AP/custodian/owner modes and VAT controls E4; tax readiness not certified | F0, M3, I3 | Invoice validity, VAT timing/base/recoverability |
| CON-01 | Construction commercial model; generalized | PARTIAL fixed original amount; unknown-total unit-rate/hybrid and BOQ not complete E7/E4 | M4 | Quantity certification, limits and variations |
| CON-02 | Universal event separation in construction; retained | PARTIAL: substantial P5 advance/certificate/payment/retention backend and P6D paths E4 | F0, M4 | Tax/deduction waterfall and actual evidence |
| CON-03 | Reusable party/contract master quality; generalized | PARTIAL Supplier metadata/status versus Subcontractor name-only E7 | M3, M4, I1 | Trade-license verification/duplicate policy |
| CON-04 | Construction cumulative certification; retained | PARTIAL cumulative monetary work exists E4; measured unit quantities not complete | M4 | Measurement approval and applied retention/VAT |
| CUS-01 | Universal person-scoped custody; revised | PARTIAL approved pooled receivable backend E4; integrated statement/UI/source funding incomplete | F0, M4 | Physical custody versus receivable and funding source |
| CUS-02 | Configurable owner/employee transactions; revised | PARTIAL existing expense OWNER mode; dedicated drawings/employee reimbursement/recovery not established | F0, M4, H3 | Ownership/legal nature, account type and recovery |
| CUS-03 | Role-specific operational statement; generalized | PARTIAL pooled readers/backend; complete manager statement/reconciliation not verified | M4 | Manager permitted scope and confidential exclusions |
| HR-01 | Reusable attendance facts/workflow; retained | PARTIAL exception-only Lite E5; explicit matrix/leave/minutes planned | H1, H2 | HR-03 semantic transition, schedule/leave rules |
| HR-02 | Reusable payroll accrual/settlement; retained | PARTIAL Lite calculations/post/payment/reversal/exports E5; expanded policies and WPS absent | H1, H3, H4 | Salary/advance/leave/allocation/legal policy |
| INV-01 | Reusable construction procurement/stock; retained | PLANNED integrated workflow S3; inspected inventory contains no implemented stock module | I1–I5 | Costing, ownership, WIP, VAT, openings/UOM |
| UX-01 | Reusable shared workspace; retained | IMPLEMENTED accepted M2.1/M2.2 package E2/E3, not all displayed future workflows | M3, H2, I5 | Human review of each new increment |
| SAAS-01 | Reusable platform onboarding; retained | IMPLEMENTED LOCALLY + local tests E1; migration65/front end not hosted | R0 | Shared-environment activation/release acceptance |
| QA-01 | Universal integrity/acceptance; retained | PARTIAL significant per-flow historical evidence; full operational/audit acceptance deferred | R0, M4, M5A, M5B, I5, O1, O2 | Scope-specific accounting and commercial signoff |

Detailed records below define business workflows, accounting treatment, integration, audit and acceptance rather than duplicating milestone sequencing. The reciprocal milestone index near the end is the complete association map; this23-row source ledger lists principal homes only.

## FIN-01 — Exact monetary presentation

Provenance: S4 FIN-01; V1.6 §0.3/§4 P0-A (`MAKERACC-FIN-001`). Original problem: stored 6,500,000 minor units rendered as 6,500,000 instead of AED 65,000.00. Universal requirement; historical UI repair superseded by E3. Operator sees exact two-decimal AED consistently in contracts, Treasury, expenses, custody, payroll and exports without altering stored values.

Evidence: M1 report and `src/master/SubcontractsList.tsx`; E2 promoted accepted package. Residual scope: audit each new surface/locale/export, not rebuild the formatter. Acceptance: 6,500,000 → 65,000.00 AED, zero/negative/large exact values and one rounding rule; strings/BigInt preserve cents; before/after financial values unchanged. No accounting recognition or tax assumption. Milestones: M3/M5B; dependency QA-01 and existing formatter.

## FIN-02 — Source-to-canonical accounting coverage

Provenance: S4 FIN-02; V1.6 §2/§4 P0-B/§6. Historical General cash source 223 rows plus 25 Payroll source rows is evidence inventory, not current GL. PARTIAL E7: `src/historical/sourcePosting.ts` limits direct expense candidates to noncancelled/unlinked outgoing EXPENSE; supplier/payroll guidance routes elsewhere, while loans/funding/deposits/drawings have unsupported commands.

Workflow: preserve immutable raw source → reviewed correction/classification → identify real event/document → match existing posting or authorized specialized command → journal → reconciled report. Every source gets an outcome: linked, cancelled with reason, awaiting evidence/policy, nonposting commitment, or approved pending command; no forced expense and no silent omission. A source cash payment can settle an existing salary/certificate/invoice without recognizing another cost. Preserve source cash month separately from earning/invoice/recognition dates.

Acceptance: per-nature coverage report, existing source/payment deduplication, normalized retry recovery, authoritative source linkage and reversal lineage; general/payroll overlap identified; source count/totals are not TB. No automatic replay of Maker's imported rows. DECISION REQUIRED for unsupported event types/evidence; milestones M5A with M3/M4/H3/I3 dependencies.

## FIN-03 — Company accounting foundation and opening balances

Provenance: S4 FIN-03; V1.6 §4 P0-C/§9; original roadmap P9/Phase2E. Revised assumption: COMPLETE baseline setup is not complete books, fiscal periods, verified funds or commercial readiness. E6 provides protected 11 accounts/10 supported keys and an owner-specified Treasury; no fiscal calendar or opening journal. Existing Maker is never a provisioning target.

Workflow: verify legal entity/fiscal/currency policy and existing books → approve COA/system mappings → reconcile opening TB and AP/AR/custody/advance/retention/payroll/asset/stock schedules → preview supported opening command → approve/post once → verify GL and subledgers. Maker's proposed July31 opening/August1 start remains source history, not an authorized opening date or zero. Capital versus loans/current accounts and bank/cash reality require evidence.

Acceptance: complete balanced approved opening set; account/type/dimensions/subledger totals agree; one atomic idempotent opening event with immutable approval/source and controlled reversal, no fabricated offset. Missing opening displays unknown. DECISION REQUIRED: dates, year/periods, balances, equity/owner funding; milestones F0/M5A, dependencies FIN-07/08 and QA-01.

## FIN-04 — Authoritative GL, statements and reconciliations

Provenance: S4 FIN-04; V1.6 §4 P0-C/§6; original Phase4. PARTIAL E7: `WorkspaceReports.tsx` exposes posted journal/expense exports; `postedJournalReport.ts` checks visible journals balance and labels turnover as not expense/cash flow. Source reports are separate; validated TB/GL balances/P&L/BS/cash-flow/aging are not thereby implemented.

Workflow: authorize report scope/date/basis → opening plus immutable posted movement → signed mapping/subledger reconciliation → statement/export with provenance/limitations. Projects show actual recognized cost, recoverables, commitments and payments distinctly; profitability requires supported revenue basis, not cash difference. Payroll privacy may hide rows from some readers: such an export cannot silently claim complete Company TB.

Acceptance: DR=CR; opening+movement=closing; BS equation, P&L integration, cash-flow reconciliation and AP/AR/retention/custody/Treasury schedules match approved basis; same report/export totals and scoped permissions; unknown values remain —. DECISION REQUIRED: statement mapping/completeness and recognition policy. Milestone M5B; FIN-03/07, PRJ-03, FIN-05/06 and relevant subledgers.

## PRJ-01 — Audited project lifecycle

Provenance: S4 PRJ-01; V1.6 §1.1/§10.1 (`MAKERACC-PROJECT-STATUS-001`). Generalize Green's Planning→Active example. E7 shows existing creation/status badges but `ProjectMetadataForm.tsx` edits only name/client/location/contract/notes. The later [local activation increment](docs/PROJECT_ACTIVATION.md) implements only Planning→Active with immutable audit, normalized replay, stale-state/tenant/role controls and preserved financial links. Migration66 is prepared but unapplied hosted. Other lifecycle extensions remain incomplete; no project recreation is needed.

Workflow: authorized operator selects transition/reason on exact Company Project → server validates lifecycle and expected state/version → audit previous/new state → reload. Define suspend/resume/complete/close/reopen without equating contract execution or cash recognition. Acceptance: stable ID and all historic links; normal Planning→Active; stale/foreign/unauthorized transitions fail; closed/inactive settlement remains legitimate; no journal generated by status alone. A translated label such as “قيد التنفيذ” may replace visible “نشط” while the stored `ACTIVE` enum, Project identity and financial records remain unchanged; relabelling and lifecycle mutation require separate acceptance cases. Planning→Active is locally verified under existing Accounting administrator authority; remaining transition/closure/reopen policy is DECISION REQUIRED. Milestone M3 remains incomplete; QA-01, PRJ-04.

## PRJ-02 — Controlled project assignment and correction

Provenance: S4 PRJ-02; V1.6 §1.1/§4 P1-C/§10. PARTIAL: real Project inputs and source corrections exist, no verified bulk financial posting or posted reassignment. Source project text does not prove canonical `project_id`; office spend is not automatically direct cost. The [local assignment increment](docs/SOURCE_PROJECT_ASSIGNMENT.md) now implements explicit whole-source unposted cash-Expense Project/Company assignment, atomic stale/version/tenant controls, immutable audit, fresh review, posting-match enforcement and bilingual source-review exports. Migration67 is applied (latest hosted history69). Mixed-destination whole-source batch review is now implemented using the same command and audit stream; no new migration. Bounded posted allocation correction is implemented under migration69; uncertain attribution, unsupported correction scenarios and split/indirect allocation remain incomplete; no mass historical financial update is implied.

Workflow: read-only preview of source/current canonical link, evidence, proposed Project/cost class and exceptions → explicit operator selection → atomic authorized correction with audit and duplicate checks. Unposted source corrections differ from posted financial dimension correction; posted lines remain immutable and need approved reversal/replacement or adjustment semantics. Acceptance: dry-run counts, correct Company dimensions, changed-intent/retry protection, no mixed-tenant mass update or duplicate expense; before/after reconciliation. The [correction review increment](docs/EXPENSE_CORRECTION_REVIEWS.md) now persists immutable, conflict-safe nonposting proposals and annotates ledger/exports; migration68 is applied with hosted preservation checks. The separate migration69 command now supports bounded current-period cash reclassification and exact reversal; its approved scope is documented in PROJECT_COST_CORRECTION_EXECUTION.md. DECISION REQUIRED remains for uncertain attribution, prior-period and settled/reconciled correction expansion. M3; FIN-02, PRJ-03/04, EXP-04.

Current shared-cost increment: [documented percentage/quantity/indirect-driver execution](docs/SHARED_COST_ALLOCATION.md) reuses the correction mechanism for eligible current-period cash Expenses with exact conserved amounts, explicit basis approval and immutable audit. No pre-posting split, WIP, prior-period or unsupported source recognition is implied.

## PRJ-03 — Project, overhead and WIP cost policy

Provenance: S4 PRJ-03; V1.6 §0.4/§1.1/§4 P1-C; S2/S3. PARTIAL E4/E5: Project cost versus Company expense keys, subcontract cost and one payroll allocation exist. Project is a dimension, not a GL account or source of money. The [posted cost ledger increment](docs/PROJECT_COST_LEDGER.md) now locally reconciles existing EXPENSE-account movements by Project/Company and posting period, preserving reversal/source lineage and Payroll RLS, with exact bilingual Excel/PDF totals. This is reporting existing posted facts; mixed-destination whole-source assignment now reuses the existing allocation command without new recognition; split/indirect allocation, capitalization and expanded recognition policy remain unresolved.

Workflow: classify direct cost/overhead/asset/advance; recognize once through originating document; where approved, allocate indirect costs/labor/materials using explicit basis/version and reconcile totals. Decide project WIP capitalization and revenue-related cost release separately from operational assignment. Acceptance: allocation sums exactly to originating cost, no cash-based duplication, overhead and project views reconcile, inactive-project settlements permitted. DECISION REQUIRED: allocation basis, timing/WIP, capitalization and corrections; F0/M3/C2/I4, FIN-04/05, HR-02, INV-01.

## EXP-01 — Clear source save, review and financial lifecycle

Provenance: S4 EXP-01; V1.6 §3/§4 P1-D/§12.2 (`EXPENSE-EDIT-UX-001`). M1 supersedes original blank/white-on-white Save repair; E2 accepted package includes it. Source save is not canonical posting. Canonical Treasury form can post immediately; no universal expense-draft feature may be inferred from source editing.

Workflow: clear source save/review/cancel controls; distinct reviewed evidence and explicitly confirmed permitted post; irreversible posted records offer authorized reverse/correct semantics. Acceptance: visible accessible Save Changes, busy and success/error, duplicate-click protection, mobile RTL and zoom; post label describes financial effect, missing evidence prevents it. Preserve existing transport and immutable results. Explicit responsive acceptance covers360px,390px and768px, with readable cards or an equivalent usable layout on narrow screens, preserved desktop tables and clear date/source/action labels; broader workspace evidence does not prove each width was tested. M3, EXP-04/FIN-02; no new accounting policy in a CSS fix.

## EXP-02 — Classify economic events rather than cash direction

Provenance: S4 EXP-02; V1.6 §0.5/§2/§4 P0-B/P1-A. Revised broad “post all expenses” intent means every genuine event is resolved correctly, not every outflow is P&L. PARTIAL canonical AP/custody/subcontract/payroll commands exist; E7 flags missing employee loan/deposit/funding/drawing commands.

Funding and transfers move assets or create capital/debt; advances/deposits create recoverables; invoice recognition creates cost/asset plus AP; payments settle; salary accrual differs from cash payroll. Refunds/partner movements must preserve original nature and references. Workflow records beneficiary, payer, evidence, dimensions, recognition point and dependency before command selection.

Acceptance: one economic event across Treasury, custody, party, project and GL; payment never reposts expense; recoverable not expensed; no invented debit/credit to balance. DECISION REQUIRED per missing event and OWNER_CURRENT; F0/M4/M5A, FIN-08, CUS-01/02, HR-02, INV-01.

## EXP-03 — Expense dimensions, invoice and VAT evidence

Provenance: S4 EXP-03; V1.6 §3/§4 P1-D/§6/§7. PARTIAL E4: existing specialized `post_expense` modes TREASURY/CUSTODIAN/OWNER/SUPPLIER_CREDIT, stable-key accounts, invoice-required recoverable VAT and deterministic money. This is technical behavior, not confirmed tax compliance or approval of all OWNER policies.

Workflow chooses genuine supplier/category/Project or overhead, actual payer/Treasury/custodian, invoice/date and evidence; recognize correct gross/net/recoverable VAT or supported nonrecoverable treatment; settle supplier liability separately. Acceptance: foreign/incompatible dimensions rejected in DB, integer rounding reconciles, duplicate invoice/source safeguards, unauthorized or evidence-free recoverability denied; no tax inferred from supplier name/TRN text. DECISION REQUIRED actual tax status/timing/base, retention/advance interaction and invoice duplicate scope. F0/M3/I3, FIN-02, CON-02.

## CON-01 — Fixed, unit-rate and hybrid subcontract agreements

Provenance: S4 CON-01; V1.6 §1.3C/§4 P1-B (`MAKERACC-SUB-004`). Generalize Al-Sajour AED50 measured-unit installation without known total. PARTIAL E7 requires `original_contract_value_minor`; E4 certificate aggregate caps at original+approved variations. Backend design must change with UI.

Workflow captures contract type, official/internal reference, BOQ/unit/rate, optional estimated quantity/cap, measurable certified quantities, variation authority and distinct signing/execution dates. Contract save itself has no cost/cash recognition. Never use 5,000 or 10,000 as fictional total to bypass required validation.

Acceptance: unknown-total agreement valid only under approved control model, fixed/hybrid caps preserve intended limits, exact quantity×rate→money rounding, measurement history immutable after approval, no cross-contract advance pooling or duplicate certificates. DECISION REQUIRED: estimate versus enforceable cap, UOM, quantities and variation/reversal rules. M4, CON-02/04, PRJ-01, QA-01.

## CON-02 — Separate work, billing, tax, security and settlement

Provenance: S4 CON-02; V1.6 §0.6/§1.3/§4 P0-B/P1-B/§7. PARTIAL with substantial E4/P5F–I and P6D implementations: advance asset; certified work cost/liability/retention/recovery; payable settlement; retention release and payment are distinct events. Contract ACTIVE is not work started; terms are not payments; warranty is not financial retention or performance security.

Accounting review required: implemented certificate `AUTO_5` is computed on net after retention, recovery and mapped deductions; deduction mappings currently use Revenue. This is observed source behavior, **not a validated tax/legal/accounting rule**. Do not retrospectively change it from a planning review. Expert approval must specify tax base/timing, gross/net offset and deduction nature before extension. The historical10% retention is a particular contract term, never a default for all Companies/contracts. Store auditable agreement/signature dates, actual execution start and milestone/payment conditions separately; retain optional actual-start unknowns. Release events must reference the contract's documented eligibility/date and remaining retention, while performance guarantees, warranty and delay clauses remain distinct from retained cash. A delay clause is not an automatic deduction or recognized receivable without the approved event/evidence policy.

Acceptance: agreement causes no journal; certification creates no cash; contract and party/project dimensions retained; recovery≤same-contract advance, payment≤payable, release/payment≤retention; consumption blocks upstream reversal until dependent events reversed; no actual paid amount invented from terms. Milestones F0/M4; CON-01/04, FIN-02, EXP-03.

## CON-03 — Party identity, legal metadata and documents

Provenance: S4 CON-03; V1.6 §1.2/§4 P1-F/P2 (`MAKERACC-PARTY-002`). Generalize missing trade-license fields and name-only Subcontractor edit. PARTIAL E7: Supplier has fuller edit/status while other party controls are narrow. Do not claim Supplier behavior applies to Subcontractors.

Workflow maintains one Company party across projects/contracts; full authorized contact/legal/TRN/license-authority/expiry metadata; duplicate warning (not automatic merge); safe deactivate/reactivate preserving existing settlements; contract-specific notes/evidence belong to contract, not general identity. Trade license and TRN are distinct. Documents use OPS-01, not public URLs.

Acceptance: edit in place, stable IDs, same party in two Projects, no history/balance changes on metadata update, inactive unavailable for new commitments while old obligations settle; linked-party deletion prohibited. Delete unused master only if explicitly designed and relationally verified, never current Maker contractors. M3/M4/I1; CON-05/OPS-01.

## CON-04 — Cumulative measured certification and payment matching

Provenance: S4 CON-04; V1.6 §1.3C/§9. PARTIAL monetary cumulative certificates E4; future BOQ/measurement support depends CON-01. Later V1.6 update supersedes first-invoice-only example: 100 units then **cumulative** 200 at AED50 means cumulative 5,000 then 10,000, with incremental second work 5,000; reported payments 5,000+5,000 are not proof of journals.

Workflow records actual signed measurement/prior approved cumulative quantity/value and derives current delta under lock; invoice, certificate, tax, retention and payment remain distinct links. Acceptance: no 5,000+10,000 double cost; concurrent certifiers cannot reuse delta or overrecover; conflicting retention/VAT evidence stays pending; retry returns original outcome. Confirmed payment evidence may be preserved/linked without asserting certified quantity or a tax/retention conclusion; check for an existing payment before any posting. Unresolved treatment still blocks its affected journal, and evidence capture is not a balancing workaround. DECISION REQUIRED disputed certification, retention application and UOM; M4, CON-01/02, FIN-02.

## CUS-01 — Financial custody with one authoritative balance

Provenance: S4 CUS-01; V1.6 §2/§4 P1-A/§7. Revised proposal: Bareq is a person, not a Company or automatic Treasury. PARTIAL E4 approved balance is Company/custodian journal-derived CUSTODY_ADVANCE receivable, not per-project/per-advance cash buckets.

Workflow Treasury advance Dr custody/Cr Treasury; substantiated custodian expense Dr cost/evidenced VAT, Cr custody once; settlement groups already posted expense IDs and has zero journal effect; return Dr Treasury/Cr custody; exact reversals preserve dimensions. Personal-financed spend/negative shortfall and nonexpense custody disbursements require explicit policy/commands, not fictional advance.

Acceptance: pooled balance and statement reconcile across Projects, no overdraw/concurrent return+expense, one settlement membership per expense, closed/inactive history remains settleable, no Project cost reversed by cash return. Legacy receipts/source difference is not opening balance. DECISION REQUIRED physical cash responsibility versus employee receivable and missing funding origins. F0/M4; FIN-02/03/08, CUS-02/03.

## CUS-02 — Partner drawings, personal funding and reimbursements

Provenance: S4 CUS-02; V1.6 §4 P1-A/§7; S2 advances/deductions. PARTIAL existing OWNER expense mode does not establish general drawings, partner equity/current account, employee reimbursement or payroll recovery lifecycle. E6 deliberately excludes OWNER_CURRENT provisioning because account-type policy is unresolved.

Workflow distinguish partner withdrawal, partner loan/capital, payment on behalf, employee salary advance, custody funding and personally financed business expense. A supported reimbursement recognizes a genuine liability to payer and pays it once; partner drawing never ordinary operating expense; loan recovery reduces receivable separately from current salary expense. Netting against later funding must be explicit and evidenced, not concealed cash duplication. Provide a distinct partner/current-account statement or clearly separated tab, with authorized opening, drawings, funding/repayments, corrections, closing balance and source/journal links. Reconcile it to the approved partner control account and the custody cash leg without counting drawings as operating costs. This output remains planned/policy blocked; a generic custody statement does not establish its implementation.

Acceptance: party/account/legal nature signed off; one original cost; linked reimbursements/recoveries bounded and reversible under dependencies; statements distinguish cash controlled versus amounts owed. DECISION REQUIRED owner entity/account type, treatment, recovery agreement/authority; F0/M4/H3, FIN-08, HR-02.

## CUS-03 — Manager statement and accountant reconciliation

Provenance: S4 CUS-03; V1.6 §4 P1-A. Generalize received/spent/balance to an authorized Company/person statement. Backend Company accounting readers exist E4; complete manager-facing statement and evidence completeness not verified.

Workflow accountant traces opening/funding/expense/nonexpense/return/reversal and documentary exceptions to GL; manager sees permitted simplified receipts/spending/expected cash/unsupported items/variance with clear source-versus-posted labels. User custody-person linkage and scope must be explicit; no payroll details inherited from management role. Acceptance: control GL agrees, verified zero distinct from missing opening, real/expected cash discrepancy explained, viewer cannot post/edit/reverse, foreign Company/person access denied. DECISION REQUIRED permitted manager scope, evidence and shortfalls; M4, CUS-01/02, FIN-03/04, OPS-01.

## HR-01 — Calendar-month explicit attendance facts

Provenance: S4 HR-01; S2 sections A/B/D/E/G. PARTIAL E5 exception-only HALF_DAY/FULL_DAY absence and reviewed eligible assignments. Target H1/H2 matrix preserves actual unknowns and minute facts; approved leave/rest/holiday differs from missing entry or salary treatment.

Workflow employee/terms/calendar → capture explicit facts → resolve conflict/leave/time exceptions → revision-bound review → controlled lock/correction. Actual 28–31 dates, sticky identifiers/header, Company/Project/employee filters, text+symbol status legend, compact expected/worked/absence editor, keyboard/bulk preview and responsive daily alternative. Approved overtime/breaks/overnight split facts remain distinct from payable rules.

Acceptance: leap year, missing-day unknown, partial hour, overnight date/timezone, overlapping leave/shift, revoked role/site, stale concurrent edits, lock dependency/audit, accessible RTL/LTR; XLSX/PDF repeat headers and carry review state. No journal at attendance capture. DECISION REQUIRED schedule/evidence/leave/lock/transition policy (HR-03). H1/H2, HR-02, PRJ-03.

## HR-02 — Earned payroll, entitlement, payment and labor cost

Provenance: S4 HR-02; S2 C–G; historical V1.6 payroll and original Phase2D. PARTIAL E5: monthly salary less half-unit absence with explicit generic supported adjustment meanings; one Project/overhead per employee; accrual/salary-payable/partial payments/exact reversals; register XLSX and browser print exist. Recorded Development synthetic results include 127 draft checks, 114 posting checks and four concurrency scenarios; no new genuine payroll executed here.

Current approved recognition is Dr project/company expense and Cr SALARY_PAYABLE for supported earned entitlement; payment Dr posted payable/Cr Treasury, no new cost. Loans/recoveries, third-party deductions, fines and reimbursements are not automatically salary reductions. Future model uses effective-dated basic/allowances/bonus/overtime/deductions policies, reproducible period snapshots and controlled split allocation. State: draft calculation → supported classification/allocation → review/approval → accrual+attendance lock → payments → payslip/reports; reverse payment before dependent payroll reversal/replacement.

Acceptance: exact deterministic rounding, no duplicate run/pay, overpayment rejected under race, stale policy/draft cannot post, allocation equals one cost, inactive employees/closed Projects can settle, confidential views/exports remain role scoped (Viewer currently denied). Individual payslips and expanded register/attendance exports remain future work. DECISION REQUIRED paid/unpaid rules, recoveries, authority, salary versions and legal jurisdiction. H1/H3/H4; HR-03, CUS-02, FIN-07. WPS is a separate verified official/provider specification and authorized acceptance gate, never generic CSV equivalence.

## INV-01 — Integrated procurement, stock and project costing

Provenance: S4 INV-01; complete S3 A–H; original roadmap site materials. PLANNED integrated system; use roadmap I1–I5 for sequence. Operational workflow: PR → optional approval/RFQ → PO → partial accepted receipt → bill/matching/AP → settlement; stock reservations/transfers/issues/returns/counts → project costing and GL. Direct site delivery has its own acceptance/invoice/cost path without warehouse intake.

Recognition must be approved: PO normally a commitment; actual ownership/acceptance event determines asset/receipt liability; invoice matches rather than duplicates; payment clears AP; issue credits inventory against approved project expense/WIP; unused return reverses approved cost/quantity with provenance; intra-Company warehouse transfer preserves Company quantity/value. These are target design conditions, not deployed journal templates. Supplier credit/returns, freight/VAT/discount/landed cost and damage/count variances need explicit treatment.

Minimum model and twelve views are specified in the roadmap. Quantities are deterministic decimals with approved UOM conversion; money BIGINT; append-only movement corrections, role/RLS/Company constraints, unique source/idempotent partial receipt/matching and last-stock concurrency. No historical source row becomes opening stock automatically; unknown value remains —.

Acceptance includes all 13 S3 scenarios (enumerated in roadmap): 100 ordered/60+40 receipt, rejected goods excluded, 50 direct project units, value-neutral transfer, issue/return, correct Project, partial bill/two payments once, reversal/credit dependencies, controlled count, simultaneous last-stock prevention, unavailable opening/value, Maker preservation, EN/AR responsive accessibility. Reconcile accepted stock/movement valuation/AP/GL and project costs under signed policy. DECISION REQUIRED FIFO/average, ownership/GRNI, WIP/expense, landed costs/tax, openings, negative stock, hierarchy/approvals/UOM. Dependencies M3/M4 masters/settlement, F0/M5A and O1; HR is a parallel track, not a prerequisite for stock.

## UX-01 — Shared Company workspace and truthful metrics

Provenance: S4 UX-01; V1.6 §0.7/§4 P1-E/P2/§11; E3/E2. IMPLEMENTED shared M2.1/M2.2 workspace and accepted prior promoted package. Superseded generic M2 appearance is history; keep six-section accounting cycle, module registry and responsive EN/AR design.

Workflow/navigation reuses shared components/tenant context, accurate permission-aware actions and explicit loading/empty/error/unknown/verified-zero states. Planned reports/cards remain unavailable, not fabricated balances. Acceptance: accessible names/focus/contrast/table scrolling/RTL and 390px-style narrow views for future increments; real source/posted provenance, correct Company switching and no hidden stale cross-scope data. Financial engine unchanged by styling. Prefer readable authorized names/codes and internal/formal document references in routine controls; raw UUIDs remain technical identifiers and must not be the sole operator-facing party/contract identity. Distinguish same-name records with approved business references, without weakening server ID/Company authorization. The original logo/sidebar concept is historical visual direction, superseded by accepted NARVO design, not a requirement to restore an M logo. Minor E2 summary grouping semantic defect remains a bounded follow-up. Milestones M3/H2/I5, FIN-01/04, UX-02; new features require their own acceptance.

## SAAS-01 — Owner-controlled Customer and Company onboarding

Provenance: S4 SAAS-01; S1; V1.6 PLATFORM-OWNER-001; latest E1/E2. IMPLEMENTED LOCALLY and locally tested only for the **new integrated onboarding**. Existing platform/memberships/manual subscriptions/foundation already have earlier hosted/release evidence; do not collapse them into the new migration's status.

Workflow owner Customer → Company → assigned/accepted Accounting Admin → activation → protected foundation → Company subscription → derived readiness/portfolio; resumable pending invitation is not an accepted membership. New business gate is database authoritative; active membership/financial permissions remain separately required. Platform owner sees administrative progress, not client financial books.

Acceptance: E1 recorded 49 SQL/20 fixture browser/4 independent PostgreSQL races with zero focused axe violations and build pass; 16 current source hashes match; local65 SQL replay versus recorded hosted64. Legacy private eligibility captures only approved existing Maker without re-creating/reprovisioning/updating its financial records. Only initialized Company/transaction/actor may provision account/Treasury before ordinary readiness. Other old unenrolled Companies are not silently exempt; Customer unlink/admin loss/expiry withdraw readiness. Permitted existing reads/settlement/reversal preserved under actual permissions.

R0 gates are mandatory: human visual review, fresh shared-db impact/eligibility inventory and tested recovery, single-file dry-run, separate Production-impact DB activation, separate frontend candidate/Preview/promotion, scoped genuine hosted journey. E1 migration65 and UI remain unapplied/undeployed; Production is already live on an earlier accepted package E2. No payment gateway/accounting revenue/billing ledger implied. Dependencies QA-01/OPS-02.

## QA-01 — Financial integrity and evidence acceptance

Provenance: S4 QA-01; V1.6 §6; AGENTS.md; original P7/P10. PARTIAL substantial per-flow evidence E4/E5, E1 local and E2 read-only; no project-wide accounting/commercial completion or current full integrity audit established.

Workflow requirements/policy → design/implementation → financial/tenant/concurrency verification → reconciled report and release review → authorized runtime acceptance → operational follow-up. Each meaningful milestone records business/security/DB/deployment/testing/documentation VERIFIED/DEFERRED/NOT APPLICABLE. Tests distinguish fixture UI, genuine SQL business execution in synthetic/rollback tests, independent connection races, real identity-bound browser and actual business acceptance. Balancing alone does not establish valid recognition or compliance.

Acceptance: invariants in register contract; one source/one effect, exact reversal/dimensions, settlement after master inactivity, negative authorization and race outcomes, full subledger-to-GL reconciliation, no secret exposure and accurate current evidence. Independently scoped full pre-production integrity audit and backup restoration cannot be inferred from a UI release. R0/M4/M5A/M5B/I5/O1/O2; OPS-02.

## Supplemental retained obligations — 12 records

### FIN-05 — Client contracts, AR and revenue recognition

Provenance: original PROJECT_ROADMAP subsequent Phase3/3B/4; S1 general accounting and S4 FIN-04/PRJ-03 context. Universal AR plus construction-specific billing/recognition; PLANNED/POLICY BLOCKED, no complete deployed client-revenue subledger established by inspected suppliers/subcontracts. Platform Customer administrative portfolio is not automatically an accounting debtor.

Workflow client/contract/variations → evidenced performance/recognition decision → certificate/invoice, tax/retention/advance/contract asset or liability as approved → receivable → collections/allocation → reversal/credit → aging/GL. Contract signature, billing and cash collection do not alone prove revenue recognition. DECISION REQUIRED performance obligations, recognition/measurement/progress, contract costs/WIP, retentions, advance/tax timing and legal scope; domain review distinguishes accounting standards from tax/product policy.

Acceptance C1/C2: contract/project/client dimensions, immutable billing and recognition sources, no double income on collection, bounded cash allocations/refunds/advance recovery and races, AR/retention/contract balances reconcile, source-to-report trace and permissions; profitability unavailable absent supported basis. Dependencies F0/M5A/PRJ-03/FIN-04, QA-01.

### FIN-06 — Fixed assets, depreciation and related schedules

Provenance: V1.6 §4 P0-C/§6; original accounting completion goals. Universal accounting, company-policy thresholds; PLANNED/NEEDS_VERIFICATION, not established as complete by COA listing or expense module. Workflow evidence-based acquisition/capitalization → asset register/location/custody → depreciation → transfer/impairment/disposal as approved → GL reconciliation. A reusable physical tool record is not automatically a capital asset.

DECISION REQUIRED asset classes, recognition/threshold, useful life/residual/method, impairment/disposal/VAT and cutover openings. Acceptance A1: asset roll-forward and depreciation equal GL, no purchase expense duplicated with capitalization, immutable authorized runs/disposal/reversals and exact rounded totals. Dependencies FIN-03/07, INV-02, INV-01 where purchasing relevant; no claims of implemented tax depreciation.

### FIN-07 — Fiscal periods, adjustments, close and reopen

Provenance: V1.6 §4 P0-B/P0-C/§6; original P10 and Phase4. Universal financial governance, company fiscal choices. PLANNED complete controls: E6 states no configurable fiscal-period setup; calendar-year reference numbering and payroll attendance locks are not fiscal period closing.

Workflow establish periods → reconcile/review → close under authority → reject affected new recognition/backdating → permitted settlement/correction through approved date/adjustment process → reasoned audited reopen if policy permits. Define period-specific financial command applicability and recognition versus actual payment dates; never trap lawful existing liability merely to enforce closure. DECISION REQUIRED fiscal year, closing authority, adjustment period and reversal/reopen policy.

Acceptance M5A/M5B: database-wide affected-command tests, no bypass via alternate RPC/direct write, concurrent close/post resolves deterministically, posted truth remains immutable, dated TB/statement roll-forwards match. Dependencies F0/FIN-03/04 and all affected subledgers; HR attendance month lock remains independent.

### FIN-08 — Funding, deposits, advances, equity and financing

Provenance: V1.6 §2/§4 P0-B/P0-C/P1-A; E7 unsupported source guidance; E6 owner mapping exclusion. Universal events with company/legal policy; PARTIAL specialized custody/subcontract advance and OWNER expense behavior; generic funding/employee advance/deposit/partner commands not complete.

Workflow determine payer/borrower/legal nature (capital, loan/current account, transfer, receipt, deposit/recoverable) → approved account/dimension/event → funding/recognition → recovery/repayment/refund with links. Never assign funding a generic income/expense offset. Loans include principal versus financing cost under approved treatment. Owner entity/OWNER_CURRENT account type remains **DECISION REQUIRED**; do not auto-provision an arbitrary Equity/Asset/Liability account.

Acceptance F0/M4/M5A/A1: independent balances and supporting agreements reconcile; exact bounded recovery and duplicate source protection; Treasury transfer balanced without income, recoverable preserved, no false opening cash. Dependencies FIN-02/03, EXP-02, CUS-02, HR-02, QA-01.

### PRJ-04 — Entity ownership and historical remediation case

Provenance: V1.6 §9/§10.2 (`MAKERACC-PROJECT-OWNERSHIP-001`) supersedes earlier §1.1 “Villa13 not created.” Maker-specific case retained with reusable tenant correction safeguards; NEEDS_VERIFICATION, no current live graph reviewed. Reported target: main Al-Zorah Villa63 stays Maker; Villa13 and Farm belong to owner-personal books; Green industrial Al-Thaoub project is separate. Parcel1116 and Villa63 are not assumed identical identifiers without evidence. Farm import remains deferred.

Workflow read-only current Project IDs, ownership evidence and full related source/document/journal/member graph → approve legal/entity model → design safe correction and reconciliation plan → separately authorize any new entity or remediation. Never change `company_id` on posted history, mass-relocate rows, delete/recreate linked projects or assume Platform Owner enrollment is required for Maker.

Acceptance M3: no lost/duplicated source/payment/history; permissions and separate books verified; approved on-behalf balances if relevant; Project status correction does not invent financial/execution dates. DECISION REQUIRED ownership documentation, entity type, disposition of existing links and correction policy. FIN-03/08, PRJ-01/02, QA-01; no remediation authorized here.

### CON-05 — Safe party lifecycle and scoped statements

Provenance: V1.6 §4 P1-F (`MAKERACC-PARTY-002`), beyond S4 CON-03 metadata summary. Generalizable master-data and accounting-history control; PARTIAL Supplier status/metadata exists, Subcontractor name-only E7. Workflow authorized edit/deactivate/reactivate preserving IDs/audit; existing payable settlement remains possible; same party reused across contracts/projects; statements filter without duplicating balances.

Acceptance M3/M4: linked party cannot be hard-deleted; no cascade deletes accounting; active choice required for new work, existing legitimate payments allowed after inactivity; stale versions/foreign roles/Company rejected; duplicate-warning normalization does not merge financial identities. Notes relocation requires original evidence and authorization, no automatic payment creation. Dependency CON-03, QA-01, FIN-04. Scope of unused-master deletion and privacy policy needs design, not a demand for delete-everywhere UI.

### EXP-04 — Historical date evidence and correction audit

Provenance: V1.6 §12.1 (`DATE-001`) and §12.3. Historical bug report, PARTIAL UI clarification E3; intended stored date/source audit remains NEEDS_VERIFICATION. G-2026-08-20 ROUND STAMP AED60 reportedly intended August1; reference string and sheet month do not prove transaction date.

Workflow read original workbook cell/raw value/number format → parser/raw/normalized date → correction and audit → ISO editor → display/export; evidence-rich read-only ambiguity report per row; approve only supported corrections. Canonical ISO YYYY-MM-DD and labelled local day/month presentation; no locale-string guessing or blind 223-row day/month swap. Preserve raw source and source-month grouping independent of actual date.

Acceptance M3/M5A: ISO2026-08-01 round-trips unchanged; DD/MM01/08 differs from08/01; unknown remains reviewable; no post/tax before required date evidence; no amount/nature/month change as a side effect. Source editing does not edit posted truth. Dependencies FIN-02/07, EXP-01, PRJ-02. Original workbook/audit and specific correction approval required; historical M1 display fix is not proof the original row was corrected.

### HR-03 — Attendance/payroll compatibility, confidentiality and policy transition

Provenance: S2 A/B/C/G versus E5 Lite specification and actual `AttendanceApplication.tsx` (no entry→Present), payroll register (calendar days minus half-absence), attendance migration (UTC) and payroll/posting (Asia/Dubai). Universal evolution control plus configurable employment policy; PLANNED, **DECISION REQUIRED** before H1–H4 expansion.

Define effective-date/versioned mode: exception-only historical inference versus explicit future attendance facts; company timezone/schedule/overnight day boundaries; reviewed draft conversion and locked/posted history preservation. Do not infer all legacy blank days were unrecorded or confirmed presence under a new meaning. Old net-salary reduction classes must not silently become loan recovery; new salary/leave/overtime/holiday/legal policies require signed scope.

Acceptance: old immutable snapshots and entitlements unchanged; compatibility fixtures under both policies, all date edges and lock/reversal dependencies; employee/profile/salary read roles stay restricted; platform owner/viewer/foreman cannot infer pay through journal or report paths. H1/H2/H3/H4; HR-01/02, FIN-07, QA-01.

### INV-02 — Physical tools and equipment custody

Provenance: original PROJECT_ROADMAP “Future contracting operations module.” Construction operating capability retained; PLANNED/DEFERRED T1, not absorbed into financial custody. Workflow tool/equipment identity, employee/custodian/Project issue date+condition, return date+condition, in-custody/returned/damaged/lost status and history. Financial consequences only through approved asset/expense/loss policy.

Acceptance: one active physical custody position per controlled item where applicable, no duplicate concurrent issue, historical issue/return retained, Company/site permissions and count reconciliation; no automatic CUSTODY_ADVANCE journal or receivable for a missing tool. DECISION REQUIRED valuation/capitalization/loss recovery/approval where financial; dependencies M3 persons/projects, FIN-06, OPS-01.

### OPS-01 — Private documents, immutable audit and traceability

Provenance: original P7/P8, V1.6 contract/legal/evidence obligations and S2/S3. PARTIAL domain immutable journals/audit events exist; complete private attachment storage/authorization not established in inspected evidence. Workflow Company/project/document-bound upload metadata → safe private storage → authorized signed read → version/replacement/retention and controlled deletion consistent with accounting evidence.

Acceptance O1: cross-tenant/role/object-path and signed-link access tests, sensitive payroll scope, no public bucket assumption, retained historical document/audit identity, actor/reason/version trace and command failures visible without credentials. Operational policy decides retention and sensitive-access audit proportionately. Dependencies QA-01 and affected contracts/HR/procurement; no new storage setup authorized here.

### OPS-02 — Delivery, recovery and commercial readiness

Provenance: original P10, AGENTS.md, S1 §5/§11, latest E1/E2. PARTIAL: actual November2 existing-site promotion/read-only smoke recorded; shared hosted64/local65 and future commercial onboarding remain distinct. Full operational readiness/restore exercise/current independent integrity audit not proven.

Workflow immutable reviewed package + environment/migration impact → tested backup/recovery and Preview → identity-bound human acceptance → exact separate Production approval → postflight/monitoring/incident handling. Backup policy specifies DB/data/schema/Auth/configuration/private storage scope, frequency, retention, restore authority, procedure/objectives and verification; source rollback alone cannot undo financial changes. Review hosting cost/limits, support/recovery, privacy/terms and truthful product claims. CI/CD gates are evaluated from actual repo evidence; do not call current flow mature automation.

Acceptance R0/O2: environment topology documented, all compatibility/impact/authorization guards, monitored failures, retained audit/evidence, completed restore rehearsal and scoped integrity audit before real accounting/commercial go-live as required. Preview success never authorizes Production or customer data tests. No new hosted action or full audit performed here. Dependencies all relevant acceptance scope, QA-01/OPS-01/UX-02.

### UX-02 — NARVO branding, white-label and entity context

Provenance: V1.6 §11; original P6B and architecture. Product/company identity separation retained; PARTIAL NARVO shared interface and tenant settings exist and E2 accepted package is live; branded documents/email/custom-domain/enterprise topology completeness not established. Workflow shared login/header/sidebar/browser title/report templates present product plus actual authorized Company branding; Company switching replaces scoped data under server authority.

Acceptance M3/O2: consistent NARVO visible identity, Company name independent, no Maker/Green/Owner-specific accounting branch, no cross-tenant stale view during switch/session refresh/back navigation, browser-safe config and no production fallback to local demo. Technical DB/repo/API/domain identifiers need not change merely for branding; current posted export filename `MakerACC-Posted-Accounting-...` is a residual presentation example, not financial corruption. Trademark/domain availability and marketing scope need appropriate external review before commercial claims. Dependencies UX-01/OPS-02/QA-01; no domain or identity migration authorized.

## Maker case and numerical provenance ledger

These examples are preserved as evidence/acceptance cases, not current financial assertions or defaults for other Companies.

| Case | Historical statement and supersession | Treatment / requirement links |
|---|---|---|
| Main Project | Al-Zorah/main Villa63; earlier parcel1116 reference; customer name from Prompt contract not proof of Maker's direct contracting client | Verify contract/legal identity; no invented prime contract. PRJ-02/04, FIN-05. |
| Villa13 / Farm / Green | Later V1.6 §10 supersedes early absent-project wording; Villa13 reported in Maker/Planning but intended owner/Active; Farm deferred; Green separate industrial project | Read-only relational/ownership analysis before any correction; no deletion or tenant reassignment. PRJ-04. |
| Ahd electricity | 65,000 AED; signing August27; admin start is not proven execution; 10% retention and separate 10% performance guarantee; delay300/day cap10%; source payments6,500 on2026-08-27 and10,000 on2026-09-12=16,500; internal reference AL-ZORAH-ELEC-001 not proven formal contract number; reported250 difference unexplained | VAT inclusive/exclusive disputed; 48,500 arithmetic difference is not recognized payable. No double guarantee/retention and no duplicate pay. CON-01/02, EXP-03. |
| Prompt insulation | Net45,534; stated VAT2,276.70; gross47,810.70; signing September23; 40/40/10/10 terms; no work/payment reported then; retention0; 25/10-year warranty is not monetary retention | Historical amounts/terms only, not verified current status; don't transfer Ahd tax ambiguity to this separate document. CON-02. |
| Al-Sajour installation | AED50 per documented measured UOM; contract dated2026-09-25, Maker signature2026-09-16 and contractor signature2026-09-25; schedule term at most one month from contracting requires evidence interpretation. Retention10%, release5% at initial handover and5% after one year; separate performance guarantee10%; delay300/day capped10% of undefined total. October3 100×50=5,000; October18 cumulative200×50=10,000; later reported actual5,000+5,000 payments supersede first-invoice-only description | Incremental second amount5,000; UOM/chronology/measurement, release eligibility, penalty-cap basis, actual retention and VAT/TRN require document review. Do not infer execution date from signing, auto-enforce a penalty, invent withheld500/1,000 or total contract. CON-01/02/04. |
| Stone materials | Zahra Al-Fouad separate material supplier, source50,110 AED | Distinguish supply from Al-Sajour installation; no duplicated material cost. INV-01/EXP-02/CON-02. |
| Party metadata | Historical Ahd license787243 and Al-Sajour1619491 were notes; Prompt reported TRN100260186000003 | Not tax validation; no automatic TRN/Company/account creation. CON-03/05. |
| General sources | August135 rows/out182,111.92; September88/out113,394.12; total223/out295,506.04 AED; inflow304,981.20 (184,000+120,981.20), invoice-without-cash15,280 | Source evidence not current GL or expense total; invoices not added to cash spending. FIN-02/03, EXP-02. |
| Payroll source | 25 September rows, net53,798.33 AED | Source payroll not automatically additive to General; earning period and existing salary settlements must match. FIN-02/HR-02. |
| Custody | Source inflow−outflow=9,475.16 AED; proposed July31 opening/August1 operations | Not verified cash/custody balance without opening, refunds, personal spend, timing and GL reconciliation. FIN-03/CUS-01/03. |
| Dates | G-2026-08-20 ROUND STAMP/SMART STAMPS AED60; intended August1 reported; image/text alone not before/after DB proof | No locale guess or bulk month/day flip; preserve source month and audit. EXP-04. |
| COA/legal records | Historical UI showed two accounts110000/510000, not proof of DB count. Maker license117580/registration201820618 reported; TRN absent then | No re-provisioning, assumed zero books or invented tax registration; verify current state only in approved scope. FIN-03/EXP-03. |
| Operating roles | Single Maker accountant and manager read-only; farm entry deferred | Preserve current permissions, no universal staffing restriction, no payroll access inferred for Viewer. SAAS-01/CUS-03/HR-03. |

Historical October8 “no imported source posted” claim is not repeated as current truth. Later source corrections/postings are unqueried here. Contract source numbers and dataset totals are not evidence of current receivables/payables, invoice tax acceptance, settled liabilities or restored backups.

## Decision register and affected release boundaries

These consolidate approval questions already attached to requirements; they are not extra requirement IDs or a second task plan.

| Decision | Required evidence/approver | Affected IDs and milestones |
|---|---|---|
| Legal Company/owner books, Villa13 and on-behalf ownership | Real contract/ownership graph, accountant+owner; no tenant-ID rewrite | PRJ-04, FIN-03/08; M3/F0 |
| Fiscal periods/openings/capital/financing/current accounts | Approved TB and schedules, owner funding agreements, accountant | FIN-03/07/08, CUS-02; F0/M5A/A1 |
| Contract measurement/caps/variation and actual retention/security | Contract/measurement/payment evidence, domain expert+accountant | CON-01/02/04; M4 |
| VAT invoice validity, taxable base/timing, recovery and deductions | Scoped current official tax requirements plus tax/accounting expert validation; implemented formula is not approval | EXP-03, CON-02; F0/M4/I3/I4 |
| Material/backcharge/other deduction economic nature | Agreements/source/cost reconciliation; accountant approves maps, not generic Revenue default | CON-02, INV-01; F0/M4/I4 |
| Custody/physical cash/personal spend/partner drawing/loan recovery | Custodian evidence, opening/reconciliation and legal nature; accountant+owner | CUS-01/02/03, FIN-08; F0/M4/H3 |
| Attendance transition, schedules/leave/overtime/salary/recovery | Effective-dated company policy, legal review where needed, accountant+owner | HR-01/02/03; H1–H3 |
| WPS/employee outputs and confidentiality | Current official/provider/bank specs, validated formats, legal/payroll owner and privacy authority | HR-02/03, OPS-01; H4/O1 |
| Inventory ownership/GRNI, FIFO/average, WIP, cost components/openings | Approved accounting and quantity evidence with deterministic rounding | INV-01, PRJ-03, FIN-03; I1–I4 |
| Stock hierarchy/negative policy/approvals/UOM/physical loss | Owner operational policy and accountant for financial effects | INV-01/02, FIN-06; I1/I2/T1/A1 |
| Client recognition/WIP and fixed-asset policy | Signed standards-applicability/treatment review and source contracts/assets | FIN-05/06, PRJ-03; C2/A1/M5B |
| Shared DB activation/access impact and recovery/commercial scope | Exact environment/Company inventory, tested restore, release approvals and full required audit | SAAS-01, OPS-02, QA-01; R0/O2 |

Documenting a decision request is not a stop for this review; it blocks future implementation only where the required treatment is underivable. No confirmed cross-tenant or financial-history corruption defect is asserted without a realistic reproduced path. Intentional Lite restrictions, unimplemented scope and expert-review gaps remain distinguished from confirmed defects.

## Historical-plan reconciliation and obligation coverage

| Source obligation | Preserved normalized home and resolution |
|---|---|
| V1.6 Platform Owner gate + autonomous local authorization | SAAS-01/R0 and OPS-02; original discovery absence superseded by actual implementation/hosted console and E2; no renewed feature/deploy permission from old text. |
| V1.6 §0 governing rules / §3/§5/§8 office process | FIN-01/02, EXP-01/02/04, PRJ-04, CUS-01, HR-03, QA-01; current documentation request supersedes old “start only owner” sequencing. |
| V1.6 P0-A / P0-B / P0-C | FIN-01 repair superseded within M1 scope; FIN-02/03/04/07/08 preserve incomplete accounting foundations. |
| V1.6 P1-A / P1-B / P1-C / P1-D | CUS-01/02/03; CON-01/02/04; PRJ-02; EXP-01/03/04. Backend reuse required, no duplicate engine. |
| V1.6 P1-E/P2, P1-F and contract metadata | UX-01/02; CON-03/05, OPS-01. Supplier functionality not assumed for all party types. |
| V1.6 §6/§7 acceptance and unknowns | QA-01 and decision ledger; source-specific disputes remain historical cases. |
| V1.6 §9–§12 later revisions | Maker case ledger, PRJ-01/04, UX-02, EXP-04; later cumulative payment/ownership facts supersede earlier descriptions, without pretending current DB proof. |
| Original roadmap P0–P6, P6E/demo boundaries | Constitution/roadmap architecture, QA-01 and UX-02; existing Development completion preserved; no hybrid writes/fallback. |
| P7 audit/reversal, P8 private documents | QA-01, OPS-01; substantial existing reversals don't imply all audit/storage work complete. |
| P9 tooling, Phase2E history/openings | FIN-02/03/07, EXP-04; preserve export/staging/hash/approval/reconciliation, no blind re-import of Maker. |
| P10 go-live, deferred operations/DR | OPS-02/QA-01; release promotion doesn't prove full integrity/restore/commercial completion. |
| Phase2D payroll/WPS | HR-01/02/03 and H1–H4; existing Lite is reused, expanded HR/WPS remains unimplemented. |
| Phase3/3B client AR/revenue, Phase4 reports | FIN-05/04/07, PRJ-03, C1/C2/M5B. |
| Future site materials/tool custody | INV-01 (I1–I5), INV-02 (T1); tools remain distinct from money custody. |
| Deferred consolidation/public signup/offline/enterprise isolated deployment | Preserve as future scope under OPS-02/UX-02; not silently implemented or required for current bounded releases. Public signup stays disabled; no automatic consolidated financial access. |
| Optional corrected replacement Expense, settlement cancellation, complex legacy reversals and automatic retention eligibility | EXP-01/FIN-02/CUS-01/CON-02/QA-01; preserve explicit dependency-aware future design, do not claim all optional P6D/P7 complete. |

## Final October22 original-source reconciliation

S6 was read **in full**, including every observation, table, condition, unresolved item, office instruction and closing reference. The supplied file is V1.0,216 lines, SHA256 `27b857f5abb62fecac6141709d7246f4f48a6f213507ac255e832e2e50e11b7e`. No separate later-revision appendix is present in this file. All its substantive lines also occur verbatim in V1.6 except the office/development sequencing sentence; later S5 sections9–12 and the Platform Owner gate supplement/supersede historical assumptions. Its title/version/project/purpose/scope differ as expected. Original source bytes remain unchanged outside the repository.

**Counting method:**60 material intent groups below cover sections0–8, all §4 priorities, all nine §6 acceptance groups, all seven §7 questions and closing references. Groups explicitly combine repeated obligations and associated examples; these numbers are review locators, **not new requirement IDs** or a claim to count every source bullet independently. Document coverage before this follow-up was52 fully represented,7 partially represented,0 missing and1 scoped repair superseded by verified implementation. All seven partial representations are now explicit under existing IDs: final coverage59 fully represented,0 partially represented,0 missing and1 superseded. Case/policy/governance classifications explain disposition separately from coverage. “Fully represented” never means implemented or financially accepted.

| Review unit | S6 locator | Coverage before follow-up | Nature / disposition | Existing requirement IDs | Roadmap milestones | Verified representation or correction; implementation limit |
|---|---|---|---|---|---|---|
| 01 | §0.1 | Fully represented | Historical governance | QA-01, OPS-02 | O2 | Office observation versus development; old sequencing grants no new permission; preserve safe existing office use. |
| 02 | §0.2 | Fully represented | Configurable operating policy | SAAS-01, CUS-03, HR-03 | R0, M4, H1 | One Maker operator and manager read-only; general roles remain extensible, no inferred payroll or foreman posting rights. |
| 03 | §0.3; §1.3A raw-fils display | Superseded by verified implementation | Universal control | FIN-01 | M3, M5B | E3 M1 and E2 promoted package repair raw monetary presentation; future surfaces still require tests. |
| 04 | §0.4 | Fully represented | Universal accounting | PRJ-03, CUS-01 | F0, M3, M4 | Project analytic dimension, payer/Treasury and event nature remain independent. |
| 05 | §0.5 | Fully represented | Universal accounting | FIN-02, EXP-02 | M5A, M4 | One actual event may appear in several statements without multiple cost/payment postings. |
| 06 | §0.6 | Fully represented | Universal accounting | CON-02, FIN-02 | M4, M5A | Agreement save is not recognition/cash/tax; source requires evidence and correct command. |
| 07 | §0.7 | Fully represented | Reusable UX | UX-01, QA-01 | M3, O2 | Incremental shared design, financial correctness and truthful metrics outrank fictional infographic figures. |
| 08 | §0.8 | Fully represented | Maker-specific operational example | PRJ-04 | M3 | Farm import deferred; no implicit entity creation or financial import. |
| 09 | §1.1 project table | Fully represented | Maker-specific operational example | PRJ-01, PRJ-04 | M3 | Al-Zorah/Ajman and Villa13 location preserved; later S5 supersedes Villa13-not-created and adds ownership correction evidence gate. |
| 10 | §1.1 provisional August/September allocation | Fully represented | Accounting-policy decision required | PRJ-02, PRJ-03 | M3, F0 | Office spend not automatically direct Project cost; no blind mass attribution. |
| 11 | §1.1 client identity/prime reference | Fully represented | Accounting-policy decision required | FIN-05, PRJ-04 | C1, M3 | Client/Owner name from Prompt is not proof of Maker contracting counterparty; no fabricated prime contract. |
| 12 | §1.1 ACTIVE translation | Partially represented | Reusable UX | PRJ-01 | M3 | Strengthened acceptance: relabel visible نشط as قيد التنفيذ without changing stored ACTIVE, IDs or journals; transition remains separate. |
| 13 | §1.2 existing parties | Fully represented | Maker-specific operational example | CON-03, CON-05 | M3, M4 | Existing AHD-ASDIQA/PROMPT-INS/ALSAJOUR are not recreated; Company party reused across contracts. |
| 14 | §1.2 licenses/TRN/documents/duplicates | Fully represented | Reusable master data | CON-03, OPS-01 | M3, O1 | License number/authority/expiry distinct from TRN; private evidence and nonmerging duplicate safeguards. |
| 15 | §1.2 names/codes instead of UUID | Partially represented | Reusable UX | UX-01 | M3 | Added explicit operator-friendly party/contract identity criteria; retain technical IDs for authoritative transport. |
| 16 | §1.3A agreement facts/security/delay | Fully represented | Maker-specific operational example | CON-01, CON-02 | M4 | 65,000 agreement, internal/formal reference distinction, signature versus actual start, guarantee and retention distinct; no automatic delay journal. |
| 17 | §1.3A disputed inclusive/exclusive VAT | Fully represented | Accounting-policy decision required | EXP-03, CON-02 | F0, M4 | No inferred tax basis/rate conversion or retrospective journal rewrite; expert/document signoff required. |
| 18 | §1.3A actual cash dates/difference | Partially represented | Maker-specific operational example | CON-04, FIN-02 | M4, M5A | Added exact historical August27 6,500 and September12 10,000, internal reference and unexplained250; 48,500 is not AP. |
| 19 | §1.3B amounts and dated agreement | Fully represented | Maker-specific operational example | CON-02 | M4 | 45,534+2,276.70=47,810.70 preserved as stated evidence; do not copy electricity tax dispute. |
| 20 | §1.3B terms versus execution/payment/warranty | Fully represented | Maker-specific operational example | CON-02 | M4 | 40/40/10/10 conditions are not payments; ACTIVE not work begun; reported zero retention differs from25/10-year warranty. |
| 21 | §1.3C signatures/duration/penalty cap | Partially represented | Accounting-policy decision required | CON-01, CON-02 | M4 | Added September16/25 signature chronology, one-month term and300/day cap10% against unknown total; interpretation remains pending. |
| 22 | §1.3C unknown contract total/UOM | Fully represented | Construction capability | CON-01 | M4 | AED50 measured-unit contract needs supported unknown-total/backend cap design; no dummy5,000/10,000 value. |
| 23 | §1.3C retention release schedule/security | Partially represented | Maker-specific operational example | CON-02 | M4 | Added contract-specific5% initial handover plus5% after one year and separate10% guarantee; no universal retention default. |
| 24 | §1.3C invoice/payment/measurement/VAT | Fully represented | Accounting-policy decision required | CON-04, EXP-03 | M4, F0 | Original100×50 payment not proof of certified quantity/withholding/tax; later S5 cumulative200/second5,000 preserved; evidence capture is not posting. |
| 25 | §1.3C supply versus installation | Fully represented | Universal accounting | EXP-02, INV-01 | M4, I3 | Zahra Al-Fouad50,110 materials distinct from Al-Sajour installation; no double materials cost. |
| 26 | §2 source table | Fully represented | Maker-specific operational example | FIN-02, HR-02 | M5A, H3 | 135+88 General rows,295,506.04 cash out,304,981.20 inflow,15,280 invoice-only and25 payroll/53,798.33 preserved as source, not GL. |
| 27 | §2 classification/full coverage | Fully represented | Universal accounting | FIN-02, EXP-02, FIN-08 | M5A, F0 | Expenses, funding, payments, deposits, salary/employee advances and drawings use specific approved events, not generic expense. |
| 28 | §2 October8 no-posted snapshot | Fully represented | Evidence discipline | FIN-02, QA-01 | M5A, O2 | Historical no-posted state is not repeated as a current DB claim; no hosted query in this review. |
| 29 | §2 MAIN_CASH | Fully represented | Maker-specific operational example | FIN-03, EXP-03 | M5A, M3 | Actual reported payment source is not verified opening cash or fictional balance. |
| 30 | §2 custody difference and opening | Fully represented | Accounting-policy decision required | CUS-01, CUS-03, FIN-03 | F0, M4, M5A | July31 opening and9,475.16 source difference require full funding/spend/refund/timing reconciliation. |
| 31 | §2 payroll/liability/VAT no double expense | Fully represented | Universal accounting | HR-02, EXP-03, EXP-02 | H3, F0 | Payroll/source cash may settle existing accrual; tax and liability movements not forced into P&L. |
| 32 | §3 items1–5 completed setup/deferred stone | Fully represented | Maker-specific operational example | CON-01, CON-03, PRJ-04 | M4, M3 | Document reported entered masters/contracts; no recreation; stone agreement waits for legitimate supported model. |
| 33 | §3 items6–7 inspect expense form/new October record | Fully represented | Historical operational safeguard | EXP-01, FIN-02 | M3, M5A | Inspect save versus immediate-post before action; existing actual movement must not be re-entered; no transaction authorized now. |
| 34 | §3 items8–10 project refs/read-only modules/Villa13/Farm | Fully represented | Historical operational safeguard | PRJ-02, PRJ-04, QA-01 | M3, O2 | Canonical link differs from source text; later S5 ownership updates supersede recreate-from-zero assumption. |
| 35 | §3 observation log | Fully represented | Evidence discipline | OPS-01, QA-01 | O1, O2 | Keep time/screen/input/result/image and whether master/source or journal changed; exclude credentials. |
| 36 | §4 P0-A all surfaces/edge values | Fully represented | Universal control | FIN-01 | M3, M5B | Formatting coverage includes exports/mobile/zero/negative/large/rounding; verified M1 scope does not prove every future surface. |
| 37 | §4 P0-B classify and trace each nature | Fully represented | Universal accounting | FIN-02, EXP-02, FIN-08 | M5A, F0 | Source→review→canonical→journal→report, including unsupported-command outcomes; no economic event omitted. |
| 38 | §4 P0-B roles/dimensions/reversal/periods/case simulations | Fully represented | Universal integrity | QA-01, FIN-07, CON-04 | M4, M5A, M5B | Same/foreign role+Company, evidence/tax/replay/race/closed periods and payment matching tested synthetically before real action. |
| 39 | §4 P0-B automation gate | Fully represented | Product control policy | FIN-02, QA-01 | M5A, O2 | Only evidenced, approved supported events eligible for automation; never blanket auto-post source outflows. |
| 40 | §4 P0-C accounting setup breadth | Fully represented | Reusable ERP foundations | FIN-03, FIN-04, FIN-05, FIN-06, FIN-07, FIN-08, INV-01 | F0, M5A, M5B, C1, A1, I4 | Actual/legal capital, bank/cash, debtors/creditors, owners/loans, assets/depreciation, inventory/WIP and tax/reporting all retained. |
| 41 | §4 P0-C gap matrix and isolated test Company | Fully represented | Evidence and environment control | QA-01, OPS-02, FIN-03 | O2, M5A | Differentiate backend/UI/test/production evidence; end-to-end synthetic Company needs safe isolation, never Maker test data. |
| 42 | §4 P0-C proposed start/opening | Fully represented | Accounting-policy decision required | FIN-03 | F0, M5A | August1 start and July31 openings require approval/schedules; no default zero. |
| 43 | §4 P1-A reuse pooled custody model | Fully represented | Universal accounting | CUS-01 | F0, M4 | Read/reuse P5D/P5E; pooled Company/person receivable authoritative; no automatic Treasury-per-person or parallel engine. |
| 44 | §4 P1-A custody statement components | Fully represented | Reusable operational control | CUS-01, CUS-03, FIN-08 | M4, F0 | Opening, funding, classified spend, transfers/returns, settlement, personal spend, expected/actual count and variance linked to evidence/GL. |
| 45 | §4 P1-A partner statement/tab | Partially represented | Reusable accounting output | CUS-02 | F0, M4 | Added explicit partner statement/tab with opening/funding/drawings/repayments/corrections/closing and GL/custody reconciliation; policy still pending. |
| 46 | §4 P1-A personally financed expense/netting | Fully represented | Accounting-policy decision required | CUS-02, FIN-08 | F0, M4 | Genuine payable to person, once-only cost/settlement; later funding netting explicit, not duplicate cash. |
| 47 | §4 P1-A viewer and manager summary | Fully represented | Role and reporting control | CUS-03 | M4 | Manager permitted own-person/Company scope; accountant detailed ledger; incomplete documents/variance explicit, no payroll access inferred. |
| 48 | §4 P1-B types/optional estimate | Fully represented | Construction capability | CON-01 | M4 | Fixed, unit/remeasurement and hybrid with optional quantity/total under approved caps; UI and DB designed together. |
| 49 | §4 P1-B measured/cumulative work and net balances | Fully represented | Construction accounting | CON-01, CON-02, CON-04 | M4 | Previous/current/cumulative certified quantity×rate, changes, recovery, tax/retention/payable/paid/outstanding distinct; no fictional withheld amount. |
| 50 | §4 P1-B contractual versus actual execution lifecycle | Fully represented | Construction workflow | CON-01, CON-02 | M4 | Agreement-not-started/running/completed/closed and signing/start/terms separated; stored enum alone does not evidence work. |
| 51 | §4 P1-C bulk attribution and payment matching | Fully represented | Universal financial correction | PRJ-02, PRJ-03, FIN-02, CON-04 | M3, F0, M5A, M4 | Preview/selection/confirmation/atomic-audited apply for supported source changes; no posted mutation or duplicate16,500/5,000 payment. |
| 52 | §4 P1-D expense lifecycle and completeness guidance | Fully represented | Reusable workflow | EXP-01, EXP-03, FIN-02 | M3, F0, M5A | New historical/current expense, draft/edit/review/post/reverse boundaries and field-specific missing-evidence guidance; generic draft remains future scope. |
| 53 | §4 P1-D360/390/768 layouts | Partially represented | Reusable UX acceptance | EXP-01, UX-01 | M3 | Added exact widths and usable narrow-layout card/equivalent behavior while preserving desktop register; no unperformed browser-pass claim. |
| 54 | §4 P1-E/P2 shared design and infographic | Fully represented | Reusable UX with superseded visual concept | UX-01, UX-02, FIN-01 | M3, O2 | Accepted NARVO visual direction replaces historical M-logo concept; no mock figures or raw technical identity as sole business label. |
| 55 | §4 P2 legal/contract metadata | Fully represented | Reusable construction records | CON-01, CON-02, CON-03, OPS-01 | M4, M3, O1 | License/TRN, dates, security/retention, milestone amounts, agreement attachments, formal/internal refs, invoice evidence and duplicates retained. |
| 56 | §5 six-step engineering/handoff/approval workflow | Fully represented | Historical governance | QA-01, OPS-02 | O2 | Inspect actual state/dirty work, resolve discrepancy, design/reuse/verify/reconcile; original AED-first order superseded by later actual fixes and current R0/F0/M3 sequence. |
| 57 | §6 all nine accounting acceptance groups | Fully represented | Universal acceptance with Maker cases | FIN-03, FIN-04, CON-01, CON-02, CUS-01, EXP-03, FIN-02, HR-02, QA-01, OPS-01, OPS-02 | M5A, M5B, M4, H3, O1, O2 | New Company/fiscal openings; fixed/unit contracts; full custody; real-dated evidenced expense;223+25 no duplicates; all subledger/GL/statements; role/tenant/audit/race/periods; EN/AR/mobile/Excel/PDF/money; independent legal/privacy/release gates. |
| 58 | §7 all seven unresolved items | Fully represented | Accounting-policy decision required | EXP-03, CON-02, CON-04, CUS-01, CUS-03, FIN-03, PRJ-03, FIN-05, FIN-02 | F0, M4, M5A, M3, C1 | Electricity VAT; stone measurement/retention/tax; opening/funding/personal spend; true client/overhead; Prompt no start/pay; current posting unknown; custody cash/receivable semantics. |
| 59 | §8 office resume point | Fully represented | Maker-specific operational example | EXP-01, EXP-02, PRJ-04 | M3, M4 | Historical first-October expense/form inspection instruction is not current permission; actual nature determines route; Farm/ownership protections persist. |
| 60 | Closing authority references and no-rebuild conclusion | Fully represented | Architecture and provenance | QA-01, OPS-02 | O2 | Constitution/actual state and factual handoff remain authoritative; preserve older roadmap/frozen decisions and technical evidence; one engine, correctness before speed. |

No newly distinct requirement family was found: **35 existing stable IDs retained;0 added**. The seven enrichments are acceptance/provenance details of existing work. The original contains neither the later project-status/ownership instructions of S5 §10 nor the expanded attendance/stock specifications of S2/S3; these later requirements remain preserved, not falsely attributed to October22. Original first-payment/absent-Villa13 wording is retained as a dated case and qualified by later evidence, not erased or asserted current.

Accounting-design review retains the existing explicit approval gates: cost recognition versus payment/certification, event-specific VAT base/timing/deductions, custody receivable versus physical cash, partner/employee funding and recovery, openings/fiscal closure, expanded attendance/payroll, inventory and revenue/WIP. Historical10% retention and salary/absence assumptions are not universal settings. Confirmed cash evidence may be retained while its classification/tax/retention is pending; only an approved unambiguous supported event can post, and none was posted here. No compliance certification or new accounting policy was inferred.

Evidence status cross-check: current E1 hashes remain16/16 matches; all pre-existing code/migration bytes match the preceding consolidation baseline; targeted source reread confirms fixed original contract input, exception-only attendance and unsupported-source guidance. E2 remains recorded earlier Production read-only acceptance. E1 remains **local implementation/tests only**, migration65 unapplied hosted, new frontend undeployed, human visual/hosted acceptance pending. Maker's existing identity, books and permissions remain untouched; approved mandatory-commercial-enrollment exemption is preserved as shared-engine configuration, not a second accounting engine. Fresh hosted state/financial execution and expert approval remain unverified.

## Reciprocal requirement-to-milestone index

The following association index mirrors the roadmap milestone table exactly. It includes all35 IDs, including the12 supplemental records. It records shared delivery/verification scope, not an alternative order or a second plan. Requirement-body references described as dependencies remain dependencies, not extra delivery assignments.

| Requirement ID | Roadmap milestones |
|---|---|
| FIN-01 | M3, M5B |
| FIN-02 | M5A, I3 |
| FIN-03 | F0, M5A, I4, A1 |
| FIN-04 | M5B |
| PRJ-01 | M3 |
| PRJ-02 | M3 |
| PRJ-03 | F0, M3, I1, I4, C1, C2 |
| EXP-01 | M3 |
| EXP-02 | F0, M3, M4, M5A |
| EXP-03 | F0, M3, M5A, I3 |
| CON-01 | M4 |
| CON-02 | F0, M4 |
| CON-03 | M3, M4, I1 |
| CON-04 | M4 |
| CUS-01 | F0, M4 |
| CUS-02 | F0, M4, H3 |
| CUS-03 | M4 |
| HR-01 | H1, H2 |
| HR-02 | F0, H1, H3, H4 |
| INV-01 | F0, I1, I2, I3, I4, I5, C2 |
| UX-01 | M3, H2, I5 |
| SAAS-01 | R0 |
| QA-01 | R0, M4, M5A, I5, M5B, O1, O2 |
| FIN-05 | C1, C2 |
| FIN-06 | T1, A1 |
| FIN-07 | F0, M5A, M5B |
| FIN-08 | F0, M4, M5A, A1 |
| PRJ-04 | M3 |
| CON-05 | M3, M4 |
| EXP-04 | M3, M5A |
| HR-03 | H1, H2, H3, H4 |
| INV-02 | T1 |
| OPS-01 | I5, O1 |
| OPS-02 | R0, H4, O2 |
| UX-02 | M3, O2 |

Final validation requires equality of every `(requirement ID, milestone)` pair in this index and the roadmap table, not merely finding an ID somewhere in each document. The follow-up repairs four omitted reciprocal associations: PRJ-03/F0, UX-02/M3, UX-01/I5 and FIN-01/M5B. These were already stated in requirement text; no feature scope was invented.

## Maintenance, review result and limits

For each future approved batch: update affected requirement status/evidence and roadmap milestone only; link the exact phase report/test result; record local/hosted/Preview/Production/accounting acceptance separately. Never turn a passing fixture test into live approval, drop unresolved case provenance or silently broaden Maker exception.

Normalization dispositions for the 23 source rows: **11 retained, 5 generalized, 5 revised, 2 superseded scoped repairs**. DECISION REQUIRED is overlapping, not an extra exclusive count. Twelve supplemental requirements are retained obligations omitted from the short source summary; none authorizes new feature work. Superseded repairs FIN-01/EXP-01 retain future coverage and residual date/source issues (EXP-04), rather than deleting their history.

Review verification: source/evidence comparison; local migration inventory; 16/16 E1 source-hash matches; V1.6 committed-content equality; 23 source IDs and 12 supplemental IDs present with milestone references; documentation links/preservation/whitespace checks. No new application test suite, financial execution, browser, hosted alignment/dry-run, legal validation or independent full security/accounting audit. Original October22 source S6 has now been reviewed completely; the prior missing-source limitation is closed for the supplied file. Current status is a reviewable, traceable documentation baseline; commercial onboarding activation and commercial launch readiness remain deferred.

Final follow-up scope: only these two canonical documents edited, no new permanent file, no requirement IDs removed/renumbered and V2.0 retained. Source provenance and the seven acceptance details above are corrected; milestone-index associations are reciprocal. Readiness: **ready for product-owner acceptance of the reconciled plan**, with product/accounting policies still requiring the approvals identified above. This is not implementation permission, hosted onboarding activation, a current-live financial validation or commercial launch approval. Relevant lifecycle lenses: business/design, traceability and documentation checks VERIFIED at review scope; fresh security/runtime/hosted alignment/dry-run/expert signoff DEFERRED; code/schema/deployment mutation NOT APPLICABLE. Other dirty work and historical sources preserved.
