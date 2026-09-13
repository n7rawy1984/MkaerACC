# P6C Slice 4 — Subcontracts READ-ONLY

2026-09-13 — **VERIFIED COMPLETE**, with authenticated acceptance and fixture/Auth cleanup complete. Slices 1–3 remain VERIFIED COMPLETE; overall P6C remains incomplete. P6D/P6E and all production master mutations remain unstarted/deferred.

## Authoritative selection and scope

`PROJECT_ROADMAP.md`, P6C, explicitly leaves “Subcontracts, all master mutations, and overall P6C completion” pending after verified Slice 3. The handoff and Slice 3 closure agreed at selection time. The smallest next cutover is therefore Subcontracts READ-ONLY using the existing async master architecture. Contract master records belong to P6C; specialized financial RPC integration belongs to P6D. This does not authorize mutations or declare this the final P6C slice: master mutations and P6C closure remain pending, with their subsequent scope requiring a separate decision.

Starting Git checkpoint: `eba096ee907d2e47acfe6338c380ea2a5b4cdd0b`, clean working tree. This batch changes only local implementation/tests/documentation. No commit or push.

## Actual schema and Development evidence

Inspected canonical P3/P4 master/RLS migrations, P5A and P5F composite references, generated public types, and the linked **MakerACC-Development** catalog in an explicit `BEGIN TRANSACTION READ ONLY` / `ROLLBACK` transaction. Project-list metadata confirmed the linked environment. All 27 local/remote migrations align through `20260911123000`; linked `db push --dry-run` reports `upToDate: true` and empty migrations/seeds/roles. No schema change is needed or applied.

Only new application table: `public.subcontracts`. Existing scoped `projects` and `parties` snapshots supply optional labels; no joins, follow-up label requests, or financial-row queries are added.

| Columns | Type / nullability / default |
|---|---|
| `id` | Required UUID PK; `gen_random_uuid()` |
| `company_id`, `project_id`, `subcontractor_id` | Required UUID; no default |
| `contract_number`, `scope_of_work` | Required text; no default |
| `original_contract_value_minor` | Required BIGINT; no default; nonnegative |
| `approved_variations_minor` | Required BIGINT; default 0; signed |
| `retention_bps` | Required INTEGER; no default; 0–10000 inclusive |
| `start_date`, `expected_end_date` | Nullable DATE; no default |
| `status` | Required `subcontract_status`; default ACTIVE |
| `notes` | Nullable text; no default |
| `created_at`, `updated_at` | Required timestamptz; default `now()` |
| `created_by`, `updated_by` | Nullable UUID; no default |

- Actual status enum: ACTIVE, COMPLETED, CLOSED. No status/date inference or ACTIVE-only query filter.
- Trimmed contract-number length 1–100; trimmed scope length >0. Unique contract number per Project on `(project_id, lower(btrim(contract_number)))`, not Company-wide.
- Revised value constraint uses numeric casts to require original value plus signed approved variations >=0 without BIGINT addition overflow. No separate revised-value column; no balance, currency, certification, payment, recovery or retention-held column.
- Four indexes, all unique B-trees: PK `(id)`; Project/normalized contract number; `(company_id,id,project_id)` from P5A; `(company_id,id,project_id,subcontractor_id)` from P5F. No additional standalone Company index was observed; the composite keys start with Company.
- Company FK → `companies(id)`; `(company_id,project_id)` → `projects(company_id,id)`; `(company_id,subcontractor_id)` → `parties(company_id,id)`; actor FKs → `auth.users(id)`. All ON DELETE RESTRICT; default ON UPDATE NO ACTION. No cascade deletion or cross-Company dimensions.
- `subcontracts_validate` invokes `validate_subcontract` before INSERT/UPDATE: Party must be same-Company SUBCONTRACTOR. On insert or Project/Party reassignment, a CLOSED Project or inactive Party is rejected. Existing referenced Party type is protected by `parties_protect_subcontractor_type`.
- `subcontracts_prevent_tenant_reassignment` blocks Company changes; `subcontracts_set_updated_at` refreshes `updated_at`. Trigger functions are invoker-security with empty fixed `search_path`, EXECUTE only for postgres in inspected ACLs.
- Incoming journal-line FK preserves Company/Contract/Project; Advances, Certificates, Payments, Retention Releases and Retention Payments preserve Company/Contract/Project/Subcontractor via composite FKs. All ON DELETE RESTRICT. Their existing P5 command behavior remains unchanged; this read path neither queries those tables nor treats Project as GL.

## Exact RLS and grants

Subcontracts has enabled **and forced** RLS. `subcontracts_read_authorized` applies to authenticated SELECT:

| Company role | Visible Subcontracts |
|---|---|
| ACCOUNTING_ADMIN | All rows in authorized Company |
| ACCOUNTANT | All rows in authorized Company |
| PROCUREMENT | All rows in authorized Company |
| MANAGEMENT_VIEWER | All rows in authorized Company |
| PROJECT_MANAGER | Only rows on Projects with the actor's own ACTIVE assignment |
| DATA_ENTRY | None |
| SYSTEM_ADMIN | None; no browser bypass |

Inspected `has_company_role`, `is_company_member`, `is_active_user` and `has_active_project_assignment` require authenticated `auth.uid()`, ACTIVE profile, ACTIVE membership and ACTIVE Company. Assignment also binds the actor, Company and Project. Subcontract ACTIVE/COMPLETED/CLOSED and Project status are not extra SELECT filters. Project Manager without active assignment sees zero rows. Inactive profile/membership/Company authorizes no rows.

These authorization helpers and `has_permission` are stable SECURITY DEFINER functions with fixed empty `search_path`; ACLs grant EXECUTE only to postgres/authenticated. They inspect protected authority rows without adding financial command access.

Actual table grants:

- `authenticated`: SELECT, INSERT, UPDATE; no DELETE/TRUNCATE/REFERENCES/TRIGGER. Existing INSERT and UPDATE policies require `subcontract.manage` (UPDATE has both USING and WITH CHECK); current permission rows grant it only to ACCOUNTING_ADMIN and PROCUREMENT. The new frontend exposes no writes; it does not claim existing administrative writes are denied by the database.
- `anon` / PUBLIC: no table grants.
- `service_role`: SELECT, INSERT, UPDATE, TRUNCATE, REFERENCES, TRIGGER; no DELETE.
- `postgres`: SELECT, INSERT, UPDATE, DELETE, TRUNCATE, REFERENCES, TRIGGER.

**Expected/intentional behavior:** a Project Manager may see a Subcontract and its Subcontractor UUID while Parties RLS hides all Party details. Preserve the UUID and display unavailable details; do not fetch or invent the hidden Party. Missing Project labels from a partial snapshot are treated the same way.

**Hardening opportunity, non-blocking:** trusted-only service_role grant extras match the previously recorded Slice 2/3 issue; unchanged and not browser-reachable. No confirmed defect, schema blocker or policy change found in this read slice. Pagination/realtime and assignment-only refresh are deferred concerns, not newly introduced controls.

## Implementation and behavior

- Explicit `ProductionSubcontract` maps all 17 columns to camelCase, preserving UUIDs, leading-zero contract numbers, scope, dates, nullable fields, actual status and actor/timestamps.
- `readActiveCompanySubcontracts` selects explicit columns, filters `company_id = activeCompanyId`, orders contract number then ID, and defensively removes wrong-Company rows. Empty, null and partial RLS results are legitimate; no hidden-row synthesis or expected-count requirement.
- BIGINT columns use server-side `::text` projections before JSON decoding. Generated base row types use `number`; the explicit projected row instead uses strings. Values above JS safe-integer limits and signed variations remain exact. Mapper rejects numeric/malformed amount responses; repository returns a safe normalized error. No Number/parseFloat conversion, financial arithmetic, revised total, invented currency or persistence. UI explicitly labels amounts as minor units; INTEGER basis points display as an exact two-decimal percentage.
- Same aggregate provider now loads seven resources once per mounted user/Company/role scope. New resource failure withholds the whole snapshot with the existing generic EN/AR error and refresh guidance. No global cache or localStorage fallback.
- `/subcontracts` is added to the existing protected routes/navigation. Supports loading, READY populated/legitimate empty, ERROR and MISSING_COMPANY through the existing shell. EN/AR/RTL, P6B branding, Company selection and logout are retained. Mixed-direction IDs/text use `bdi`; long text wraps. No create/edit/delete, financial action, balance or posting control.
- Authoritative P6A identity/Company/role and P6B presentation are unchanged. Provider remains keyed by user/Company/role; synchronous visible-scope, generation, mount and pre/post-session guards prevent old responses committing into a new scope. Tenant switches/logout/revocation remove the protected tree. Same-authority focus/visibility and redundant same-user SIGNED_IN preserve providers and snapshots; no new focus handler or master reload is added.

Existing limits remain: lists are API-limited snapshots without completeness claims; no pagination/realtime. Assignment-only changes require refresh/new query, because ordinary focus revalidates P6A authority, not assignment snapshots. One resource failure withholds the aggregate. Final representative browser acceptance is recorded below; mock transport alone does not prove a hosted PostgREST response.

## Exact file manifest

Added:

- `src/master/SubcontractsList.tsx`
- `docs/P6C_SLICE_4_SUBCONTRACTS.md`

Changed:

- `src/master/masterTypes.ts`
- `src/master/masterRepositories.ts`
- `src/master/ProductionMasterDataProvider.tsx`
- `src/app/TenantReadyApplication.tsx`
- `src/auth/ProtectedApplication.tsx`
- `src/i18n/en.ts`
- `src/i18n/ar.ts`
- `scripts/verify-p6c-boundary.mjs`
- `scripts/verify-p6c-behavior.mjs`
- `PROJECT_ROADMAP.md`
- `PROJECT_HANDOFF.md`

No generated type or migration edits.

## Implementation-stage verification (historical)

- `npm run build`: PASS; existing demo chunk-size advisory.
- `npm run lint`: PASS; four established Fast Refresh warnings.
- `npm run verify:p6a-boundary`: PASS.
- `npm run verify:p6c-boundary`: PASS, including existing controlled behavior and list checks; table allowlist/read-only/query/scope/route checks extended to Subcontracts. Production/demo graph separation, no financial table/RPC/mutation/private-secret markers and focus/visibility source guards pass.
- `node scripts/verify-p6c-behavior.mjs`: PASS. Added exact BIGINT strings including maximum int8 and signed variation above JS safe range, zero/invalid amount rejection, 17-column mapping, all statuses, nullable/non-null dates/actors/notes, legitimate partial/empty/null responses, explicit text projections/filter/order and safe errors. Extended real transpiled provider adapter cases for delayed Company/role/user changes, session loss/unmount and valid Subcontracts-with-empty-Parties. Unchanged scope stays at seven reads. Actual React list static rendering covers hidden/same-Company labels, UUIDs, leading-zero number, Arabic scope, exact amount strings and percentage boundaries, empty state and no mutation controls.
- `git diff --check` and focused changed-file credential scan: PASS.
- Development read-only catalog review and 27-version migration alignment: PASS; linked dry-run: no-op. No synthetic fixture or business/Auth data changed.
- Not performed: authenticated browser/Data API role matrix, hosted `::text` response proof, timed browser races, browser fault injection, exhaustive EN/AR/RTL/keyboard/network acceptance, hosted mutation-denial tests. No browser fixture or test identity was created. Existing lifecycle adapters/source checks are not presented as new browser evidence.

## Original authenticated browser plan (final evidence below)

1. Use MakerACC-Development only. Reuse suitable authorized data/identities or separately authorize a minimal guarded synthetic fixture and exact cleanup manifest. Companies A/B need distinct P6B branding and valid memberships. A: assigned and unassigned Projects, SUBCONTRACTOR Parties, multiple contracts for one Party, all three statuses, null and non-null dates/notes/actor metadata, leading-zero contract number, Arabic/long scope. Include zero, positive and negative valid variations, BIGINT maximum `9223372036854775807`, a value above `9007199254740991`, and retention 0/1/125/10000 basis points. B: legitimate empty Subcontracts. No financial documents or journals needed.
2. Signed out, open `/subcontracts`: login, no data. Sign in/select A; navigate and directly refresh the route. Compare each displayed field to the fixture. In Network, verify both amount fields arrive as JSON strings via `::text`, including exact last digits and sign; no precision loss. Check all statuses and nullable fields, no invented currency/balance/revised total. Visit existing master routes without extra reloads.
3. Verify each role against the table above. Project Manager sees assigned contracts and real Subcontractor UUIDs with unavailable Party details; no hidden Party names appear. Disable assignment, refresh, expect no contracts; restore and refresh. DATA_ENTRY and SYSTEM_ADMIN get legitimate empty lists; procurement sees contracts. Alter requested company_id under the authenticated Data API session to confirm unrelated-Company denial. Do not weaken RLS.
4. Switch A→B→A; verify branding/empty/populated isolation. Delay A Subcontracts responses, switch to B, release A; no A data may render or commit. Repeat delayed response across role downgrade, logout, session loss and different-user login. A role downgrade detected by focus must clear/reload the role-sensitive snapshot. Missing active Company must fail closed (P6A may route to no-company before the master state's message).
5. Repeated unchanged tab-away/return must preserve content/branding, with only P6A authority reads: no “Loading securely...”, provider unmount, neutral-brand flash, settings reload or any of the seven master reloads. Separately revoke synthetic profile/membership/Company, trigger focus, and verify data clears; restore and Retry safely rebuilds authorized selection. Record actual requests and console output without recording tokens.
6. Fail only Subcontracts requests and inject malformed numeric amount responses with a controlled browser adapter: safe aggregate error, no raw server details, stale data or demo fallback. Remove fault and refresh; exact populated state recovers. Use throttling to verify loading.
7. Check EN/AR, document lang/dir and RTL, P6B branding, narrow viewport, keyboard navigation, long/mixed-direction values, legitimate empty state and no mutation controls. Network allows only Auth/P6A/settings and the seven master resources; no financial query, journal/posting RPC or private key. `/journal`, `/expenses`, `/advances` and other financial routes remain holding states.
8. Verify local-demo separately with existing `cas:v1:*` data unchanged and no production graph crossover. After acceptance, perform only separately authorized guarded fixture/Auth/browser cleanup and record actual evidence/limitations. Mark only Slice 4 verified if accepted; leave overall P6C incomplete.

## Implementation-stage boundaries and lifecycle (historical)

No unapproved mutation, financial-flow cutover, journal/posting RPC access, migration, RLS/grant weakening, production localStorage fallback, synthetic fixture, Staging/Production action, commit or push. Site Materials / Stores and reusable Tool Custody, separate from financial Custody Advances, remain future-only. No following slice started.

- Business/accounting: **VERIFIED** for read-only contract semantics and exact amount transport design; no policy invented.
- Security/authorization: schema/source/controlled scope evidence **VERIFIED**; authenticated acceptance **DEFERRED**.
- Database: applied catalog/canonical alignment **VERIFIED**; schema changes **NOT APPLICABLE**.
- Deployment: **NOT APPLICABLE** to this local batch; Staging/Production and production readiness **DEFERRED**.
- Testing: automated and hosted metadata **VERIFIED**; authenticated browser/runtime acceptance **DEFERRED**.
- Documentation: **VERIFIED**, with P6C incomplete and remaining gates explicit.

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
