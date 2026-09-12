# P6C Slice 3 — Accounts and Treasury READ-ONLY

2026-09-12 — **VERIFIED COMPLETE**, with representative authenticated browser acceptance and fixture/Auth cleanup complete. Overall P6C remains NOT COMPLETE; Slices 1/2 remain VERIFIED COMPLETE. P6D/P6E and Subcontracts are not started. This is local implementation plus automated verification and read-only Development metadata review, not deployment or production acceptance.

## Actual schema and applied evidence

Inspected canonical P2/P3/P4 migrations, P5A's Treasury composite unique key, generated public DB types, and the linked **MakerACC-Development** catalog in explicit read-only transactions. All 27 local/applied migration versions align through `20260911123000`; linked `db push --dry-run` returned `upToDate: true` with empty migrations/seeds/roles. No migration was created or applied.

### Accounts (`public.accounts`)

- Required UUID `id` (PK, default `gen_random_uuid()`), UUID `company_id`, text `code`, text `name`, enum `account_type`, boolean `requires_party` (default false), enum `status` (default ACTIVE), timestamptz `created_at` and `updated_at` (default `now()`).
- Nullable UUID `parent_account_id`, enum `system_key`, UUID `created_by`/`updated_by`.
- `account_type`: ASSET, LIABILITY, EQUITY, REVENUE, EXPENSE. No separate class field. `status`: ACTIVE, INACTIVE.
- `system_key`: INPUT_VAT, CUSTODY_ADVANCE, SUPPLIER_PAYABLE, OWNER_CURRENT, SUBCONTRACTOR_ADVANCE, SUBCONTRACTOR_PAYABLE, SUBCONTRACTOR_RETENTION_PAYABLE, PROJECT_COST, PROJECT_COST_SUBCONTRACTORS, COMPANY_EXPENSE. Non-null keys are unique per Company. No separate `is_system`, `is_control` or `is_permanent` boolean exists; preserve the actual key and `requires_party`.
- Code/name trimmed lengths: 1–50 / 1–200. Code uniqueness: `(company_id, lower(btrim(code)))`. `(company_id,id)` also unique.
- Parent FK `(company_id,parent_account_id)` → Accounts `(company_id,id)` enforces Company consistency and ON DELETE RESTRICT; direct self-parenting is forbidden. The schema does not establish arbitrary-depth acyclicity; the UI makes no tree-depth/acyclicity claim and never recursively traverses links.
- Company FK → Companies; actor FKs → `auth.users`; all ON DELETE RESTRICT. Update triggers prevent tenant reassignment and set `updated_at`.
- No currency, balance, bank, opening-balance or financial amount column.

### Treasury (`public.treasury_accounts`)

- Required UUID `id` (PK, default `gen_random_uuid()`), UUID `company_id`, text `code`, text `name`, enum `type`, UUID `gl_account_id`, enum `status` (default ACTIVE), timestamptz `created_at`/`updated_at` (default `now()`).
- Nullable UUID `project_id`, text `bank_name`, `account_reference`, `notes`, UUID `created_by`/`updated_by`.
- Types: CASH, PETTY_CASH, BANK, PROJECT_CASH_BOX, PROJECT_BANK. Status: ACTIVE, INACTIVE. No currency or balance field; no frontend default is invented.
- Code/name trimmed lengths: 1–50 / 1–200. Code unique on `(company_id, lower(btrim(code)))`; `(company_id,id)` unique (P5A).
- Company/actor FKs use ON DELETE RESTRICT. `(company_id,project_id)` → Projects `(company_id,id)` also uses RESTRICT. Project is optional; no extra project-required-by-type rule is invented.
- `(company_id,gl_account_id)` → Accounts `(company_id,id)` uses RESTRICT, with globally unique `gl_account_id`: each Treasury has exactly one mapped Account; an Account can back at most one Treasury. Some Accounts have no Treasury.
- Actual `validate_treasury_account` trigger rejects Company/GL reassignment and requires a same-Company ASSET Account when Treasury is inserted/updated. Its function is invoker-security with fixed empty `search_path`; no new function/grant was introduced. Update timestamp trigger remains unchanged. This read slice makes no additional Account mutation guarantees.

## Exact RLS and grant matrix

Both tables have enabled and forced RLS. Accounts SELECT policy `accounts_read_accounting` checks the three accounting/viewer roles. Treasury SELECT policy `treasury_read_authorized` checks `treasury.view` or Project Manager plus a non-null Project and own active assignment. Hosted permissions confirm only Accounting Admin, Accountant and Management Viewer have `treasury.view`.

| Existing Company role | Accounts | Treasury Accounts |
|---|---|---|
| ACCOUNTING_ADMIN | All Company Accounts | All Company Treasury |
| ACCOUNTANT | All Company Accounts | All Company Treasury |
| MANAGEMENT_VIEWER | All Company Accounts | All Company Treasury |
| PROJECT_MANAGER | None | Only rows with non-null Project and own ACTIVE assignment to that Project |
| DATA_ENTRY | None | None |
| PROCUREMENT | None | None |
| SYSTEM_ADMIN | None | None |

All authorized reads additionally require authenticated `auth.uid()`, an ACTIVE profile, ACTIVE Company membership and ACTIVE Company through the inspected helpers. Project Manager without an assignment sees zero Treasury rows, including no Company-wide/null-project Treasury. Master row ACTIVE/INACTIVE is not a read filter. An inactive profile/membership/Company receives no authorized rows; anonymous has no table grants. Platform System Admin status supplies no browser data bypass.

On both tables, actual grants are:

- `authenticated`: SELECT, INSERT, UPDATE; no DELETE/TRUNCATE/TRIGGER/REFERENCES. Existing INSERT/UPDATE RLS policies require `account.manage` or `treasury.manage`, currently Accounting Admin only. Slice 3 exposes no write method/control and does not claim the existing database denies every administrative master mutation.
- `anon` and PUBLIC: no table grants.
- `service_role`: SELECT, INSERT, UPDATE, REFERENCES, TRIGGER, TRUNCATE; no DELETE.
- `postgres`: SELECT, INSERT, UPDATE, DELETE, REFERENCES, TRIGGER, TRUNCATE.

**Expected/intentional behavior:** Project Manager can see the Treasury's existing `gl_account_id` while Account details remain hidden. No hidden Account lookup or join is needed. **Hardening opportunity (existing, non-blocking):** trusted-only grant extras are the same category recorded in Slice 2. That note remains unchanged; this observation does not authorize grant hardening in this slice. No blocking read-path defect or schema blocker was found.

## Implemented architecture and behavior

- Added explicit production `ProductionAccount` / `ProductionTreasuryAccount` models typed from generated DB enums, with all 13 / 15 master columns mapped to camelCase. IDs, codes/leading zeros, names, type/status, nulls, booleans, system keys, parent/Project/GL references and actor/timestamps are preserved without demo defaults.
- `readActiveCompanyAccounts` and `readActiveCompanyTreasuryAccounts` select explicit columns, filter `company_id = activeCompanyId`, sort code then ID, normalize query errors, and defensively drop wrong-Company rows. They accept RLS-shaped partial, empty and null result sets; no expected-count assertions, status filters, balances, financial queries, joins or fallback reads exist.
- Reused the existing aggregate provider: Company, Projects, Parties, Categories, Accounts and Treasury load concurrently once per mounted user/Company/role scope. Each resource has a separate reader. Navigation among master routes makes no new read; Treasury label resolution uses the same scoped Account snapshot without another request.
- `findVisibleAccount` resolves only an existing same-Company ID in the authorized snapshot. The UI displays the authoritative parent/GL UUID and, when visible, code/name; otherwise it explicitly says details are unavailable in the current authorized list. A null parent is shown as no parent. No hierarchy, root, GL mapping or missing Account is synthesized.
- `/accounts` and `/treasury-accounts` use existing production navigation and shell. Flat read-only lists show types/status; Accounts show parent, party requirement and non-null system key. Treasury clearly labels its permanent GL link plus actual optional Project ID/bank/reference/notes. Long/mixed-direction references use wrapping and `bdi`.
- Existing aggregate LOADING, ERROR (safe generic message, refresh retry), MISSING_COMPANY, READY populated/legitimate empty states remain. All new copy exists in EN and AR. Existing document direction, P6B branding, language switch, Company selector and logout remain in place.
- P6A supplies the active Company and authoritative role. The keyed provider, synchronous visible-scope guard, generation/mount guards and pre/post-load user-session checks remain. Late old tenant/role/user responses cannot commit; logout/revocation unmount protected state. Same-authority focus/visibility revalidation preserves the mounted tree and snapshots. No new cache, localStorage authority or demo fallback.

Existing limitations: snapshots are not realtime; API row limits/pagination remain deferred and lists make no completeness claim. Assignment-only changes require a new query/refresh, as in Slice 2; routine focus revalidates P6A identity/membership/Company, not assignment snapshots. One failed resource withholds the entire aggregate master snapshot. No balance feature is present or implied.

## Exact file manifest

Added:

- `src/master/accountPresentation.ts`
- `src/master/AccountMasterLists.tsx`
- `docs/P6C_SLICE_3_ACCOUNTS_TREASURY.md`

Changed:

- `src/master/masterTypes.ts`
- `src/master/masterRepositories.ts`
- `src/master/ProductionMasterDataProvider.tsx`
- `src/auth/ProtectedApplication.tsx`
- `src/app/TenantReadyApplication.tsx`
- `src/i18n/en.ts`
- `src/i18n/ar.ts`
- `scripts/verify-p6c-boundary.mjs`
- `scripts/verify-p6c-behavior.mjs`
- `PROJECT_ROADMAP.md`
- `PROJECT_HANDOFF.md`

## Implementation-stage verification evidence (final acceptance below)

- `npm run build`: PASS, existing large demo-chunk advisory only.
- `npm run lint`: PASS, same four established Fast Refresh warnings.
- `npm run verify:p6a-boundary`: PASS.
- `npm run verify:p6c-boundary`: PASS, including existing behavior verification; allowed-table/read-only/secret-marker and production/demo graph checks extended to Accounts/Treasury.
- `node scripts/verify-p6c-behavior.mjs`: PASS. Real transpiled mappers/readers/provider run with controlled adapters: exact metadata/null/enum mapping, partial/empty results, tenant filter, errors, missing Company, six reads per scope, delayed Company/role/user changes, session loss/unmount, and valid Treasury-with-empty-Accounts readiness. Actual React list static rendering checks verify hidden references, system flags, valid empty and no mutation controls.
- Focus/visibility/same-user SIGNED_IN source guards remain verified; unchanged-scope controlled rerenders do not reload. These are not claimed as newly performed authenticated focus/browser tests.
- `git diff --check` and focused changed-file credential scan: PASS.
- Development: read-only catalog queries inspected columns, enum values, constraints, indexes, triggers, helper definitions, RLS flags, policies, permission rows and grants. All 27 migration versions match; linked no-op dry-run passed. No business-row or Auth data was modified; no synthetic fixture created. Authenticated Data API role testing and browser acceptance were not performed.

## Original authenticated browser verification plan (evidence limits below)

1. Use only MakerACC-Development. Separately authorize any needed synthetic fixture setup; none exists for this slice yet. Prepare two Companies with distinct P6B branding and authorized identity/memberships. A should have Account roots/children, all five types, null/non-null system keys, true/false party flags, active/inactive and nullable actor metadata; Treasury should cover all five types with distinct valid ASSET GL links, Company-wide and assigned/unassigned Project rows, nullable bank fields and leading-zero references. B should have empty Accounts/Treasury. Keep the manifest and exact cleanup IDs; do not create financial records.
2. Signed out, open `/accounts` and `/treasury-accounts`: expect login and no protected data. Sign in, select A, visit and directly refresh both routes and the three existing master views. Check exact fixture values, parent UUID/code/name, system flags, Treasury permanent GL UUID and authorized labels, optional fields and inactive status. Check B's legitimate empty state.
3. Exercise all seven roles against the matrix above. For Project Manager verify assigned-project Treasury only, zero Accounts, and GL UUID with unavailable-detail text rather than a missing-mapping error or synthesized name. Without assignment expect zero Treasury; refresh after assignment-only changes. Check no other-Company rows are retrievable with altered URL/query company IDs using the user's authenticated Data API session.
4. Throttle reads to see loading. Delay A Account/Treasury responses, switch to B, release A; verify no A content under B. Repeat B→A, logout while pending, and sign in as a different user. Check refresh restores only an authorized Company. Perform a controlled role downgrade from Accountant to Project Manager/Data Entry; focus authority revalidation must discard the old sensitive snapshot and query the new role scope.
5. Repeatedly leave/return to the tab with unchanged authority. Expect only existing P6A authority reads, no master/settings reload, blocking loader or branding flash. Navigation between Accounts/Treasury must issue no extra Account label query. Then separately revoke synthetic profile/membership/Company, trigger focus, and confirm protected data clears; restore and Retry safely recovers. Record actual network/console evidence.
6. Fail Accounts and Treasury requests separately: safe aggregate error, no stale snapshot/demo fallback/raw server text; remove fault and refresh. Verify missing-Company state with a controlled browser response adapter or an authorized revocation case (P6A may correctly route to no-company first).
7. Check EN/AR, RTL `dir`/`lang`, branding, narrow viewport, keyboard navigation, long names and mixed Arabic/Latin UUID/code/reference text. No mutation controls or financial balances appear. Network permits only Auth/P6A, settings and six master resources; no journal/movement/posting RPC request or private credential. Deferred `/journal`, `/expenses`, `/advances` and Subcontracts remain holding views.
8. Check local-demo independently with existing `cas:v1:*` data unchanged and no production master graph crossover. After acceptance, clean only the separately authorized fixture/Auth/browser state, retain demo data, and record evidence/limitations. Mark only Slice 3 verified if accepted; overall P6C remains incomplete.

## Implementation-stage scope and lifecycle (superseded by final acceptance below)

No Account mutation; no Treasury mutation; no Subcontracts implementation; no financial-flow cutover, journal read or posting RPC access; no balance calculation, opening balances, reconciliation, bank import or Treasury movement/payment. No migration/RLS/grant/P5 change, production localStorage fallback, hosted fixture, Staging/Production action, commit or push.

- Business/accounting: **VERIFIED** for read-only master semantics and unchanged P5 boundary.
- Security/authorization: schema/source/controlled scope evidence **VERIFIED**; authenticated browser role/tenant acceptance **DEFERRED**.
- Database: actual metadata and canonical alignment **VERIFIED**; schema changes **NOT APPLICABLE**.
- Deployment: **NOT APPLICABLE** to this local batch; unchanged browser-safe configuration. Staging/Production **DEFERRED**.
- Testing: automated and hosted metadata **VERIFIED**; authenticated browser/runtime acceptance **DEFERRED**.
- Documentation: **VERIFIED**; roadmap/handoff preserve incomplete P6C and future-only Construction Materials / Site Stores + Tool Custody.

## Final acceptance and cleanup — 2026-09-12

**P6C Slice 3 — VERIFIED COMPLETE.** The user supplied authenticated manual acceptance: MANAGEMENT_VIEWER saw 8 Accounts / 5 Treasury; root/child UUID and labels, CUSTODY_ADVANCE system key, requires_party=true, inactive ASSET/EXPENSE, NULL parent/system fields and Arabic text passed. All five Treasury types, permanent GL UUID/authorized labels, inactive petty cash, correct Project references, absent nullable bank fields and leading-zero references `001234567890` / `000987654321` passed without invented balances.

PROJECT_MANAGER with ACTIVE assignment saw 0 Accounts / 2 project Treasury; real GL UUIDs remained while hidden Account codes/names did not leak. INACTIVE assignment yielded 0/0; ACTIVE was restored. SYSTEM_ADMIN saw 0/0. Restoring MANAGEMENT_VIEWER recovered 8/5; Alpha→Beta showed Beta branding and 0 Projects/Accounts/Treasury without Alpha leakage. Repeated Beta tab-away/return retained the Company and presentation without secure-loading interruption, presentation-loading interruption, branding flash or stale Alpha content.

The user executed the guarded cleanup successfully, verified zero fixture database counts and global 14 Companies/14 settings with zero missing/orphan rows, then manually removed Auth user `dc9ad1f5-804d-4f33-ab65-5e796fec0616` / `p6c-slice3-user@example.test`. Final read-only Development verification independently reconfirmed all fixture counts zero and Auth absence. No fixture is currently present; operational scripts are retained as historical/reusable documentation, not live setup or migrations.

Final build, lint, P6A/P6C boundaries (including existing controlled behavior and list-rendering verification), focused credential/boundary scans and diff checks pass. Lint retains four established Fast Refresh warnings; build retains its demo chunk-size advisory. All 27 local/Development migrations align through `20260911123000`; linked dry-run is a no-op. No unrelated change or blocking defect was found. One local checkpoint is authorized; pushing remains the user's action.

Evidence limits: acceptance uses the supplied representative browser cases plus existing controlled tests and schema/source review. Separate Accounting Admin/Accountant/Data Entry/Procurement browser runs, timed browser races, error injection, exhaustive RTL/keyboard/direct-route tests and detailed network-request counts were not supplied and are not newly claimed. Pagination/realtime and assignment-only snapshot refresh limitations remain documented. The trusted service_role grant hardening note remains unchanged and non-blocking. Overall P6C remains incomplete; the next slice, Subcontracts, P6D and P6E have not started. No migration, RLS/grant change, financial-flow cutover or Staging/Production action occurred; no push.

Final lifecycle: business/accounting **VERIFIED** (read-only); security/authorization **VERIFIED** for inspected boundaries and representative authenticated acceptance; database **VERIFIED** (aligned history and cleaned fixture); testing **VERIFIED** with the explicit evidence limits above; documentation **VERIFIED**. Deployment **NOT APPLICABLE** to this checkpoint; Staging/Production and full production readiness **DEFERRED**. Development slice completion is not production readiness.
