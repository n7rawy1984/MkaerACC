# V1 Employee/Custodian roles and Project creation — Development implementation complete

2026-10-07. Code/workflow only. No real Company, identity, Project or accounting data created; no administrator bootstrap or import. Implementation verification preceded the authorized local commit closure below.

## Model and compatibility

Preserve `parties.type`. Add `party_person_roles(company_id, party_id, role, created_at, created_by)` for only the **opposite** EMPLOYEE/CUSTODIAN capability on an existing person Party. Composite FK preserves Company/Party identity, enum/check limits capabilities and trigger rejects Supplier/Subcontractor/other primary types and redundant primary-role rows. Existing primary type OR explicit opposite role is the eligibility rule. No bulk backfill, primary-type rewrite, duplicated human identity or arbitrary Party RBAC.

New dual-role persons have primary EMPLOYEE plus CUSTODIAN capability. Existing primary CUSTODIAN can gain EMPLOYEE on the same ID. Primary types remain valid without extra rows. Capabilities are additive and immutable; no browser removal/reactivation API is included. Lacking the respective capability fails eligibility; removing roles around historical Payroll/Custody would need separately approved lifecycle/dependency rules and must not trap settlement/reversal.

## Applied canonical migration and commands

`20261007140000_v1_party_person_roles_project_creation.sql` was applied only to **MakerACC-Development** after a successful canonical-DDL/fixture rollback rehearsal and a linked dry-run proposing only this file. All 49 canonical versions align; final linked dry-run is a no-op. Schema application is durable; all verification fixture data rolled back. Staging/Production untouched.

- RLS-protected role table: authenticated SELECT through actual Party visibility; no browser INSERT/UPDATE/DELETE grants.
- Private fixed-search-path eligibility helper; its policy EXECUTE grant does not expose the private schema through browser RPCs.
- `create_person_party(uuid,jsonb)`: Employee-only, Custodian-only or dual; only name/code/status/notes and supported kind, using existing Party fields. Optional codes obey existing Company-wide case-insensitive uniqueness. Unicode trim matches existing creation conventions. No PayrollProfile or accounting is created automatically.
- `add_party_person_role(uuid,uuid,party_type)`: idempotent additive role assignment to an ACTIVE same-Company Employee/Custodian, attributed to authenticated actor. No existing identity rewrite. Other types rejected.
- `create_project(uuid,jsonb)`: required stable code/name/status plus existing optional client_name/location/contract_number/notes. Uses existing PLANNING/ACTIVE/ON_HOLD/COMPLETED/CLOSED model; no invented inactive status, financial amount, GL account or balance.
- All three public commands use authenticated actor, ACTIVE Company/profile/membership and exact ACCOUNTING_ADMIN plus existing party.manage/project.manage. Existing Project Manager descriptive edits remain unchanged; Project Manager cannot create unrestricted Projects. Viewer/System Admin/platform status grants no creation bypass. Fixed empty search_path and authenticated-only EXECUTE; old Party/Project direct-write grants remain unchanged.
- Existing sensitive Party RLS is extended so a CUSTODIAN-primary Party with EMPLOYEE capability remains hidden from Procurement/Data Entry, matching existing Employee privacy. Supplier/Subcontractor visibility/creation/type behavior is unchanged.

## Minimal consumer changes implemented

Only eligibility predicates change in seven current deployed function definitions: Payroll profile guard and profile employee selector; Custody advance, settlement, cash-return and Expense wrapper validation; private Expense funding-party validation for CUSTODIAN only. Current authoritative function definitions are copied into the forward migration to preserve all other authorization, hashing/idempotency, locking, lifecycle, calculations, recognition, journals and reversal behavior. Existing function grants are retained. OWNER/SUPPLIER_CREDIT/TREASURY and Supplier/Subcontractor type behavior remains unchanged. No financial command was successfully posted during verification.

Production master repository now reads additional capabilities Company-scoped and fails closed if their read fails. Lists show the dual role without duplicating identity; name edits continue through the existing primary-type control. Legacy localStorage/demo financial screens remain unchanged; this adds no production Custody posting UI.

Creation panel on production Parties provides Employee/Custodian/dual creation and opposite-role assignment; production Projects provides creation. Existing PayrollProfile master editor remains the profile workflow after identity creation; payroll_id, payroll_type, profession, work_station, exact minor-unit salary, descriptive payment_type, status and optional Project remain its existing fields. No operating-group/visa/loan/proration fields added. EN/AR labels, narrow/RTL form layout, save locking, server error classification, refresh/readback, uncertain-result recovery and focus restoration follow existing master patterns.

## Approved Attendance compatibility completion

The user explicitly approved the three role-only Attendance adaptations in this same checkpoint. `private.validate_employee_site_assignment`, `public.save_employee_site_assignment`, and `public.attendance_context` each replace exactly one `type='EMPLOYEE'` predicate with the shared Company-scoped capability helper. Existing primary EMPLOYEE OR additional EMPLOYEE eligibility is used consistently for a CUSTODIAN-primary identity. No other Attendance statement changes: Project/site assignment identity/effective dates/overlap, Foreman scope, absence logic, correction restrictions, review/revision/locking and Payroll's reviewed-Attendance dependency remain intact.

## Verification completed

- Development canonical-DDL rehearsal + rollback-only fixture matrix: **66 checks PASS before and after apply**. Primary Employee/Custodian compatibility; one identity in both roles; missing capability fails; Custodian-primary Employee PayrollProfile and selector work; role assignment replay; Company isolation, duplicate code, unsupported roles/provenance, direct role INSERT denial and all non-admin role denials; dual-role Employee privacy; Supplier/Subcontractor visibility unchanged.
- Actual Custody command validation checks: Employee-only rejected for lacking Custodian; existing Custodian and dual person pass identity validation and stop at a deliberately nonexistent Project before accounting. No advance, journal or financial request is committed.
- Counts unchanged for journals, Expenses, Custody Advances, Payroll postings and Salary Payments. All synthetic Companies/persons/Projects/profiles/role assignments, Attendance exceptions/reviews/locks and Payroll drafts rolled back; pre-apply rehearsal schema rolled back. The approved canonical schema then applied separately. No actual business records or real tenant created.
- Isolated local browser PASS: actual forms/providers, exact creation/assignment RPCs, authoritative capability readback, one identity retained, role denials, EN/AR and 390px RTL/no page errors. Runtime is in-memory with remote requests blocked; hosted signed-in UI is not performed.
- Type checking, build and focused touched-file lint PASS; existing bundle-size warning is informational. Tracked-file `git diff --check` passed before staging; closure staged-file check identifies one trailing blank line at EOF in the applied migration, preserved unchanged under forward-only migration discipline. Function before/after review confirms only seven Payroll/Custody and three Attendance role eligibility substitutions; no recognition/formula edits. Eleven existing Attendance/Payroll business-function definitions and EXECUTE grants, plus Foreman permissions, have identical pre/post-apply fingerprints.

- Additional Attendance runtime checks PASS: primary Employee and CUSTODIAN+EMPLOYEE assignment/selection, Custodian-only exclusion, overlap rejection, assigned Foreman roster (three eligible identities) with no Company-wide Employee selector, unassigned Project/foreign Company/assignment/review denials, unreviewed Attendance blocks Payroll, reviewed Attendance consumed correctly with identical exact absence deductions for primary/capability employees, locked-month correction/review rejection and lock visibility.
- Post-apply Company, Party, Project, membership and journal checksums are identical to pre-apply; Custody Advance/Payroll posting/Salary Payment counts unchanged. Capability table retains zero rows after rollback. Forced RLS verified; no authenticated role-table write privileges or private-schema access. Three new public RPCs are fixed-empty-search-path SECURITY DEFINER with authenticated-only EXECUTE (no anon/service_role execution).

## Readiness and lifecycle

Business/model: VERIFIED compatibility and zero-accounting boundary. Security: VERIFIED focused role/tenant/visibility/scope/grant checks; full production audit DEFERRED. Database: VERIFIED 66-check pre/post-apply rollback evidence, 49 canonical versions aligned and no-op linked dry-run. Deployment: Development schema VERIFIED applied; application deployment/hosted signed-in acceptance DEFERRED. Migration precedes application because capability reads fail closed on older schema. Testing: VERIFIED scoped SQL/source/browser/type/build/lint evidence; no unrelated tests rerun. Documentation: VERIFIED this completed implementation record and current handoff/roadmap. Ready for controlled Development master provisioning after operator/real-Company prerequisites; not a production readiness declaration.

Real onboarding also requires approved operator bootstrap, a distinct real Company and supplied real master values; none is performed here. No Categories, Treasury, opening balances, real employees/custodians/Projects, accounting postings or Attendance business-rule changes.

## Authorized checkpoint closure

Closure reconciles the documentation with the final applied Development state and reviews the exact approved 16-file diff. Migration `20261007140000` is applied to MakerACC-Development only; the recorded 49-version alignment and no-op dry-run remain the verification evidence. No new implementation, hosted actions or broad test reruns occur during closure. Delivery is one local commit, `Add employee custodian roles and project creation`, with no push. Categories and Treasury remain outside this checkpoint.
