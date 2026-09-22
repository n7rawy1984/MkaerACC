# P6C Slice 11 — OTHER Party Display Name UPDATE

**VERIFIED COMPLETE.** P6C **IN PROGRESS**; P6D/P6E **NOT STARTED**; production readiness **DEFERRED**. Development only. Authenticated browser acceptance and exact guarded cleanup PASS; no Staging/Production action or Slice 12.

## Selection and scope

Started at clean HEAD/origin/main `13809a83a65c62ccef81e4dc78884f5cb9bc9079`; Slices 1–10 remain VERIFIED COMPLETE. Selected the smallest useful remaining low-coupling Party mutation: existing OTHER display names, including ACTIVE and INACTIVE rows. ACCOUNTING_ADMIN and PROCUREMENT use unchanged `party.manage` semantics. Trim JavaScript boundary whitespace, require 1–200 Unicode characters, preserve internal spacing/case.

Only `parties.name` for existing OTHER rows. Exclude creation/deletion, status, type, code, TRN/contact/address/notes, Company/identity/provenance/timestamps and other Party types. Supplier's already-completed create/metadata/status contract remains unchanged. No GL, journal, ledger, balance/opening balance, payment, expense, receivable/payable, transfer, settlement, subcontract or posting behavior. No financial historical truth changes.

## Database and authorization

Canonical `20260921130000_p6c_other_party_name.sql` applied only to MakerACC-Development (`eqnzueginpkskbnqvgoc`). Before applying: all 33 migrations aligned; exact Party columns/constraints/indexes/triggers/functions/grants/forced RLS matched canonical history; global Companies/settings 14/14, missing/orphan 0/0. Dry-run listed only this migration. No material drift.

The restrictive UPDATE policy now permits SUPPLIER or OTHER, ANDed with unchanged P4 permission/role policies. INSERT remains Supplier-only. No grants widened: existing exact Supplier metadata/status column grants remain necessary. PostgreSQL column grants are table-wide, so an additional SECURITY INVOKER trigger enforces OTHER's name-only restriction even against direct authenticated calls. It compares all fields except name and the earlier trigger's timestamp; rejects changes to protected fields, derives `updated_by` from `auth.uid()`, normalizes name, and uses `greatest(clock_timestamp(), old.updated_at + 1 microsecond)`.

Trigger ordering is explicit: `parties_prepare_z_other_name` runs after unchanged Slice 6 `parties_prepare_supplier_mutation`, which previously sets non-Supplier tokens to `now()`. The new trigger overrides that timestamp for all OTHER updates after forward correction `20260921133000`, including trusted writes. Only authenticated writes receive the name-only guard and actor derivation. Existing Supplier function, INSERT path, tenant guard, subcontractor-type validator, constraints/indexes, FORCE RLS, SELECT policies, role mappings and trusted/service provisioning privileges and INSERT behavior are unchanged. No direct PUBLIC/anon/authenticated/service-role EXECUTE, new browser RPC, broad writes or DELETE/TRUNCATE grants. Prior trusted TRUNCATE/REFERENCES/TRIGGER privileges are unchanged. No generated row-type change is required.

Focused review confirmed a token defect in the initial migration: trusted OTHER updates could move a future token backwards via the old `now()` trigger. The added rollback regression reproduced `FAIL trusted token monotonic`. Applied forward-only correction `20260921133000_p6c_other_party_trusted_token.sql` after a single-correction linked dry-run; rerunning the focused suite passed 108/108, including trusted future-token advancement. No applied migration was rewritten.

Security classification: this confirmed token defect is resolved; the newly authorized OTHER name path is expected/intentional behavior. Hosted checks confirm no protected-field or type bypass; no unresolved confirmed defect. Full Production Security & Accounting Integrity Audit remains deferred.

## Frontend behavior

Explicit repository builds `{name}` only and filters Company + OTHER type + ID + exact loaded `updated_at`. Zero rows means conflict/authority loss; no silent retry. Provider checks current user/session/scope before and after writes/reads; generation guards discard late results on Company/user/role/logout/unmount transitions. Only Parties refresh; all other resources retain their snapshots. Separate mutation feedback preserves uncertain-write versus committed-write/failed-read recovery. Supplier and OTHER operations mutually exclude concurrent writes/refreshes to their shared Party resource.

Inline populated row form, one selected OTHER row, keyboard open/save/close, focus restoration/error focus, EN/AR/RTL and narrow layout. Existing Party details remain readable under RLS, and Supplier controls stay type-specific. Global refresh also keeps OTHER recovery errors visible when the row panel closes. Auth authority revalidation remains the existing focus/tab-return behavior; the database immediately enforces revocation while an unchanged tab may retain its loaded snapshot until refresh.

## Verified automated evidence

- Hosted rollback suite **108/108 PASS**: FORCE RLS, exact unchanged column grants, no direct trigger EXECUTE, fixed empty search_path/invoker, both allowed roles and five denied roles, cross-tenant read/write isolation, inactive profile/membership/Company, every protected column, normalization/Unicode bounds, actor/provenance, future/no-op/stale tokens, other-type denial and trusted provisioning. Focused Supplier create/metadata/status/normalization/actor regression passed in this suite; no historical hosted suites rerun.
- Two concurrently launched exact-token updates returned **1/0**; winner actor and advanced token verified. Guarded fixture cleanup removed only disposable Company/Party/membership/settings; existing synthetic actor/profile retained. No Auth user created.
- Repository/provider behavior **PASS**: strict name payload, exact token/type filter, allowed/denied roles, duplicate submission, delayed write/read isolation across Company/role/user/logout/unmount, selective refresh, conflict/denial/uncertainty/known-commit recovery and shared Supplier/OTHER resource serialization. Existing small master-provider regressions pass through the current boundary gate.
- Real isolated **Slice 11 Chromium PASS**: actual Auth/settings/master providers/shell/form, populated lower-row keyboard/focus, exact name-only payload and token, inactive rename, Procurement, denied controls, stale conflicts, row/global failed-refresh recovery, tenant/delayed-save isolation, open-edit downgrade, tab-return drafts, profile revocation/logout, Arabic/RTL/390px.
- Directly affected **Supplier Chromium PASS**, including edit/create/status, exact tokens, role/type controls, cancellation/focus, resource-only refresh and delayed-result isolation. Its obsolete assertion that OTHER has no buttons was updated to require no Supplier controls and exactly the new OTHER rename action.
- Build **PASS**, lint **0 errors / 4 existing warnings**, P6A/P6C boundaries/behavior **PASS**. Existing demo bundle-size advisory only. `git diff --check` and focused changed-file real-secret scan **PASS**; no credentials stored.
- Public DB lint **clean**. All **35 migrations aligned**; final linked dry-run **up to date**.
- Final read-only integrity: fixture Companies/Parties/memberships/browser Auth **0**; global Companies/settings **14/14**, missing/orphan **0/0**.

Initial local test harness needed the new control import mocked for the existing Supplier-only static-render assertions; real new-control coverage is in Chromium. Localhost Chromium required sandbox escalation. These were verification setup issues, corrected before final passing gates.

## Lifecycle classification and accepted gate

| Category | Classification | Evidence / deferred work |
|---|---|---|
| Business/accounting | VERIFIED | Approved descriptive name scope; financial behavior NOT APPLICABLE |
| Security/authorization | VERIFIED | Hosted grants/RLS/forgery/isolation plus authenticated browser acceptance PASS |
| Database | VERIFIED | Canonical Development migration, catalog review, hosted checks, concurrency, lint/alignment/dry-run |
| Deployment | VERIFIED Development boundary; DEFERRED release | No Staging/Production action; production readiness deferred |
| Testing | VERIFIED | Automated gates plus authenticated browser acceptance and guarded fixture cleanup PASS |
| Documentation | VERIFIED | Handoff/roadmap/authorization/phase/fixture records describe actual state |

Authenticated browser acceptance is COMPLETE. Real hosted acceptance covered ACCOUNTING_ADMIN and PROCUREMENT ACTIVE/INACTIVE OTHER name edits; OTHER-only mutation boundaries and protected fields; validation/normalization; stale two-tab conflict without overwrite/retry; Alpha/Beta isolation; complete role matrix; open-edit downgrade; Company/membership/profile revocation and restoration; keyboard/focus/tab-return draft preservation. The earlier automated Chromium 390px scrollWidth report was not reproduced in the real Chrome UI: manual Arabic/RTL responsive verification at 394px with the same valid 200-character unbroken OTHER name wrapped inside the Party card without user-visible horizontal page overflow, so no CSS change was made. Procurement ACTIVE and INACTIVE OTHER rename checks also passed manually. Exact guarded cleanup completed and final verification returned all Slice 11 fixture/Auth counts 0, global Companies/settings 14/14, missing/orphan 0/0. Supplier behavior remains covered by the already-passed directly affected automated regression.

## Files changed/created

Created:

- `src/master/otherPartyNameMutations.ts`, `OtherPartyNameForm.tsx`, `OtherPartyNameControl.tsx`.
- `supabase/migrations/20260921130000_p6c_other_party_name.sql` and `20260921133000_p6c_other_party_trusted_token.sql`.
- `scripts/fixtures/p6c-other-party-name-interactions.tsx`, `scripts/verify-p6c-other-party-name-interactions.mjs`.
- `scripts/sql/p6c-slice11/{hosted-checks,concurrency-setup,concurrency-edit-1,concurrency-edit-2,concurrency-verify,concurrency-cleanup}.sql`.
- `docs/verification/p6c-slice11/{preflight,browser-setup,browser-role,browser-authority,browser-cleanup,verify}.sql`, `README.md`; this phase record.

Updated:

- `src/master/{PartiesList.tsx,ProductionMasterDataProvider.tsx,masterTypes.ts}`; `src/i18n/{en,ar}.ts`.
- `scripts/verify-p6c-{boundary,behavior,supplier-interactions}.mjs`.
- `PROJECT_HANDOFF.md`, `PROJECT_ROADMAP.md`, `docs/P4_AUTHORIZATION.md`.
