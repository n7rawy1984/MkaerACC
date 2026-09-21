# P6C Slice 9 — Account Display Name UPDATE

Status: **P6C Slice 9 — Account Display Name UPDATE — VERIFIED COMPLETE** (2026-09-21). P6C IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED. User-completed authenticated acceptance and guarded fixture/Auth cleanup PASS. No credentials stored.

## Automated evidence (2026-09-20)

- Canonical `20260917120000_p6c_account_display_name.sql` applied to MakerACC-Development only after alignment/preflight and single-migration dry-run.
- `hosted-checks.sql`: **99/99 PASS**, transaction rolled back. Exact Account grants, forced RLS, unchanged account.manage authorization, all six denied roles, cross-tenant isolation, revoked profile/membership/Company, name normalization/Unicode bounds, provenance, protected configuration, trusted provisioning and stale/no-op token checks.
- `concurrency-setup.sql`, simultaneous `concurrency-edit-1.sql` / `concurrency-edit-2.sql`: **1/0 affected rows**. `concurrency-verify.sql` checks winning name, actor and token; `concurrency-cleanup.sql` removes the exact fixture and preserves the existing synthetic actor.
- `npm run verify:p6c-boundary`: PASS including repository/provider behavior for Slice 9 and Category/Supplier/Company/Project regressions, existing Account/Treasury read mappings/rendering and independent Account/Project state.
- `node scripts/verify-p6c-account-name-interactions.mjs`: isolated real Chromium PASS. Actual Auth/settings/master providers and shell with in-memory transport; no Supabase connection or credentials. Covers lower-row keyboard focus, exact name-only payload/token, inactive/system Account, Account-only refresh, conflict and known-commit refresh recovery, six denied roles, downgrade, delayed tenant switch, focus/tab return, profile revocation/logout and Arabic/RTL/narrow viewport.
- Directly affected Project/Company/Supplier isolated Chromium regressions PASS. Build and P6A boundary PASS; lint 0 errors, 4 existing warnings.
- Public DB lint: no errors. Final migration alignment, no-op dry-run, cleanup/integrity and diff/secret review are recorded in the phase document.

Earlier automated evidence is retained without rerunning checks. User-completed authenticated acceptance is recorded separately below. Historical hosted Slice 1–8 suites were not rerun.

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

## Historical fixture reference — cleaned

The fixture used only MakerACC-Development (`eqnzueginpkskbnqvgoc`) and disposable email `p6c-s9-browser@example.test`. Setup/role/authority/cleanup templates retain empty UUID placeholders; no password/token or actual browser Auth UUID is stored. The fixture is no longer live. These files are retained for traceability, not a request to recreate it.

| Resource | Deterministic ID | Meaning |
|---|---|---|
| Alpha Company | `79200000-0000-4000-8000-0000000000a1` | `P6C-S9-BROWSER-A`, slug `p6c-s9-browser-a` |
| Beta Company | `79200000-0000-4000-8000-0000000000a2` | `P6C-S9-BROWSER-B`, slug `p6c-s9-browser-b` |
| Alpha A1 | `79200000-0000-4000-8000-0000000000b1` | ACTIVE parent, code `0001` |
| Alpha A2 | `79200000-0000-4000-8000-0000000000b2` | INACTIVE child of A1, code `0002`, stable key `INPUT_VAT` |
| Beta B1 | `79200000-0000-4000-8000-0000000000b3` | ACTIVE, code `0003` |

Settings and memberships use Company keys (one per Company/actor); no Project assignment, Treasury, journal or financial fixture is needed. All three Accounts are ASSET and require no Party. Names may change; IDs/code/type/hierarchy/system key/status must not.

## Evidence limits

Authority checks occur in PostgreSQL on every write; browser authority revalidation occurs on focus/tab return. Other tabs retain loaded snapshots until refresh. A lost response is uncertain and requires refresh/review, never automatic resubmission. Isolated Chromium used fake transport; real authenticated hosted browser acceptance has separately passed according to the user. Staging, Production, release/operations gates and all financial cutover remain deferred.
