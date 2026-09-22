# P6C Slice 12 — EMPLOYEE Party Display Name UPDATE

**VERIFIED COMPLETE.** P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. Development only (`eqnzueginpkskbnqvgoc`). Authenticated browser acceptance, exact guarded cleanup and final integrity verification PASS. No Staging/Production action or Slice 13.

## Scope and decision

Started from clean HEAD/origin/main `0ecd34bb86715a384a59ee264ed23ad21687e6e5`; Slices 1–11 VERIFIED COMPLETE. The smallest useful remaining P6C Party operation selected is the **existing EMPLOYEE display name** on ACTIVE and INACTIVE rows. Only ACCOUNTING_ADMIN under unchanged `party.manage` may edit. The name is required, trimmed at its boundaries, at most 200 Unicode characters; internal spaces/case remain. Employee creation/deletion, type/status/code/TRN/contact/notes/Company/provenance/configuration and all other Party types are outside this operation. Payroll/WPS, GL, Project, journal, balances, financial documents, settlements and P6D are unchanged. Name is descriptive and does not establish payroll or accounting policy.

## Database and security

Exact Development Parties catalog matched canonical preflight before implementation: forced RLS, unchanged P4 permissive permission/role and sensitive SELECT policies, the existing Supplier/OTHER restrictive UPDATE policy, expected exact column grants, triggers/constraints/indexes; global Companies/settings 14/14 and missing/orphan 0/0. Forward-only `20260922120000_p6c_employee_party_name.sql` passed a linked one-migration dry-run and was applied only to Development. The restrictive UPDATE policy now allows Supplier, OTHER or EMPLOYEE; unchanged P4 policies limit EMPLOYEE UPDATE to ACCOUNTING_ADMIN with `party.manage`. Supplier-only INSERT, exact column grants and other Party permissions are unchanged.

The new fixed-empty-search-path SECURITY INVOKER trigger runs after existing Supplier preparation and before OTHER preparation. On authenticated EMPLOYEE updates it rejects every changed field except `name` and the earlier stamped `updated_at`, requires `auth.uid()`, trims Unicode boundary whitespace, derives `updated_by` from the actor, and advances `updated_at` monotonically. It also advances trusted EMPLOYEE tokens without narrowing trusted metadata/provisioning. No direct trigger EXECUTE, browser RPC, broad table UPDATE/INSERT/DELETE/TRUNCATE grant, schema rewrite or financial mutation was introduced. Hosted tests exercise direct authenticated attempts against protected fields and types, revocation and tenant isolation; no confirmed defect remains.

## Frontend

The explicit writer sends `{name}` only, filtered by active Company, EMPLOYEE type, ID and exact loaded `updated_at`. Zero rows is a conflict/authority loss; no silent retry. The scoped provider checks user/session before and after mutation and Party-only refresh, discards late responses across Company/user/role/logout/unmount, and distinguishes failed write from saved write/failed refresh. EMPLOYEE, OTHER and Supplier writes/refreshes serialize on their shared Parties snapshot. The inline row editor is ACCOUNTING_ADMIN-only, populated and keyboard accessible; close/save/error feedback restores or moves focus. EN/AR/RTL and 390px long-name wrapping were exercised in isolated Chromium.

## Automated evidence and limits

- Development hosted rollback suite **115/115 PASS**: exact grants, forced RLS, invoker/fixed path/no direct EXECUTE, admin ACTIVE/INACTIVE writes, all six denied roles, cross-tenant denial, protected columns/types, normalization/Unicode bounds, actor/provenance, exact/future/trusted monotonic tokens, revocation and Supplier/OTHER continuity. It rolled back and left no durable fixture.
- Two concurrently launched exact-token updates returned **1/0**. Winner `updated_by` and advanced token verified; guarded disposable Company/Party/membership/settings fixture removed. No Auth identity created.
- Focused repository/provider checks **PASS**: one-field payload, exact token/type/tenant filter, invalid/zero/malformed responses, allowed/denied roles, duplicate guard, late write/read isolation across scope/session/unmount, Party-only refresh, error recovery and serialization against Supplier/OTHER.
- Real isolated Chromium **PASS**: actual providers/shell/form with in-memory transport and external requests blocked; inactive row edit, exact payload/token, conflict, recovery, role/tenant/revocation, focus/keyboard/draft, Arabic/RTL. Separate 390px EN/AR test passed full 200-character unbroken ASCII/Arabic wrapping without document/body overflow. This is **not** authenticated hosted browser acceptance.
- Directly affected Supplier and OTHER Party isolated Chromium regressions **PASS** after changing the shared Parties list; no hosted browser fixture was touched.
- Build PASS; lint 0 errors/4 existing warnings; P6A/P6C boundaries/affected master behavior PASS; `git diff --check` and focused secret scan PASS. Development migration history aligned at 36, final linked dry-run no-op, public DB lint clean. Final disposable fixture/browser Auth/profile counts 0; global Companies/settings 14/14, missing/orphan 0/0.

Authenticated browser acceptance is COMPLETE using the prepared `verification/p6c-slice12/` kit. Real Development Auth acceptance covered ACCOUNTING_ADMIN ACTIVE/INACTIVE EMPLOYEE name mutation; required/trim/Unicode 200-character boundary and 201-character rejection; protected-field/type boundaries; controlled two-tab stale conflict with zero-row rejection and no overwrite/silent retry; Alpha/Beta isolation; ACCOUNTANT and MANAGEMENT_VIEWER read-only behavior; PROCUREMENT and DATA_ENTRY EMPLOYEE exclusion; PROJECT_MANAGER and SYSTEM_ADMIN no-Party behavior; open-edit downgrade and genuine tab-return authority revalidation; membership, Company and profile revocation/restoration; draft preservation, keyboard/focus/error focus; EN/AR/RTL 390px long-name wrapping without visible horizontal overflow; existing Supplier/OTHER controls and OWNER/CUSTODIAN/SUBCONTRACTOR protection; and unchanged financial/P6D holding boundaries. One earlier stale attempt was timing-sensitive; the controlled stale reproduction was then repeated successfully and rejected as designed. Exact guarded cleanup completed after sign-out. Final verification returned all Slice 12 fixture Companies/Parties/memberships/settings/assignments and browser Auth/profile counts 0, global Companies/settings 14/14, missing/orphan 0/0. No credentials are stored.

## Lifecycle gates

| Category | State |
|---|---|
| Business/accounting | VERIFIED descriptive-only scope; payroll/financial work NOT APPLICABLE |
| Security/authorization | VERIFIED | Automated Development boundary plus authenticated browser role/tenant/revocation acceptance PASS |
| Database | VERIFIED Development migration, hosted invariants/concurrency, alignment/lint/dry-run |
| Deployment | VERIFIED Development-only action; Staging/Production and readiness DEFERRED |
| Testing | VERIFIED | Focused automated gates plus authenticated browser acceptance and guarded cleanup PASS |
| Documentation | VERIFIED | Implementation, accepted browser evidence, cleanup and final integrity recorded |

Final Slice 12 state is **VERIFIED COMPLETE**. Authenticated browser acceptance, guarded cleanup and final Development integrity PASS. One local closure commit is authorized; pushing remains the operator action. P6C remains IN PROGRESS; P6D/P6E remain NOT STARTED; production readiness remains DEFERRED.
