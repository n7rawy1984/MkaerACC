# P6C Slice 9 — Account Display Name UPDATE

**P6C Slice 9 — Account Display Name UPDATE — VERIFIED COMPLETE** (2026-09-21). P6C remains **IN PROGRESS**; P6D/P6E **NOT STARTED**. Production readiness is **DEFERRED**.

## Recovery and approved scope

Resumed the current working tree from baseline `8403dea95780483420965b8841812d4569705f06`. Found eight tracked changes and five new paths: existing Account repository/form/panel, provider/types/list/shell wiring, EN/AR text, boundary/test harness wiring, preflight SQL and one unapplied migration. The implementation was internally consistent and preserved. No reset, reselect, redesign, duplicate migration or applied-history rewrite occurred. Recovery confirmed the 31 previously applied migrations aligned and Account catalog/RLS/grants matched the existing preflight. No unrelated dirty work or material schema/accounting/authorization drift was found.

After resume: added focused repository/provider assertions, hosted rollback and concurrency suites, isolated Chromium fixture/test, prepared manual acceptance scripts, applied the existing canonical migration to Development, completed missing verification and reconciled this record/handoff/roadmap/P4 authorization. No already-passed Slice 9 gate was rerun. Historical Slice 1–8 hosted verification was not rerun.

Existing Account `name` only, including inactive/system Accounts, for ACCOUNTING_ADMIN under existing `account.manage` RLS. Trim JavaScript boundary whitespace; require 1–200 Unicode characters, retaining internal spacing/case. No create/delete/status/code/type/hierarchy/requires_party/system_key/tenant/provenance controls or browser grants. Stable system keys, Account IDs and Treasury mappings retain their meaning. No journal, ledger, balance, opening balance, payment, expense, liability/receivable, posting or financial RPC behavior is introduced; historical financial records are untouched.

## Database and authorization

Canonical `supabase/migrations/20260917120000_p6c_account_display_name.sql` applied only to linked MakerACC-Development (`eqnzueginpkskbnqvgoc`) after a single-migration dry-run. Authenticated broad INSERT/UPDATE/DELETE/TRUNCATE privileges are removed; effective UPDATE is only `name`. Existing SELECT, forced RLS, account.manage UPDATE policy, tenant guard, constraints/indexes and trusted provisioning remain. The legacy INSERT policy stays present without an authenticated INSERT grant.

The Account-local SECURITY INVOKER trigger uses fixed empty search_path, validates creation provenance, stamps authenticated actor, normalizes name and advances updated_at strictly (including no-op/future timestamps). Direct EXECUTE is revoked from PUBLIC/anon/authenticated/service_role; PostgreSQL invokes it through the trigger. No new SECURITY DEFINER function, RPC or permission. Trusted INSERT timestamps/defaults are unchanged. Prior service-role privileges are preserved, not expanded. No generated row type change is needed: no columns/enums changed and no callable browser function was added.

Repository payload is constructed as `{name}` only and filters active Company + Account ID + exact unparsed loaded updated_at. Zero rows means conflict/authority loss. Unknown outcomes require refresh/review; no silent retries. Confirmed write plus failed read retains distinct saved-but-refresh-failed feedback. Account-only refresh merges into current snapshots with independent operation state/lock. Tenant/user/role/session/logout/unmount guards prevent delayed results entering another scope. UI uses existing Account display rows with inline populated form, focus restoration, localized feedback and EN/AR/RTL support.

## Actual verification

| Gate | Result |
|---|---|
| Focused hosted SQL | 99/99 PASS; rollback-only suite, no durable fixtures |
| Two-writer concurrency | PASS, 1/0 affected rows; winner Editor 1, correct actor and advanced token |
| Account isolated Chromium | PASS; actual providers/shell/form, in-memory transport |
| Repository/provider and existing master regressions | PASS via P6C suite, including independent Account/Project operations |
| Project/Company/Supplier isolated Chromium | PASS; directly affected shared provider/shell regressions |
| Build | PASS |
| Lint | 0 errors, 4 existing warnings |
| P6A/P6C boundaries and behavior | PASS |
| Public DB lint | No schema errors |
| Migration alignment | All 32 local/Development migrations aligned |
| Final linked dry-run | Remote up to date, no pending migrations |
| Guarded automated cleanup/global integrity | PASS; fixture counts 0, Companies/settings 14/14, missing/orphan 0/0 |
| Complete scope review, diff check and focused secret scan | PASS; only Slice 9 files, no credentials stored |
| Authenticated hosted browser acceptance | PASS (user-completed); exact guarded cleanup and final 14/14 integrity accepted |

The first concurrent Company/Supplier Chromium launches timed out on initial local page navigation, before assertions. Each failed check was retried serially; no production implementation change was required. Slice 9 Chromium and Project Chromium passed on their first runs. This is a test-run limitation, not hosted browser acceptance.

## Lifecycle classification

| Category | Classification | Evidence / remaining work |
|---|---|---|
| Business/accounting | VERIFIED for bounded metadata scope | Name only; no financial behavior; financial cutover NOT APPLICABLE to this slice |
| Security/authorization | VERIFIED | Automated actor/grants/RLS/isolation tests and user-completed authenticated acceptance passed |
| Database | VERIFIED | Canonical Development migration, focused catalog/grant review, SQL/concurrency/lint/alignment |
| Deployment | VERIFIED Development boundary; DEFERRED release | No Staging/Production action; no credentials persisted; production readiness not claimed |
| Testing | VERIFIED | Automated evidence and user-completed authenticated acceptance/cleanup passed |
| Documentation | VERIFIED | Handoff, roadmap, P4 authorization and phase documentation reflect accepted verified closure |

[Historical acceptance procedure and fixture manifest](verification/p6c-slice9/README.md): browser fixture and Auth identity have been cleaned. SQL templates retain empty UUID placeholders and no credentials. The automated concurrency fixture was previously removed while retaining its existing synthetic actor/profile. Account names remain mutable current master labels; other tabs retain snapshots until refresh, with browser authority revalidation on focus/tab return. No known unresolved slice blocker. Staging/Production action is NOT APPLICABLE to this Development closure; frontend release and production readiness remain DEFERRED.

## Accepted authenticated browser evidence (2026-09-21)

User-completed hosted acceptance PASS; these are accepted user results, distinct from the earlier automated SQL and isolated Chromium evidence. Closure reran no verification or hosted queries.

- ACCOUNTING_ADMIN: Alpha Accounts visible; ACTIVE/INACTIVE name edits; surrounding whitespace normalized; leading-zero codes preserved; code/type/status/hierarchy/system key protected; blank/oversized names rejected.
- Two tabs opened the same Account before the first save: first save succeeded; stale second save reported “This account changed or is no longer available. Refresh and review before trying again.” No overwrite or silent retry.
- Beta mutation worked independently; no stale Alpha/Beta data leakage.
- ACCOUNTANT and MANAGEMENT_VIEWER read only with no Edit; PROJECT_MANAGER, PROCUREMENT, DATA_ENTRY and SYSTEM_ADMIN saw no Account rows; ACCOUNTING_ADMIN restored successfully.
- Downgrade with edit open removed the form. Membership revocation removed Alpha/fail-closed, then restore succeeded. Profile revocation reached `/no-company` with no stale Alpha/Beta data, then restore succeeded.
- Focus/tab return, draft preservation, keyboard interaction, cancel/focus restoration, Arabic/RTL and narrow 390px viewport PASS. Treasury remained read-only; no financial route became writable.
- Exact guarded cleanup completed. Final accepted verification: fixture_companies=0, fixture_accounts=0, fixture_memberships=0, fixture_assignments=0, browser_auth=0, companies=14, settings=14, missing=0, orphan=0.

No additional manual cases or measurements are claimed. No financial/P6D behavior, Staging/Production action, credentials stored or Slice 10 work. One local closure commit authorized: `Complete P6C Slice 9 account display name`; no push. Production readiness remains DEFERRED.

## Changed files

- Existing: `src/master/{AccountMasterLists.tsx,ProductionMasterDataProvider.tsx,masterTypes.ts}`, `src/app/TenantReadyApplication.tsx`, `src/i18n/{en,ar}.ts`, `scripts/verify-p6c-{boundary,behavior}.mjs`.
- New: `src/master/{accountNameMutations.ts,AccountNameForm.tsx,AccountNamesPanel.tsx}`, the canonical migration above, `scripts/fixtures/p6c-account-name-interactions.tsx`, `scripts/verify-p6c-account-name-interactions.mjs`.
- Documentation: this phase record, `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`, `docs/P4_AUTHORIZATION.md`, and `docs/verification/p6c-slice9/` (preflight, hosted/concurrency SQL, manual setup/role/authority/cleanup/verify, README).
