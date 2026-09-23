# P6D Checkpoint 3 — Expense Reversal

**P6D IN PROGRESS. Expense READ COMPLETE for Development. Treasury-funded Expense POST COMPLETE for Development. Expense Reversal COMPLETE for Development.** P6C remains COMPLETE; P6E NOT STARTED; Production readiness DEFERRED. The short operator smoke below is deferred/non-blocking.

Clean starting baseline: `main`, HEAD = fetched `origin/main` = `9474cd24eaf32c42f11da4a597281a074f6cf8d7`. This checkpoint changes no migration or accounting policy and performs no commit/push or Staging/Production action.

## Canonical contract

Existing P5B `public.reverse_expense` from `20260901120000_p5b_expense_commands.sql`, unchanged:

- `target_company_id uuid`
- `target_expense_id uuid`
- `target_reversal_date date`
- `target_reason text` (trimmed, 1–1000 characters)
- `target_idempotency_key uuid`

It returns exactly one `{ expense_id, expense_reference, reversal_journal_entry_id, replayed }`. The fixed-search-path SECURITY DEFINER command derives `auth.uid()`, requires `accounting.reverse`, reserves the normalized request hash, locks the Company-scoped Expense, accepts only `POSTED`, calls private `reverse_journal`, links the reversal journal and transitions the document to `REVERSED` atomically. Only ACCOUNTING_ADMIN has the permission. Authenticated has EXECUTE on this specialized command; table writes and private journal primitives remain unavailable.

Idempotency reservation precedes the lifecycle lock/check. A same-key/same-payload retry after a committed but unconfirmed response returns the original result even though the Expense is now reversed; changed payload with the key fails. A returned PostgreSQL error means the first atomic command rolled back. Network/malformed outcomes remain frozen for same-key retry. Actor/Company/Expense-scoped session storage holds recovery intent/receipt only, never accounting truth. An authoritative `REVERSED` read with the linked journal can resolve a pending lost response without another command.

## UI and accounting boundary

Production `/expenses` shows a compact reversal action only to ACCOUNTING_ADMIN and only for eligible `POSTED` rows (or an existing scoped recovery record). It requires a separate open step, reversal date, reason and explicit confirmation checkbox. Success performs targeted authoritative Company/Expense readback, verifies unchanged posted-journal linkage plus the returned reversal-journal link, then refreshes Expense READ. A confirmed command with failed readback can retry the read without reposting. EN/AR/RTL and narrow layout are supported.

React sends only the five command inputs. It does not edit the posted Expense, construct journal lines, swap debits/credits, calculate VAT/gross, convert money through JS Number, expose GL accounts, or use demo repositories. The server creates an immutable reversal journal whose lines retain account/project/party/Treasury/subcontract dimensions and exactly swap BIGINT debit/credit amounts. Project remains analytic.

## Focused verification

- `verify-p6d-expense-reversal.mjs` PASS: exact five-field actual SDK payload, date/reason validation, ACCOUNTING_ADMIN/POSTED UI gate, actor/Company/Expense-scoped recovery, simultaneous-send coalescing, stored-receipt no-resend, lost-response same-key replay, first rejection versus uncertainty, and no direct financial DML/demo access.
- `verify-p6d-expense-reversal-interactions.mjs` PASS using actual component and isolated in-memory transport with no hosted Auth fixture: explicit confirmation, exact RPC payload, confirmed-command readback failure/retry without repost, authoritative reversed status/journal link, all denied roles including SYSTEM_ADMIN, EN/AR/RTL and 390px layout.
- `scripts/sql/p6d-expense-reversal/hosted-checks.sql` PASS in MakerACC-Development in one rollback-only transaction: exact command, POSTED success, internal DRAFT and REVERSED denial, ACCOUNTING_ADMIN-only full role matrix, missing actor, cross-tenant command/read denial, RLS own-row readback, exact balanced opposite lines and dimensions, immutable original Expense economics/provenance and original journal, maximum 9,000,000,000,000,000-minor-unit precision, same-key replay and changed-payload rejection. The posting used solely to establish the maximum-BIGINT reversal fixture, all role changes and all financial effects rolled back.
- Directly affected Expense READ regression PASS. Current P6A and P6C static-only boundaries PASS: 70 production modules, 42 master modules and 54 demo modules. Historical P6C suites and unrelated POST matrices were not rerun.
- Build PASS. Lint PASS with the same four existing Fast Refresh warnings. Focused changed-file secret scan and `git diff --check` PASS.
- Post-rollback read-only integrity: Companies/settings 14/14, missing/orphan 0/0; Expense counts remain 84 POSTED / 7 REVERSED; forced Expense RLS and SELECT-only table grants remain unchanged.

No schema, RLS, grant or accounting migration was required or applied. Canonical migration history remains unchanged; its previously verified 41-migration alignment was not redundantly rerun.

| Lens | Classification |
|---|---|
| Business/accounting | VERIFIED exact immutable Expense reversal; corrected replacement Expense NOT STARTED |
| Security/authorization | VERIFIED ACCOUNTING_ADMIN only, lifecycle, tenant/RLS, actor and production/demo boundaries |
| Database | VERIFIED existing command, exact journals, rollback and final integrity; migration NOT APPLICABLE |
| Deployment | Development only; Staging/Production/readiness DEFERRED |
| Testing | VERIFIED focused automated and rollback-only hosted evidence; operator smoke DEFERRED/non-blocking |
| Documentation | VERIFIED checkpoint contract, evidence and limits recorded |

No implementation blocker. PRE_DEMO_UAT should later use an existing Accounting Admin session to reverse one disposable synthetic posted Expense, confirm explicit warning/confirmation, authoritative reversed linkage, refresh without duplication and EN/AR presentation. Reversal creates permanent immutable Development history, so the operator must choose a disposable synthetic Expense. No corrected replacement, Supplier Payment, custody/subcontract workflow, attachment, report or generic journal UI was started.
