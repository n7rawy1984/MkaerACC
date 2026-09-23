# P6C Final Closeout / Boundary Audit

**P6C — COMPLETE (Development), 2026-09-23.** Slices 1–16 remain VERIFIED COMPLETE. This is the final integrated boundary audit and its narrow grant correction, not Slice 17. P6D — NOT STARTED. P6E — NOT STARTED. Production readiness — DEFERRED.

Starting clean `main`: HEAD = fetched origin/main = `1bd696ae9103b1d93b4e4667e2edddff63b8349b`. Only MakerACC-Development (`eqnzueginpkskbnqvgoc`) was inspected/changed. No commit or push was performed.

## Integrated architecture and frozen scope

The initial audit and correction used the same unchanged application baseline. The production graph passes the P6A/P6C checks across 61 production modules and 42 master modules; the isolated demo graph contains 54 modules. App mode fails closed; local-demo is development-only and lazy. Production master reads/writes do not use demo repositories or `cas:v1` financial state. Browser Auth/tenant preference storage is not accounting storage or authorization.

| Slices | Completed production contract |
|---|---|
| 1 | Company profile and Projects READ; async provider foundation |
| 2 | Parties and Expense Categories READ |
| 3 | Accounts and Treasury READ |
| 4 | Subcontracts READ, exact BIGINT text projection |
| 5 | Expense Category create/metadata/status mutation; ACCOUNTING_ADMIN |
| 6 | Supplier create/metadata/status mutation; ACCOUNTING_ADMIN and PROCUREMENT |
| 7 | Company legal_name/TRN/address/notes; ACCOUNTING_ADMIN and tenant-scoped SYSTEM_ADMIN |
| 8 | Project name/client_name/location/contract_number/notes; ACCOUNTING_ADMIN or assigned PROJECT_MANAGER |
| 9–10 | Account and Treasury name only; ACCOUNTING_ADMIN |
| 11 | OTHER Party name; ACCOUNTING_ADMIN and PROCUREMENT |
| 12–14 | EMPLOYEE/CUSTODIAN/OWNER name; ACCOUNTING_ADMIN |
| 15 | SUBCONTRACTOR name; ACCOUNTING_ADMIN and PROCUREMENT |
| 16 | Subcontract scope_of_work/start_date/expected_end_date/notes; ACCOUNTING_ADMIN and PROCUREMENT |

Supabase-backed routes are `/` (Projects), `/company-profile`, `/projects`, `/parties`, `/expense-categories`, `/accounts`, `/treasury-accounts` and `/subcontracts`. Other production paths render the deferred surface, including financial paths; no old demo financial writer is reachable through production routing. No required frozen P6C operation remains missing. Broader CRUD/lifecycle operations are optional future product work. Provisioning, subscription and platform administration remain outside P6C.

Company scope comes from claims-validated P6A identity, active profile/membership/Company and explicit tenant selection. Every master repository scopes queries by Company and checks returned identity. Database RLS remains authoritative; PROJECT_MANAGER stays assignment-constrained and SYSTEM_ADMIN has no financial bypass. Keyed provider scope includes user/Company/role; request generations, unmount invalidation and session checks reject late reads/write results. Resource refreshes merge only the affected snapshot; shared Party operations serialize. Existing assignment-only snapshot refresh limitations do not bypass database write authorization.

P6C invokes no posting/reversal RPC and creates no journals, ledger movements, expenses, liabilities/receivables, certificates, advances, payments, retention events or allocations. Existing P5 specialized RPC grants are intentional backend capabilities and remain unchanged; frontend financial integration belongs to P6D. Generic accounting primitives remain private. Metadata changes preserve stable IDs and financial source references.

Subcontract amount projections and write responses cast BIGINT to text before JSON decoding; exact amounts remain strings, including `9007199254740993`. Integer basis points remain safe; no P6C derived financial totals were introduced. Account type/parent/requires_party/system key/status and Treasury permanent GL/type/Project/status/configuration remain protected. Subcontract contract number, Company/Project/Subcontractor FKs, economics, retention, status and provenance remain protected.

## Confirmed blocker and forward correction

Read-only catalog inspection found unintended `TRUNCATE`, `REFERENCES` and `TRIGGER` on `public.project_assignments` for both `anon` and `authenticated`. The required global audit also found PostgreSQL 17 `MAINTAIN` on the same table for both roles. DELETE was already denied. No exploit path was demonstrated and no destructive command was executed. These residual grants contradicted the P4 browser-role contract and failed the explicit closeout grant gate.

Applied forward migration: `20260923130000_p6c_closeout_grant_hardening.sql`. It revokes precisely those four privileges from both browser roles on this one table and asserts the intended effective grants and forced RLS. No applied migration was edited. No DELETE change, default-privilege change, role redesign, policy change, ownership change or trusted-role correction occurred.

Global audit covered all 32 public application tables, both browser roles, all eight PostgreSQL 17 table privileges and effective SELECT/INSERT/UPDATE/REFERENCES column privileges:

| Classification | Finding and disposition |
|---|---|
| A — intended/documented | Authenticated SELECT and approved master column mutations; assignment SELECT/INSERT/UPDATE under P4 policies. Preserved. Existing P5 financial-table reads and specialized RPCs remain intentional. |
| B — unintended residual | Eight table grants: four privileges × two browser roles on project_assignments. All removed in this migration; no additional table required correction. |
| C — uncertain | None found in the browser grant audit. |

Exact post-fix project_assignments privileges:

| Role | SELECT | INSERT | UPDATE | DELETE | TRUNCATE | REFERENCES | TRIGGER | MAINTAIN |
|---|---|---|---|---|---|---|---|---|
| anon | false | false | false | false | false | false | false | false |
| authenticated | true | true | true | false | false | false | false | false |

Across all 32 application tables, browser DELETE/TRUNCATE/REFERENCES/TRIGGER/MAINTAIN are false; anon has no effective table/column privileges. Intended authenticated mutations exactly retain the P6C column allowlists and assignment contract.

The read-only before/after catalog comparison proved exactly eight table-grant removals and 18 corresponding inherited column REFERENCES removals (nine assignment columns × two roles). Every SELECT/INSERT/UPDATE grant and every service_role table/column privilege is unchanged. All 32 RLS/owner records, 48 policies, 38 role-permission records, 46 function definitions/ACLs and 372 constraints compare unchanged. RLS remains enabled and forced throughout.

Assignment role behavior is preserved by unchanged effective DML grants, policy expressions, helpers, constraints and role permissions: `project.assign_users` remains ACCOUNTING_ADMIN/SYSTEM_ADMIN, tenant-scoped; PROJECT_MANAGER cannot administer assignments. Trusted provisioning is preserved at the same enforcement boundaries. This is catalog/source preservation evidence, not a claim of new hosted mutation or browser role-matrix execution.

## Verification and database integrity

- Fresh fetch/clean main/hash baseline PASS; live project identity confirmed as MakerACC-Development.
- Before correction: 40 local/remote migrations aligned; Companies/settings 14/14, missing/orphan 0/0. Linked dry-run listed only the new correction, which was then applied successfully.
- After correction: 41 local/remote migrations aligned through `20260923130000`; final linked dry-run no-op; public DB lint returned no schema errors.
- Read-only global grant audit and exact preservation comparison PASS. `scripts/sql/p6c-closeout/grant-audit.sql` is the reusable catalog query (`supabase db query --linked --file ...`); it contains no business-row data or credentials.
- `npm run build` PASS; `npm run lint` PASS with four unchanged Fast Refresh warnings and no errors. Existing demo chunk-size advisory remains.
- `npm run verify:p6a-boundary` PASS; `npm run verify:p6c-boundary` PASS (includes `verify-p6c-behavior.mjs`, so no redundant second run).
- Latest shared Party/Subcontract behavior gate `node scripts/verify-p6c-subcontractor-party-name-behavior.mjs` PASS, including Slice 16 four-field payload, exact tokens, roles, selective refresh/recovery and delayed-result isolation. The base consolidated runner ends at Slice 11, so this supplies current Slice 16/shared-boundary evidence.
- `node scripts/verify-p6c-slice16-browser-kit.mjs` PASS (static manifest verification only; no browser launched).
- Focused real-secret scan and `git diff --check` PASS.
- Global Companies/settings remain 14/14; missing/orphan 0/0. The preceding read-only closeout audit verified zero historical P6C fixture-prefix counts across ten tables and zero P6C-named Auth accounts; this correction creates no fixture or Auth user and changes only grants.

No historical hosted slice suites, concurrency suites, isolated Chromium suites or manual browser matrices were rerun. No application code changed. Prior accepted slice evidence remains valid; no additional browser acceptance is claimed.

## Deferrals and lifecycle decision

`PRE_DEMO_UAT.md` remains a separate, non-blocking pre-demo/pilot gate. The Slice 16 residual expanded manual role/UI sweep is not complete and is not reopened as a Development blocker. Existing pagination/realtime limitations, assignment-only snapshot refresh behavior, provider hardening recommendations and trusted-only grant extras remain separate future concerns. The generic deferred-screen copy still mentions future master-data cutover; that presentation-only wording is obsolete, not a missing master operation, and is left outside this grant correction.

Historical IN PROGRESS, next-slice, master-mutations-pending and temporary-fixture statements in prior phase records describe their original checkpoints and are superseded by this final record. There is no Slice 17.

| Lifecycle category | Final classification |
|---|---|
| Business/accounting | VERIFIED frozen master contract, protected history and P6D boundary |
| Security/authorization | VERIFIED integrated source/current catalog and corrected browser grant boundary; accepted slice behavior evidence retained |
| Database | VERIFIED one forward Development migration, preserved policies/trusted privileges, 41 aligned migrations, clean lint and no-op dry-run |
| Deployment | VERIFIED Development-only application of correction; Staging/Production promotion and Production readiness DEFERRED |
| Testing | VERIFIED consolidated automated/catalog gates; residual pre-demo manual UAT DEFERRED |
| Documentation | VERIFIED final record, handoff, roadmap and authorization summary reconciled |

**P6C — COMPLETE. P6D — NOT STARTED. P6E — NOT STARTED. Production readiness — DEFERRED.**

**Development completion is not Production readiness.** The full Production Security & Accounting Integrity Audit, operational/recovery gates, Pre-Demo UAT and Staging/Production promotion are not claimed complete. No Staging/Production action, commit or push was performed.
