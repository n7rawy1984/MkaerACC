# P6C Slice 11 — OTHER Party Display Name UPDATE

VERIFIED COMPLETE; AUTHENTICATED BROWSER ACCEPTANCE COMPLETE; FIXTURE CLEANUP COMPLETE.
Development only (`eqnzueginpkskbnqvgoc`). P6C IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED.

## Authenticated acceptance — COMPLETE

Authenticated hosted acceptance is COMPLETE.

- ACCOUNTING_ADMIN ACTIVE and INACTIVE OTHER display-name mutation PASS.
- PROCUREMENT ACTIVE and INACTIVE OTHER display-name mutation PASS.
- OTHER-only boundary, protected fields/type/status/code/TRN/contact/notes and validation/normalization PASS.
- Two-tab stale optimistic conflict PASS: first write won, stale write affected zero rows; no overwrite or silent retry.
- Alpha/Beta tenant isolation PASS.
- All documented role checks PASS. Open-edit downgrade PASS.
- Company, membership and profile revocation/restoration PASS; fail-closed behavior preserved.
- Keyboard/open/save/cancel, focus restoration and ordinary tab-return draft preservation PASS.
- Role revalidation investigation confirmed the earlier delay was Playwright focus-emulation behavior; genuine headed browser blur/focus revalidated correctly without an application fix.
- The earlier Playwright `scrollWidth = 2372px` result at a synthetic 390px viewport was not reproduced in the real browser. Manual Chrome acceptance at 394px, Arabic/RTL, `/parties`, using the same valid long unbroken OTHER name showed correct multi-line wrapping inside the card and no user-visible horizontal page overflow. No CSS/layout modification was made.
- Existing directly affected Supplier automated regression remains PASS; no additional Supplier browser fixture was required.
- No financial/P6D route became writable.
- Guarded exact-manifest cleanup PASS.
- Final `verify.sql`: all Slice 11 fixture Companies/Parties/memberships/assignments/browser Auth counts 0; global Companies/settings 14/14; missing/orphan 0/0.

Acceptance state: **COMPLETE**. Closure/commit is authorized; production readiness remains deferred.

## Historical acceptance procedure

The original implementation run created no browser fixture/Auth identity; the acceptance attempt above subsequently used the user-provisioned identity and ran setup once. Email: `p6c-s11-browser@example.test`. SQL retains empty UUID placeholders, no password or token. For any future rerun, an operator must separately provision a disposable synthetic Development Auth identity and its ACTIVE profile. Put its UUID only in private execution copies of setup/role/authority/cleanup scripts.

1. Review `preflight.sql` (read-only catalog and integrity). The canonical migration `20260921130000` and forward token correction `20260921133000` must be applied; global baseline is 14 Companies / 14 settings, missing/orphan 0/0.
2. Run the guarded `browser-setup.sql` execution copy only after acceptance is authorized. It adds two Companies/settings/memberships and three OTHER Parties, without financial fixtures. Start Auth mode and select Alpha, `/parties`.
3. ACCOUNTING_ADMIN: rename ACTIVE and INACTIVE OTHER rows; verify populated name-only form, trimming, Arabic text, internal spacing, required/200-character validation. Code, type, status, leading-zero TRN, contact and notes stay unchanged. No create/deactivate/delete controls for OTHER.
4. Two tabs: load the same row, save in tab A, submit stale tab B. Expect conflict, no overwrite or silent retry; refresh/review restores editing.
5. Switch Alpha/Beta; rename Beta independently; no stale Alpha data or feedback. Company/branding remain correct.
6. `browser-role.sql` changes Alpha role: PROCUREMENT may rename; ACCOUNTANT, DATA_ENTRY and MANAGEMENT_VIEWER read without edit; PROJECT_MANAGER and SYSTEM_ADMIN have no Party rows. Downgrade with an open form and return focus; the old form must disappear.
7. `browser-authority.sql` toggles only the selected fixture Company, membership or profile ACTIVE/INACTIVE. Verify revocation on refresh/tab-return, stale edit denial and restore. With only Alpha membership inactive, Beta remains available; profile revocation removes all Company access. Restore before continuing.
8. Verify draft survives ordinary tab-return, keyboard Enter/open/save/close, focus restoration, error focus, Arabic/RTL and 390px width. Financial routes remain holding states. Existing Supplier behavior is covered separately by the isolated automated regression; do not add Supplier rows to this exact browser manifest.
9. Close fixture tabs, restore authority, then execute guarded `browser-cleanup.sql` with the exact fixture UUID. It removes only the manifest and the disposable profile/Auth user; aborts on extra data/dependencies; no explicit CASCADE. `verify.sql` must report zero fixture/Auth counts and global 14/14, missing/orphan 0/0. Preserve unrelated data; never loosen cleanup guards to force removal.

## Deterministic browser IDs

All UUIDs have prefix `81200000-0000-4000-8000-0000000000`:

| Suffix | Resource |
|---|---|
| a1 | Alpha Company, `P6C-S11-BROWSER-A`, slug `p6c-s11-browser-a` |
| a2 | Beta Company, `P6C-S11-BROWSER-B`, slug `p6c-s11-browser-b` |
| b1 | Alpha INACTIVE OTHER, code `0001`, leading-zero TRN, Arabic contact, fixed notes |
| b2 | Alpha ACTIVE OTHER, code `0002`, nullable metadata |
| b3 | Beta ACTIVE OTHER, code `0003`, nullable metadata |

Membership/settings keys derive from Company and the placeholder Auth actor. No GL, Project, subcontract or financial documents are needed.

## Automated evidence and limits

Focused hosted rollback checks: 108/108 PASS. Exact-token concurrent edits: 1/0, actor/token verified. Real isolated Chromium uses actual providers/shell/forms and in-memory transport, with external requests blocked; it is not authenticated hosted acceptance. Repository/provider checks cover exact payload/token, both allowed and all denied roles, write/read delays across user/role/Company/logout/unmount, duplicate prevention, recovery, Party-only refresh and serialization with Supplier operations. Directly affected Supplier Chromium is included. Historical hosted Slice 1–10 suites are not rerun.

Automated SQL is in `scripts/sql/p6c-slice11/`; rollback IDs use prefix `81000000`, disposable concurrency IDs `81100000`. The concurrency fixture reuses an existing synthetic actor without creating/deleting Auth. See the [phase record](../../P6C_SLICE_11_OTHER_PARTY_NAME.md) for final gates and limitations. During acceptance, setup and the prepared role/authority helpers ran; authority was restored. Guarded cleanup and final integrity verification completed successfully.
