# V1 Treasury master provisioning — Development implementation complete

2026-10-08. Treasury master data only. No real Company, platform administrator, Treasury, opening balance, funding/inflow, receipt, transfer, Expense, payment or journal created. No XLSX import. Authorized local delivery is recorded below; no push. Staging/Production untouched.

## Architecture and bounded gap

Production Treasury reads and ACCOUNTING_ADMIN name edits already existed. Direct browser INSERT was intentionally revoked by P6C Slice 10; only name UPDATE is granted. There was no production creation or status workflow. Reuse all current read/name infrastructure and add only narrow creation/status commands and EN/AR forms in `/treasury-accounts`.

Existing schema: Company, optional Project, code/name, CASH/PETTY_CASH/BANK/PROJECT_CASH_BOX/PROJECT_BANK, permanent GL account, ACTIVE/INACTIVE, optional bank_name/account_reference/notes and provenance. These are existing fields; no description, IBAN, currency, opening balance or financial inputs added. The existing account_reference field is retained without inventing a new bank-account model. No Chart of Accounts creation or redesign.

## Database and authority

Forward canonical migration `20261008120000_v1_treasury_master_provisioning.sql` adds:

- `create_treasury_master(uuid,jsonb)`: rejects unknown/non-string business inputs, Unicode-trims fields, requires code/name/type/GL and derives actor/timestamps. Defaults status ACTIVE. Locks authoritative same-Company GL and optional Project during validation. Optional Project must exist in that Company and not be CLOSED, following current master-creation conventions.
- `set_treasury_master_status(uuid,uuid,account_status,timestamptz)`: locks the same-Company Treasury, rejects stale updated_at, changes status only and attributes the actor. No delete or remapping API. Existing name updates remain unchanged.

Both require the authenticated active actor/profile/Company membership and exact ACCOUNTING_ADMIN plus existing `treasury.manage`. ACCOUNTANT, MANAGEMENT_VIEWER, PROJECT_MANAGER, SYSTEM_ADMIN, PROCUREMENT, DATA_ENTRY and FOREMAN gain no mutation permission; platform status is no accounting bypass. Both SECURITY DEFINER functions have a fixed empty search_path and authenticated-only EXECUTE; PUBLIC/anon/service_role execution is revoked. Existing forced RLS, read visibility and name-only DML grants remain intact.

Existing database invariant permanently forbids Company/GL reassignment even for trusted UPDATE. Composite FK requires the GL to belong to the Company; the existing trigger requires ASSET. The new creation command additionally requires ACTIVE and excludes reserved system/subledger (`system_key`) and Party-dependent (`requires_party`) accounts, so new money locations use ordinary Asset GL accounts. This is a provisioning restriction, not a rewrite of old mappings or payment validation. No new leaf-account or chart policy is invented.

The existing unique GL constraint reserves each account for one Treasury, including inactive Treasury; GL IDs are globally unique Company-owned identities, so this does not create global code/name uniqueness. The existing code index enforces `(company_id,lower(btrim(code)))`; the new command normalizes surrounding Unicode whitespace before insertion. Codes remain reserved when inactive, other Companies can reuse a code, and names are not merged. Unique constraints deterministically arbitrate duplicate/racing inserts. Creation has no financial idempotency/document/journal path; uncertain results require authoritative refresh before retrying.

All existing referenced-history FKs use RESTRICT/NO ACTION, browser DELETE remains denied and status changes retain identity/GL. Status never rewrites accounting history. Code/type/Project/GL/bank metadata are creation inputs and remain outside browser edits; maintenance supports existing name edits and the new status command only.

## UI and consumers

`TreasuryMasterPanel` uses eligible unused GL options from the existing Company-scoped master read, optional visible Project, existing types/status and optional metadata. No balance/funding field or financial RPC. Required fields, EN/AR labels, 390px RTL layout, submission locking, authority/session-scoped remounting, stale-token/duplicate/denied error handling, uncertain-result recovery and authoritative Treasury refresh are included. Server validation remains authoritative if options become stale. No suitable GL leaves creation disabled with a prerequisite explanation. Inactive mappings remain excluded from GL options.

Existing Expense/Supplier/Subcontractor payment selectors retain Company/ACTIVE/Asset and applicable Project rules. Payroll retains its Company/ACTIVE Treasury context and Project-scoped payment selection. No consumer, posting/reversal function, recognition rule, balance or settlement behavior is modified. GL status and existing payment eligibility remain governed by those unchanged consumers; setting Treasury ACTIVE does not override them.

## Applied Development state and evidence

- Confirmed linked MakerACC-Development, ref `eqnzueginpkskbnqvgoc`. Pre-apply 49 canonical versions aligned, with only this migration pending; linked dry-run proposed it alone. Canonical `db push --linked --yes` applied only `20261008120000`, no seeds/roles. Final all **50** versions align and dry-run is a no-op. No manual durable schema patch.
- **71 hosted checks PASS before and after apply**; the final matrix extends to **74 PASS** with actual Payroll Treasury-context reads (active visibility, inactive exclusion and cross-Company denial). Pre-apply canonical DDL rehearsal and all synthetic Auth/Company/Project/GL/Treasury fixtures rolled back. Separate post-apply read-only check proves zero retained identities, Companies and Treasury fixtures. These are SQL-role checks, not hosted password-login acceptance.
- Coverage: admin creation/name/status; all seven non-admin role denials; inactive actor/membership/Company; cross-Company creation/status/GL/Project; invalid/missing/inactive/non-Asset/Party/system GL; invalid type/status/UUID/blank/forged/balance/funding inputs; normalized duplicate code and GL; inactive mapping reservation; stale token; same code in another authorized Company; permanent remapping; forced RLS, no broad browser writes, fixed search_path/minimal RPC grants and non-cascading history references.
- Existing Company/membership/GL/Treasury/Expense/Supplier Payment/Salary Payment/Subcontractor Payment/journal entry/journal line fingerprints are identical before/after application. All existing public/private function definitions and grants have identical fingerprints. Fixture GL rows are unchanged by creation/status. No Expense, payment, journal or financial command request INSERT is executed by the tests or commands; account balances derived from journals are unchanged.
- Isolated actual forms/Auth/master providers PASS: create Cash and Bank, status change, authoritative readback, eligible GL filtering, inactive mapping reservation, non-admin controls, EN/AR and **390px RTL** without overflow/page errors; exact two master RPCs only, remote requests blocked. This uses in-memory adapters, not hosted signed-in acceptance.
- Current TypeScript/build and focused touched-file oxlint PASS; existing chunk-size advisory informational. Whitespace, focused secret and exact checkpoint file-scope review PASS. No unrelated broad tests/audit.

## Readiness and deferrals

Business/accounting: VERIFIED master-only zero accounting effects. Security/authorization: VERIFIED focused actor/role/tenant/grant boundaries; full Production audit DEFERRED. Database: VERIFIED forward migration applied to Development, alignment, rollback checks and unchanged historical mappings/data. Deployment: VERIFIED Development schema; application deployment and hosted signed-in acceptance DEFERRED. Migration must precede the new UI. Testing: VERIFIED scoped hosted/source/browser/type/build/lint evidence with the stated limitations. Documentation: VERIFIED this record and handoff/roadmap.

Real Treasury creation remains blocked by the absent real Company and authorized operator, suitable real Company-owned GL provisioning and approved Treasury inputs/scopes. No real records are created by this checkpoint. General funding/inflow and opening-balance workflows remain separate product gaps; existing specialized receipts/returns and reversal paths do not establish a general funding/onboarding workflow. No implementation of those events is included, and this checkpoint is not Production readiness.

Files: PROJECT_HANDOFF.md, PROJECT_ROADMAP.md, this record; src/i18n/en.ts, src/i18n/ar.ts; src/master/TreasuryNamesPanel.tsx, TreasuryMasterPanel.tsx, treasuryMasterRepository.ts; scripts/fixtures/treasury-master-client.ts, treasury-master.tsx; scripts/verify-treasury-master-browser.mjs; scripts/sql/treasury-master-provisioning/hosted-checks.sql; the one canonical migration above.

## Authorized checkpoint closure

Documentation reconciled with the final applied Development state. Migration `20261008120000` is applied only to MakerACC-Development; Staging/Production remain untouched. Recorded 50-version alignment, no-op dry-run, 71 pre/post-apply checks and final 74-check matrix remain the verification evidence. Closure reviews exactly the approved 13 files, makes no implementation changes and performs no test reruns or hosted actions. Delivery is exactly one local commit, `Add treasury master provisioning`; no push. Funding, inflows, opening balances and real-data work remain outside this checkpoint.
