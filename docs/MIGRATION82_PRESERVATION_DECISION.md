# Migration82 preservation acceptance decision

## Approval and completed database result — supersedes the pending-approval disposition below

The Product Owner explicitly approved this replacement criterion and applying only82. A separate current baseline was accepted without altering the original historical evidence. Migration82 APPLIED at 2026-11-05T14:49:49.469685+00:00; strict immediate and resumed read-only postflight PASS (latest 2026-11-05T15:38:13.623301+00:00), including exact85-table/full Auth/per-identity material preservation, unchanged grants/guards, balanced journals and retained payroll confidentiality. The historical Auth delta remains NOT RECOVERABLE FROM AVAILABLE EVIDENCE. No business configuration, push, deployment or restoration rehearsal. This approval changes the acceptance criterion, not the unresolved historical facts. See `EXISTING_COMPANY_ACCOUNTING_SETUP.md` for release status. The original decision and its historical pending-approval text are retained below.

2026-11-05, current read-only verification at 14:33:49 UTC. Target: `eqnzueginpkskbnqvgoc`. Migration82 remains unapplied; no commit, push, deployment or business-data change.

## Historical evidence limit

**Exact historical Auth delta: NOT RECOVERABLE FROM AVAILABLE EVIDENCE.** The approved82 snapshot retained one aggregate full-row hash for `auth.users`, not historical per-row/per-field values or hashes. Available audit evidence does not establish its exact field delta. Previously attempted reconstruction did not match. This task did not repeat that investigation. A successful same-account refresh is evidence of operational activity, not proof that it explains every byte of the historical discrepancy.

Original baseline: `/tmp/narvo-foundation82/preservation-baseline.json`; original preflight: `/tmp/narvo-foundation82/preflight.json`. Original Auth aggregate SHA256: `40c923a2a73eddd95c3b9fda1bd53598fd1efb9f36aee632ab54723d450db887`,290 rows. Neither file was overwritten. Historical investigation and discrepancy evidence remain under `/tmp/narvo-foundation82/auth-drift`.

## Independent evidence and its limits

**A — Verified current integrity: PASS.** Canonical hosted1–81 and reviewed82 SHA256 `2b908163a0d8dbde7155df45b823b3eaaf4b47b686e7f72e6dd3149aae6145f2` align. Existing function definitions, grants and relevant account/Treasury/journal guards remain unchanged. All84 other monitored financial/business/access/Auth-profile/membership/MFA/Owner/HR tables match the original82 preservation baseline; journals remain balanced, preserving the journal-line basis of Treasury balances. Maker/current Accountant access and Management Viewer payroll restrictions pass read-only role checks.

**B — Verified historical consistency: PASS within the stated reference.** All290 current Auth UUIDs and all compared stored fields match the retained encrypted migration75 archive except `updated_at` on two identities. This comparison includes credentials/token fields, email/phone/confirmation, role/audience/privilege flags, provider/user metadata and banned/deleted/anonymous/SSO state. Values are never disclosed or stored in repository evidence. Decryption/parsing was in memory; no restoration occurred. A new full Auth fingerprint change since the preceding investigation justified refreshing only this material-field comparison; no repeated historical reconstruction or general audit was performed.

**C — Unexplained historical difference:** equivalence to the older archive is not equivalence to the specific82 snapshot. Current integrity does not prove the exact historical delta or that no intervening transient change occurred.

A separate protected read-only evidence snapshot now records current full table fingerprints, per-identity full-row/material hashes and operational timestamps. Material coverage includes every current `auth.users` field except `updated_at`, including `last_sign_in_at`. It is labelled **proposed independent evidence, not an accepted replacement release gate**. No original acceptance baseline or activation script was changed. Evidence: `/tmp/narvo-foundation82/auth-drift/independent-current-decision.json` and `proposed-independent-snapshot-private.json`.

Existing migration75 backup integrity/scope evidence remains a reference, not a current82 recovery guarantee; restoration remains untested. No restoration requirement is newly imposed by this decision.

## Proposed replacement acceptance criterion

The alternative is technically defensible for this additive, no-backfill migration, subject to explicit approval of the changed historical acceptance condition:

1. Retain the original aggregate hash, investigation and NOT RECOVERABLE limitation permanently; do not classify the old discrepancy as explained.
2. Immediately before activation, verify the exact target, canonical1–81 and reviewed82 hash/dependencies/client compatibility; reuse the existing passing47 database/five native concurrency/ten browser/build evidence. Verify available backup integrity and disclose recovery limits.
3. Establish a separate timestamped snapshot with exact financial/access table fingerprints, complete Auth UUID membership, per-identity material and full-row hashes, and operational timestamps. Confirm material consistency against the verified encrypted reference, active protected access, RLS/grants/authorization and payroll confidentiality. Do not omit material fields or normalize hosted records.
4. Apply only82, with no Company setup or financial command. Require immediate read-only postflight preserving all existing financial/access records, journal/Treasury balances, identity set and material Auth fields; verify canonical82 and new schema/grants/RLS with an empty setup table. Retain full-row evidence. Any operational timestamp-only difference must have an exact field-level delta and supporting audit evidence from the new baseline; stop for material or unexplained new differences.
5. After successful postflight only, prepare one isolated reviewed release commit on current GitHub main. No automatic push/deployment. No other migration, Auth/business-data modification, Excel processing or restoration rehearsal.

## Authorization disposition

**Approval of replacement criterion REQUIRED.** The existing authorization to apply only82 remains valid, but the Product Owner's earlier “Migration82 Auth Baseline Drift” request §3–4 permitted continuation/baseline refresh only after satisfactorily explaining that historical drift. Substituting independent current evidence while accepting that the exact delta is unrecoverable changes that explicit condition. AGENTS.md permits proportional risk-based evidence but does not override this user-imposed condition. The present request §3 instructs stopping if such a change requires approval.

Required approval wording:

> I approve replacing Migration82's historical Auth-delta reconstruction requirement with the independent current-preservation criterion documented in docs/MIGRATION82_PRESERVATION_DECISION.md. Retain the original hash and unrecoverable discrepancy. Capture and verify the fresh financial/access and per-identity Auth baseline, then apply only Migration82 to eqnzueginpkskbnqvgoc and require preservation postflight. Stop on material or unexplained new drift. Prepare one local release commit only; do not push or deploy.

**Decision: STOP before hosted mutation pending this single gate-replacement approval.** No new software defect or additional migration authorization requirement is asserted. Existing isolated candidate `/tmp/narvo-foundation82-release-20261105` remains unchanged and uncommitted. This decision report is not yet part of that reviewed candidate; include it with required release documentation after authorization and successful postflight.
