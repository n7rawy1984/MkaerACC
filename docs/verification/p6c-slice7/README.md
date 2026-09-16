# Slice 7 verification — Development only

Status: **P6C Slice 7 — Company Profile Metadata UPDATE — VERIFIED COMPLETE.** Authenticated hosted browser acceptance and final fixture cleanup were completed by the user and accepted at closure. P6C remains IN PROGRESS; P6D/P6E remain NOT STARTED. See [phase record](../../P6C_SLICE_7_COMPANY_PROFILE_METADATA.md) for recovery manifest, contract, environment boundary and actual evidence.

## Executed evidence

- `preflight.sql`: read-only live catalog review; original 29-version baseline and forced RLS/Company config policy matched; Companies/settings 14/14, no missing/orphans.
- Existing migration `20260916120000_p6c_company_profile_metadata.sql`: single-item linked dry-run, then canonical Development application. Never reapply via SQL Editor or edit it now.
- `hosted-checks.sql`: **96/96 PASS**, all fixtures/helpers rolled back.
- `concurrency-setup.sql`: created exact non-login fixture. `concurrency-edit-1.sql` and `concurrency-edit-2.sql` ran concurrently, producing **1/0** affected rows from identical exact microsecond tokens. Winner/actor/token verified.
- `concurrency-cleanup.sql`: exact guarded cleanup executed. `verify.sql`: fixture Companies/Auth/profiles/memberships zero; global **14/14**, missing/orphan **0/0**.
- Existing Slice 6 and Slice 5 hosted rollback suites: **104/104** and **70/70 PASS**.
- Company and Supplier real Chromium scripts: **PASS with isolated transport**, no hosted Auth credentials.
- Final P6A/P6C boundaries (including behavior), `git diff --check`, and focused real-secret scan across all 30 changed/new files: PASS.
- Final migration alignment: all 30 local/remote versions match; linked dry-run: **Remote database is up to date**, no migrations/seeds/roles.
- Repository/provider behavior PASS. Public DB lint PASS (no schema errors). Build PASS with existing demo chunk advisory. Lint PASS (4 existing warnings, 0 errors).

Local commands (Playwright 1.62.1 is already pinned as a dev dependency; matching Chromium is required):

```sh
npm run build
npm run lint
npm run verify:p6a-boundary
npm run verify:p6c-boundary
node scripts/verify-p6c-company-profile-interactions.mjs
node scripts/verify-p6c-supplier-interactions.mjs
git diff --check
```

P6C boundary invokes deterministic behavior tests. Chromium scripts start loopback Vite servers and block external network requests. They do not alter demo browser profiles or connect to Supabase. `CHROMIUM_PATH` is optional when using an installed matching browser.

## Authenticated fixture reference — acceptance and cleanup complete

`browser-setup.sql`, `browser-role.sql`, and `browser-cleanup.sql` require a newly provisioned synthetic Auth identity with email `p6c-s7-browser@example.test`; fill its UUID in a temporary execution copy. No credentials belong in SQL/source/logs. Alpha/Beta Company IDs are `77200000-0000-4000-8000-0000000000a1` / `77200000-0000-4000-8000-0000000000a2`. Alpha starts ACCOUNTING_ADMIN; Beta starts SYSTEM_ADMIN. Settings are distinct fixture presentation data. There are no financial or other master fixtures.

Before setup, positively confirm Development, applied migration/alignment, fixture ID/code/slug/user collisions absent, and global counts. Setup must pass its guards. Record exact UUIDs without tokens/passwords. After testing, cleanup checks exact Company identities, settings count, membership ownership, unexpected Company-owned records and outside actor dependencies before removing only the manifest and synthetic Auth identity. It never uses broad deletion or explicit CASCADE.

## Original authenticated acceptance procedure (reference only)

1. In an isolated browser profile, log in and open `/company-profile` directly. Verify Alpha metadata/nulls/Unicode/leading-zero TRN, exactly four optional text fields, and no identity/status/branding controls.
2. ACCOUNTING_ADMIN: edit/save/clear, verify persistence and exact id/updated_at predicate. Save should issue only the Company write and Company reread; shell legal identity updates immediately while branding remains. Focus/tab return must retain the form and settings/master snapshot without blocking “Loading securely”.
3. Open two real tabs on the same token. Save in the first; the second must conflict, never overwrite. Refresh/review then deliberately edit again. Test denial and unknown-network outcome without automatic replay; a confirmed write/failed refresh must retain its distinct recovery state.
4. Switch Alpha/Beta. SYSTEM_ADMIN in Beta may update only Beta profile; UUID guessing must not grant unrelated tenant access or financial visibility. Repeat legal-name synchronization and focus behavior for SYSTEM_ADMIN.
5. Use guarded `browser-role.sql` on Alpha to cover every denied role and SYSTEM_ADMIN. Revalidate while an edit is open; denied roles lose controls. Confirm RLS independently denies mutation, not only the UI.
6. Using exact synthetic identifiers only, revoke membership/profile in separate controlled transactions; tab return must fail closed. Restore authority and explicitly select a valid Company again. Verify tenant switch/logout during delayed operations never paints old data or feedback in another scope.
7. Verify English/Arabic/RTL, keyboard open/save/close and restored focus, narrow viewport, plain-text long/freeform content, console and request boundaries. Financial paths remain deferred. No settings or other master mutation request is allowed.
8. Run guarded exact-manifest cleanup. Verify browser Company/settings/membership/profile/Auth IDs absent, SQL fixture IDs absent, global counts restored and missing/orphan settings zero. Clear only isolated synthetic browser Auth/tenant state, preserving any pre-existing `cas:v1:*` keys.
9. Record actual results and limitations before closure. Slice 7 is now VERIFIED COMPLETE from the accepted evidence below. One local closure commit is authorized; no Slice 8 or push.

## Final accepted authenticated evidence

The user reports PASS for ACCOUNTING_ADMIN and same-Company SYSTEM_ADMIN mutation; denied-role UI; metadata update/clear; leading-zero TRN; real stale two-tab conflict; Alpha/Beta isolation; authority downgrade/revocation fail-closed and profile revocation to no-company; focus/tab-return; Arabic/RTL/keyboard/narrow layout; final fixture cleanup and no stale tenant data.

This user-supplied acceptance closes the prior browser/credential/fixture gate. The reference procedure above is not a claim that additional individual cases or measurements beyond those reported were separately executed. The previously verified automated cleanup baseline was 14 Companies/14 settings, no missing/orphan rows. Final authenticated cleanup is accepted from the user; no fresh count or query was performed at closure. No credentials are stored.

No verification was rerun during this documentation-only closure. Business/accounting, security/authorization, database, testing and documentation are VERIFIED for the accepted slice. Development migration acceptance is VERIFIED; frontend release/production readiness remain DEFERRED; Staging/Production action is NOT APPLICABLE. No P6D/financial behavior or Slice 8 work; one local commit only, no push.
