# Post-P5 Focused Engineering and Accounting Integrity Review

Date: 2026-08-30. Outcome: **READY FOR P6A**.

## Scope and source of truth

This checkpoint reviewed the financial work added after the P0–P5G retrospective: P5H Subcontractor Payments, P5I-A Retention Releases, P5I-B Retention Payments, their new reversal dependencies, and their interaction with the complete P5 accounting layer. It was not the future Production Security & Accounting Integrity Audit and did not implement or start P6.

The review used repository state and the canonical migrations actually aligned with synthetic-only `MakerACC-Development` as implementation truth. Sources reviewed included `AGENTS.md`, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`, the multi-tenant architecture record, the P0–P5G retrospective, P5A/P5C/P5F/P5G interaction documents, P5H/P5I phase documents, generated database types, Git history, and migrations through `20260910120000`.

Preflight confirmed a clean worktree at P5 closure commit `770b798`, linked project `eqnzueginpkskbnqvgoc` / `MakerACC-Development`, identical local and remote migration versions through `20260910120000`, and a successful no-op linked dry-run.

## P5H Subcontractor Payments

The production command creates one immutable Payment for one Subcontract and accepts only Certificate allocations. Composite foreign keys and allocation validation enforce Company, Project, Party and Subcontract identity. A Subcontract-first lock and deterministic Certificate locks serialize same-contract settlement. Live `POSTED` Payment allocations alone consume immutable Certificate `payable_amount_minor`; reversed Payments retain allocation history but restore derived outstanding.

Posting is exactly Dr stable-key `SUBCONTRACTOR_PAYABLE` / Cr the selected Treasury's permanent active Asset GL. Both lines preserve Project and Subcontract; the payable line preserves Party and the cash line preserves Treasury. Hosted journal inspection confirmed no Cost, VAT, Retention Payable or Subcontractor Advance effect. Active same-company and Project-compatible Treasury validation remains mandatory, while existing liabilities remain settleable after Project closure, Subcontract completion/closure and Subcontractor inactivation.

Normalized allocation ordering, explicit total equality, P5A request reservation, atomic `SCPAY` references, unique source posting, immutable history and exact reversal were verified in code and hosted behavior.

## P5I Retention Release

Retention Release is Accounting-Admin-only and allocates only live Certificates from one Subcontract. Authoritative remaining retention is immutable Certificate retention less allocations from live `POSTED` Releases. Subcontract-first and UUID-ordered Certificate locking prevents staged or concurrent over-release and prevents same-Party contracts from pooling retention.

Posting is exactly Dr `SUBCONTRACTOR_RETENTION_PAYABLE` / Cr `SUBCONTRACTOR_PAYABLE`, with matching Company, Project, Party and Subcontract dimensions. Hosted inspection confirmed no Treasury, Cost, VAT, Advance recovery or deduction line. Reversal is an exact P5A inversion; allocations remain immutable and stop consuming availability only when the Release becomes `REVERSED`.

Existing recognized retention remains releasable through closed/completed/inactive master lifecycle states. This is a liability reclassification only and does not authorize new Certificate recognition.

## P5I Retention Payment

Retention Payment belongs to one Subcontract and allocates only live Retention Releases from that same Subcontract. It cannot accept a Certificate as its settlement source. Live `POSTED` Payment allocations derive released-but-unpaid balances; Subcontract-first and deterministic Release locks prevent duplicate or concurrent overpayment.

Posting is exactly Dr `SUBCONTRACTOR_PAYABLE` / Cr the selected Treasury's permanent active Asset GL. Hosted inspection confirmed no Retention Payable, Cost, VAT, Advance recovery or deduction effect. Reversal exactly inverts the original journal, retains allocation provenance and restores Release availability. Existing released liabilities remain payable after closure/completion/inactivation, subject to active compatible Treasury validation.

## Shared Payable and subledger separation

P5G Certificate payable and P5I Release payable intentionally share the `SUBCONTRACTOR_PAYABLE` control account but retain independent business-document sources:

- P5H allocations reference only `subcontractor_certificates` and consume only original Certificate payable.
- P5I-B allocations reference only `subcontractor_retention_releases` and consume only released Retention payable.
- Same-company foreign keys, source-type validation and same-Subcontract checks reject cross-source, cross-contract and cross-tenant substitution.

Hosted negative tests confirmed P5H cannot consume a Release UUID and P5I-B cannot consume a Certificate UUID. Whole-scope reconciliation matched the shared Payable GL to live Certificate payable plus live Releases less live P5H and P5I-B Payments. Retention Payable independently matched live Certificate retention less live Releases.

## Reversal dependency chain

P5H and P5I install independent database triggers on Certificate reversal. P5I-B installs a separate trigger on Release reversal. All specialized commands share the Subcontract-first lock order, so posting and reversal cannot bypass dependency checks through concurrency.

A new synthetic Certificate with both payable and retention was posted in Development, followed by a live P5H Payment and live P5I Release. The targeted sequence verified:

1. Certificate reversal failed while both consumers were live.
2. A live Retention Payment blocked Release reversal.
3. Reversing only the ordinary P5H Payment did not allow Certificate reversal while the Release remained live.
4. Reversing the Retention Payment restored Release reversal eligibility.
5. Reversing the Release then restored Certificate reversal eligibility because the independent P5H consumer was already reversed.
6. The Certificate then reversed successfully.
7. All original documents, allocations and exact reversal journals remained immutable history.

Failed attempts rolled back their command reservation and journal effects atomically. Reversed consumers no longer consumed outstanding/availability.

## Accounting continuity and reconciliation

The reviewed code preserves the previously accepted P5 chains without creating or destroying balances: Supplier Credit settlement does not recreate expense; Custody funding/expense/return semantics remain separate; Subcontractor Advances remain recoverable Assets; Certificates recognize Cost/VAT/Retention/Advance recovery/deductions/payable once; P5H settles Certificate payable; and P5I reclassifies and then settles Retention.

Read-only whole-scope hosted reconciliation covered 48 Certificates, 23 P5H Payments with 25 allocations, 21 Releases with 21 allocations, 24 Retention Payments with 25 allocations, and 107 linked original/reversal journals. It found:

- zero allocation-total mismatches;
- zero orphan allocations or original/reversal links;
- zero live overpayment, over-release or released-payable overpayment;
- zero duplicate P5H/P5I original sources;
- zero unbalanced relevant journals;
- zero missing Project/Subcontract journal dimensions;
- zero forbidden Cost/VAT/Retention/Advance effects in Payments;
- zero Treasury or non-control-account effects in Releases; and
- exact Payable and Retention control-account/subledger reconciliation.

## Tenant, authorization and privileged boundary

All P5H/P5I documents carry direct Company ownership and composite same-company constraints for Subcontract, Project, Party, Treasury, Certificate, Release and journal links. Hosted tests denied same-Party cross-contract allocation and cross-company command injection.

All six P5H/P5I document/allocation tables have RLS enabled and forced. Their only browser table privilege is `SELECT`, constrained to active company Accounting Admin, Accountant or Management Viewer roles. Direct authenticated INSERT was denied; no UPDATE/DELETE browser grant exists. Operational roles and `SYSTEM_ADMIN` receive no raw-row policy. Anonymous command execution was denied.

Public specialized functions are executable only by `authenticated` and derive `auth.uid()`. P5H/P5I Payment posting checks `accounting.post`; all reversals check `accounting.reverse`; manual Release additionally requires the `ACCOUNTING_ADMIN` role. Current role-permission mappings give posting to Accounting Admin/Accountant and reversal only to Accounting Admin. Private allocation/history guards and the P5A creation/reversal kernel have no browser or service execution grant. Every reviewed SECURITY DEFINER function fixes `search_path` to empty and schema-qualifies objects.

## Kernel and migration discipline

P5H/P5I financial persistence uses `BIGINT` minor units and no floating money columns. Percentage persistence remains integer basis points at the Certificate/Subcontract layer. Specialized commands call the private P5A journal primitives, whose deferred constraint enforcement, immutability, source/purpose uniqueness, normalized idempotency and exact dimension-preserving reversal remain in force.

P5H and P5I were introduced as three forward-only canonical migrations. Git history shows the phase migrations committed as their batches; no corrective rewrite or manual schema patch was required by this review. Development migration history is aligned and the final linked dry-run is a no-op. Staging and Production were not touched.

## Findings

### CRITICAL

None.

### HIGH

None.

### MEDIUM

None.

### LOW / HARDENING

- Hosted database lint retains the known P5C unused `supplier_row` variable warning. It is outside the changed P5H/P5I surface and has no reachable accounting or authorization effect.

### EXPECTED

- P5H and P5I-B share one Payable GL control while settling distinct immutable document-source subledgers.
- Closed/completed/inactive masters do not trap previously recognized liabilities; cleanup commands do not create new cost or commercial recognition.
- Reversed documents retain allocations and journals as immutable provenance while ceasing to consume live balances.
- Accounting Admin, Accountant and Management Viewer have company-wide raw financial reads; operational roles and System Admin do not.

### DEFERRED

- P6 Auth/tenant/white-label/frontend cutover remains unimplemented.
- Audit events, private document Storage, reporting-safe views and historical import remain in their approved later phases.
- The full read-only Production Security & Accounting Integrity Audit remains mandatory before real production data or go-live.

### DECISION REQUIRED

None.

## Corrections and quality gates

No accounting, authorization, schema or application defect required correction. The targeted hosted matrix passed 42 assertions after selecting a positive-retention synthetic fixture. The first attempted fixture had a valid 0% retention policy and therefore could not exercise the combined branch; it created no Payment or Release and was not treated as a defect. Whole-scope reconciliation then passed 18 checks.

Hosted database lint completed with only the known P5C warning. Generated schema types remained aligned. Frontend build and lint, `git diff --check`, focused floating-point/grant/RLS/search-path review, secret scan, final migration alignment and final linked dry-run completed successfully; existing frontend lint warnings remain unchanged.

## Final readiness

No Critical, High, unresolved Medium, tenant-isolation, privilege, accounting-integrity, migration or decision-required blocker remains.

**READY FOR P6A**
