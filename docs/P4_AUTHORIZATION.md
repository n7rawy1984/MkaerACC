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
| `accounts` | Accounting Admin, Accountant, Management Viewer | Accounting Admin only | None | SELECT/INSERT/UPDATE; no DELETE |
| `treasury_accounts` | Accounting/viewer company-wide; Project Manager assigned project-specific rows only | Accounting Admin only | None | SELECT/INSERT/UPDATE; no DELETE |
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
