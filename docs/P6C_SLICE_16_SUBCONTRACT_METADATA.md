# P6C Slice 16 — Subcontract Descriptive Metadata UPDATE

**VERIFIED COMPLETE — DEVELOPMENT GATE CLOSED.** Focused automated authorization/security/accounting-integrity verification is complete and the operator accepted the primary real-browser smoke. The remaining extended manual role/UI sweep is explicitly deferred to `PRE_DEMO_UAT.md` and is non-blocking for continued Development. P6C remains IN PROGRESS only until its Final Closeout / Boundary Audit; P6D/P6E NOT STARTED; Production readiness DEFERRED. Development only (`eqnzueginpkskbnqvgoc`); no Staging/Production action.

## Decision and boundary

Slice 16 updates existing Subcontracts only. The selected safe fields are `scope_of_work`, `start_date`, `expected_end_date`, and `notes`. They are descriptive attributes of the stable Subcontract UUID: P5 certificates, advances, payments, retention records and journal lines reference Subcontract/Project/Subcontractor IDs and do not copy or use these fields as source identity, idempotency keys, amounts or posting inputs. `contract_number` is excluded because its case-insensitive per-Project unique index makes it a business reference and current policy does not prove it mutable. IDs/FKs, original value, variations, retention, status and provenance remain protected.

Canonical P4 `subcontract.manage` authorizes **ACCOUNTING_ADMIN and PROCUREMENT**. ACCOUNTANT and MANAGEMENT_VIEWER read Company rows without edit. PROJECT_MANAGER reads assigned-Project rows only and cannot edit. DATA_ENTRY and SYSTEM_ADMIN see no Subcontract rows. Active profile, membership and Company remain mandatory. The existing UPDATE policy has no lifecycle predicate, so the selected descriptive fields are editable for ACTIVE, COMPLETED and CLOSED Subcontracts by both write roles; this does not reopen economics or financial eligibility.

## Implementation

Forward migration `20260923120000_p6c_subcontract_metadata.sql` is applied to MakerACC-Development. It removes broad browser INSERT/UPDATE/DELETE/TRUNCATE privileges and grants UPDATE only on the four selected columns. The fixed-empty-search-path SECURITY INVOKER trigger preserves creation provenance, derives the authenticated actor, applies JavaScript-compatible Unicode boundary trim, maps blank notes to NULL and advances `updated_at` monotonically. Trusted writes preserve actor authority while retaining the same normalization/token behavior. Forced RLS and existing role/tenant policies remain authoritative; no privileged browser RPC was added.

The repository sends only the four selected fields with active Company, Subcontract ID and exact loaded token filters. Zero rows mean conflict/authority loss and there is no retry. Strict real ISO calendar dates are accepted; nullable dates and notes clear to NULL; scope is required with no invented maximum or date relationship. The provider rechecks the session around the write and Subcontracts-only refresh and discards late Company/role/user/logout/unmount results. The inline EN/AR editor has populated save/cancel, duplicate lock, conflict/known-commit recovery, keyboard/focus, RTL and narrow-layout handling. Project and Subcontractor labels still use only the existing scoped snapshots; exact BIGINT strings are retained.

## Automated evidence

- Focused Development preflight confirmed the exact 17-column schema, ACTIVE/COMPLETED/CLOSED enum, forced RLS, unchanged policies and role mappings, four UPDATE columns, stable-ID incoming P5 FKs, and 14/14 Company/settings integrity.
- Hosted rollback suite passes all assertions for both writers, every denied/read role, all lifecycle statuses, protected identity/economics/status/provenance, tenant and inactive-authority denial, actor/normalization/null clears, stale tokens, trusted behavior, exact amounts/FKs and unchanged financial/journal counts.
- Simultaneous exact-token editors return 1/0; the winner has the DB actor and advanced token. Guarded cleanup removes the durable concurrency fixture.
- Repository/provider behavior and real isolated Chromium pass four-field payload/filtering, validation, ACTIVE/CLOSED UI, conflict/no retry, recovery, tenant/role/authority/session isolation, draft/focus/keyboard, EN/AR/RTL and 390px. Slice 4 exact read/display and Subcontractor/Supplier Party regressions pass.
- Build, lint, P6A/P6C boundaries and behavior, changed-file secret/diff checks, DB lint, migration alignment and final linked no-op dry-run pass. Final automated fixture counts are zero; Companies/settings are 14/14, missing/orphan 0/0.

The authenticated Development fixture was exercised for the primary real-browser flow and then cleaned. The operator accepted Slice 16 for Development closure. The remaining extended role/authority and presentation sweep is tracked separately in `PRE_DEMO_UAT.md`; it is not a P6C/P6D development blocker and does not imply that every README matrix item was manually executed.

| Lifecycle category | State |
|---|---|
| Business/accounting | VERIFIED descriptive-only metadata and unchanged historical financial truth |
| Security/authorization | VERIFIED automated RLS/tenant/role coverage; primary real-browser smoke accepted; extended manual sweep deferred to Pre-Demo UAT |
| Database | VERIFIED canonical Development migration, rollback suite, concurrency and cleanup |
| Deployment | Development only; Staging/Production DEFERRED |
| Testing | Focused automated COMPLETE; Development gate CLOSED; residual manual presentation/role sweep tracked as Pre-Demo UAT |
| Documentation | Phase record and prepared acceptance kit COMPLETE |

Read-only completion assessment: no additional operation is currently required to satisfy the frozen P6C production master-data cutover after Slices 1–16. Broader create/delete/lifecycle or full-field CRUD is optional future product work. Certificates, advances, payments, retention, posting, journals, reversals and reconciliation belong to P6D/P6E. Provisioning, subscription, custom-domain and platform administration remain outside P6C. The recommended next checkpoint after browser acceptance/closure is **P6C Final Closeout / Boundary Audit**; this document does not mark P6C complete or start that checkpoint.
