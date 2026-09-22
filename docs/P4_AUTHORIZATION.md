# P4 RLS and Authorization

P4 is implemented by `20260830120000_p4_rls_authorization.sql` plus the forward corrective migrations `20260830123000_p4_assignment_validation_security.sql` and `20260830124500_p4_project_insert_visibility.sql`. All three are applied and verified only on the linked synthetic-only `MakerACC-Development` project. P4 adds no journals, accounting documents, posting commands, audit tables, Storage objects, or frontend data path.

## Authoritative access model

Every browser decision derives the actor from `auth.uid()`. Company access requires an `ACTIVE` profile, `ACTIVE` membership, and `ACTIVE` company. Project Manager scope additionally requires an `ACTIVE` row in `project_assignments`; a caller cannot supply an alternate user identity to either project helper. Inactive profile, membership, or assignment revokes access immediately.

`project_assignments` is company/project/user scoped, has a same-company project foreign key and a partial unique constraint allowing only one active assignment per project/user. Its validation trigger permits only an active profile with active same-company membership. Assignment administration requires `project.assign_users`; the target checks run as a non-browser-callable, fixed-search-path security-definer trigger so an authorized administrator can validate protected identity rows without receiving read access to them.

## Role matrix

| Role | Master-data visibility | P4 browser writes |
|---|---|---|
| `ACCOUNTING_ADMIN` | Company-wide projects, parties, categories, accounts, treasury, subcontracts | Company config; projects; all master data; project assignments |
| `ACCOUNTANT` | Company-wide projects, parties, categories, accounts, treasury, subcontracts | None in P4 |
| `PROJECT_MANAGER` | Assigned projects; their project treasury and subcontracts; category definitions only when assigned somewhere | Assigned project updates only; no assignment, membership, COA, party, or financial-admin writes |
| `DATA_ENTRY` | Company projects/categories and operational non-owner/non-employee parties | None in P4 |
| `PROCUREMENT` | Company projects/categories, operational non-owner/non-employee parties, and subcontracts | Supplier/subcontractor/other party masters and subcontracts |
| `MANAGEMENT_VIEWER` | Approved company-wide master and treasury reads | None |
| `SYSTEM_ADMIN` | Its member company/configuration identity only; no accounting/master/project visibility | Project-assignment administration through `project.assign_users`; no financial/master writes |

New stable permissions are `party.manage`, `category.manage`, `account.manage`, `subcontract.manage`, and `project.assign_users`. Permission maps remain database-owned and browser read/write access is absent. `SYSTEM_ADMIN` is still not a cross-tenant browser bypass; cross-company platform work remains a controlled service pathway requiring operational MFA and future P7 audit.

## Table and mutation boundaries

- All exposed public tables have RLS enabled and forced. `anon` has no table access.
- Tenant-owned master rows cannot change `company_id`; same-company composite foreign keys continue to protect project, party, account, treasury, and subcontract dimensions.
- Browser DELETE remains absent on all P4 tables. `service_role` remains the trusted provisioning/administration pathway with reviewed SELECT/INSERT/UPDATE only and no DELETE.
- The two authenticated project helpers are fixed-search-path security-definer functions, derive identity internally, and reveal only booleans. Trigger functions are not directly executable by browser roles.
- P4 has no journal, posted-document, audit, or Storage tables to authorize. Those controls remain in their frozen later phases; P4 did not create placeholders.

| Table | Authenticated SELECT | Authenticated INSERT / UPDATE | DELETE | Trusted `service_role` |
|---|---|---|---|---|
| `profiles` | Own row only | None | None | P2 provisioning grants retained |
| `companies` | Active member companies | None / `company.manage` in same company | None | P2/P3 SELECT/INSERT/UPDATE; no DELETE |
| `company_memberships` | Own memberships only | None; trusted provisioning remains required | None | SELECT/INSERT/UPDATE; no DELETE |
| `permissions` | Active users may read definitions | None | None | Protected configuration |
| `role_permissions` | No direct browser rows; use boolean helper | None | None | Protected configuration |
| `projects` | Company-wide approved roles; assigned-only Project Manager | Accounting Admin insert; Accounting Admin or assigned Project Manager update | None | SELECT/INSERT/UPDATE; no DELETE |
| `parties` | Accounting/viewer all; Procurement/Data Entry operational types only; no Project Manager direct read | Accounting Admin all; Procurement operational types only | None | SELECT/INSERT/UPDATE; no DELETE |
| `expense_categories` | Approved company roles; Project Manager only while actively assigned in company | Accounting Admin only | None | SELECT/INSERT/UPDATE; no DELETE |
| `accounts` | Accounting Admin, Accountant, Management Viewer | Accounting Admin only | None | SELECT; UPDATE(name) only since P6C Slice 9; no INSERT/DELETE/TRUNCATE |
| `treasury_accounts` | Accounting/viewer company-wide; Project Manager assigned project-specific rows only | Accounting Admin only | None | SELECT; UPDATE(name) only since P6C Slice 10; no INSERT/DELETE/TRUNCATE |
| `subcontracts` | Accounting/Procurement/viewer company-wide; Project Manager assigned projects only | Accounting Admin and Procurement | None | SELECT/INSERT/UPDATE; no DELETE |
| `project_assignments` | Own rows or assignment administrators | `project.assign_users` only | None; deactivate by status | SELECT/INSERT/UPDATE; no DELETE |

The private `system_administrators` registry remains inaccessible from browser schemas. Membership creation, role changes, and membership deactivation remain trusted service/operator operations; project assignment is the only P4 authorization administration exposed to a narrowly permissioned authenticated role.

## Helper and security review

- Existing `is_active_user`, `is_company_member`, `has_company_role`, and `has_permission` helpers remain fixed-empty-search-path, identity-derived, boolean-only functions.
- New `has_active_project_assignment(company, project)` and `can_access_project(company, project)` accept scope identifiers but never a user identifier; both require active membership and derive the actor from `auth.uid()`.
- Only those six boolean helpers are authenticated-callable. Assignment/tenant validation trigger functions have browser EXECUTE revoked.
- Database lint returned no findings. The Supabase advisor class of warnings for intentionally authenticated-callable security-definer authorization helpers remains expected and justified: the functions need protected-table reads, expose booleans only, fix `search_path`, and cannot impersonate another user. The new assignment validation security-definer is trigger-only and browser EXECUTE is revoked.
- Development leaked-password protection remains a known provider-hardening recommendation from P2, not a P4 schema regression or frozen P4 exit requirement. No provider-side Auth setting was changed in P4.

## Hosted Development verification

The final run used ten synthetic `example.invalid` Auth users, two synthetic companies, three projects, and synthetic master rows. All 46 required checks passed: bidirectional tenant isolation and UUID guessing; inactive profile/membership/assignment revocation; anonymous denial; assigned/unassigned Project Manager boundaries; assignment grant/revoke and self-assignment denial; treasury/COA/party/subcontract scope; read-only viewer behavior; Accounting Admin, Accountant, Data Entry, Procurement, and System Admin boundaries; unauthorized INSERT/UPDATE/DELETE; authorized project creation; cross-company writes and tenant reassignment; and treasury/subcontract dimensional consistency.

Four additional hardening checks passed: unrelated-tenant helper returns false, inactive-assignment helper returns false, helper calls do not infer membership, and protected profile fields cannot be changed. The initial verification identified and the forward migrations corrected (1) protected-row visibility inside assignment validation and (2) PostgREST `return=representation` visibility for a newly inserted project. The full matrix passed after both corrections.

No real company data, Staging project, or Production project was accessed. Synthetic verification rows are deliberately retained as non-production Development test fixtures; they grant no access outside Development.


## P6C Slice 6 Supplier-only narrowing — VERIFIED COMPLETE (2026-09-16)

The P4 matrix above records the historical baseline. Applied Development canonical migration `20260913123000_p6c_supplier_party_mutations.sql` intentionally narrows authenticated Party INSERT/UPDATE to SUPPLIER only. No current authenticated production code path writes other Party types; demo/localStorage writes are isolated and P5 commands only reference/validate/lock Parties. This narrowing is explicitly user-approved.

Restrictive Supplier INSERT and UPDATE USING/WITH CHECK policies AND with the existing P4 party.manage/role policies. Allowed roles remain ACCOUNTING_ADMIN and PROCUREMENT, requiring active profile/membership/Company. All other roles, including SYSTEM_ADMIN, remain denied. SELECT policies/type visibility and permission mappings do not change. Broader P4 non-Supplier authenticated writes cease to be available; they must not be described as still enabled after this migration.

Authenticated INSERT columns: company_id,name,code,trn,contact_person,phone,email,address,notes. UPDATE: name,code,trn,contact_person,phone,email,address,notes,status. No table-wide write, DELETE/TRUNCATE, type/identity/provenance/timestamp writes, creation-status write or Company reassignment. DB preparation supplies Supplier/ACTIVE and actor/time provenance. Trusted non-Supplier operations retain their existing behavior, and no P5 command/grant changes.

**Final accepted evidence:** Development migration applied, local/remote history aligned and final linked dry-run up to date; 104/104 hosted checks, concurrency and authenticated browser acceptance PASS. All Slice 6 fixtures/Auth were cleaned; global 14 Companies / 14 settings, zero missing/orphan settings. No P6D path or Staging/Production action. Release/production readiness remains deferred. See `P6C_SLICE_6_SUPPLIER_PARTY_MUTATION.md` and `verification/p6c-slice6/README.md`.


## P6C Slice 7 Company profile UPDATE — VERIFIED COMPLETE (2026-09-16)

Canonical migration `20260916120000_p6c_company_profile_metadata.sql` narrows authenticated Company UPDATE to legal_name, trn, address and notes. No authenticated table-wide UPDATE, INSERT, DELETE or TRUNCATE remains. Existing forced RLS and `companies_update_config_admin` USING/WITH CHECK are preserved. `company.manage` continues to permit both ACCOUNTING_ADMIN and SYSTEM_ADMIN only with active same-Company membership/profile/Company; this configuration permission is not a financial or cross-tenant bypass. The historical matrix's SYSTEM_ADMIN row must not be read as excluding its existing Company configuration permission.

Company-local update handling derives the authenticated actor, preserves creation provenance/trusted actor metadata, normalizes the four text fields and advances the exact optimistic token, including trusted/no-op updates. Browser identity/status/actor/timestamp writes and direct trigger EXECUTE are denied. Trusted provisioning INSERT, shared timestamp helper and FKs are unchanged.

Development SQL acceptance: 96/96 checks and exact-token two-writer 1/0 PASS. Supplier/category regressions pass. User-completed authenticated hosted acceptance and final fixture cleanup are accepted: both permitted roles, denied-role controls, tenant isolation, stale two-tab conflicts, authority/profile revocation, focus and RTL/keyboard/narrow-layout behavior passed. Slice 7 is VERIFIED COMPLETE; P6C remains IN PROGRESS and P6D/P6E NOT STARTED. Closure reran no verification. No P6D/financial behavior, Staging/Production action, Slice 8 work or stored credentials; one local commit only, no push. See `P6C_SLICE_7_COMPANY_PROFILE_METADATA.md` for recovery, implementation and evidence limits.


## P6C Slice 8 Project descriptions — VERIFIED COMPLETE (2026-09-17)

Canonical Development migration `20260916140000_p6c_project_metadata.sql` narrows authenticated Project writes to UPDATE(name, client_name, location, contract_number, notes). Historical P4 Project INSERT and broader UPDATE grants are no longer available to browser roles. Existing forced RLS and SELECT/UPDATE policies remain unchanged: Accounting Admin Company-wide; Project Manager only with active assignment; active profile/membership/Company required. No new permission/helper/assignment-administration surface. Trusted provisioning INSERT remains unchanged.

Only Project's timestamp trigger is replaced by an invoker function with empty search_path and no direct browser/service EXECUTE. It preserves creation provenance, derives authenticated updated_by, retains trusted actors and advances monotonic exact tokens. Tenant guard, constraints/FKs, shared helper and P5 remain intact. Financial/code/status/date/id/Company/actor fields cannot be written by authenticated callers.

Hosted 108/108 and concurrency 1/0 PASS, focused provider and isolated Chromium PASS. All 31 migrations aligned, dry-run no-op, public DB lint clean; exact fixture cleanup/global 14/14 verified. **Authenticated browser acceptance and exact-manifest cleanup PASS (user-supplied):** Accounting Admin Alpha/Beta edits, assigned-P1-only Project Manager, assignment revocation/refresh removal/restore, all five denied roles, open-edit downgrade, membership/profile revocation/restore, stale two-tab conflicts, tenant isolation, focus/tab-return and Arabic/RTL/keyboard/narrow layout. Final fixture Companies/Projects/memberships/assignments/browser Auth 0; global Companies/settings 14/14, missing/orphan 0/0. Assignment-only UI snapshots remain until query/refresh; UPDATE RLS rechecks immediately. Closure reran no verification. No credentials stored or P6D/financial behavior. See `P6C_SLICE_8_PROJECT_METADATA.md`. P6C IN PROGRESS; P6D/P6E NOT STARTED; no Staging/Production or Slice 9. One local closure commit only; no push.

## P6C Slice 9 — Account Display Name UPDATE — VERIFIED COMPLETE (2026-09-21)

Development migration `20260917120000` narrows authenticated Account UPDATE to `name` and removes browser INSERT. Existing account.manage RLS allows ACCOUNTING_ADMIN only; six other roles remain denied, including SYSTEM_ADMIN. Name updates preserve code/type/hierarchy/requires_party/system key/status and tenant/provenance; trigger stamps actor and advances exact update token. No financial or Treasury behavior. Forced RLS, tenant guard and trusted provisioning remain unchanged.

Hosted 99/99, concurrency 1/0, repository/provider and isolated Chromium PASS; 32 migrations aligned, dry-run no-op and public DB lint clean. Automated fixtures removed; global 14/14, missing/orphan 0/0. **Authenticated hosted browser acceptance PASS (user-completed):** admin Alpha/Beta name edits, protected configuration, two-tab stale conflict, full denied-role matrix, downgrade, membership/profile revocation and restore, focus/draft/keyboard/cancel/RTL/390px checks; Treasury read-only and financial routes unwritable. Exact guarded cleanup PASS: fixture Companies/Accounts/memberships/assignments/browser Auth 0; global 14/14, missing/orphan 0/0. Closure reran no verification. P6C IN PROGRESS; P6D/P6E NOT STARTED. Production readiness DEFERRED. No financial/P6D behavior, Staging/Production, stored credentials or Slice 10. One local closure commit only; no push. See `P6C_SLICE_9_ACCOUNT_DISPLAY_NAME.md` and `verification/p6c-slice9/README.md`.

## P6C Slice 10 — Treasury Display Name UPDATE — VERIFIED COMPLETE (2026-09-21)

Development migration `20260921120000` narrows authenticated Treasury writes to UPDATE(name). Existing treasury.manage remains ACCOUNTING_ADMIN only; forced RLS and SELECT/UPDATE policies unchanged. Project Manager remains assigned-Project read-only with hidden GL details protected. All configuration (including permanent GL, Project scope, code/type/status/bank/reference/notes) is excluded from browser writes. The table-local invoker trigger preserves creation provenance, derives authenticated update actor and advances exact tokens; permanent-GL validator/shared helpers/trusted INSERT remain intact. No financial/P6D behavior.

Hosted 108/108, concurrency 1/0, Treasury/Account Chromium and repository/provider regressions PASS; 33 migrations aligned, final dry-run no-op, public DB lint clean. Automated fixture cleanup/global 14/14, missing/orphan 0/0 verified. User-completed authenticated browser acceptance and exact guarded cleanup PASS: admin ACTIVE/INACTIVE name-only edits and protected configuration; stale two-tab conflict; Alpha/Beta isolation; complete read-only/denied-role matrix; assigned Project Manager visibility and assignment revoke/restore; open-edit downgrade, membership/profile revocation/no-company; focus/tab/draft/keyboard/RTL/390px; Account name regression and unwritable financial routes. Final fixture Companies/Accounts/Treasuries/Projects/memberships/assignments/browser Auth 0; global Companies/settings 14/14, missing/orphan 0/0. Closure reran no verification. P6C IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED. No financial/P6D behavior, Staging/Production, stored credentials or Slice 11. One local closure commit only; no push. See `P6C_SLICE_10_TREASURY_DISPLAY_NAME.md`.


## P6C Slice 11 — OTHER Party name — VERIFIED COMPLETE

Development migration `20260921130000` adds existing OTHER name UPDATE for ACCOUNTING_ADMIN and PROCUREMENT under unchanged party.manage. The restrictive UPDATE policy allows SUPPLIER/OTHER; INSERT stays Supplier-only. Historical Slice 6 Supplier-only UPDATE narrowing above is superseded only for this one OTHER operation. SELECT/role mapping/FORCE RLS stay unchanged.

Existing exact Supplier INSERT/UPDATE column grants remain unchanged (PostgreSQL grants are table-wide). The new fixed-empty-search-path SECURITY INVOKER trigger rejects all authenticated OTHER field changes except name, derives update actor and advances monotonic exact tokens after the unchanged Supplier preparation trigger. Protected identity/type/status/code/contact/creation provenance cannot change. No direct trigger EXECUTE or new RPC; trusted provisioning unchanged.

Hosted 108/108 and exact-token concurrent 1/0 PASS; isolated Slice 11/Supplier Chromium and repository/provider/shared-resource-lock checks PASS. All 35 migrations aligned; dry-run no-op; DB lint clean. Authenticated browser acceptance PASS for ACCOUNTING_ADMIN and PROCUREMENT ACTIVE/INACTIVE OTHER name mutation, protected boundary, stale conflict, tenant isolation, role/downgrade/revocation behavior, focus/tab/keyboard and Arabic/RTL responsive manual verification. Earlier synthetic Playwright overflow was not reproduced in real Chrome at 394px; no CSS fix was required. Guarded cleanup PASS; all fixture/Auth counts 0, global Companies/settings 14/14, missing/orphan 0/0. P6C IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED. No Staging/Production or Slice 12. See `P6C_SLICE_11_OTHER_PARTY_NAME.md`.

Slice 11 forward correction `20260921133000_p6c_other_party_trusted_token.sql` preserves monotonic OTHER update tokens for trusted writes too. A focused rollback test reproduced the initial trusted future-token regression; the correction preserves trusted provisioning privileges/INSERT and browser name-only rules. Final hosted suite 108/108; 35 migrations aligned. See the Slice 11 phase record.

## P6C Slice 12 — EMPLOYEE Party name — VERIFIED COMPLETE

Development migration `20260922120000` adds name-only existing EMPLOYEE UPDATE for ACCOUNTING_ADMIN under unchanged party.manage, while preserving Supplier/OTHER UPDATE and Supplier-only INSERT. Existing table-wide column grants remain unchanged; a fixed-path SECURITY INVOKER trigger restricts authenticated EMPLOYEE changes to name, stamps the DB actor and advances tokens for authenticated and trusted updates. Forced RLS, sensitive SELECT and P4 role policies remain unchanged. Hosted 115/115 and exact-token concurrency 1/0 PASS; focused repository/provider and isolated Chromium including RTL/390px PASS. Authenticated Development browser acceptance PASS across ACTIVE/INACTIVE edits, validation, stale conflict, tenant isolation, full documented role matrix, downgrade/revocation/restoration, focus/draft/keyboard, EN/AR/RTL responsive layout, protected Party types and unchanged financial boundaries. Exact guarded cleanup/final verify PASS: all Slice 12 fixture/Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. No Staging/Production or Slice 13. See `P6C_SLICE_12_EMPLOYEE_PARTY_NAME.md`.
