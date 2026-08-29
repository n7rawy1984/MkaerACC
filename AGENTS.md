# Engineering Constitution

This file is binding for every AI agent and human developer working in this repository. Keep it concise; detailed phase history belongs in the roadmap, handoff, and phase documents.

## Source of truth

- Actual repository state and actually applied canonical migrations are the primary implementation truth.
- `PROJECT_HANDOFF.md` records the current verified state; `PROJECT_ROADMAP.md` records approved direction and phase boundaries; phase documents record detailed verified decisions.
- Planned is not implemented. If documentation and implementation conflict, investigate and reconcile them—never silently guess.

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

## Financial command standard

Where relevant, every financial command must derive the authenticated actor, require active Company membership and explicit permission, validate authoritative masters and lifecycle, enforce tenant/dimension consistency in the database, use normalized request hashing and idempotency, protect source uniqueness, lock transaction-safely, commit document plus journal atomically, preserve immutable posted results, and implement specialized reversal/dependency rules.

Browser financial commands accept business inputs only. Never expose arbitrary journal lines or caller-controlled system GL accounts. Generic accounting primitives remain private.

## Migration discipline

- Use forward-only canonical migrations. Never rewrite an applied migration; fix hosted defects with a new forward correction.
- Apply development changes only to `MakerACC-Development` unless explicitly authorized. Never touch Staging or Production without explicit instruction, and never patch live schema around migration history.
- New tenant-owned tables are safe by default. Prefer database constraints for financial invariants, and avoid destructive cascade behavior around accounting history.

## Security priority

Prioritize proportionately: cross-tenant access, privilege escalation, unauthorized posting/reversal, financial-history mutation, duplicate effects, secret exposure, unsafe browser execution of privileged functions, Auth/session/tenant confusion, and inappropriate financial-data exposure are blocking concerns.

Do not block normal work for speculative or low-impact concerns. Development-only provider recommendations, understood informational warnings, attacks requiring trusted database/operator access, unrelated minor lint warnings, and internet-scale abuse controls for unexposed functionality are normally non-blocking and may be documented.

Classify review findings as `confirmed defect`, `hardening opportunity`, `expected/intentional behavior`, or `deferred future concern`. A confirmed finding identifies affected code/schema, a realistic reachable path, impact, and evidence. Prefer a few high-confidence findings over speculative lists.

## Stop policy

Use approved rules and the smallest safe engineering judgment for ordinary choices. Stop only for a concrete blocker: unintended Staging/Production risk, destructive out-of-scope action, missing user-controlled credential/configuration, unrelated or unidentified dirty work, migration conflict, real accounting ambiguity, real tenant/privilege defect, an underivable required business rule, a change that weakens a frozen financial invariant, or verification proving material incorrectness.

## Development workflow

Before a meaningful batch: inspect git status, read this file, confirm phase boundaries, inspect relevant code/migrations, and consult official memory as needed.

At completion: verify actual behavior; run relevant hosted/business tests, build/lint, `git diff --check`, migration alignment and dry-run, a focused DB/RLS/grant review, secret scan, and reconcile official memory. Do not run unrelated heavyweight audits after every batch.

## Frontend/backend boundary

Until P6, the frontend remains localStorage and the production-style backend lives in Supabase Development. Never introduce hybrid financial writes. P6 is the controlled Auth/tenant/white-label and repository/data cutover.

## Pre-production gate

Before real production accounting data or go-live, complete a read-only **Production Security & Accounting Integrity Audit** covering tenant isolation; RLS/authorization; Auth/session/tenant switching; financial RPC abuse; journal, reversal, dependency, idempotency and concurrency integrity; overpayment/over-recovery; immutable history; document/storage access; report/data leakage; secrets/configuration; white-label/custom-domain tenant confusion; and financial reconciliation.

Do not perform that full audit during ordinary feature batches unless explicitly authorized.

## Do not overengineer

Prefer simple constraints, explicit permissions, deterministic commands, small reusable helpers, and clear business rules over unnecessary abstraction, threat-free security layers, excessive permission proliferation, premature infrastructure, or repeated audits of unchanged code.
