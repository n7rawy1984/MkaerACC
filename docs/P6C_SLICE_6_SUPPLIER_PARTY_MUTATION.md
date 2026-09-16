# P6C Slice 6 — Supplier Party MUTATION — VERIFIED COMPLETE

Development acceptance closed on 2026-09-16. Overall P6C remains IN PROGRESS. P6D/P6E and other master mutation slices remain unstarted. Release/production readiness is deferred.

## Authorization, baseline and lifecycle

Implementation began from clean `main` at `049447c43b12554b949f81d80d0ca50e60714fd8`, equal to origin/main. Prior source review found no authenticated production non-Supplier Party writer: demo writes are isolated in localStorage, and P5 commands only reference/validate/lock Parties. Supplier-only narrowing was authorized and is now applied and verified in Development. Final evidence below supersedes the earlier implementation-only and live-fixture states.

## Business and schema boundary

Only `public.parties`, type SUPPLIER: single create; edit name/code/TRN/contact/phone/email/address/notes; deactivate/reactivate. Inactive Suppliers remain visible under existing reads and editable by authorized managers. No delete, upsert, bulk operation, merge, type conversion, Customer model, other master mutation, balance, financial write or RPC. No zero-payable condition is added. P5 new-activity/settlement semantics remain unchanged.

The six Party types remain OWNER/CUSTODIAN/SUPPLIER/EMPLOYEE/SUBCONTRACTOR/OTHER. No new table or generated row shape. Existing primary/composite keys, Company/actor restrictive FKs, all incoming financial/contract references, tenant immutability and subcontractor-type guard remain intact.

Normalize Supplier text at DB and repository boundaries: outer whitespace uses exactly JavaScript String.trim's whitespace/line-terminator set, spelled out in the Party trigger; internal text/case/Unicode/phone punctuation/leading zeros remain. Name is required 1–200 Unicode characters; optional code becomes NULL when blank, otherwise at most 50 characters. Optional TRN/contact/phone/email/address/notes become NULL when blank. TRN/phone remain text; no jurisdiction-specific validation or additional uniqueness is invented. Existing `(company_id, lower(btrim(code))) WHERE code IS NOT NULL` uniqueness still spans every type and status. Duplicate names/null codes and cross-Company codes remain valid. Collision UI never identifies a hidden Party.

## One applied canonical migration

`20260913123000_p6c_supplier_party_mutations.sql` follows the 28-version baseline ending `20260913120000`. The 29-version history is aligned locally/remotely in MakerACC-Development; the final linked dry-run is a no-op. The applied migration is unchanged during closure.

- Revoke broad authenticated INSERT/UPDATE plus DELETE/TRUNCATE; INSERT only company_id/name/code/trn/contact_person/phone/email/address/notes; UPDATE only name/code/trn/contact_person/phone/email/address/notes/status. Assert effective table/column privileges, including inheritance.
- Add restrictive authenticated Supplier-only INSERT and UPDATE policies. These AND with existing P4 manager policies, which require party.manage and the allowed role scope. Both UPDATE USING and WITH CHECK require Supplier. SELECT and permission maps remain unchanged. Merely adding permissive policies would not narrow P4.
- Only active ACCOUNTING_ADMIN and PROCUREMENT can mutate Suppliers. ACCOUNTANT/DATA_ENTRY/MANAGEMENT_VIEWER/PROJECT_MANAGER/SYSTEM_ADMIN, anon, inactive profile/membership/Company and unrelated tenants remain denied.
- Browser creation cannot specify id/type/status/actors/timestamps. The trigger sets type SUPPLIER and status ACTIVE; UUID default remains DB-owned. No global Supplier default. company_id is untrusted creation scope supplied from resolved context, never a form field or UPDATE field; RLS authorizes it.
- Drop only parties_set_updated_at; replace it with one invoker-security Party-local preparation trigger/function, fixed empty search_path, direct EXECUTE revoked from PUBLIC/anon/authenticated/service_role. Preserve the tenant and subcontractor guard triggers; shared public.set_updated_at and every other entity are unchanged.

## Provenance and token ownership

Authenticated INSERT is identified by current_user='authenticated', not JWT presence: both actors derive from auth.uid(), and both timestamps share a database clock reading. Authenticated UPDATE preserves creation provenance and stamps updated_by. Supplier-touching updates (old or new Supplier) reject changed created_by/created_at and set `greatest(clock_timestamp(), OLD.updated_at + interval '1 microsecond')`, including trusted/no-op updates. Trusted Supplier INSERT retains supplied/null actors and historical timestamps; trusted UPDATE retains supplied/null update actor without fabricating browser provenance. No backfill.

Trusted non-Supplier INSERT returns its existing input/defaults unchanged. Updates where neither old nor new type is Supplier retain the previous now()-owned update timestamp and do not receive Supplier normalization/provenance restrictions. Trusted type transitions touching a Supplier get the Supplier token/creation protection; the pre-existing referenced-Subcontractor type guard still applies independently. Browser type changes have no column privilege.

## Repository and frontend

`supplierPartyMutations.ts` defines only Supplier commands and normalized allowlisted business inputs, reusing mapPartyRow. Generated Insert types require type because the shared column has no default; one documented type assertion bridges the trigger-generated value without adding a runtime payload property. No generated file is hand-edited.

Every UPDATE filters Company + UUID + type SUPPLIER + exact updated_at string; no JS Date conversion. Exactly one matching Supplier row is required. Safe invalid/duplicate/denied/conflict/uncertain errors never display server detail. Zero rows is conflict/unavailability, never success. No retry/idempotency ledger; an uncertain create must be refreshed/reviewed before deliberate resubmission, especially with optional codes.

Existing `/parties` mounts extracted PartiesList, preserving all authorized read types and plain-text fields. Only Accounting Admin/Procurement see Create supplier and Supplier-row edit/status actions. SupplierPartyForm has eight metadata fields; no Company/type/status-on-create/actors/timestamps. Status changes require confirmation. EN/AR/RTL, keyboard labels, wrapping, nulls and leading zeros are preserved. Demo routes/storage and financial holding routes are untouched.

The existing provider adds independent supplierMutation/saveSupplierParty/refreshParties, lock and request generation. Successful save rereads only Parties; category operation state and resources are independent and use functional state merges. Scope/session/unmount guards prevent old responses entering another user/Company/role; keyed providers invalidate forms. Existing P6A focus/visibility and branding are unchanged, with no new revalidation handler or whole-master refresh.

Errors block saves until explicit refresh/review. A confirmed write followed by failed refresh remains distinctly REFRESH_ERROR, including another failed recovery read. A plain refresh failure never claims a committed write. Closing/navigating/logout cannot reverse a request already committed in its original authorized Company.

## Final accepted evidence — 2026-09-16

The user completed the final database, authenticated browser and local verification externally and supplied the accepted results below. This documentation closure records that evidence; it does not claim a new execution of those checks.

- **Hosted database: 104/104 PASS.** Migration `20260913123000_p6c_supplier_party_mutations.sql` is applied to MakerACC-Development only. Local/remote migration history is aligned; final linked dry-run: **Remote database is up to date**.
- **Concurrency: PASS.** Competing creates produced one success and one SQLSTATE `23505`; competing edits from the same exact token affected **1** and **0** rows. Final state was verified and the concurrency fixture fully cleaned.
- **Authenticated browser: PASS.** ACCOUNTING_ADMIN create/edit/deactivate/reactivate; PROCUREMENT controls/deactivate/reactivate; MANAGEMENT_VIEWER read-only; non-Supplier rows without controls; Alpha/Beta isolation; duplicate rejection; two-tab stale-edit conflict; refresh recovery; role downgrade during open edit; membership revocation fail-closed; profile revocation to `/no-company`; focus/tab return without blocking “Loading securely”, unnecessary master reloads or stale tenant/branding flash; Arabic/RTL and Supplier-only rendering.
- **Local gates: PASS.** Build (only the existing Vite >500k demo-chunk advisory); lint (exactly four pre-existing Fast Refresh warnings, zero errors); Supplier Chromium interaction regression; P6A boundary; P6C boundary; P6C behavior; `git diff --check`; focused real-secret scan.
- **Cleanup: VERIFIED.** Fixture Companies/settings/memberships/Parties/profile/Auth user are all **0**. Global Companies **14**, settings **14**, missing settings **0**, orphan settings **0**. Browser cleanup used the exact generated Party UUID manifest; no broad deletes or CASCADE cleanup. Both cleanup scripts retain the PL/pgSQL ambiguity correction from `companies` to `fixture_companies`. No fixture remains live.

Business/accounting scope, security/authorization, Development database/migration, testing and documentation: **VERIFIED**. Development environment boundary and migration acceptance: **VERIFIED**. Staging/Production action: **NOT APPLICABLE** (none occurred). Frontend release, production readiness and the full pre-production audit: **DEFERRED** to their later gates. No P6D/financial mutation path was introduced; P6D remains **NOT STARTED**. Overall P6C remains **IN PROGRESS**; Slice 7 was not started.

## File manifest

Added: the one canonical migration; src/master/supplierPartyMutations.ts, SupplierPartyForm.tsx, PartiesList.tsx; this phase record; docs/verification/p6c-slice6/README.md, preflight.sql, hosted-checks.sql, concurrency-setup.sql, concurrency-create-1.sql, concurrency-create-2.sql, concurrency-edit-1.sql, concurrency-edit-2.sql, concurrency-verify.sql, concurrency-cleanup.sql, browser-setup.sql, browser-role.sql, browser-cleanup.sql, verify.sql.

Modified: src/master/ProductionMasterDataProvider.tsx, masterTypes.ts; src/app/TenantReadyApplication.tsx; src/i18n/en.ts, ar.ts; scripts/verify-p6c-boundary.mjs, verify-p6c-behavior.mjs; PROJECT_ROADMAP.md, PROJECT_HANDOFF.md, docs/P4_AUTHORIZATION.md. Also added: `scripts/verify-p6c-supplier-interactions.mjs` and `scripts/fixtures/p6c-supplier-interactions.tsx`. `package.json` and `package-lock.json` declare pinned Playwright 1.62.1 as a development dependency only. The existing context module and Party reader/mapper required no edits.

## Readiness and deferrals

Slice 6 is VERIFIED COMPLETE in Development. Staging/Production/release, pagination/realtime, P7 audit, full production readiness, trusted-only grant-extra review, other Party mutation types, and P6D/P6E remain deferred. Conditional optimistic concurrency is an application request contract; arbitrary authorized SQL is not forced to provide a token. Direct custom SQL upsert is not a supported browser API; no general SQL command framework is added.

## Browser QA correction and regression coverage

Confirmed UI defect: row Edit/status handlers set the correct local state, but both panels rendered above the entire Party list with no focus/scroll transition. In isolated Chromium at a 1000×650 viewport, clicking the last Supplier opened its populated edit form at y=-3997 and status confirmation at y=-3314; focus remained outside the form. Create was near the top panel and therefore appeared to work. No missing callback, no-op context wrapper, permission-gate defect or repository update failure was found in the traced current code. TenantReadyApplication only routes/renders the list; selection state correctly belongs to PartiesList.

Correction: render Edit and status confirmation within the selected Party row; retain create at the list start. The form mounts with the selected Supplier snapshot (including exact original updated_at) and focuses the name field/scrolls the panel into view. Status opens a labeled focusable inline confirmation; explicit Confirm still sends a single status command. Cancel/success returns focus to the initiating control. Error/recovery feedback is beside the active action, receives focus, and includes a local Refresh action. No provider/repository/RLS/concurrency changes were needed. Existing scope keys and stale-result guards invalidate form/feedback across tenant/role/user/logout; unchanged focus retains the draft/snapshot.

Why prior tests missed it: renderToStaticMarkup asserted action labels/role gates, while controlled provider and repository tests invoked commands independently. Neither clicked actual DOM buttons, mounted the form after a row click, nor checked viewport/focus. All could pass with an offscreen action panel.

Added `scripts/verify-p6c-supplier-interactions.mjs` plus isolated `scripts/fixtures/p6c-supplier-interactions.tsx`. Actual React route shell/list/form/provider/context/readers/mutation repository run in Chromium against an in-memory Supabase-shaped transport and stubbed authority/branding/localization. No real Auth session or database is used; non-local browser requests are blocked. It verifies lower-row click and keyboard opening, prefilled metadata, exact-token edit and Parties-only refresh, confirmed status transitions/labels, cancellation/focus return, stale conflict, pending state, committed-write/read-failure recovery, Create protected-field absence, allowed/denied role controls, non-Supplier controls, draft preservation on unchanged rerender/focus, late writes across Company/role/user/logout, and narrow RTL panel visibility. This is local browser interaction evidence, not new authenticated hosted acceptance or a replacement for P6A authority tests.

Final Chromium regression and authenticated acceptance both PASS. Create remained intact. The behavior script reports when browser interaction coverage is not run and supports `P6C_BROWSER_INTERACTIONS=1`. The initial undeclared external Playwright dependency was corrected by pinning Playwright 1.62.1 in devDependencies and using a normal import. The fixture controller now lives outside React rendering and uses `useSyncExternalStore`; its component is exported, restoring lint to the four baseline warnings without suppressions. No runtime dependency was added. All disposable hosted fixtures have been cleaned as recorded above.
