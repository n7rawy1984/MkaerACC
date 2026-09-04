# Engineering Constitution

This file is binding for every AI agent and human developer working in this repository. Keep it concise; detailed phase history belongs in the roadmap, handoff, and phase documents.

## Source of truth

- Actual repository state and actually applied canonical migrations are the primary implementation truth.
- `PROJECT_HANDOFF.md` records the current verified state; `PROJECT_ROADMAP.md` records approved direction and phase boundaries; phase documents record detailed verified decisions.
- Planned is not implemented. If documentation and implementation conflict, investigate and reconcile them—never silently guess.

## Professional SDLC and cross-cutting review

MakerACC is a commercial multi-tenant contracting-accounting product, not merely a collection of working screens. Every meaningful phase or batch follows an iterative SDLC: requirements/business intent; analysis; architecture/design; implementation; verification/testing; security/authorization review; database/migration review; deployment readiness; release/production validation; operations/monitoring; and maintenance/continuous improvement. Implementation findings may require revisiting an earlier stage. Code existence never proves a later lifecycle stage complete.

Continuously consider six cross-cutting lenses: business/accounting correctness; security and authorization; database engineering; deployment/environment/operations; testing/verification; and documentation/traceability. At the start of meaningful work, identify the current lifecycle stage, what is already complete, what is deferred, and which later gates are affected. Apply this discipline proportionately and avoid bureaucracy for its own sake.

Controls must match reachable risk and lifecycle stage. Use stronger review when work affects accounting truth, authorization, tenant isolation, Auth/session state, financial mutation, Company/user data, schema, privileged functions, secrets, external deployment, production data, or irreversible operations. Presentation-only work may use lightweight verification. Do not turn every UI change into a full security audit or block work for speculative or unreachable risks. The full Production Security & Accounting Integrity Audit remains the separate pre-production gate below.

## Product architecture

- This is one reusable multi-tenant, white-label contracting-accounting platform. Company is the tenant and accounting boundary.
- One codebase and one canonical migration history serve all tenants. Never hardcode tenant UUIDs, add Maker-specific accounting assumptions or tenant branches, or copy React pages/apps per customer.
- Branding belongs to configuration/data. Users may belong to multiple Companies. Active tenant context never replaces database authorization.
- `SYSTEM_ADMIN` is not a browser financial cross-tenant bypass.

## Non-negotiable accounting invariants

- Project is an analytic/cost-center dimension, never a GL account. Treasury is the real money location and permanently maps to a real GL account.
- Subcontract accounting is contract-scoped.
- PostgreSQL money uses `BIGINT` minor units; percentages use integer basis points. Persist no floating-point financial amounts.
- Posted accounting is immutable. Corrections use reversal plus a corrected business event where applicable. Historical posted truth is never rewritten for convenience.
- Journals always balance. Never invent an account or amount merely to force balance. Resolve system accounts by stable key/configuration, never display name.
- Supplier/Subcontractor payments settle liabilities without recreating cost. Custody Advances are assets/receivables, not expenses. Custody Settlement never reposts Expenses. Cash Return reduces Custody and does not reverse Project Cost.
- Legitimate liabilities/receivables must not become trapped merely because a Project, Contract, Supplier, Custodian, or other master later closes or becomes inactive.
- If accounting treatment is genuinely ambiguous and a wrong choice could create incorrect financial history, stop and report the ambiguity. Do not guess.

Before implementing financial behavior, establish the actual business event, recognition point, asset/liability/cost/revenue effect, required dimensions, lifecycle, settlement behavior, reversal dependencies, authorization, and concurrency/idempotency needs. Never invent accounting merely to balance a journal. Where relevant, distinguish an accounting-standard requirement, jurisdiction/legal requirement, common contracting-industry practice, and configurable product policy. If required policy is genuinely undefined, stop and report `DECISION REQUIRED`.

## Financial command standard

Where relevant, every financial command must derive the authenticated actor, require active Company membership and explicit permission, validate authoritative masters and lifecycle, enforce tenant/dimension consistency in the database, use normalized request hashing and idempotency, protect source uniqueness, lock transaction-safely, commit document plus journal atomically, preserve immutable posted results, and implement specialized reversal/dependency rules.

Browser financial commands accept business inputs only. Never expose arbitrary journal lines or caller-controlled system GL accounts. Generic accounting primitives remain private.

## Database engineering and migration discipline

The database is part of the accounting and authorization enforcement boundary, not merely storage. Constraints, RLS, grants, and specialized commands must enforce invariants that cannot safely depend on React or caller behavior alone.

- Use forward-only canonical migrations. Never rewrite an applied migration; fix hosted defects with a new forward correction.
- Development, Staging, and Production use the same canonical migration history. Manual SQL Editor schema/function/policy/constraint changes are not substitutes for migrations and must not create schema drift.
- SQL Editor use is limited to read-only verification, controlled synthetic fixtures, focused diagnosis, or explicitly approved operational actions. Any durable database change belongs in a canonical migration.
- Apply development changes only to `MakerACC-Development` unless explicitly authorized. Never touch Staging or Production without explicit instruction, and never patch live schema around migration history.
- New tenant-owned tables are safe by default. Prefer database constraints for financial invariants, and avoid destructive cascade behavior around accounting history.
- When database work occurs, verify local/remote migration alignment and use a linked dry-run where appropriate.
- Preserve `BIGINT` minor-unit money, integer basis points, balanced immutable journals, Company-consistent dimensions, authoritative subledgers, source uniqueness, normalized idempotency, deterministic concurrency, and exact reversal semantics. Persist no floating-point financial truth.

## Continuous security and authorization review

For relevant changes, establish: who the authenticated actor is and how identity/session transitions are validated; the required permission and Company/Project scope; and whether another role or tenant can invoke or read the path. Company is the security and accounting boundary. A URL, slug, React Context, localStorage value, or caller-supplied UUID is never authorization; database authorization and RLS remain authoritative.

The browser never receives service-role/private secrets. Generic financial primitives remain private. Every `SECURITY DEFINER` function must be justified, constrained, use a safe fixed `search_path`, and have minimal `EXECUTE` grants. Focused review must cover reachable direct-write bypass, replay, duplicate effects, races, overpayment, over-release, over-recovery, unauthorized reversal, and dimension leakage where relevant.

Never expose, print, persist in source, or commit a service-role key, database password, Supabase personal/management token, private API key, user password, or access/refresh token. All `VITE_*` values must be browser-safe.

## Security priority

Prioritize proportionately: cross-tenant access, privilege escalation, unauthorized posting/reversal, financial-history mutation, duplicate effects, secret exposure, unsafe browser execution of privileged functions, Auth/session/tenant confusion, and inappropriate financial-data exposure are blocking concerns.

Do not block normal work for speculative or low-impact concerns. Development-only provider recommendations, understood informational warnings, attacks requiring trusted database/operator access, unrelated minor lint warnings, and internet-scale abuse controls for unexposed functionality are normally non-blocking and may be documented.

Classify review findings as `confirmed defect`, `hardening opportunity`, `expected/intentional behavior`, or `deferred future concern`. A confirmed finding identifies affected code/schema, a realistic reachable path, impact, and evidence. Prefer a few high-confidence findings over speculative lists.

## Stop policy

Use approved rules and the smallest safe engineering judgment for ordinary choices. Stop only for a concrete blocker: unintended Staging/Production risk, destructive out-of-scope action, missing user-controlled credential/configuration, unrelated or unidentified dirty work, migration conflict, real accounting ambiguity, real tenant/privilege defect, an underivable required business rule, a change that weakens a frozen financial invariant, or verification proving material incorrectness.

## Development workflow

Before a meaningful batch: inspect git status, read this file, confirm phase boundaries, inspect relevant code/migrations, and consult official memory as needed.

At completion: verify actual behavior; run relevant hosted/business tests, build/lint, `git diff --check`, migration alignment and dry-run, a focused DB/RLS/grant review, secret scan, and reconcile official memory. Do not run unrelated heavyweight audits after every batch.

Use the smallest sufficient evidence mix: unit and integration tests, hosted database tests, authorization matrices, concurrency tests, reconciliation, browser smoke tests, build/lint, migration dry-run, static/source review, and manual verification. Never manufacture a pass. Automated checks do not replace required browser/runtime evidence; manual testing does not replace practical deterministic financial/database verification.

## Deployment, environments and delivery automation

The lifecycle progression is Development → Staging → Production, without implying that every environment is currently active. Development may contain synthetic data. Staging rehearses production-like delivery when the roadmap reaches it. Production changes always require explicit authorization; Development success never authorizes touching Staging or Production.

Configuration belongs outside source. Production configuration must fail closed and must never silently fall back to demo/local accounting data. Relevant deployment review considers build output, environment variables and secrets, migration order, compatibility, smoke testing, rollback/recovery, production-data safety, and observability.

CI/CD is a tracked engineering concern, but current GitHub/Vercel flow must not be described as mature automation unless the repository proves it. Evaluate automated build, lint, tests, migration validation, secret scanning, preview/staging gates, and production approvals when their benefit justifies the complexity. Do not implement future infrastructure merely because it is documented here.

## Operations, observability and recovery

Before real production go-live, evaluate application and database monitoring, error visibility, Auth failures, failed financial commands, audit trail, backups, restoration testing, incident response, deployment history, failed-release recovery, and justified performance/resource monitoring. These remain Production Readiness/P10/audit concerns until actually implemented.

Production readiness must define backup scope, frequency, retention, restoration procedure, restoration authorization, recovery expectations, and restoration verification. An untested backup is not sufficient production assurance.

## Phase completion and Definition of Done

Before declaring a meaningful phase complete, explicitly classify each materially relevant category as `VERIFIED`, `DEFERRED`, or `NOT APPLICABLE`:

- Business/accounting: approved policy implemented; unresolved policy identified.
- Security/authorization: actor, role, tenant and privileged boundaries; direct-write and cross-tenant exposure.
- Database: schema need, canonical migrations, RLS, constraints and invariants.
- Deployment: configuration/action required, environment boundary, values and secrets.
- Testing: risk-appropriate automated, hosted and manual/browser evidence.
- Documentation: roadmap, handoff and phase records match actual state; planned work is not presented as complete.

A meaningful batch is not done merely because code compiles, SQL runs, UI looks correct, or one happy path succeeds. Proportional completion requires the approved requirement, correct business/accounting semantics, respected authorization/tenant boundaries, protected database invariants, canonical migrations where needed, appropriate passing evidence, understood deployment/configuration implications, no hidden unresolved blocker, reconciled documentation, and explicit deferrals. Development-complete is not automatically production-ready.

For significant implementation or review work, record files/migrations changed, environment affected, verification performed, verification not performed, known limitations, deferred work, and final readiness. Never report planned validation as completed validation.

## Frontend/backend boundary

Until P6, the frontend remains localStorage and the production-style backend lives in Supabase Development. Never introduce hybrid financial writes. P6 is the controlled Auth/tenant/white-label and repository/data cutover.

## Pre-production gate

Before real production accounting data or go-live, complete a read-only **Production Security & Accounting Integrity Audit** covering tenant isolation; RLS/authorization; Auth/session/tenant switching; financial RPC abuse; journal, reversal, dependency, idempotency and concurrency integrity; overpayment/over-recovery; immutable history; document/storage access; report/data leakage; secrets/configuration; white-label/custom-domain tenant confusion; and financial reconciliation.

Do not perform that full audit during ordinary feature batches unless explicitly authorized.

## Do not overengineer

Prefer simple constraints, explicit permissions, deterministic commands, small reusable helpers, and clear business rules over unnecessary abstraction, threat-free security layers, excessive permission proliferation, premature infrastructure, or repeated audits of unchanged code.
