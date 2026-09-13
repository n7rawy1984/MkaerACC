# P6C Slice 4 — Development fixture and manual acceptance

2026-09-13. **SLICE 4 VERIFIED COMPLETE; fixture and Auth user removed.** This directory is operational fixture/runbook support, not migrations or application logic. The accepted implementation remains unchanged. The setup/runbook below is historical; final acceptance and cleanup at the end record the current state. No live fixture remains. Overall P6C remains incomplete; P6D/P6E have not started.

## Environment and identity

Only **MakerACC-Development**, project ref `eqnzueginpkskbnqvgoc`. Confirm the dashboard project before running SQL Editor scripts. CLI execution must explicitly target it:

```bash
node_modules/.bin/supabase db query --linked --project-ref eqnzueginpkskbnqvgoc --file docs/verification/p6c-slice4/verify.sql
```

Auth identity: `9dbcfe8d-0333-4d3c-8b1b-3acc4b9b47d3`, `p6c-slice4-user@example.test`. Exact UUID/email uniqueness and ACTIVE matching profile were verified before any insert. The password remains private: do not put it, tokens, cookies or authorization headers into SQL, screenshots, reports or shared HAR files.

## Exact deterministic manifest

All fixture UUIDs use prefix `74000000-0000-4000-8000-`. Each suffix below is the complete final 12 characters. Settings use Company UUIDs as their primary keys; no separate settings ID exists.

| Entity | UUID suffix | Exact code / reference |
|---|---|---|
| Alpha Company/settings | `0000000000a1` | `P6C-S4-ALPHA` / `p6c-s4-alpha` |
| Beta Company/settings | `0000000000a2` | `P6C-S4-BETA` / `p6c-s4-beta` |
| Alpha membership | `0000000000b1` | Auth user above; initial ACTIVE/MANAGEMENT_VIEWER |
| Beta membership | `0000000000b2` | Same Auth user; ACTIVE/MANAGEMENT_VIEWER throughout |
| Alpha Project A | `0000000000c1` | `P6C-S4-PROJECT-A` |
| Alpha Project B | `0000000000c2` | `P6C-S4-PROJECT-B` |
| Project A assignment | `0000000000d1` | Auth user → Project A; initial ACTIVE |
| Concrete Subcontractor | `0000000000e1` | `P6C-S4-SUB-001` |
| Finishes Subcontractor | `0000000000e2` | `P6C-S4-SUB-002` |
| Active contract | `0000000000f1` | `P6C-S4-A-001` |
| Completed precision contract | `0000000000f2` | `P6C-S4-A-002` |
| Closed contract | `0000000000f3` | `P6C-S4-B-001` |

Alpha is `P6C Slice 4 Alpha`, legal name `P6C Slice 4 Alpha Synthetic LLC`; display `P6C S4 Alpha`, default locale en, primary `#1d4ed8`, accent `#0891b2`. Beta is `P6C Slice 4 Beta`, legal name `P6C Slice 4 Beta Synthetic LLC`; display `P6C S4 Beta`, default locale ar, primary `#7e22ce`, accent `#c2410c`. Both Companies ACTIVE, both logo/favicon NULL. Locale may follow existing explicit-user precedence; verify Arabic with the language control instead of assuming Beta overrides it.

Both Projects are ACTIVE, named `P6C Slice 4 Project A — المشروع أ` and `P6C Slice 4 Project B — المشروع ب`. Only A has the user's assignment. Both Parties are ACTIVE/SUBCONTRACTOR: `P6C S4 Concrete — مقاول الخرسانة` and `P6C S4 Finishes — مقاول التشطيبات`. Beta has no Projects, Parties, assignments or Subcontracts. Neither Company has Accounts, Treasury, categories or financial records.

| Contract | Project / Party | Status | `original_contract_value_minor` | `approved_variations_minor` | `retention_bps` → UI |
|---|---|---|---|---|---|
| P6C-S4-A-001 | A / Concrete | ACTIVE | `12500000` | `250000` | `500` → 5.00% |
| P6C-S4-A-002 | A / Concrete | COMPLETED | `9007199254740993` | `0` | `1000` → 10.00% |
| P6C-S4-B-001 | B / Finishes | CLOSED | `800000` | `-10000` | `125` → 1.25% |

Three rows cover every requested case, so a fourth is unnecessary. Two contracts deliberately share one Party and Project, preserving separate contract identity.

- A-001 scope: `Synthetic concrete works — أعمال الخرسانة`; dates 2026-01-15 / 2026-12-31; notes `Synthetic dated contract — ملاحظة تحقق`.
- A-002 scope: `Synthetic BIGINT precision verification only`; both dates and notes NULL. `9007199254740993` is strictly above `9007199254740991`; it must never become `9007199254740992`.
- B-001 scope: `Synthetic finishes — أعمال التشطيبات`; start 2026-02-01; end/notes NULL. Negative variation is valid: revised value remains nonnegative.
- All inserted `created_by`/`updated_by` are explicitly NULL. Default database timestamps apply; the synthetic user is not falsely credited with administrative fixture creation. Role/assignment scripts leave actors NULL and allow normal timestamp triggers.

## Reconfirmed schema/policy boundaries

Actual Subcontract FK column is **`subcontractor_id`**, not `subcontractor_party_id`. Both amounts are PostgreSQL BIGINT, retention INTEGER constrained 0–10000, statuses ACTIVE/COMPLETED/CLOSED. Contract number uniqueness is case-insensitive/trimmed per Project. Required Company/Project/Party references and delete restrictions remain in force. Original value and original-plus-variation must be nonnegative. Active Project/Party insertion requirements are met. Nullable dates/notes and actors are valid.

No policy/constraint surprise blocks setup. Existing Company settings FK uses ON DELETE CASCADE and actor FKs SET NULL; these are P6B presentation semantics. Cleanup explicitly deletes settings first and does **not** rely on cascade. Accounting/master dependencies use their existing RESTRICT rules.

| Alpha Company role | Contracts with assignment ACTIVE | With assignment INACTIVE | Party labels |
|---|---:|---:|---|
| ACCOUNTING_ADMIN | 3 | 3 | Both visible |
| ACCOUNTANT | 3 | 3 | Both visible |
| PROCUREMENT | 3 | 3 | Both visible |
| MANAGEMENT_VIEWER | 3 | 3 | Both visible |
| PROJECT_MANAGER | 2 (A-001/A-002) | 0 | No Party rows; UUID retained, details unavailable |
| DATA_ENTRY | 0 | 0 | Parties themselves may be visible; no contracts |
| SYSTEM_ADMIN | 0 | 0 | No Party rows; no bypass |

All authorized reads require active profile, Company and membership. PROJECT_MANAGER additionally requires the actor's own active Project assignment. Status does not hide COMPLETED/CLOSED contracts. Existing INSERT/UPDATE policies are not exercised by the app or role test scripts. SYSTEM_ADMIN here is a Company membership role, never a row in private platform administrators.

## Setup-stage files and execution status (historical)

- `preflight.sql`: read-only, exact identity/schema/baseline and global namespace/code/slug/contract collisions. Fails rather than choosing replacement IDs. Run before first creation only; it must fail once the fixture exists.
- `create.sql`: one guarded transaction, exact deterministic inserts with NULL actors; repeats preflight in the transaction, asserts exact manifest/counts/dimensions, rejects any out-of-scope Company rows.
- `verify.sql`: read-only exact live-manifest checks and counts; also usable after cleanup. It casts BIGINT to text in the administrative report. That alone does not prove the browser Data API response.
- Seven `role-*.sql` files: exact guarded Alpha membership updates for accounting_admin, accountant, procurement, management_viewer, project_manager, data_entry and system_admin. Beta remains MANAGEMENT_VIEWER. **Prepared, not executed during setup.**
- `assignment-active.sql`, `assignment-inactive.sql`: exact guarded Project A assignment updates. **Prepared, not executed during setup.**
- `cleanup.sql`: exact identity/Company/code/row-content and count guards, unrelated membership/assignment/platform authority rejection, catalog-driven rejection of unexpected Company-scoped rows, row-count assertions and one transaction. **Prepared, not executed.**

Guarded switches accept any current Alpha Company role and either assignment status, but require the rest of the manifest unchanged and the profile/Companies/memberships ACTIVE. Do not loosen guards when a mismatch occurs; investigate. File execution is a manual Development operational action, not an app mutation feature.

## Original manual browser sequence

1. Signed out, visit `/subcontracts`: login, no protected data. Sign in privately as the exact synthetic user, choose Alpha. MANAGEMENT_VIEWER: three contracts, all statuses/fields as above; both Project and Party labels visible. Check direct refresh and existing master navigation. In Network inspect `/rest/v1/subcontracts`: select includes `original_contract_value_minor::text` and `approved_variations_minor::text`, Company filter is Alpha. Response fields must be quoted JSON strings, particularly `"9007199254740993"`, `"0"` and `"-10000"`. UI must preserve digits/sign without rounding or scientific notation. Contract IDs are in Network; referenced UUIDs are also visible in the UI. Compare retention to the table above.
2. Run `role-procurement.sql`, then return focus to the app to trigger authoritative role revalidation. Expect three contracts and both labels. This is a representative broad-reader check; Accounting Admin/Accountant use inspected policy branches and have optional prepared scripts rather than mandatory duplicate browser runs.
3. Run `role-project_manager.sql`, return focus: old broad snapshot must clear and reload. Expect only A-001/A-002; B-001 and Finishes details absent. Party UUID `74000000-0000-4000-8000-0000000000e1` remains; Concrete name/code must not appear. The UI indicates related details unavailable. Project A label remains authorized.
4. Run `assignment-inactive.sql`, then **refresh**: zero Subcontracts. Assignment-only changes do not refresh master snapshots on routine focus. Run `assignment-active.sql`, refresh: two return. Leave assignment ACTIVE afterward.
5. Run `role-data_entry.sql`, focus: zero contracts. Run `role-system_admin.sql`, focus: zero contracts and no financial bypass. Restore `role-management_viewer.sql`, focus: three contracts return. Do not click create/edit controls in any other tool or invoke financial commands.
6. Alpha→Beta: purple/Beta branding and zero Projects/Parties/Subcontracts; no Alpha flash. Repeat tab-away/return: no “Loading securely...”, neutral-brand flash, settings reload or Subcontract request under unchanged authority. Expect P6A authority reads only. Return Alpha and repeat focus check with populated rows.
7. Check EN/AR, document lang/dir/RTL, Arabic scope/Party names, long UUIDs, narrow viewport and keyboard navigation. Direct `/subcontracts` is available; `/journal`, `/expenses`, `/advances` and other deferred financial routes stay holding states. Network contains only Auth/P6A/settings/master reads, no financial/journal/posting requests. Record relevant console errors without credentials.

## Original failure/async verification plan

- Delayed Alpha→Beta: use a browser automation request interceptor or a response-delay proxy scoped to Alpha `/rest/v1/subcontracts`; hold Alpha response, switch Beta and let its empty response complete, release Alpha. Beta must remain empty/branded correctly. Ordinary network throttling is useful but not deterministic proof of this ordering.
- Role downgrade: hold a broad-role Alpha response, run exact `role-project_manager.sql` or `role-data_entry.sql`, trigger focus authority revalidation, then release old response. Only the new-role snapshot may commit. Restore MANAGEMENT_VIEWER after testing.
- Logout while request pending: sign out, release old response; login screen remains with no protected contract data. Session loss: use the Auth dashboard to revoke only this synthetic user's session or a controlled browser Auth-response adapter, then focus; data must clear. Do not copy tokens into scripts or reports.
- Different-user login: use an existing separately authorized identity only if available; sign out the fixture user, sign in privately as that identity while old response is held, then release. Previous user's snapshot must not remain. No second identity was created here; if none is available, record this browser case as deferred and retain existing automated evidence.
- Query failure: browser DevTools request blocking or an interceptor returns a failed Subcontracts request; refresh. Expect safe aggregate error, no raw server message or demo fallback. For malformed data, interceptor replaces an amount string with a numeric JSON value or invalid decimal text; expect the same safe failure. Remove interception and refresh to recover. Do not mutate stored data for failure injection.
- Interception/throttling setup is later browser tooling, not an application change. Do not report these cases as passed until actually executed. No browser fixture credentials or response bodies containing tokens should be shared.

## Cleanup procedure — subsequently completed

After acceptance and separate cleanup authorization, sign out/close test tabs. Restore ACTIVE profile/Companies/memberships and the exact fixture metadata first. Alpha may have any of the seven roles; assignment may be ACTIVE or INACTIVE. Run `verify.sql`, inspect counts/manifest, then `cleanup.sql` only in Development.

Delete order is assignment → three Subcontracts → two Projects → two Parties → two memberships → two settings → two Companies → exact profile. Every DELETE has exact identity/content predicates and a one-row assertion; any failure rolls back the transaction. No CASCADE statement or financial-history deletion. Unexpected Company-owned rows, changed manifest or unrelated user memberships/assignments/platform authority block cleanup.

Run `verify.sql` again: profile, fixture Companies/settings/memberships/Projects/Parties/assignments/Subcontracts must all be zero; unexpected Company-scoped rows and unrelated user memberships/assignments must be zero; global Companies/settings return to 14/14 with zero missing/orphans if no unrelated Company work occurred. Auth identity should still be exactly one. **Only then manually delete the exact synthetic Auth user in Authentication** and rerun verification to confirm Auth=0. Retain these files as historical support, update this README with acceptance/cleanup evidence, and never rerun creation silently.

## Setup-stage evidence and lifecycle (historical)

Setup completed in one guarded transaction; independent read-only verification passed. No role/assignment switch, cleanup, authenticated browser acceptance or hosted browser BIGINT-string proof is claimed at setup. Build/lint/application checks already passed in the preceding implementation batch; fixture-only work does not reclassify that as new browser evidence.


### Original setup evidence — 2026-09-13

Executed only identity/schema read-only inspection, `preflight.sql`, one `create.sql` transaction, and read-only `verify.sql`. Exact identity/profile checks passed. Namespace/code/slug/contract collisions were all zero before creation. Applied Subcontracts and Parties policies, fixture columns, enums and constraints were reconfirmed. All 27 local/Development migrations align through `20260911123000`; linked dry-run was a no-op (empty migrations/seeds/roles).

| Post-creation check | Verified result |
|---|---:|
| Exact Auth identity / ACTIVE profile | 1 / 1 |
| Fixture Companies / memberships / settings | 2 / 2 / 2 |
| Alpha Projects / Beta Projects | 2 / 0 |
| Assignments / ACTIVE assignments | 1 / 1 |
| Alpha SUBCONTRACTOR Parties / Beta Parties | 2 / 0 |
| Alpha Subcontracts / Beta Subcontracts | 3 / 0 |
| Invalid contract Company/Project/Party dimensions | 0 |
| Unrelated user memberships / assignments | 0 / 0 |
| Unexpected fixture Company-scoped rows | 0 |
| Global Companies / settings | 16 / 16 |
| Missing / orphan settings | 0 / 0 |

Exact contract values/statuses/dates/notes/retention match the manifest above, including PostgreSQL `9007199254740993`. Created/updated actor fields are NULL. The catalog-driven scan checks every public/private Company-owned table outside the six allowed fixture child tables, proving zero journals, journal lines, advances, certificates, payments, releases, allocations and other out-of-scope rows for both Companies. The synthetic user has no private platform administrator row.

All seven role scripts, both assignment scripts and cleanup remain **unexecuted**, including rollback rehearsals. Both memberships are still ACTIVE/MANAGEMENT_VIEWER and the sole assignment is ACTIVE. Cleanup is statically reviewed and shares identity/manifest guards already exercised during creation/verification; its destructive statements have not been runtime-tested.

A hash comparison confirms every pre-existing repository file is unchanged in this setup turn, including the accepted dirty Slice 4 application/tests/roadmap/handoff. Only these 14 support files were added. Script inventory, transaction/boundary checks, focused credential-marker scan and `git diff --check` pass. Build/lint were not rerun for this fixture-only batch; preceding implementation results remain historical evidence.

Lifecycle: business/fixture semantics **VERIFIED**; schema/RLS discovery and exact fixture boundaries **VERIFIED**, authenticated browser authorization **DEFERRED**; canonical migration alignment **VERIFIED**, schema change **NOT APPLICABLE**; Development fixture execution and read-only verification **VERIFIED**, browser/runtime/cleanup execution **DEFERRED**; application deployment **NOT APPLICABLE**, Staging/Production **DEFERRED**; fixture/runbook documentation **VERIFIED**. This is fixture readiness, not Slice 4 acceptance or P6C completion.

No application logic, migration, RLS/grant, financial history/command, P6D/P6E, Staging/Production, commit or push change occurred. No password was requested, stored or logged. Preserve the fixture for manual verification.

## Final authenticated acceptance and cleanup — 2026-09-13

**P6C Slice 4 — Subcontracts READ-ONLY is VERIFIED COMPLETE.** The user supplied completed authenticated browser acceptance and guarded fixture cleanup evidence. Implementation/setup-stage statements above are historical; this closure supersedes their pending/live-fixture status.

- MANAGEMENT_VIEWER: Alpha displayed exactly three Subcontracts; authorized Project/Party labels, actual statuses/amounts/dates/notes and safe NULL handling passed. `9007199254740993` rendered exactly, without rounding or scientific notation. No mutation or financial action UI appeared.
- PROCUREMENT: three Subcontracts remained visible; foreground/focus revalidation detected the role change without manual refresh or a “Loading securely...” regression.
- PROJECT_MANAGER with ACTIVE Project A assignment: only `P6C-S4-A-001` and `P6C-S4-A-002` appeared; Project B's contract remained hidden. Authorized Project label and authoritative Subcontractor UUID remained visible, while Party code/name/details did not leak. The unavailable-details message and exact BIGINT display passed.
- PROJECT_MANAGER with INACTIVE assignment: refresh yielded zero Subcontracts; assignment was restored ACTIVE afterward.
- SYSTEM_ADMIN: zero Subcontracts, confirming no browser tenant-data bypass.
- Restoring MANAGEMENT_VIEWER returned Alpha to three. Alpha→Beta yielded zero with no stale Alpha flash. Repeated tab-away/return preserved Beta with no blocking secure loader or branding flash.

Guarded Development cleanup succeeded. The user verified zero fixture Companies/settings/memberships/Projects/assignments/Parties/Subcontracts/profile, then manually removed Auth identity `9dbcfe8d-0333-4d3c-8b1b-3acc4b9b47d3` / `p6c-slice4-user@example.test`. Final independent read-only `docs/verification/p6c-slice4/verify.sql` confirms all fixture counts and Auth identity zero, no unexpected Company-scoped rows or unrelated user memberships/assignments, global 14 Companies/14 settings, and zero missing/orphan settings. No fixture remains. Operational SQL is retained as historical support, not live setup or migrations.

Evidence limits: closure uses the supplied representative authenticated cases, exact runtime BIGINT display, existing controlled lifecycle/rendering tests and applied schema/RLS review. Separate Accounting Admin/Accountant/Data Entry browser runs, timed browser race interception, fault injection, exhaustive EN/AR/RTL/keyboard/direct-route checks and detailed network counts/raw JSON capture were not separately supplied and are not newly claimed. The implementation's `::text` projection and string-only mapper plus exact rendered value support end-to-end precision; this does not manufacture a separate captured Network response.

Final checks: build, lint, P6A boundary, P6C boundary, standalone P6C behavior, focused credential scan and diff checks pass. Lint retains exactly four `react(only-export-components)` warnings at `src/components/ui/Field.tsx:29:14`, `src/i18n/I18nContext.tsx:93:17`, `src/i18n/I18nContext.tsx:100:17`, and `src/state/AppDataContext.tsx:1397:17`: “Fast refresh only works when a file only exports components. Use a new file to share constants or functions between components.” Build retains the existing demo chunk-size advisory. All 27 local/Development migrations align through `20260911123000`; linked dry-run is a no-op. No blocking defect or unrelated change found.

No production localStorage fallback, frontend financial/master mutation, journal/posting path, migration or RLS/grant weakening was introduced. No fixture password/private credential is present in the reviewed change set. Staging/Production were untouched. One final local checkpoint commit is authorized after passing checks; no push is authorized or performed.

Overall P6C is **NOT COMPLETE**. The next documented remaining item is **P6C master-data mutation cutover**; the roadmap does not yet specify the first entity/command sequence, which must be established before implementation. P6D specialized financial RPC integration and P6E have not started. Site Materials / Stores and reusable Tool Custody remain future-only. Existing pagination/realtime and assignment-only snapshot refresh limits remain; trusted service_role grant extras remain a non-blocking hardening opportunity.

Final lifecycle: business/accounting **VERIFIED** for read-only semantics and exact values; security/authorization **VERIFIED** for inspected boundaries and accepted representative browser evidence; database **VERIFIED** for aligned history and cleaned fixture; testing **VERIFIED** with the explicit evidence limits above; documentation **VERIFIED**. Deployment **NOT APPLICABLE** to the local checkpoint; Staging/Production and full production readiness **DEFERRED**. Development slice completion is not production readiness.
