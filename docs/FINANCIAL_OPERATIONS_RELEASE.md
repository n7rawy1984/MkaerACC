# Financial Operations release — 2026-11-04

## Authorized policy and scope

The Product Owner explicitly replaced the ordinary-release mandatory restoration gate with AGENTS.md's active-development risk-based policy. Full restoration rehearsal and comprehensive disaster-recovery validation remain required at final operational readiness, not each ordinary milestone. Essential target/history/dependency/compatibility, accounting/authorization, preservation, backup-integrity and read-only postflight gates remain active. Destructive/high-risk irreversible changes still require specific approval.

## Verified database activation

- Target: `eqnzueginpkskbnqvgoc` (shared Development/Production database).
- 76 APPLIED: `20261104180000_financial_operation_evidence.sql`, SHA256 `603200db1a5458797df3d3b35dd8a9d6fa8b916ef6ac47d6437b44ce6cc3ee64`.
- 77 APPLIED: `20261104190000_operational_liability_posting.sql`, SHA256 `e0595e8770f3b0af41dcb398588043b74474b7c1d86865e2634e169169a16887`.
- Each isolated canonical package dry-run listed exactly one intended migration, followed by supported CLI `migration up --linked`. No blanket migration push or manual history edit.
- Read-only postflight76 and77 PASS: complete canonical SQL alignment; expected tables/guards, forced RLS, private/minimal EXECUTE privileges, fixed search paths, invoker view; new business/configuration and serialization tables empty.
- Existing financial/business/access tables unchanged against immediate preflight fingerprints. No financial command or synthetic hosted data. Auth activity since the backup is explicitly recorded; the snapshot is not claimed to include later session activity. Auth user counts and protected access memberships/roles/MFA remain preserved.
- Maker legacy readiness remains ready/unmanaged. Missing accounting-foundation configuration requires a separately approved operational setup before affected new workflows; no automatic foundation backfill occurred.

## Accounting impact and verification

Existing four negative Treasury scopes and one negative Custody scope are preserved. New unfunded outflows remain rejected; actual funding/corrective inflows and eligible reversals may improve negatives without forcing them to zero. Each other money leg must independently be valid. Existing signed reports and independently funded scopes remain usable. Actual economic classification/opening completeness is not inferred from test-like names or GL movements.

The existing locally verified financial integration, concurrency, browser/export and Production build evidence in `financial-operations-verification.json` is retained. The additional17 negative-balance policy checks PASS. No unchanged suite was repeated. Clean isolated release-candidate Production build PASS (TypeScript and Vite;2794 modules); Explicit45-file preservation/allowlist and private-token/key-pattern scan PASS. Staged whitespace inspection identified one pre-existing space-only line164 in approved migration77; it is retained to preserve the now-applied canonical SQL hash. No other whitespace finding. Focused candidate lint exits0 with eight existing warnings (test unused variables/imports and existing effect lint); no new code changes made. Focused candidate lint exits0 with eight existing warnings (test unused variables/imports and existing effect lint); no new code changes made. Existing non-blocking large-chunk warning remains.

## Recovery limitation and rollback

Encrypted migration75 database and password-free role exports captured2026-11-04 have verified ciphertext hashes, decryption integrity and scope, covering114 fingerprinted tables. Full restoration has NOT been demonstrated; no recovery-time or recovery-success guarantee is made. External configuration, role passwords, off-site copies and Storage blobs require separate protection. Full disaster-recovery validation is DEFERRED to the final comprehensive operational-readiness milestone.

Frontend rollback cannot reverse committed SQL or journals. Retain the prior Ready release for frontend incident recovery; financial/schema defects require approved forward correction. Full database recovery would require separate authorization, restore validation and intervening-write assessment across all Companies/Auth.

## Publication boundary

Approved destination: existing `n7rawy1984/MkaerACC` GitHub `main`, existing Vercel `maker` project. The owner's prior dashboard evidence shows Ready Production from `main`/`b915fae`; formal branch settings and API visibility are separate evidence. Preserve `release/platform-owner-console`; prepare the reviewed allowlist in an isolated worktree, never force-push. Database activation is verified; Git push alone is not evidence of successful Vercel Production deployment. Record exact commit/deployment and read-only smoke results after publication; do not infer them in advance.

## SDLC disposition

Business/accounting, focused authorization, local implementation evidence and hosted schema/preservation: VERIFIED within supported scope. Full recovery rehearsal, final operational-readiness/audit and live financial operator acceptance: DEFERRED. Vercel publication/read-only smoke: pending execution at preparation of this record. Approved themes, terminology, existing financial data and local development work are preserved.
