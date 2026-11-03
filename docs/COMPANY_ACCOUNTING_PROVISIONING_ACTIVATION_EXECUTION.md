# Development accounting provisioning activation — execution

2026-11-01. **DEVELOPMENT ACTIVATION VERIFIED / AUTHENTICATED OWNER UI PASS / NO COMPANY PROVISIONING.** [Secret-free execution evidence](release/development-company-accounting-activation-execution-result.json). Separate owner authorization covered the single migration, one pinned Preview deployment and read-only checks. [Approved plan](COMPANY_ACCOUNTING_PROVISIONING_ACTIVATION.md); [completed native race gate](COMPANY_ACCOUNTING_PROVISIONING_RACES.md).

## Migration and hosted postflight

- Target: `eqnzueginpkskbnqvgoc` / MakerACC-Development, verified healthy and linked correctly.
- Single migration: `20261101120000_company_accounting_provisioning.sql`; exact SHA256 `2058d940ba7f6f932eba64065f515edf67a333c89475c14e307c7d14a2e1545e`.
- Accepted14 implementation/package/test hashes and six-scenario native race gate verified unchanged. Fresh62-version alignment and preservation baseline passed.
- Linked dry-run listed only the approved migration, no seeds or custom roles. Applied once through canonical CLI tooling; exit0. Migration history now exactly63 local/remote versions.
- Used `--skip-vault` for dry-run and apply because installed CLI explicitly documents default Vault synchronization. No Vault/configuration update was included. The first CLI help lookup encountered the workspace sandbox's local telemetry write restriction; the permitted help invocation outside that filesystem restriction succeeded. This was tooling setup, not a failed migration/environment guard or a deployment retry.
- Read-only postflight verified both hosted RPC bodies exactly match the migration's dollar-quoted source, fixed empty search_path, SECURITY DEFINER and authenticated-only execution; anon/service_role cannot execute. Private provisioning table has forced RLS and no browser/service-role SELECT/INSERT/UPDATE/DELETE grants.
- All existing public/private table RLS/grants, policies and function bodies/grants match the preflight catalog. Existing account/Treasury indexes and system-key enum mappings match. The setup constraint accepts INCOMPLETE/COMPLETE.
- Zero provisioning records. The mutating provisioning RPC was never invoked, including for smoke checks. No accounts, Treasury, references, journals, balances, opening entries or business records were created.
- All17 historical Companies and count/fingerprint checks over46 public Company-owned tables match. Stage D remains ACTIVE/version3/INCOMPLETE with the exact existing single ACTIVE ACCOUNTING_ADMIN membership and ACCEPTED invitation.
- Full Auth configuration, secret metadata and Edge Function metadata fingerprints match preflight. Invitation delivery, origin, Auth templates, MFA and SMTP remain unchanged.

## Preview deployment

- Uploaded only the approved247-file source package after exact SHA256 closure and CLI dry upload SHA1/file-list verification:247 files,0 ignored. Source digest `6d7ac5f6ef780a0db5575338c6edab9fba8dad596cf0d27929fda601845db239`.
- Existing project `prj_n03DWya5Gr1uB82qtY084FvsC7q4`, team `team_HozmwrkzbERtyer2nIT25MWv`, explicit Preview environment, verified existing Development browser variables. No Git metadata or environment files uploaded.
- **One submission only** via pinned Vercel CLI65.9.0. Deployment `dpl_5EPhWmzaPyjjdJ9Vfd9LYkiWiLY2`, READY.
- New Preview: **https://maker-bkylvumek-n7rawy1984-8059s-projects.vercel.app**.
- Read-only GET checks for `/`, `/platform/entities` and `/auth/callback` return302 to Vercel authentication, with no deployment-error page. This verifies protection/route delivery, not signed-in business behavior.
- In a new tab of the existing owner Chrome window, Vercel protection passes and NARVO renders its sign-in screen. Private owner sign-in/MFA was completed and the owner replied Ready. Before interruption the authenticated Accounting Entities heading had loaded; the resumed read-only checks below complete the row/form review. No credentials were requested in chat and no provisioning submission occurred.
- Actual Production alias `maker-eosin.vercel.app` remains on `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`. All environment entries, protection and Git/main configuration match preflight. Provider `aliasAssigned=true` with an empty returned alias list is retained as metadata; actual Production alias lookup proves it did not move to this Preview. No alias/settings command was used.

## Remaining acceptance and stop boundary

**Authenticated owner UI smoke is now VERIFIED.** The preserved owner session was reused on the confirmed new Preview. Exact code filtering showed the Stage D Company ACTIVE, Administrator assigned and Accounting setup incomplete. Provision accounting opened the correct-company form, with Treasury name/type, Bank name and reason fields, baseline11-account/one-Treasury explanation and OWNER_CURRENT exclusion. All inputs remained untouched and confirmation unchecked. Cancel returned to the unchanged Company row. No mutating RPC was submitted.

Actual provisioning remains separately approved work. Specify exact eligible Company UUID/code/current version, `CONTRACTING_BASELINE_V1`, actual owner-defined Treasury name, CASH/BANK, bank name for BANK only and audit reason. The Stage D candidate `23ec33fa-8045-468d-bbdb-0c06d0a816f6` / `NARVO-INVITE-TEST-20261101` is **not authorized for provisioning**. Later acceptance must verify exact chart/Treasury, duplicate-free recovery and recipient COMPLETE/workspace reads. No hosted financial test is included.

OWNER_CURRENT and owner-funded operations remain excluded; no accounting policy was invented. Company funding and operation-specific masters remain separate. Invitation origin/callback configuration stays on the previously accepted Preview; invitation delivery from the new Preview is outside scope. No Production/Staging, existing Company/membership/financial, Git commit/push/merge, redeployment, rollback or cleanup action occurred. The single deployment authorization is consumed; do not retry automatically.

Lifecycle at this checkpoint: business/accounting preservation and non-provisioning boundary **VERIFIED**; security/database source, RLS, grants and hosted migration **VERIFIED**; Preview deployment/protection/Production preservation **VERIFIED**; authenticated UI read-only smoke **VERIFIED**; actual provisioning/recipient completion **DEFERRED pending separate approval**; documentation/evidence **VERIFIED** for these results. Commercial readiness is not claimed.

## Interrupted-session resumption closure — 2026-11-01 12:30:23 Asia/Dubai

Read the saved execution report/JSON and the existing conversation before acting. Migration success is established by the original canonical apply exit0 and database postflight, not inferred from Preview readiness. A narrow read-only final query reconfirms migration20261101120000 present, total63, private provision records0, Stage D ACTIVE/version3/INCOMPLETE, accounts0, Treasury0 and the original single ACTIVE ACCOUNTING_ADMIN membership for the exact recipient. No migration, deployment, six-race test, general audit or source refactor was repeated.

[Exact Company row](release/development-company-accounting-owner-row.png), [review form](release/development-company-accounting-form-review.png), [unchecked confirmation](release/development-company-accounting-form-confirmation.png), [after cancellation](release/development-company-accounting-form-cancelled.png). Captures exclude URLs and authentication inputs. The recipient browser session was left untouched.

Production preservation and all17 historical Companies/46-table fingerprints are confirmed by the retained original successful execution evidence; they were not re-audited during this UI-only resumption. No hosted mutation occurred during resumption. Development activation is complete within the authorized migration/deployment/read-only scope; actual Company provisioning acceptance is not complete.

**Single next action:** obtain separate owner approval for provisioning this exact test Company/current version3 with CONTRACTING_BASELINE_V1, the actual primary Treasury location name and CASH/BANK type, bank name if BANK, and audit reason. This approval must expressly permit the11 GL accounts/one zero-balance Treasury/setup COMPLETE transition. No such approval is inferred from activation or viewing the form. Stop here; commercial readiness is not claimed.

## Subsequent separately authorized Company provisioning

The owner later approved the exact Stage D fixture/Main Cash/CASH/version3 operation. It committed once and verified ACTIVE/version4/setup COMPLETE,11 accounts/one Treasury with no journals or historical changes. [Separate operational result and limits](COMPANY_ACCOUNTING_PROVISIONING_TEST_EXECUTION.md). Earlier no-provisioning statements describe the activation-only checkpoint; this later operation did not redeploy or alter activation configuration.
