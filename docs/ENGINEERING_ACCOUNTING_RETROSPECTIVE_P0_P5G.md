# Engineering and Accounting Retrospective — P0 through P5G

Date: 2026-08-29. Scope: focused review of the actual repository and canonical migrations applied to synthetic-only `MakerACC-Development` through P5G, using repository-root `AGENTS.md` as the binding baseline. This was not the future full Production Security & Accounting Integrity Audit and did not authorize P5H.

## Evidence reviewed

- Current `main` commit, clean pre-review worktree, local migration files, linked project identity, and aligned remote history through `20260906123000`.
- Roadmap, handoff, multi-tenant architecture, and every P5A–P5G implementation document.
- P2/P4 role, permission, active-membership, forced-RLS, and Project Manager assignment functions/policies.
- P3 company-owned masters, composite dimension foreign keys, stable system accounts, Treasury permanent GL enforcement, and restrictive deletes.
- P5A journal tables, deferred balance enforcement, immutability, references, source uniqueness, idempotency reservations, private creation/reversal primitives, grants, and search paths.
- P5B–P5G document schemas, specialized commands, row locks, lifecycle/reversal guards, RLS/grants, generated types, and hosted verification records.
- Local Certificate calculator, chart of accounts, posting builder, approval flow, and contract-scoped ledger helpers, especially deductions, retention, VAT, recovery, payable, cumulative work, and reversal assumptions.

## Review results

### Tenant architecture and dimensions

`Company` consistently remains the tenant/accounting boundary. Financial documents carry direct `company_id`; composite foreign keys constrain same-company Project, Party, Treasury, Subcontract and journal relationships. Forced RLS and company-role helpers prevent UUID knowledge from granting access. Project remains analytical, Treasury retains one permanent Asset GL identity, Custody remains company/Custodian pooled by approved policy, and subcontract accounting remains company/Subcontract scoped. No tenant UUID or Maker-specific accounting branch appears in application or migration logic.

### Authorization and RLS

Financial tables are forced-RLS and browser read scopes match documented roles. Posted economic writes occur only through authenticated specialized SECURITY DEFINER commands that derive `auth.uid()` and check active membership through permission/role helpers. `SYSTEM_ADMIN` has no raw financial browser bypass. Direct browser journal/document mutation and generic private kernel execution remain denied. Trusted service writes are limited to provisioning/master configuration appropriate to their tables; P5G deduction mapping configuration is not browser-writable.

### Accounting kernel

P5A uses `BIGINT` minor units, bounded `NUMERIC` aggregation, balanced two-layer journal enforcement, immutable headers/lines, atomic references, normalized-hash idempotency, unique source/purpose, and exact dimension-preserving reversal. No persisted financial floating type or arbitrary browser journal interface was found.

### P5B–P5G commands

- P5B recognizes cost/VAT once and separates Treasury, Custodian, Owner and Supplier Credit funding.
- P5C settles explicit Supplier Credit liabilities without recreating cost/VAT, locks source Expenses against over-allocation, and blocks source reversal while live payments exist.
- P5D treats Custody funding as an Asset transfer and serializes pooled Custodian consumption/reversal safety.
- P5E Settlement groups already-posted Expenses without GL effect; Cash Return reduces Custody without reversing cost.
- P5F funds a contract-scoped recoverable Asset and blocks reversal after contract balance consumption.
- P5G recognizes cost, evidence-qualified VAT, retention, same-contract recovery, mapped deductions and residual payable without Treasury movement. It locks the Subcontract for cumulative/recovery authority and exactly reverses before P5H dependencies exist.

Idempotency, source uniqueness, lifecycle state, overpayment/over-recovery, and dependency rules are present where the implemented downstream parent exists. P5H must introduce the already-documented live Certificate-payment dependency before payment settlement.

### Multi-tenant and white-label readiness

The frontend is still the explicit localStorage adapter until P6 and no hybrid financial writes exist. No public slug or active-tenant UI context is treated as authorization. Branding and tenant selection remain planned configuration/cutover work, not copied applications or tenant code branches.

### Migration discipline and documentation

Applied history is forward-only; hosted corrections were preserved as new migrations. Staging and Production were untouched. Official memory distinguishes implemented P0–P5G from planned P5H/P6 and now identifies `AGENTS.md` plus the future pre-production audit gate.

## Accounting treatment assessment

### P5G deduction Revenue mapping — EXPECTED

Verified correct under current product accounting policy. The local chart defines all three supported types as `Recovery - Company Materials`, `Recovery - Subcontractor Backcharges`, and `Recovery - Other Certificate Deductions`, each an Income account. The local posting builder credits the selected fixed recovery account. P5G preserves—not invents—that policy by restricting each trusted company/type mapping to an active PostgreSQL `REVENUE` account and preventing browser-selected GL IDs.

Different businesses may choose inventory/cost-offset treatment in a future explicitly approved policy, but no conflicting policy exists in this product. Therefore this is not a defect or current decision blocker. It must not be changed silently.

### Retention basis — EXPECTED

Local and P5G both calculate retention once on gross current Certificate value: current work plus current variation. P5G replaces client percentage input with the P3 Subcontract’s integer basis points and deterministic PostgreSQL rounding. Retention is contract-scoped and reversal restores it exactly. Retention Release remains deferred.

### VAT waterfall — EXPECTED, with future compliance validation deferred

Local and accepted P5G policy calculate VAT on net-before-VAT after retention, Advance recovery and mapped deductions. Positive recoverable VAT requires invoice evidence; AUTO 5% uses deterministic numeric rounding. Stored/journal components balance and are internally consistent. Jurisdiction/customer-specific tax-policy validation remains part of the future pre-production audit/configuration review; this retrospective found no conflict with the currently approved product rule and made no tax-policy change.

### Current work and cumulative certification — EXPECTED

P5G derives prior work from live posted same-contract Certificates, calculates current work from work-to-date, includes current variation in gross, and caps cumulative live gross at original value plus approved variations. A Subcontract row lock serializes competing approvals and recoveries. Reversed Certificates leave immutable provenance but no longer consume live cumulative value.

### Reversal dependencies — EXPECTED / DEFERRED

P5B–P5F block reversals where an implemented downstream dependency would be violated. P5G Certificate reversal is safe before P5H because no production Certificate payment parent exists. P5H must add a live-payment link/allocation and block Certificate reversal until those payments are reversed. Retention Release dependencies are likewise deferred to their dedicated flow.

## Findings by classification

### CRITICAL

None.

### HIGH

None.

### MEDIUM — confirmed defect, corrected

**P5F active-only lifecycle check was not serialized.** Affected schema: `20260906120000_p5f_active_contract_advances.sql`. Reachable path: the public wrapper read `ACTIVE` without a row lock, then delegated to the older private implementation whose own locked validation rejected only `CLOSED`. A concurrent trusted status update could commit `COMPLETED` between those steps, allowing funding contrary to the frozen active-only rule. Impact: one new Advance could be posted after contract completion during that race.

Correction: `20260907120000_p5f_active_contract_lock.sql` forward-replaces the public wrapper, locks the same-company Subcontract `FOR UPDATE`, then validates `ACTIVE` before delegation. It changes no historical document or journal.

### LOW / HARDENING

- Database lint retains the known P5C unused `supplier_row` variable warning. It has no reachable accounting or authorization effect and was not changed.
- Provider/deployment recommendations and jurisdiction-specific tax confirmation remain appropriate pre-production work, not blockers for the currently unexposed Development backend.

### EXPECTED

- P5G deduction credits to trusted Revenue mappings, retention-on-gross basis, accepted VAT waterfall, revised-value cap, inactive-party obligation recognition, and pre-P5H Certificate reversal behavior.
- Company-wide raw financial reads for Accounting Admin/Accountant/Management Viewer and denial for System Admin/operational roles, as documented.
- Service-managed deduction mapping writes and browser read-only access.

### DEFERRED

- P5H Subcontractor Payment and its Certificate-reversal dependency.
- Retention Release/payment.
- P6 Auth/tenant/white-label/frontend cutover, P7 audit events, private document Storage, report-safe views, and historical import.
- Full Production Security & Accounting Integrity Audit before real production data/go-live.

### DECISION REQUIRED

None before P5H.

## Regression and final state

The focused P5F lifecycle regression passed 9/9: active posting, stable result, transition to `COMPLETED`, explicit lifecycle rejection, no duplicate document/effect, preserved original history, and one source journal. Static inspection confirms the status read now uses `FOR UPDATE` before delegation.

Final verification also includes migration alignment/no-op dry-run, database lint, focused RLS/grant/SECURITY DEFINER/search-path review, journal/financial reconciliation evidence from accepted P5A–P5G matrices, build, lint, diff hygiene, and secret scanning.

## Readiness

No Critical, High, unresolved Medium, tenant-isolation, privilege, migration, or decision-required accounting blocker remains.

**READY FOR P5H**
