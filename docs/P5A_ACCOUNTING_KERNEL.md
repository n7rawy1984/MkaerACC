# P5A Accounting Kernel and Journal Core

P5A is implemented by `20260831120000_p5a_accounting_kernel.sql` plus forward corrections `20260831123000_p5a_balance_trigger_row_shape.sql` and `20260831124500_p5a_service_role_least_privilege.sql`. All were applied only to the synthetic-only `MakerACC-Development` project. P5A adds no business transaction tables or browser-callable posting RPC.

## Domain mapping

The existing localStorage engine remains the behavioral specification: a `JournalEntry` has a business date, human reference, source type/id, description, and balanced lines; a line has one account side plus optional project, party, and subcontract dimensions. Treasury activity resolves to the treasury row's permanent GL account. Subcontract accounting preserves its project and contract scope. VAT, custody, supplier, owner, subcontractor, certificate, and payment calculations remain outside P5A and are unchanged.

PostgreSQL replaces client UUID-derived references and application-only balance validation with atomic counters, private posting primitives, and an independent deferred invariant. Amounts are `BIGINT` AED minor units; there are no floating financial columns.

## Public journal schema

`journal_entries` is an append-only posted header with company, generated journal reference, posting date, description, source type/id, posting purpose, optional reversal link, actor, and timestamps. Unique invariants protect company/reference, `(company, source type, source id, posting purpose)`, and one reversal per original.

`journal_lines` carries direct `company_id`, journal/line identity, account, exactly one positive debit or credit, optional project/party/treasury/subcontract dimensions, memo, and timestamp. Each journal line number is unique. A per-side bound of 9,000,000,000,000,000 minor units plus `NUMERIC` aggregation prevents silent `BIGINT` total overflow.

Composite foreign keys require the journal, account, project, party, treasury, and subcontract to share a company. A subcontract requires and must match its project. A treasury dimension is valid only when the line account is that treasury's permanent GL account.

## Balance and immutability

`private.create_journal` performs the first balance layer: JSON array, 2–1,000 lines, positive debit total, equal debit/credit totals, structurally valid rows. It inserts header and lines atomically.

The independent second layer consists of initially deferred constraint triggers on both headers and lines. At transaction end, `private.assert_journal_balanced` rejects fewer than two lines, a non-positive total, or unequal totals. Direct trusted SQL that bypasses the posting primitive was proven to fail.

Header and line `UPDATE` or `DELETE` always raise. The original is never marked or changed when reversed. A reversal is another immutable journal whose `reversal_of_journal_entry_id` points to the original.

## References, idempotency, and concurrency

`private.reference_counters` is keyed by company/reference type/year. `private.allocate_reference` uses one atomic `INSERT ... ON CONFLICT DO UPDATE ... RETURNING`, producing `{COMPANY}-{TYPE}-{YYYY}-{NNNNNN}` without `MAX()+1`. UUID identities remain separate.

`private.financial_command_requests` stores company, command type, idempotency UUID, 32-byte SHA-256 request hash, actor, status, result journal, and timestamps. It stores no request payload. Unique `(company, command type, idempotency key)` and row locking provide safe replay: same hash returns the reservation/outcome; a different hash rejects; completion cannot change its outcome.

Source uniqueness is a database unique constraint on `(company, source type, source id, posting purpose)`. Different explicit purposes are allowed; an identical purpose is not. Concurrent testing produced one effect and one uniqueness failure. Two concurrent reference calls produced distinct consecutive values, and two concurrent identical idempotency reservations returned the same reservation UUID.

## Private functions and reversal

- `private.allocate_reference`
- `private.reserve_financial_command`
- `private.complete_financial_command`
- `private.validate_journal_line_dimensions`
- `private.assert_journal_balanced`
- `private.enforce_journal_balance`
- `private.reject_journal_mutation`
- `private.create_journal`
- `private.reverse_journal`

All use fixed empty search paths. Generic posting/reversal/reference/idempotency functions have no `PUBLIC`, `anon`, `authenticated`, or `service_role` EXECUTE grant. Future specialized commands execute as their owner after enforcing domain state, permission, source ownership, calculation, idempotency, and locking rules.

The reversal primitive locks the original, rejects reversal-of-reversal and duplicate reversal, swaps every debit/credit exactly, and preserves account, project, party, treasury, subcontract, line order, and memo provenance.

## RLS and grants

Both public journal tables have RLS enabled and forced. Only `ACCOUNTING_ADMIN`, `ACCOUNTANT`, and `MANAGEMENT_VIEWER` can SELECT journals and lines for an active member company. `PROJECT_MANAGER`, `DATA_ENTRY`, `PROCUREMENT`, and `SYSTEM_ADMIN` receive zero raw-journal rows. `anon` is denied.

Authenticated users and `service_role` receive SELECT only. There are no browser INSERT/UPDATE/DELETE policies or grants. The final corrective migration removed provider-default `TRUNCATE`, `TRIGGER`, and `REFERENCES` privileges from `service_role`, restoring SELECT alone. Private tables have no browser/service privileges.

## Synthetic verification

All required tests passed on Development-only fixtures:

| # | Test | Result |
|---:|---|---|
| 1–4 | Two-line/multi-line journals, balance, generated reference | PASS |
| 5–9 | Unbalanced, one-line, zero/zero, both sides, negative rejection | PASS |
| 10–15 | Cross-company account/project/party/treasury/subcontract and project-contract rejection | PASS |
| 16–19 | Header/line update/delete rejection | PASS |
| 20–24 | Reversal creation, exact inversion/dimensions/balance, duplicate rejection | PASS |
| 25–28 | Reservation, replay, changed-hash rejection, concurrent same reservation/effect | PASS |
| 29–30 | Duplicate source rejection and distinct posting-purpose acceptance | PASS |
| 31–33 | Reference uniqueness, scope, concurrent allocation | PASS |
| 34–36 | Accounting Admin/Accountant/Viewer reads; Viewer no writes | PASS |
| 37–40 | Project Manager/Data Entry/Procurement/System Admin raw journal denial | PASS |
| 41–42 | Anonymous denial and every authenticated direct journal write denial | PASS |

Additional service direct-insert denial passed. Five committed synthetic journals are balanced; one is a linked reversal. Synthetic records remain clearly labeled in Development because journal immutability and no-delete policy must not be weakened for cleanup.

## Security findings and limitations

Database lint returned no findings. Security advisors reported only the six previously justified authenticated P2/P4 boolean authorization helpers and Development leaked-password protection; no P5A private function is exposed. RLS, grants, search paths, constraint triggers, and column types were inspected directly.

The first matrix exposed a polymorphic deferred-trigger row-shape bug; the test transaction rolled back and `20260831123000` corrected it. Privilege inspection then exposed provider default non-DML service privileges; `20260831124500` removed them.

P5A does not implement expenses, payments, advances, settlements, certificates, business-state reversal, P7 audit events, reporting-safe Project Manager views, or frontend Supabase writes. The exact next batch is a separately reviewed P5B specialized business-command batch; its flow scope is not yet authorized.
