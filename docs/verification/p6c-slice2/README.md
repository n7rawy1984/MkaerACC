# P6C Slice 2 Development verification fixture — CLEANUP COMPLETE

**Current status: P6C Slice 2 VERIFIED COMPLETE. The fixture is NOT present. All fixture database rows are zero and the Auth test user has been removed. Scripts below are retained for traceability; do not rerun creation or cleanup against the completed run.**

Target only **MakerACC-Development**, project ref `eqnzueginpkskbnqvgoc`. These are controlled operational fixture scripts, not canonical migrations or application mutation APIs. Never execute the directory as a batch. Creation, role changes, assignment changes and cleanup are distinct actions.

Auth identity: `74e36291-172a-44e7-95be-f6c1283c315b`, exact email `p6c-slice2-user@example.test`. The user created this confirmed identity manually; its automatic profile was verified ACTIVE before insertion. No password is requested, stored or documented.

## Exact fixture manifest

Every fixture UUID below is the prefix `72000000-0000-4000-8000-` followed by the full twelve-character suffix shown. Company settings use the Company UUID as their primary key. All actor fields on newly inserted rows are NULL; timestamps use database defaults.

| Suffix | Table / purpose | Code / name | Status |
|---|---|---|---|
| `0000000000a1` | Company Alpha / settings | `P6C-S2-ALPHA` / P6C Slice 2 Alpha | ACTIVE |
| `0000000000a2` | Company Beta / settings | `P6C-S2-BETA` / P6C Slice 2 Beta | ACTIVE |
| `0000000000b1` | Alpha membership | Exact Auth UUID above / MANAGEMENT_VIEWER | ACTIVE |
| `0000000000b2` | Beta membership | Exact Auth UUID above / MANAGEMENT_VIEWER | ACTIVE |
| `0000000000c1` | Alpha Project | `P6C-S2-PROJECT` / P6C Slice 2 Assignment Project | ACTIVE |
| `0000000000d1` | Alpha Project assignment | Exact user + Alpha + Project above | ACTIVE |
| `0000000000e1` | OWNER Party | `P6C-S2-OWNER` / P6C S2 Owner | ACTIVE |
| `0000000000e2` | EMPLOYEE Party | `P6C-S2-EMPLOYEE` / P6C S2 Employee | ACTIVE |
| `0000000000e3` | CUSTODIAN Party | `P6C-S2-CUSTODIAN` / P6C S2 Custodian | ACTIVE |
| `0000000000e4` | SUPPLIER Party | `P6C-S2-SUPPLIER` / P6C S2 Supplier | ACTIVE |
| `0000000000e5` | SUBCONTRACTOR Party | `P6C-S2-SUBCONTRACTOR` / P6C S2 Subcontractor | ACTIVE |
| `0000000000e6` | OTHER Party | `P6C-S2-OTHER` / P6C S2 Other | INACTIVE |
| `0000000000f1` | Category | `P6C-S2-CAT-ACTIVE` / P6C CAT ACTIVE | ACTIVE |
| `0000000000f2` | Category | `P6C-S2-CAT-INACTIVE` / P6C CAT INACTIVE | INACTIVE |
| `0000000000f3` | Category | `P6C-S2-CAT-NULL` / P6C CAT NULL DESCRIPTION | ACTIVE |

Alpha legal name: `P6C Slice 2 Alpha Synthetic LLC`; Beta: `P6C Slice 2 Beta Synthetic LLC`. Both Company notes are `Temporary P6C Slice 2 verification only`; other optional Company fields are NULL.

| Settings | Alpha | Beta |
|---|---|---|
| Slug | `p6c-s2-alpha` | `p6c-s2-beta` |
| Display name | P6C S2 Alpha | P6C S2 Beta |
| Default locale | en | ar |
| Primary color | `#1d4ed8` | `#7e22ce` |
| Accent color | `#0891b2` | `#c2410c` |
| Logo/favicon | NULL / NULL | NULL / NULL |

Supplier TRN is exactly `001234567890123`, contact person `P6C جهة اتصال`, notes `Leading-zero TRN verification`. All other optional Party fields are NULL; non-Supplier rows have NULL TRN/contact/notes too. Category descriptions are respectively `Synthetic active category — مواد`, `Synthetic inactive reference`, NULL. Project optional business/money fields are NULL. Beta has no Projects, assignments, Parties or Categories.

## Role changes — prepared, not executed during setup

Use the full contents of exactly one linked SQL file in the Development SQL Editor. Each is an explicit transaction, validates exact Auth UUID/email/ACTIVE profile and Company UUID/code/name, and updates only the exact ACTIVE Alpha membership UUID/user/Company. It requires exactly one affected row or rolls back. Beta is never updated.

| Exact guarded SQL | Expected Alpha Parties | Expected Alpha Categories |
|---|---|---|
| [role-management_viewer.sql](role-management_viewer.sql) | 6, all types | 3 |
| [role-accounting_admin.sql](role-accounting_admin.sql) | 6, all types | 3 |
| [role-accountant.sql](role-accountant.sql) | 6, all types | 3 |
| [role-procurement.sql](role-procurement.sql) | 4: CUSTODIAN, SUPPLIER, SUBCONTRACTOR, OTHER | 3 |
| [role-data_entry.sql](role-data_entry.sql) | Same 4 | 3 |
| [role-project_manager.sql](role-project_manager.sql) | 0 | 3 if assignment ACTIVE; 0 otherwise |
| [role-system_admin.sql](role-system_admin.sql) | 0 | 0 |

This matrix was reconfirmed from the applied `parties_read_sensitive_roles` and `categories_read_operational` policies before creation. All roles require active profile, membership and Company. Inactive master records are still readable when their type is authorized. Project Manager's category rule requires at least one own ACTIVE assignment in the same Company; it does not permit direct Party reads.

Suggested sequence: initial MANAGEMENT_VIEWER → ACCOUNTING_ADMIN → PROCUREMENT → ACCOUNTANT → DATA_ENTRY → PROJECT_MANAGER (active/inactive/active assignment) → SYSTEM_ADMIN → restore MANAGEMENT_VIEWER. This tests reductions and expansions of visibility in one session. After each role commit, return focus to the application or use its normal authority Retry path if present. Confirm the displayed authoritative role changes, master scope reloads, and newly forbidden records disappear; never set a browser-only role. Repeated focus with unchanged role must not reload P6B/P6C.

Use [assignment-inactive.sql](assignment-inactive.sql) and [assignment-active.sql](assignment-active.sql) for the negative/positive Project Manager cases. Each transaction guards the exact identity, Companies, Project UUID/code, and assignment UUID/user/Company/Project, requiring one updated row. No assignment DELETE is needed. Assignment-only changes are not part of P6A's authority snapshot: after each assignment change, refresh the page (or deliberately re-enter the Company) to issue fresh Project/category reads. Do not claim focus alone refreshes assignment-dependent snapshots. Party count remains zero in both cases.

The original browser plan covered: populated/empty Alpha/Beta switching, delayed A responses released under B, role invalidation, EN/AR/RTL, query failure/recovery, unchanged-authority focus/visibility, fail-closed identity revocation and deferred financial routes. The tenant default locale does not override a stronger explicit browser/profile locale; use the language toggle to test EN/AR. No financial actions are part of this run.

## Integrity and cleanup — completed; retained runbook

[create.sql](create.sql) is a one-time guarded transaction. It rejects existing deterministic IDs/codes/slugs and any pre-existing membership/assignment for this user. No upsert or reuse occurs. It checks the 14/14 Company/settings baseline, prohibits out-of-scope Company-owned rows, and verifies global settings integrity before commit.

[verify.sql](verify.sql) is read-only. It verifies zero out-of-scope Company rows across public/private physical tables with `company_id`, including financial parents/children, accounts, treasury and subcontracts; dependent rows without Company columns cannot exist without their constrained parent. It reports all fixture counts, orphan checks, unrelated user membership/assignment checks, role values and notable mapper test values.

Expected populated counts: profile 1; Companies/memberships/settings 2 each; Alpha Projects/assignments 1 each; Alpha Parties 6; Alpha Categories 3; Beta Projects/Parties/Categories 0; financial and other out-of-scope rows 0; orphan fixture rows 0; unrelated user memberships/assignments 0. Global baseline grows from 14/14 to 16/16 Companies/settings, with zero missing/orphan settings.

The following procedure was used for the accepted run and is retained for reference:

1. Sign out the synthetic user and stop its browser activity. Restore its profile ACTIVE if the revocation test left it inactive. Run `verify.sql` and inspect counts. Investigate unexpected extra rows; never broaden cleanup predicates.
2. Run the complete [cleanup.sql](cleanup.sql) on Development. The transaction validates exact Auth UUID/email/profile and Company UUID/code/name; locks Companies; rejects financial/out-of-scope rows or unexpected fixture counts; rejects unrelated memberships/assignments; then deletes only the exact assignment, Project, six Parties, three Categories, two memberships, two settings, two Companies, and profile. Individual deletes require their exact expected row counts. Party/category/Project deletes include codes; memberships/assignment include the user; settings include slugs. No manual CASCADE or Auth deletion exists. FK failures or any mismatch roll back the whole cleanup. The user reported successful execution of this guarded cleanup; post-cleanup counts were independently rechecked at checkpoint.
3. Run `verify.sql` again. Every fixture database count must be zero; Party/category details/TRN and roles must be NULL; financial/unrelated/orphan counts zero. Expect global Company/settings counts back to 14/14 if no unrelated provisioning occurred during verification; global one-to-one integrity must always hold.
4. Only after zero-count database verification, manually delete Auth UUID `74e36291-172a-44e7-95be-f6c1283c315b` with exact email `p6c-slice2-user@example.test` in Supabase Authentication. Confirm absence by UUID and email, remove only temporary browser Auth state, preserve demo `cas:v1:*` data, and record final cleanup evidence.

No application logic, migration, RLS/grant, P5/financial behavior or other entity slice is changed by this fixture preparation. No Staging/Production action occurred. The final checkpoint authorizes one commit, with no push. Do not mark browser acceptance or P6C complete from fixture creation.

## Setup evidence — 2026-09-12

Creation completed successfully in one transaction on Development. Post-commit `verify.sql` returned the exact populated counts above, both memberships ACTIVE/MANAGEMENT_VIEWER, exact leading-zero TRN, zero orphan/unrelated/out-of-scope rows, and global 16 Companies/16 settings with zero missing/orphan settings. Preflight returned zero deterministic ID/code/slug/user conflicts and confirmed the required applied schemas/policies. Earlier in this same session all 27 canonical migrations aligned through `20260911123000` and linked dry-run was a no-op; no migration was added or applied by setup.

The first explicit-project CLI invocation rejected its flags before execution; the corrected invocation supplied both `--linked` and `--project-ref eqnzueginpkskbnqvgoc`. The guarded creation transaction ran once successfully. At initial setup, role-switch SQL, assignment-toggle SQL and cleanup SQL had not yet been executed; subsequent manual acceptance and cleanup supersede that setup status. Source review, fixture-artifact credential/DDL/manual-CASCADE scan and `git diff --check` passed. Application build/lint were not repeated because this turn changed only operational fixture documentation/scripts and authorized Development synthetic data.

Business/accounting: VERIFIED no financial rows. Database: VERIFIED fixture/integrity checks. Security: VERIFIED applied policy inspection and guarded operator scope; browser role/revalidation evidence DEFERRED. Deployment: NOT APPLICABLE beyond the authorized Development fixture. Testing: VERIFIED setup checks, browser acceptance DEFERRED. Documentation: VERIFIED fixture existence/cleanup instructions recorded. P6C remains incomplete.


## Final manual acceptance and cleanup

The user reported PASS for MANAGEMENT_VIEWER 6 Parties/3 Categories; PROCUREMENT 4/3 excluding OWNER/EMPLOYEE (representative of DATA_ENTRY's shared policy branch); PROJECT_MANAGER 0/3 with ACTIVE assignment and 0/0 with INACTIVE assignment; SYSTEM_ADMIN 0/0. The assignment and Alpha MANAGEMENT_VIEWER membership were restored before cleanup. Leading-zero TRN `001234567890123`, Arabic contact text, nullable fields, inactive Party/category status and NULL description passed. Alpha→Beta isolation and repeated Beta focus/visibility without secure/presentation loading or stale flash passed.

Cleanup removed all fixture database rows. The user then manually deleted the exact Auth identity. Independent final read-only checks confirmed all fixture counts zero, Auth UUID/email absent, and global 14 Companies/14 settings with zero missing/orphan settings. No fixture currently exists. The broader original browser plan is retained for reuse; do not infer unreported detailed browser checks or separate DATA_ENTRY/ACCOUNTING_ADMIN/ACCOUNTANT runs from representative acceptance.

Final status: business/accounting, accepted authorization boundaries, database, proportionate testing and documentation VERIFIED; Staging/Production deployment DEFERRED. Overall P6C remains incomplete. The unchanged trusted-role extra grants remain a future hardening item.
