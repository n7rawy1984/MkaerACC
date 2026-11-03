# Accounting provisioning — Development activation preparation

**Update — 2026-11-01: Local race gate PASSED6/6 on native PostgreSQL18.4 under separate owner approval.** No implementation/hash change or hosted action. [Race execution and cleanup](COMPANY_ACCOUNTING_PROVISIONING_RACES.md). Remaining sequence: fresh guards/dry-run, separately approved migration, one Preview deployment, read-only hosted verification. Earlier preparation-only descriptions below are historical for gate A; no repeat needed without source change.

2026-11-01. **PREPARED / CONDITIONAL APPROVAL REQUIRED. No hosted changes or provisioning performed.** [Accepted implementation](COMPANY_ACCOUNTING_PROVISIONING.md). Local55 database/10 browser results remain accepted; they were not rerun during this preparation. Current lifecycle stage is deployment preparation; hosted new-feature acceptance remains deferred.

## Pinned scope and preservation

Only pending migration: `20261101120000_company_accounting_provisioning.sql`.

SHA256: `2058d940ba7f6f932eba64065f515edf67a333c89475c14e307c7d14a2e1545e`.

Fresh read-only Development inspection confirms62 applied versions equal the first62 local migrations;63 local files leave exactly this candidate. All14 recorded implementation/test/package hashes still match the accepted implementation evidence. The migration only expands the private setup-status constraint to INCOMPLETE/COMPLETE, creates the forced-RLS private provisioning-evidence table and two explicitly granted SECURITY DEFINER RPCs with empty search_path. Accounts/Treasury/receipt/audit insertion occurs only inside the provisioning function when separately invoked. It contains no automatic Company backfill, function invocation or financial posting. Existing migration files were not changed.

Development: `eqnzueginpkskbnqvgoc`. Historical Companies17; Stage D is the18th Company, code `NARVO-INVITE-TEST-20261101`, UUID `23ec33fa-8045-468d-bbdb-0c06d0a816f6`, ACTIVE/version3/INCOMPLETE. Its single ACTIVE ACCOUNTING_ADMIN membership and ACCEPTED invitation remain intact. Preservation fingerprints/counts cover all46 public Company-owned tables for the17 historical Companies, plus Company identity fingerprints and exact Stage D membership/state. Future execution must compare these against a fresh baseline immediately before and after each hosted step. No unrelated financial content is printed.

[Read-only preservation evidence](release/development-company-accounting-activation-preflight.json). This records current state; it is not a claim that an activation has run.

## Preview source package

The previous deployed package had246 files and lacked the new status component. A new private source package is assembled at `/tmp/narvo-accounting-activation/source`, using the existing reviewed allowlist plus only `src/master/CompanyAccountingSetupStatus.tsx`.

**247 files:240 unchanged,6 changed,1 added.** Changed files are package.json, TenantReadyApplication.tsx, PlatformApplication.tsx, platformApi.ts, platformRecovery.ts and platformText.ts. Their hashes match the accepted P0 implementation. The package includes the provisioning form, RPC routing, pending-request recovery allowlist, bilingual completion labels, workspace integration and status component. Existing onboarding/InvitationOnboarding and `scripts/production-boundary.d.mts` are retained. No Git metadata, env files, credentials, fixtures, operator tools, database migrations, docs or prebuilt output belongs in the source upload.

[Exact247-file manifest](release/development-company-accounting-activation-manifest.json). Source digest (sorted `path:sha256\n`): `6d7ac5f6ef780a0db5575338c6edab9fba8dad596cf0d27929fda601845db239`.

The source is a newly prepared candidate for approval; the old deployed Preview does not already contain these changes. **Isolated247-file build PASS; compiled Supabase target is Development only.** [Build/scope/preparation evidence](release/development-company-accounting-activation-preparation-result.json). The exact upload list/hash closure passes; no runtime or hosted provisioning was executed. Two initial packaging checks correctly failed closed: missing data-mode environment, then a redacted key placeholder from the old manifest. Validation uses only the actual three existing browser-safe Preview values fetched read-only and passed to the local process; no hosted environment variable changes are permitted. Dependency symlink/build output are removed from the upload directory after validation. No old general audits are repeated.

Existing Vercel project `prj_n03DWya5Gr1uB82qtY084FvsC7q4`, team `team_HozmwrkzbERtyer2nIT25MWv`; target **Preview only**. Existing Preview `dpl_9uerokdducUaR4V35BvDDbyfnqZH` remains READY at `https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app`. Protection remains `all_except_custom_domains`. Production alias `maker-eosin.vercel.app` remains on `dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh`; branch main. [Read-only Vercel baseline](release/development-company-accounting-activation-vercel.json).

## Smallest conditional sequence and approval scopes

**A — Local race gate, before hosted writes.** Separately authorize a disposable native PostgreSQL runner under `/tmp` and execution of `scripts/verify-company-accounting-provisioning-races.mjs`. The existing optional documented runner is `embedded-postgres@18.4.0-beta.17`, expected at `/tmp/narvo-postgres-runner/node_modules/embedded-postgres/dist/index.js`; it is not installed there now. Obtain/review that local dependency or an approved equivalent before running. Do not use a hosted connection, owner token, production clone or existing Company's data. The prepared harness accepts only a local runner, creates a loopback server with disposable Auth scaffolding/Companies, and destroys that local server directory afterward. No provisioning ran during this preparation.

At preparation the hash-pinned harness had syntax/lint validation only. It has now passed its separately authorized native runtime gate; the verified protocol requires distinct `pg_backend_pid()` values, an observed lock wait and bounded completion for all six orderings:

1. Same request UUID: one foundation and identical receipts.
2. Different UUIDs/equivalent intent: one foundation and no duplicated accounts/Treasury/audit.
3. Different intent: first succeeds; waiter rejects22023 without takeover.
4. First transaction rolls back: waiter creates the single complete foundation; no partial remnants.
5. Suspension commits first: waiting setup rejects42501 with zero foundation rows.
6. Provisioning commits first: waiting lifecycle command with old version rejects40001; one complete foundation remains.

Assert11 accounts/one Treasury/one provision/one audit per winner, zero journals/reference counters. Existing global authorization lock serializes these commands; the test must actually observe the competing backend waiting, rather than pass on sequential Promise calls. Failure stops activation; any code change invalidates accepted hashes and requires renewed focused validation/review. This gate creates only disposable **local** Companies and master data after approval; no hosted race fixture or financial transaction is included.

**B — Exactly one Development migration.** Only after A passes, recheck source/migration hashes, linked project reference,62-version alignment, the17 historical fingerprints, Stage D state/membership and current Vercel/Production baseline. Run the linked migration dry-run; it must list exactly the pinned migration. If it differs or credentials are unavailable, stop. Approval must explicitly authorize applying only this canonical migration to `eqnzueginpkskbnqvgoc`, once. No manual SQL patch, Stage A/B setting, Auth/SMTP/redirect/template/secret, invitation delivery, Staging or Production change. Catalog-read verification then confirms migration63, new table/constraint, function source/fixed search_path and exact grants, with zero provision records and preserved business data. Do not invoke the provisioning RPC to smoke-test it.

**C — One pinned Preview deployment.** Separately or conditionally approve one deployment of only the247-file manifest to the existing project/team, after B verifies. Recheck the clean private package and existing browser-safe Development variables; inspect CLI dry upload list/hash equality before submission. Use the previously reviewed Vercel CLI65.9.0 with explicit project/scope/Preview, without Git metadata:

```bash
npx vercel@65.9.0 deploy /tmp/narvo-accounting-activation/source \
  --project prj_n03DWya5Gr1uB82qtY084FvsC7q4 \
  --scope n7rawy1984-8059s-projects \
  --environment preview \
  --local-config deploy/platform-preview.vercel.json
```

This is a future command template, not executed here. Resolve local configuration from the source-directory working directory. No --prod, promotion, Production alias assignment, --verify/protection bypass, project linking/creation, Git push/merge or environment changes. Record the new generated Preview URL/deployment ID and verify build READY, correct project/Development target, unchanged Production alias/protection/configuration.

**D — Hosted read-only verification only.** In the actual protected owner browser, sign in/complete MFA privately if required; inspect exact Stage D row ACTIVE/version3/setup pending and availability of the new provisioning form. Opening/reviewing a form is allowed; **do not confirm/submit provisioning**. In the recipient's separately authenticated session, the new Preview should show the exact Company/role and setup pending. Use only normal read-only status/COA/Treasury reads and catalog/fixture reconciliation, with active-membership RLS/grant checks. No new user/invitation/membership, no new Company, no records or emails. Preserve Stage D membership/Company state and compare all17 historical preservation fingerprints. Stop and record results. A screenshot must exclude passwords, MFA inputs, tokens and invitation links.

A new Preview gets a new origin. Keep `PLATFORM_APP_ORIGIN` and existing Auth callback allowlists on their accepted origin. **Do not exercise invitation delivery or new-user email redirects from the new Preview in this activation.** Existing users may sign in privately to test this provisioning UI; invitation-origin migration/redirect access is a separate future scope. Do not assume a Preview deployment authorizes collaborator grants.

## Separate subsequent acceptance-test approval and required business inputs

No Company is approved for provisioning by this preparation. The existing isolated candidate is the Stage D fixture above, with recipient `n7rawy19840@gmail.com` / ACCOUNTING_ADMIN. **Naming it here does not approve mutation.** If the owner chooses it for the subsequent test, obtain approval of exact UUID/code, fresh version (currently3), `CONTRACTING_BASELINE_V1`, and:

- The owner-defined, verified primary Treasury location name (required,1–200 characters).
- Type CASH or BANK. CASH must have no bank name; BANK requires an actual owner-defined bank name (1–200 characters).
- The audit reason (required,1–500 characters), confirmation that current AED/calendar-year behavior is suitable, and explicit approval for eleven GL accounts/one zero-balance Treasury, private provision/audit/receipt and setup COMPLETE/version+1.

Do not invent a cash location or bank account. If another fresh Company is preferred, its creation/name/code/admin membership require separate explicit approval; never adopt one of the17 historical Companies. The acceptance test would verify exact chart/Treasury IDs, same/new equivalent request retries, member workspace and safe read-only exclusion of other Companies. No journal, opening balance, funding, expense, invoice, fiscal-period creation, email or permission change is part of provisioning acceptance. Hosted financial test transactions require their own approval.

OWNER_CURRENT and owner-funded operations remain excluded. Neither deployment nor setup COMPLETE approves a frozen owner-account type. Existing supported ten mappings and separate required business masters remain unchanged. There is no new fiscal-calendar/period engine or multi-currency claim.

## Rollback and stop conditions

- Any hash/scope/target mismatch, failed race/dry-run/readback, unexpected historical/Stage D change or Production/protection drift stops the sequence. No automatic second deployment or provisioning attempt.
- Migration failure/uncertain application: read the canonical ledger/catalog, determine actual state and stop. Never rewrite/unapply an applied migration or repair live functions outside canonical history. A correction needs a separately reviewed forward migration.
- Successful migration may remain installed with zero provision rows if frontend fails. Keep the old protected Preview available; no destructive schema rollback or data deletion is implied.
- Failed new Preview: stop using it and return to the existing Preview URL; no Production promotion, alias reassignment or bypass is needed. Deployment deletion/configuration rollback would require specific approval if proposed.
- After any future committed provisioning, do not delete/reseed/remap accounts or Treasury, reset the completion marker or rewrite history. Recover an uncertain outcome with the original request envelope; correction/cleanup requires separate approval and reviewed forward remediation.

Lifecycle: implementation/test baseline **VERIFIED previously**; preparation source integrity/hosted read-only preservation **VERIFIED**. Local package build is reported in the result artifact. Native race runtime **VERIFIED6/6** in the linked execution report; linked dry-run, hosted migration/deployment/runtime and actual Company provisioning **DEFERRED pending the scopes above**. No commercial-readiness declaration. **Stop before activation.**
