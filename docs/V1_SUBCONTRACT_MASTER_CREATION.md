# V1 Subcontract master creation — 2026-10-07

Scope: close the production master-data creation gap only. Existing P6C editing and frozen financial workflows remain intact. No journal recognition or settlement occurs when a master is created.

## Implementation and authority

Forward migration `20261007120000_v1_subcontract_master_creation.sql` is applied only to MakerACC-Development (`eqnzueginpkskbnqvgoc`). All 48 local/remote migration versions align; final linked dry-run is a no-op. No Staging/Production action.

`create_subcontractor_party(uuid,jsonb)` and `create_subcontract(uuid,jsonb)` are narrow SECURITY DEFINER commands with an empty fixed search_path. EXECUTE is revoked from PUBLIC, anon and service_role and granted only to authenticated. Each derives auth.uid(), requires an ACTIVE profile/Company/membership through canonical helpers, specifically requires ACCOUNTING_ADMIN, and checks the existing party.manage/subcontract.manage permission. target_company_id selects a candidate Company; server-side membership/role checks authorize it. The browser’s active Company preference is never authority. MANAGEMENT_VIEWER, PROCUREMENT, SYSTEM_ADMIN and ACCOUNTANT cannot create through these commands. Existing Procurement Supplier/name/metadata permissions are unchanged.

Business JSON accepts only whitelisted existing fields. Caller-controlled type, provenance and tenant fields are rejected. Party creation derives SUBCONTRACTOR/ACTIVE and stamps actor/timestamps. Subcontract creation validates and locks same-Company Project and ACTIVE SUBCONTRACTOR masters, rejects CLOSED Projects, applies existing constraints and case-insensitive reference uniqueness, and stamps provenance. Existing RLS, triggers and browser DML grants are unchanged; no broad INSERT restored.

Production `/parties` adds Create subcontractor and preserves Create supplier. Production `/subcontracts` adds Create subcontract. `/subcontractors` has no production workspace and remains unchanged; the legacy demo workspace is not activated. The Party form reuses production business-field normalization with an optional form title. The new Subcontract form selects tenant-scoped repository masters and uses text/BigInt decimal conversion: exact BIGINT minor-unit strings, signed variations with nonnegative revised value, integer retention bps 0–10000, optional valid dates and existing status values. Successful commands refresh the corresponding authoritative production repository. Duplicate/constraint/denial errors have safe EN/AR feedback. Uncertain responses block resubmission until refresh and explicit record review; these master commands do not add a new idempotency table.

## Verification and lifecycle status

- Business/accounting VERIFIED: rollback-only hosted assertions prove ZERO changes to journals, journal lines, advances, certificates, payments, retention releases/payments.
- Security/authorization VERIFIED: focused 34-check Development transaction passes admin creation/provenance/readback, missing name, duplicate codes/references, protected inputs, exact >2^53 amounts, dimension requirements, inactive Subcontractor, cross-Company references, closed Project, retention bounds, revised-value constraint, overflow, numeric JSON rejection, role denials, inactive membership, missing actor, minimal grants and blocked direct INSERT. Both preflight and post-application matrices passed 34/34. Preflight ran the canonical migration inside a rollback-only transaction before application. Synthetic records existed only inside test transactions; no existing data was deleted or populated. Post-rollback fixture Company count is 0.
- Database VERIFIED: one forward canonical migration, 48-version alignment, unchanged RLS/column restrictions and existing constraints.
- Deployment VERIFIED for Development migration application only. Application deployment and hosted signed-in browser acceptance DEFERRED. Production readiness remains DEFERRED.
- Testing VERIFIED: focused repository/parser tests; real Chromium forms/Auth/master providers with in-memory transport; authoritative refresh/readback, exact RPC payload, role-hidden controls, preserved Supplier control, missing name, safe duplicate feedback, uncertain-result freeze/recovery (including a failed recovery refresh), focus return, EN/AR and 390px RTL. Build/typecheck and focused lint pass; changed-file secret scan and diff whitespace check pass. Browser test is isolated transport evidence, not a hosted signed-in smoke. Existing bundle-size warning is non-blocking.
- Documentation VERIFIED: this record and current handoff/roadmap entries describe the bounded change without reopening frozen financial phases.

## Files

- Migration above.
- `src/master/subcontractCreationRepository.ts`, `SubcontractCreationPanel.tsx`.
- `src/master/PartiesList.tsx`, `SubcontractsList.tsx`, `SupplierPartyForm.tsx`.
- `src/i18n/en.ts`, `ar.ts`.
- `scripts/verify-subcontract-master-creation.mjs`, `verify-subcontract-master-creation-browser.mjs`.
- `scripts/fixtures/subcontract-master-creation.tsx`, `subcontract-master-creation-client.ts`.
- `scripts/sql/subcontract-master-creation/hosted-checks.sql`.
- This record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`.

No real data import, XLSX changes, persistent population records, unrelated refactor or broad historical suite. The user authorized checkpoint-only closure in exactly one local commit, `Add subcontractor and subcontract creation`; no push. Closure reconciled these records and confirmed the final diff contains only this approved master-creation checkpoint. No implementation or tests were rerun at closure; verification above records the implementation batch. Development checkpoint closed with application deployment, hosted signed-in smoke and Production readiness explicitly deferred; this is not production approval.
