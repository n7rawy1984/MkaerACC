# P6C Slice 5 verification — Development only

**P6C Slice 5 — Expense Categories MUTATION — VERIFIED COMPLETE.** Overall **P6C — IN PROGRESS**. Browser acceptance and disposable fixture/Auth cleanup are complete. This closure record supersedes all earlier live-fixture, prepared-only, pending-acceptance and deferred-cleanup notes, including the historical execution comment in `browser-setup.sql`. Current global Company/settings counts are **14/14**.

Target: verified linked **MakerACC-Development**, ref `eqnzueginpkskbnqvgoc`. Staging/Production were not touched. No P6D or financial mutation path was introduced.

## Final accepted browser evidence — 2026-09-13

The user completed and accepted authenticated manual acceptance:

- ACCOUNTING_ADMIN list/create/edit/deactivate/reactivate: PASS.
- Normalized duplicate-code rejection: PASS.
- Optimistic concurrency stale-edit conflict: PASS.
- Beta tenant / MANAGEMENT_VIEWER read-only behavior: PASS.
- Alpha role downgrade to MANAGEMENT_VIEWER observed after revalidation; mutation controls disappeared: PASS.
- Tab-away/tab-return regression: PASS, without blocking “Loading securely” or stale tenant flash.
- Arabic/RTL: PASS.

Cross-tab locale persistence is a **non-blocking UX observation**: one tab retained English until refresh, then converged to Arabic. No Slice 5 fix is required or introduced.

## Final Development cleanup

The disposable database fixture was fully removed. Auth user `e6cac418-6739-4b66-a1ab-f7cd98bf89fc` was deleted through Supabase Authentication. Final accepted cleanup counts:

- `auth_user=0`, `profile=0`, `fixture_companies=0`, `memberships=0`.
- `global_companies=14`, `global_settings=14`.
- No missing/orphan Company settings.
- All inspected financial/out-of-scope fixture tables were zero before cleanup.

## Final accepted local and migration checks

These are the user's final accepted results, recorded during documentation closure without rerunning build/lint/database verification:

- `npm run build`: PASS; only the existing Vite >500 kB demo chunk advisory.
- `npm run lint`: PASS; 0 errors, 4 pre-existing Fast Refresh warnings.
- P6A boundary, P6C boundary, P6C behavior: PASS.
- `git diff --check`: PASS.
- All 28 local/remote migration versions aligned, including `20260913120000`.
- Linked `db push --dry-run`: Remote database is up to date.
- Focused real-secret scan: PASS.

## Executed database verification

- `hosted-checks.sql`: 70 assertions passed in one rolled-back transaction. Actual `authenticated`, `anon`, and `service_role` execution roles are exercised with synthetic identity claims. This proves database boundaries; it is not a password-login/browser or captured PostgREST acceptance run.
- `concurrency-setup.sql`: created only the disposable `75100000-...` Company, non-login Auth/profile identity, membership and edit category. It was never intended for browser acceptance.
- `concurrency-create-1.sql` and `concurrency-create-2.sql`: submitted concurrently; one insert succeeded and one received SQLSTATE 23505. One normalized category persisted.
- `concurrency-edit-1.sql` and `concurrency-edit-2.sql`: submitted concurrently from the same timestamp; returned `affected_rows=1` and `affected_rows=0`. An earlier run returned only the final sleep result, so the disposable edit row was recreated and the final scripts captured the exact counts. No migration or production data was reset.
- `concurrency-verify-cleanup.sql`: verified the two expected categories and exact identity, then removed only the disposable concurrency rows. This is not browser fixture cleanup.
- `verify.sql`: read-only effective privileges, triggers, unchanged shared timestamp function, defaults, policies, fixture absence and global settings integrity. CLI exposes the last result set; use individual SELECTs when inspecting earlier catalog result sets.

Run a reviewed script with the project-local CLI:

```sh
node_modules/.bin/supabase db query --linked --project-ref eqnzueginpkskbnqvgoc --file docs/verification/p6c-slice5/hosted-checks.sql
```

The canonical schema change is solely `supabase/migrations/20260913120000_p6c_category_mutations.sql`, applied through `db push`, never these fixture scripts.

## Archived browser fixture and script use

`browser-setup.sql` was rollback-validated, then executed once for the confirmed disposable identity `p6c-slice5-user@example.test`. Alpha (`75200000-0000-4000-8000-0000000000a1`) initially had ACCOUNTING_ADMIN; Beta (`75200000-0000-4000-8000-0000000000a2`) had MANAGEMENT_VIEWER. Alpha contained one Project/assignment and two initial categories; Beta had no categories. Acceptance ran at `http://127.0.0.1:5173/expense-categories` in process-configured `supabase-auth` mode. The password was never stored in repository files. This fixture no longer exists.

Scripts in this directory are retained operational evidence, not canonical migrations or instructions to recreate fixtures. Never execute the directory as a batch. The empty browser UUID setting intentionally fails closed. Any future reuse requires separately authorized Development identity, migration, collision and cleanup checks.

Browser PASS claims are limited to the accepted cases above. SQL-role simulations and controlled automated tests remain distinct evidence; unreported exploratory browser cases are not claimed as separately executed.
