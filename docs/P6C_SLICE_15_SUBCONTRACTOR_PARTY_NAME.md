# P6C Slice 15 — SUBCONTRACTOR Party Display Name UPDATE

**VERIFIED COMPLETE.** P6C IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. Development only (`eqnzueginpkskbnqvgoc`). Authenticated browser acceptance, guarded cleanup and final integrity verification PASS. No Staging/Production action or Slice 16.

## Baseline and decision

Started from clean `main`/`origin/main` `a871f12ba4ebfc9a8e38c7e539361c1e235445ce`, with Slices 1–14 VERIFIED COMPLETE. All 38 pre-Slice-15 migrations aligned. The Development Parties catalog matched the canonical 16-column, forced-RLS surface, grants, policies, triggers, constraints and indexes; Companies/settings were 14/14 with missing/orphan 0/0.

P4 `party.manage` and Party UPDATE authorize **ACCOUNTING_ADMIN and PROCUREMENT** for SUBCONTRACTOR. ACCOUNTANT, MANAGEMENT_VIEWER and DATA_ENTRY may read SUBCONTRACTOR but not update it. PROJECT_MANAGER and SYSTEM_ADMIN have no Party rows. All access still requires active profile, membership and Company and remains tenant scoped; no role mapping or browser privilege was broadened.

The historical-integrity finding is **current display identity only**. Subcontracts and subcontractor advances, certificates, payments and retention documents reference immutable subcontractor UUIDs; journal entries use source IDs and journal lines use Party IDs. The current Subcontracts list resolves a visible name from its already-scoped Parties snapshot. Updating `parties.name` therefore changes that current label but does not rewrite Subcontract economics, source IDs, posted documents or journals. The focused hosted rollback test snapshots a linked Subcontract row and financial/journal counts across rename. No financial field, command, trigger or route was changed.

## Exact implementation boundary

Existing ACTIVE and INACTIVE SUBCONTRACTOR `parties.name` only: Unicode boundary trim, 1–200 characters, case/internal-space preservation, exact loaded `updated_at` optimism, zero-row conflict/authority loss and no silent retry. Code, type, status, TRN, contact, address, notes, provenance, Company, Project and Subcontract fields stay protected. Creation/deletion, activation, bank/payment instructions, contract values/status, advances, certificates, retention, payments, postings, reversals, balances, journals and P6D/P6E are excluded.

Canonical forward migration `20260922150000_p6c_subcontractor_party_name.sql` was applied to MakerACC-Development only. The restrictive Party UPDATE policy now includes SUBCONTRACTOR beside Supplier/OTHER/EMPLOYEE/CUSTODIAN/OWNER; unchanged P4 role and permission policies remain the final authority. The fixed-empty-search-path SECURITY INVOKER trigger permits authenticated SUBCONTRACTOR name changes only, stamps `auth.uid()`, trims Unicode boundary whitespace and advances the token monotonically. Trusted provisioning retains metadata authority; no new direct trigger EXECUTE or broad browser grants were added.

The explicit browser repository sends `{name}` only with active Company, Party ID, SUBCONTRACTOR type and exact loaded token filters. Provider checks session/scope/generation before and after write and Party-only refresh, discarding late tenant/role/user/logout/unmount results. Its lock serializes with Supplier/OTHER/EMPLOYEE/CUSTODIAN/OWNER operations. The populated inline control supports validation, save/cancel, error recovery, keyboard/focus and EN/AR/RTL. Subcontracts uses the same Parties snapshot; no separate Subcontracts refresh or record mutation is needed.

## Verification and pending gate

- Hosted Development rollback suite **117/117 PASS**: grants/FORCE RLS, exact roles and active/inactive rows, all protected fields, cross-tenant/inactive authority, Unicode and 200/201 boundaries, actor/creation provenance, exact/future/trusted tokens, prior Party types, and unchanged linked Subcontract plus financial/journal counts. It leaves no durable fixture.
- Two simultaneous exact-token editors returned **1/0**; winner actor and advanced token verified. Guarded automated concurrency cleanup passed. No Auth user was created.
- Focused repository/provider behavior and isolated Chromium **PASS**: one-field payload, exact filters, errors/recovery, shared Party serialization, stale and late-result isolation, ACTIVE/INACTIVE, ADMIN/PROCUREMENT and denied roles, focus/draft/keyboard, Subcontracts current display, EN/AR/RTL at 390px and 200-character unbroken wrapping. Isolated Chromium uses in-memory transport; it is not authenticated hosted browser acceptance.
- Supplier, OTHER, EMPLOYEE, CUSTODIAN and OWNER isolated Chromium regressions PASS; the read-only Subcontracts current-name dependency PASS. Build PASS; lint has 0 errors and the four established Fast Refresh warnings; P6A/P6C boundaries and affected behavior PASS. All **39** migrations align, final linked dry-run is no-op, and public DB lint is clean. Focused changed-file secret scan and `git diff --check` PASS. Final automated/browser fixture Companies/Parties/Projects/Subcontracts/memberships/settings/assignments and browser Auth/profile counts are **0**; global Companies/settings **14/14**, missing/orphan **0/0**. Financial/P6D routes remain outside the production master mutation graph and unwritable holding states.

The [manual authenticated browser kit](verification/p6c-slice15/README.md) was executed against Development. Authenticated acceptance PASS covered ACCOUNTING_ADMIN and PROCUREMENT ACTIVE/INACTIVE SUBCONTRACTOR name updates, validation/Unicode/200-vs-201 boundaries, controlled stale conflict with no overwrite or silent retry, Alpha/Beta isolation, the documented role matrix, open-form downgrade, Company/membership/profile revocation and restoration, draft/focus/keyboard behavior, EN/AR/RTL 390px wrapping and prior Party regressions. The read-only Subcontract resolved the renamed current SUBCONTRACTOR through its Party ID while contract number, scope, values, retention and status remained unchanged. Cleanup initially exposed a verification-kit-only defect: browser setup created the minimal Project with schema-default status PLANNING while cleanup expected ACTIVE. The failed cleanup transaction rolled back; the repository guard was corrected to PLANNING, exact cleanup then PASSed, and final verification returned all Slice 15 fixture Companies/Parties/Projects/Subcontracts/memberships/settings/assignments and browser Auth/profile counts 0, with global Companies/settings 14/14 and missing/orphan 0/0.

| Lifecycle category | State |
|---|---|
| Business/accounting | VERIFIED descriptive-only boundary and historical source-ID integrity; financial behavior NOT APPLICABLE |
| Security/authorization | VERIFIED focused Development role/RLS and tenant checks; hosted authenticated browser gate DEFERRED |
| Database | VERIFIED canonical Development migration, hosted tests/concurrency, 39 aligned migrations and final integrity |
| Deployment | VERIFIED Development-only action; Staging/Production DEFERRED |
| Testing | VERIFIED focused automated checks; authenticated browser acceptance DEFERRED |
| Documentation | VERIFIED implementation and prepared kit; acceptance evidence PENDING |

Final Slice 15 state: **VERIFIED COMPLETE**. P6C remains IN PROGRESS; P6D/P6E NOT STARTED; Production readiness DEFERRED. One closure commit is authorized; no Staging/Production or Slice 16.
