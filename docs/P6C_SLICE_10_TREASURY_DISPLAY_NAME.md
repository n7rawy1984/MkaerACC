# P6C Slice 10 — Treasury Display Name UPDATE

**P6C Slice 10 — Treasury Display Name UPDATE — VERIFIED COMPLETE** (2026-09-21). P6C **IN PROGRESS**; P6D/P6E **NOT STARTED**; production readiness **DEFERRED**.

## Selection and scope

Started from clean main/origin/main `d909dab79f5cdfa43c5db2f15fc5c5dd4c0cd763`. Selected existing Treasury display name as one small useful descriptive mutation: it follows Slice 9 without reopening Supplier's shared Party contract or exposing Treasury configuration. Account, Project, Company, Supplier and Category mutation contracts remain unchanged.

Only `treasury_accounts.name` UPDATE, including ACTIVE and INACTIVE rows, for ACCOUNTING_ADMIN under existing `treasury.manage`. Trim JavaScript boundary whitespace; required 1–200 Unicode characters; retain internal spacing/case. Exclude create/delete, code/type/status, Project, permanent GL mapping, bank_name/account_reference/notes, Company, actor and timestamps from browser writes. No transfer, balance/opening balance, expense, payment, liability/receivable, journal, ledger, settlement or posting behavior. Treasury name is a current master label; no historical financial truth is rewritten.

## Architecture and database

`20260921120000_p6c_treasury_display_name.sql` applied only to MakerACC-Development (`eqnzueginpkskbnqvgoc`). Preflight confirmed all 32 prior migrations aligned and the exact selected table's columns/constraints/indexes/triggers/grants/forced RLS matched canonical history. Initial dry-run listed this one migration. No material drift found. Prior documented service-role TRUNCATE/REFERENCES/TRIGGER privileges were not expanded or otherwise changed.

Authenticated table-wide INSERT/UPDATE/DELETE/TRUNCATE removed; effective UPDATE(name) only. Existing SELECT/UPDATE RLS and role semantics unchanged: Accounting Admin writes; Accountant/Management Viewer read; assigned Project Manager reads only Project-specific Treasury and cannot read hidden GL labels; remaining roles have no Treasury rows. Existing INSERT policy remains without authenticated INSERT grants.

Replace only `treasury_accounts_set_updated_at` with a table-local SECURITY INVOKER trigger using empty search_path, immutable creation provenance, DB-derived authenticated updated_by and strictly increasing update token (including no-op/future timestamps). No direct PUBLIC/anon/authenticated/service-role EXECUTE. Preserve `validate_treasury_account`, permanent Company/GL mapping and ASSET validation, trusted INSERT, constraints/indexes and shared helpers. No generated row-type change required; no columns/enums or callable browser RPC added.

Explicit repository constructs `{name}` and filters Company + ID + exact loaded updated_at. Zero rows is conflict/authority loss. No silent retry; confirmed write/failed read remains distinct from uncertain write. Independent Treasury operation state/lock and scoped session guards reject late results across Company/user/role/logout/unmount. Treasury-only refresh merges into current snapshots. Inline populated form preserves keyboard/focus restoration and EN/AR/RTL/narrow layout; all existing read-only mapping fields remain visible subject to RLS.

## Actual automated evidence

- Hosted rollback-only checks **108/108 PASS**: grants/forced RLS, allowed admin and all six denied roles, cross-tenant, inactive Company/profile/membership, all protected columns, normalization/Unicode, actor/creation provenance, trusted provisioning, future/no-op/stale tokens and unchanged Project/GL/configuration. Assigned Project Manager reads scoped Treasury while GL is hidden.
- Two overlapping exact-token updates **1/0 PASS**; Editor 1 won, correct actor and advanced token verified. Guarded concurrency cleanup removed only disposable Company/Treasury/GL/membership/settings; existing synthetic Auth identity/profile retained. No Auth user was created during automated verification.
- Treasury isolated real Chromium **PASS**: actual Auth/settings/provider/shell/form with in-memory transport, exact one-field/token payload, lower-row keyboard/focus, INACTIVE rename, selective refresh, conflict and known-commit recovery, six denied roles, open-edit downgrade, delayed tenant switch, tab return, profile revocation/logout, Arabic/RTL/390px.
- Account isolated Chromium regression **PASS**, directly affected shared list/provider/shell. P6C repository/provider behavior **PASS**, including existing Category/Supplier/Company/Project/Account behavior and independent Treasury/Project operations. Historical hosted suites were not rerun.
- Build **PASS** (existing demo bundle-size advisory). Lint **0 errors, 4 existing warnings**. P6A/P6C boundaries and behavior **PASS**. An initial new test variable-name collision was corrected before the successful behavior run; no implementation defect was found.
- Public DB lint **clean**; all **33 migrations aligned**, final linked dry-run **up to date**.
- Automated fixture cleanup/integrity **PASS**: Slice 10 Companies/Treasuries/Accounts/Projects/memberships/assignments/browser Auth 0; global Companies/settings **14/14**, missing/orphan **0/0**.
- Complete changed-file scope review, `git diff --check`, focused secret scan **PASS**. No credentials stored.

## Lifecycle classification

| Category | Classification | Evidence / remaining gate |
|---|---|---|
| Business/accounting | VERIFIED for bounded descriptive scope | No financial effect; financial command integration NOT APPLICABLE |
| Security/authorization | VERIFIED | Automated RLS/grants/isolation and user-completed authenticated acceptance passed |
| Database | VERIFIED | Canonical Development migration, focused catalog/grants, hosted/concurrency/lint/alignment |
| Deployment | VERIFIED Development boundary; DEFERRED release | No Staging/Production action; production readiness deferred |
| Testing | VERIFIED | Automated and user-completed authenticated acceptance/cleanup passed |
| Documentation | VERIFIED | Handoff, roadmap, authorization, phase and fixture documentation reflect accepted verified closure |

## Accepted authenticated browser evidence (2026-09-21)

User-completed hosted acceptance **PASS**, accepted separately from the earlier automated evidence. Closure reran no verification or hosted queries.

- ACCOUNTING_ADMIN name-only Treasury mutation, including ACTIVE/INACTIVE rename; code/type/status/GL/Project/bank/reference/notes protected.
- Stale two-tab conflict and Alpha/Beta isolation PASS.
- ACCOUNTANT and MANAGEMENT_VIEWER read-only; PROJECT_MANAGER sees assigned Project Treasury only, without Edit; assignment revoke/restore PASS. PROCUREMENT, DATA_ENTRY and SYSTEM_ADMIN see no Treasury rows.
- Downgrade while editing, membership revocation, and profile revocation/no-company PASS.
- Focus/tab return, draft preservation, keyboard, RTL and 390px viewport PASS; Account name regression PASS. Financial routes remained unwritable.
- Final guarded cleanup/verify accepted: fixture_companies=0, fixture_accounts=0, fixture_treasuries=0, fixture_projects=0, fixture_memberships=0, fixture_assignments=0, browser_auth=0, companies=14, settings=14, missing=0, orphan=0.

Only the supplied browser evidence is claimed. No financial/P6D behavior, Staging/Production action, stored credentials or Slice 11 work. One local closure commit authorized: `Complete P6C Slice 10 treasury display name`; no push. Production readiness remains DEFERRED.

## Evidence limits

[Historical fixture record](verification/p6c-slice10/README.md): browser fixture and Auth identity cleaned; SQL templates retain empty UUID placeholders and no credentials. Required GL masters and one Project/assignment supported existing visibility without financial documents. Browser authority revalidation remains focus/tab-return based; other tabs retain snapshots until refresh. No unresolved slice blocker. Frontend release and production readiness DEFERRED; Staging/Production action NOT APPLICABLE to this Development closure.

## Files

- New: `src/master/treasuryNameMutations.ts`, `TreasuryNameForm.tsx`, `TreasuryNamesPanel.tsx`; canonical migration above; `scripts/fixtures/p6c-treasury-name-interactions.tsx`, `scripts/verify-p6c-treasury-name-interactions.mjs`; this record and `docs/verification/p6c-slice10/`.
- Updated: `src/master/{AccountMasterLists.tsx,ProductionMasterDataProvider.tsx,masterTypes.ts}`, `src/app/TenantReadyApplication.tsx`, `src/i18n/{en,ar}.ts`, `scripts/verify-p6c-{boundary,behavior}.mjs`, handoff, roadmap and P4 authorization.
