# Maker Contracting Accounting System — Project Roadmap

This is the official living roadmap. Read it with `PROJECT_HANDOFF.md` before development. Architecture planned does not mean implemented.

## Product Goal

Build a production, bilingual accounting system for a small/medium UAE contracting company: company/project dimensions, treasury, custody, suppliers, subcontractors, payroll/WPS, controlled historical import, client contracts, VAT, journals, and financial reporting.

## Binding Architecture Decisions

1. **Production Data Foundation is the immediate next phase.** It precedes Payroll/WPS and the large 2025/2026 import, superseding the former “infrastructure later” decision.
2. **Platform:** React/Vite remains the frontend; Supabase Auth, PostgreSQL, private Storage, and database RPCs form the production data plane. There is no public signup.
3. **Company is the security tenant.** Every operational/accounting row is company-scoped directly or through an enforced parent. Optional project access narrows project managers; it never expands company access.
4. **RLS/database commands enforce authorization.** UI permissions are usability only. Browser clients cannot directly mutate journals, audit events, or posted documents.
5. **Posting is atomic and server-side.** A command validates authorization, dimensions, lifecycle, VAT and funding; writes the document, balanced journal and audit event; then commits once. Failure rolls back all work.
6. **Posted history is immutable.** Drafts may be edited. Corrections use reversal and replacement/correcting documents, never silent mutation/deletion.
7. **Journal integrity:** integer minor units, exact balance, one source posting, idempotent commands, consistent company/project/contract dimensions.
8. **Project remains an analytic dimension, not a GL cash/bank account.**
9. **Subcontract accounting remains contract-scoped:** project, subcontractor and subcontract dimensions are preserved.
10. **Each TreasuryAccount retains one permanent dedicated GL account.** Inactive treasury cannot fund new activity; history remains readable.
11. **Money uses `BIGINT` fils (AED minor units), never floating point.**
12. **Historical data is staged/reviewed.** Demo seeds never enter production and opening balances are separate approved documents.
13. **No consolidated accounting yet.**

## Production Architecture Freeze — P0 Approved

These decisions are binding inputs to P1–P10. They are **approved architecture**, not implemented features.

### 1. Tenant ownership and project dimension

`company_id` is mandatory on every tenant-owned master, operational document, journal entry, attachment, import batch and audit event. `project_id` is nullable only for a genuine company-level event; no fake “General Project” is allowed. Project answers what job/cost center; TreasuryAccount answers where money moved. A project cash box/bank is a real TreasuryAccount linked to that project and its permanent GL account.

| Table/area | Company/project rule |
|---|---|
| `companies` | Tenant root; no parent `company_id` |
| `profiles` | Global Auth extension; company access only through memberships |
| `company_memberships` | Mandatory `company_id`; one membership per user/company |
| `project_access` | Mandatory matching `company_id` and `project_id` |
| `projects`, `parties`, `accounts`, `expense_categories`, `treasury_accounts` | Mandatory `company_id`; treasury `project_id` optional and same-company when present |
| `expenses`, `supplier_payments` | Mandatory `company_id`; `project_id` optional only for company-level activity |
| `advances`, `custody_settlements` | Mandatory `company_id`; project may be null only for explicitly company-wide custody; selected expenses must match company and compatible project scope |
| `custody_settlement_expenses` | Company derived through protected settlement/expense parents; both parents must share company |
| `subcontracts`, `subcontractor_advances`, `subcontractor_certificates`, `subcontractor_payments` | Mandatory `company_id` and `project_id`; contract, subcontractor and certificate parents must match |
| `certificate_deductions` | Company/project derived through the protected certificate parent |
| `journal_entries` | Mandatory `company_id`; source document company must match |
| `journal_lines` | Company derived through journal parent; optional project/party/subcontract dimensions must belong to that company and match the source semantics |
| `attachments`, `audit_log`, `import_batches` | Mandatory `company_id`; project optional where genuinely company-level |
| `import_rows` | Company derived through protected batch parent until promoted |

Financially important tables carry direct `company_id` even when derivable, making RLS and reconciliation explicit. RPCs derive/validate it from trusted membership and parent rows; client-supplied tenant identity is never trusted alone.

### 2. Permissions and Project Manager boundary

Use stable permission keys behind the small initial roles. Initial keys include `certificate.prepare`, `certificate.approve_post`, `financial.post`, `financial.reverse`, `members.manage`, `project.read_assigned`, and `company_gl.read`. Roles map to permissions in database-owned configuration/functions; RPCs check permissions, not UI labels.

Subcontractor certificate approval/posting requires `certificate.approve_post`, initially granted to `ACCOUNTING_ADMIN` only. `ACCOUNTANT` may prepare/review drafts but does not receive it automatically. Permission expansion later changes role-permission data/policy, not every RPC.

`PROJECT_MANAGER` is restricted to assigned projects. It may read the project, project expenses/cost summaries, relevant suppliers/subcontracts/certificates and project attachments, and may create permitted operational drafts. It cannot see company-wide GL, unrelated treasury balances, owner current accounts, payroll details, other projects, user administration, or company-wide sensitive accounting. Shared supplier master fields are exposed only through a safe project-relevant view; company-wide balances/activity are not.

### 3. Document immutability and reversal

Drafts may be edited/deleted only where the workflow already permits and before posting. After posting/approval, accounting-critical amounts, dates, company/project/party/contract/funding dimensions and source links are immutable. Non-financial notes may be corrected only through a controlled audited metadata action. No generic delete exists for posted documents.

Every reversal is an authorized, atomic, idempotent RPC that locks the original, rejects an existing effective reversal, creates a new journal with exact opposite lines and identical dimensions, links `reversal_of_journal_entry_id` and source document, records reason/actor/time, updates the business document to `REVERSED` (or records a linked reversal status where its operational status must be retained), and writes audit. A corrected event is a new document/posting; the original remains unchanged.

| Current posted flow | Initial reversal outcome |
|---|---|
| Normal expense / supplier-credit purchase | Expense `POSTED → REVERSED`; reverse cost, VAT and funding/payable lines. Replacement expense is new |
| Supplier payment | Payment `POSTED → REVERSED`; reverse payable settlement and funding; supplier payable reopens |
| Custody advance | Advance `POSTED → REVERSED`; reverse custody asset/funding, only if later dependencies do not make reversal invalid; otherwise reverse dependent items first |
| Custody cash return | Settlement remains finalized but gains `posting_status=REVERSED` (or equivalent) and linked reversal; selected-expense reconciliation is preserved. Any replacement return is a new correcting action |
| Subcontractor advance | Advance `POSTED → REVERSED`; block while recovered by a live certificate unless dependencies are reversed first |
| Approved certificate | Certificate accounting status `APPROVED/PARTIALLY_PAID/PAID → REVERSED`; require live payments to be reversed first; reverse cost/VAT/retention/advance recovery/deductions/payable |
| Subcontractor payment | Payment `POSTED → REVERSED`; reverse payable/funding and recalculate certificate payment status |

### 4. Reference numbering

UUID primary keys remain internal. Human references are allocated only by PostgreSQL inside the creation/posting transaction using a row-locked/atomic counter keyed by `(company_id, document_type, fiscal_year)`. A committed or explicitly cancelled number is never reused; gaps are acceptable and safer than renumbering. A transaction that fully rolls back before issuance has issued no document number.

Format: `{COMPANY_CODE}-{TYPE}-{YYYY}-{NNNNNN}`. Initial type codes: `JE`, `EXP`, `CADV`, `CSTL`, `SPAY`, `SC`, `SADV`, `SCERT`, `SCPAY`. Scope is company + calendar year + type. Subcontract number uniqueness remains additionally enforced per project; the server-generated reference is the accounting-system reference and an optional vendor/contract number remains separate. Branch/site numbering is deferred.

### 5. Money and deterministic rounding

Persist money as signed/non-negative-by-context `BIGINT` AED minor units: AED 1.00 = 100. No floating point enters an RPC. API money inputs are integer minor units; UI converts validated decimal strings at the boundary.

Percentages are stored/passed as integer basis points (100% = 10,000 bps) unless a later rule needs a documented finer scale. Calculate aggregate bases first with integer/rational or PostgreSQL `NUMERIC` intermediate precision, retain full intermediate precision through the formula, then round once when producing each legally/accountingly posted minor-unit result. Default rounding is round-half-away-from-zero, matching PostgreSQL `round(numeric)`; negative reversals reverse the already-rounded original amounts exactly. VAT rounds per document/tax line according to the approved tax policy; retention and other percentage components round once per posted component. Any residual required to balance a document is assigned only by an explicit documented rule, never an unexplained hidden adjustment.

### 6. Journal enforcement and idempotency

Posting RPCs generate lines, validate line shape/dimensions and total debit=credit before setting `POSTED`. A deferred constraint trigger independently rechecks every inserted/changed posted journal at transaction end because balance is cross-row. Direct browser INSERT/UPDATE/DELETE grants and RLS policies for journals/lines are absent; only trusted RPCs/migration roles write them. Posted entries/lines are immutable by trigger as defense in depth.

Every financial command requires a client-generated UUID `idempotency_key` and stores a canonical request hash. Unique `(company_id, operation_type, idempotency_key)` makes retries return the same result when the hash matches and reject changed payloads. Unique live `(company_id, source_type, source_id, posting_kind)` prevents a second original posting or reversal. Source documents hold `posted_journal_entry_id` and, where applicable, `reversal_journal_entry_id`. Row locks and state predicates prevent duplicate payments, double certificate approval, settlement finalization and overpayment/recovery under concurrency.

### 7. Legacy pooled Cash/Bank

Migration never guesses a named TreasuryAccount for legacy pooled `CASH`/`BANK`. Staging records retain source payload/reference and receive `NEEDS_REVIEW/UNRESOLVED_TREASURY`. A reviewer may approve a mapping only with evidence; otherwise the record posts/preserves provenance against an explicit company-level legacy pooled GL/bucket and remains flagged as unresolved for treasury-subledger reporting. Original journals are never silently rewritten.

### 8. Environments, deployment safety and Auth

Use three separate Supabase projects: Development, Staging and Production. Staging is justified now because Auth/RLS, local migration rehearsal and financial cutover need isolation from both engineering data and real books.

- Frontend variables are environment-specific public URL and anon/publishable key only (for example `VITE_SUPABASE_URL`, `VITE_SUPABASE_ANON_KEY`, and an explicit app environment flag). Production builds fail closed if production configuration is missing; they never fall back to demo/localStorage.
- Database URLs, access tokens and service-role/secret keys live only in protected CI/server secret stores. They never use a `VITE_` prefix or enter browser bundles/logs.
- Versioned migrations are reviewed once and promoted unchanged Development → Staging → Production. Production changes require backup confirmation, migration plan, explicit approval and post-migration checks. Demo seed commands are environment-gated and prohibited in Production.
- No public signup. Supabase Auth identity links to profile, active company membership, role and permission resolution. Authorized admins invite/create users.
- `SYSTEM_ADMIN` is a platform break-glass/admin capability executed through controlled server/service tooling with MFA and audit; it is not represented as an RLS “see every tenant” browser role. Routine UI sessions still require explicit company membership. Service-role bypass is never exposed to the frontend.

Region, data-location expectations, subscription plan, backup/PITR availability and final RPO/RTO are external deployment decisions. Initial recommendation: choose the nearest acceptable Supabase region after company/legal confirmation; use a plan with automated daily backups and PITR if affordable; target RPO ≤ 24 hours without PITR or about 15 minutes with PITR, RTO ≤ 8 business hours, encrypted monthly exports, and quarterly restore tests. These are recommendations, not confirmed compliance requirements.

### 9. Audit and attachment security

Minimal append-only audit event: `id, company_id, project_id?, actor_user_id, action, entity_type, entity_id, occurred_at, request_id?, idempotency_key?, before_data?, after_data?, reason?, actor_ip/user_agent?`. Actor comes from `auth.uid()`/trusted service context, never arbitrary client input. Normal clients cannot insert/update/delete audit events. Financial RPCs and security/member-management commands write audit in the same transaction.

Accounting documents use private Storage only. Object paths are company-scoped and include optional project, entity type/entity UUID and random file/version UUID. PostgreSQL attachment metadata stores ownership, object path, checksum, MIME/size, version/supersession and actor/timestamps. Authorized reads receive short-lived signed URLs. Posted evidence is versioned/superseded, never overwritten; no public accounting bucket exists.

### 10. Production cutover

LocalStorage remains an explicit demo/development adapter. Production mode never silently reads or writes it for accounting when Supabase is unavailable. An outage produces a visible unavailable/read-only failure and blocks posting. Cutover uses export → staging validation/review → approved import → reconciliation → write freeze → production switch; source exports and unresolved provenance remain retained.

## Completed

- ✅ Phase 1 — Core Accounting MVP
- ✅ Phase 2A — Custody Settlements + Subcontractor Certificates
- ✅ Phase 2B.1 — Company + Project + Treasury Foundation
- ✅ Phase 2B.1A — Treasury Integration + Project Guards
- ✅ Phase 2B.2 — Subcontractor Operationalization + Contract Dimension
- ✅ Phase 2B.3 — Arabic / English i18n + RTL
- ✅ Production Data Foundation P0 — Production Architecture Freeze *(documentation/decisions only; no backend implemented)*
- ✅ Production Data Foundation P1 — Supabase Environments + Migration Foundation *(repository/CLI foundation; no remote projects or business schema)*
- ✅ Production Data Foundation P2 — Auth, Profiles, Memberships and Roles *(Development-applied and remotely verified with synthetic data)*
- ✅ Production Data Foundation P3 — Core Production Schema and Master Data *(Development-applied and remotely verified with synthetic data)*

Detailed implementation history remains in `PROJECT_HANDOFF.md` and git history.

## Current Phase

### ➡ Phase 2C — Production Data Foundation *(P0–P3 complete; P4 next)*

#### ✅ P0 — Production Architecture Freeze

- The architecture, ownership, permission, posting, reversal, numbering, money, environment, audit, attachment and cutover decisions below are frozen.
- Completion means the design is approved and documented only. No Supabase environment, migration, Auth, table, RLS policy, RPC or Storage bucket exists yet.

#### ✅ P1 — Supabase Environments + Migration Foundation

- Added the pinned project-local Supabase CLI, official `supabase/config.toml`, timestamped forward-only migration directory, safe environment example/ignore rules, and exact developer workflow.
- Frozen separate remote Development/Staging/Production projects with one canonical migration history promoted in that order. No remote project was provisioned because region/plan/data-location decisions and credentials remain external.
- Automatic database seeding is disabled. The P1 migration is intentionally schema-free and creates no business/demo data.
- Repository lifecycle verified with CLI version/init/migration creation and config parsing. Local migration application is deferred because this machine has neither Docker nor Podman; remote verification is deferred because no project/credentials exist.
- Existing frontend build and lint remain successful; secret-pattern and diff checks pass. The application still uses only the localStorage adapter.

#### ✅ P2 — Auth, Profiles, Memberships and Roles

- Added a timestamped migration for Auth-triggered profiles, the minimum P2 company identity parent, active/inactive memberships, all frozen roles, central role-permission mappings, and a private platform-admin registry.
- Added least-privilege RLS/GRANTs and fixed-search-path helpers for active user, membership, role, and permission checks. Browser users can read only their own identity/membership and active member companies; they cannot mutate security configuration.
- `SYSTEM_ADMIN` does not bypass tenant membership in browser queries. Cross-company administration is reserved for a trusted service pathway, with MFA and immutable audit still required operationally.
- Public signup and anonymous sign-ins are disabled in both local config and the verified hosted Development Auth settings. Invitation lifecycle and the complete remote negative-test matrix are documented in `docs/P2_AUTHORIZATION.md`.
- Project access is deliberately deferred to P3's real project parent. Frontend Auth/profile-locale cutover is deferred so verified Development identities are not misleadingly associated with browser-local demo books.
- Applied all four canonical P1/P2 migrations to the approved `MakerACC-Development` project. Hosted public signup and anonymous sign-ins are disabled; Development Site/redirect URLs are verified.
- Synthetic remote verification passed for Admin Auth creation, profile trigger/defaults, own-profile access, tenant isolation/UUID guessing, membership and role write denial, duplicate-active constraint, inactive profile/membership revocation, every frozen role's certificate permission, anon denial, public-signup denial, and System Admin isolation.
- The first remote run exposed missing `service_role` SQL privileges for the trusted provisioning pathway; `20260828120000` corrects these without granting browser writes or DELETE. `20260828123000` removes unnecessary browser EXECUTE from the provider event-trigger helper.
- Linked migration status is aligned, final dry-run is up to date, database lint has no errors, generated types are stored in `src/types/database.generated.ts`, and frontend build/lint/secret checks pass.

#### ✅ P3 — Core Schema and Master Data

- Extended the existing P2 company tenant parent and added production projects, shared parties, expense categories, chart of accounts, treasury accounts, and subcontract masters. No duplicate company, transaction, journal, certificate, or payment table was created.
- Money is `BIGINT` minor units and retention is integer basis points. Stable per-company `accounts.system_key` values replace account-name or hardcoded-UUID resolution for future P5 commands.
- Composite foreign keys and fixed-search-path validation triggers enforce company/project/party/account/treasury/subcontract consistency, active subcontractor/open-project creation rules, permanent one-to-one treasury GL identity, and restrictive deletion behavior.
- Case-insensitive uniqueness is global for company code, company-scoped for project/party/category/account/treasury codes and system keys, and project-scoped for subcontract numbers.
- Every P3 table has forced RLS, conservative active-membership reads, no anon/browser writes, and server-only SELECT/INSERT/UPDATE with DELETE withheld. Full P4 permission/project policy expansion remains deferred.
- Applied `20260829120000` only to `MakerACC-Development`. The complete synthetic constraint/master-data matrix and tenant-isolation smoke test passed; final dry-run is current, database lint is clean, generated types are refreshed, and the localStorage frontend/build/lint remain unchanged.

#### P4 — RLS and Authorization

- Enable RLS on all exposed tables and Storage objects.
- Enforce membership, role, project scope and document-state rules.
- Deny direct journal/audit/posted-document mutation.
- Test ID guessing, inactive users and privilege escalation across companies/projects.

#### P5 — Atomic Accounting Commands

- Implement minimally granted `SECURITY DEFINER` PostgreSQL functions with fixed `search_path`, authorization checks and appropriate row locks.
- Cover Expense, Advance, Supplier Payment, Settlement finalization, Subcontractor Advance, Certificate approval, Subcontractor Payment and reversal.
- Add idempotency, unique source posting, balance/dimension checks, journal immutability and audit.
- Reconcile RPC results against current pure posting fixtures.

#### P6 — Async Data/Command Layer and Cutover

- Replace synchronous collection repositories with typed async query repositories plus domain command RPCs.
- Split `AppDataContext` into server-state queries and explicit mutations; do not load/rewrite whole tables.
- Retain pure money/certificate/ledger logic for previews and verification; the database is authoritative.
- Keep LocalStorage only as an explicitly labeled demo/development adapter, never an offline production ledger.

#### P7 — Audit, Reversal and Operational Controls

- Add immutable events for create/edit/approve/post/reverse/status and permission changes.
- Implement the frozen per-flow reversal commands, actors/timestamps/reversal links and dependency guards; prohibit hard deletion of financial history.
- Add reconciliation and operational error queries.

#### P8 — Private Documents

- Add private buckets and attachment metadata linked to company/project/document.
- Authorize paths and signed access by membership, project access, role and document state.
- Audit upload/replacement/deletion and sensitive access where required.

#### P9 — LocalStorage Migration Tooling

- Export a versioned read-only package with manifest, counts, schema version, hashes and provenance.
- Load staging tables; validate references, amounts, duplicates, balance and dimensions.
- Promote only approved/reconciled batches through an authorized command. Never guess uncertain dimensions.
- Preserve original exports and import batches as evidence/rollback inputs.

#### P10 — Rehearsal and Go-Live

- Test roles/RLS/posting/concurrency/idempotency/reversal/documents end to end.
- Reconcile counts and trial balance; perform a backup restore drill.
- Freeze local writes, export, import/reconcile/approve, then switch production.
- Retain local data read-only for an agreed verification window with rollback criteria.

## Exit Criteria

- No production accounting write depends on localStorage.
- Authenticated company isolation and negative RLS tests pass.
- Accounting commands are atomic, idempotent, balanced and audited.
- Posted documents/journals cannot be silently edited/deleted.
- Private files cannot cross tenant/project boundaries.
- Restore and migration rehearsals pass.
- Trial balance and source-document reconciliation match approved data.

## Subsequent Sequence

1. **Phase 2D — Payroll + WPS:** employees, salary structures, allowances/deductions, periods, project allocation, journal posting, salary payable, WPS and payroll register. Model details from real evidence.
2. **Phase 2E — Historical 2025/2026 Import + Opening Balances:** staging, duplicate detection, traceability, approval and reconciliation; opening balances separately approved.
3. **Phase 3 — Client Contracts / Certificates / Receivables:** external clients, contracts/variations, certificates, VAT, retention receivable, advances, AR and collections.
4. **Phase 3B — Revenue Accounting:** contract assets/liabilities, unbilled amounts, WIP and recognition policy after accounting-policy approval.
5. **Phase 4 — Financial Reporting:** TB, GL, P&L, Balance Sheet, cash flow, project profitability, aging and VAT reports. Balance Sheet waits for complete opening balances.

## Deferred

- Multi-company consolidation and public signup.
- Offline/multi-master production accounting.
- Retention release and complex legacy reversals until explicitly designed.
- Client revenue-recognition assumptions.
- Enterprise DR beyond practical managed backups, exports and tested restoration.

## Decision Log Addendum — 2026-08-26

- Production Data Foundation moved ahead of Payroll/WPS and historical import.
- P0 Production Architecture Freeze completed as documentation/decision work only.
- P1 migration/tooling foundation completed without creating a remote project or business schema.
- P2 identity/authorization was completed on 2026-08-27 after applying and verifying the canonical migrations on Development with synthetic data.
- P3 core master data was completed on 2026-08-27 with Development migration/constraint/RLS verification. P4 is now the next phase.
- Supabase Auth/PostgreSQL/Storage selected. PostgreSQL RPCs are the ledger transaction boundary; Edge Functions are optional external orchestration, not the accounting commit boundary.
- Company membership plus optional project restriction is authoritative through RLS/database commands.
- `BIGINT` AED minor units selected.
- A generic synchronous `StorageDriver` swap is insufficient; production requires async queries and domain commands.
- Posted journals and audit events are append-only; corrections use reversals.

---

*P0–P3 are complete. P4 is the exact next phase; P4–P10 have not started. Do not start Payroll/WPS or bulk historical import until all Foundation exit criteria pass.*
