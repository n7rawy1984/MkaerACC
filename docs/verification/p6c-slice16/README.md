# P6C Slice 16 — Subcontract Descriptive Metadata UPDATE

**VERIFIED COMPLETE — DEVELOPMENT GATE CLOSED.** Primary authenticated browser smoke accepted by the operator after complete automated verification. The extended manual role/UI matrix below is retained as reference and moved to non-blocking Pre-Demo UAT. Development project `eqnzueginpkskbnqvgoc`. P6C remains IN PROGRESS only until Final Closeout / Boundary Audit; P6D/P6E NOT STARTED; Production readiness DEFERRED.

Closure note (2026-09-23): the disposable Development fixture was used for the primary browser smoke and subsequently cleaned. The operator accepted the Slice for Development closure. Not every item in the extended matrix below was manually executed; those remaining checks are explicitly tracked in `../../PRE_DEMO_UAT.md` and must not block subsequent Development work.

Run [preflight.sql](preflight.sql), require migration `20260923120000`, forced RLS, UPDATE columns exactly `expected_end_date`, `notes`, `scope_of_work`, `start_date`, roles exactly ACCOUNTING_ADMIN/PROCUREMENT, and global integrity 14/14 with 0/0 missing/orphan. Then run [browser-setup.sql](browser-setup.sql) once. It creates only two Companies/settings/memberships, two explicitly ACTIVE Projects, two SUBCONTRACTOR Parties plus one Supplier regression Party, and three zero-posting Subcontracts (Alpha ACTIVE/CLOSED and Beta ACTIVE). It creates no financial document, journal, assignment, or posting.

Use real password sign-in and perform this matrix without weakening fixtures or using reload as the primary authority check:

1. Open Alpha → Subcontracts as ACCOUNTING_ADMIN. Confirm both rows, exact amounts/retention/status, Project/Subcontractor IDs and scoped labels. The editor must contain only scope, start date, expected end date and notes; contract number, ownership, economics, retention and status have no controls.
2. Edit ACTIVE and CLOSED descriptive metadata. Verify Unicode boundary trim, internal case/spacing preservation, required nonblank scope, nullable date/note clearing, valid date handling, save/cancel, pending lock and focused validation error. Confirm amounts, contract number, retention, status, Project and Subcontractor remain unchanged.
3. Open the same Alpha row in two tabs. Save tab A, then save stale tab B. Expect conflict, no overwrite and no silent retry; refresh explicitly before another change.
4. Switch to Beta. Only Beta data may appear; an Alpha draft/result must never cross the tenant boundary. Switch back and confirm Alpha state.
5. With [browser-role.sql](browser-role.sql), test ACCOUNTING_ADMIN and PROCUREMENT: read and edit all three lifecycle states represented by the fixture (ACTIVE/CLOSED; COMPLETED was automated). ACCOUNTANT and MANAGEMENT_VIEWER read without edit. PROJECT_MANAGER has no fixture assignment, so sees no rows. DATA_ENTRY and SYSTEM_ADMIN see no Subcontract rows. Restore ACCOUNTING_ADMIN.
6. Open an edit, downgrade to ACCOUNTANT, make a genuine tab/window blur and return, and require authority revalidation to remove the editor. Repeat [browser-authority.sql](browser-authority.sql) membership INACTIVE/ACTIVE, Company INACTIVE/ACTIVE and profile INACTIVE/ACTIVE. Each revocation must fail closed; each restore must use real focus/tab return.
7. Confirm an ordinary tab return with unchanged authority preserves the draft. Exercise keyboard open/save/cancel, focus into the form, focus restoration to the origin button, and alert focus after validation/conflict.
8. Test EN and AR with RTL at 390px. Use a long unbroken 200-character scope/notes value. Require no body horizontal overflow and readable wrapping.
9. Confirm the Subcontractor and Project labels still come only from the authorized snapshots, the Supplier row and existing Party controls are unchanged, and no hidden label is fetched. Confirm exact BIGINT strings remain exact.
10. Confirm no certificate, advance, payment, retention, journal, ledger, posting, reversal, allocation or other P6D route becomes writable.
11. Sign out and close sessions. Run exact guarded [browser-cleanup.sql](browser-cleanup.sql), including manual Auth/profile deletion. Run [verify.sql](verify.sql) and require every fixture/Auth/profile count 0, Companies/settings 14/14 and missing/orphan 0/0.

[browser-role.sql](browser-role.sql) accepts only an explicitly chosen canonical role in the execution copy. [browser-authority.sql](browser-authority.sql) accepts only the documented target/status pair. The cleanup verifies protected fixture identity/economics/status and all dependency counts before deleting anything. Any mismatch aborts the transaction.

The matrix below remains useful for Pre-Demo UAT and regression investigation. Slice 16 Development closure does not authorize Staging or Production and does not weaken any P6D/P6E or accounting-integrity gate.
