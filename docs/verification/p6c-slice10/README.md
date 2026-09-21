# P6C Slice 10 — Treasury Display Name UPDATE

**P6C Slice 10 — Treasury Display Name UPDATE — VERIFIED COMPLETE**. Development only. P6C IN PROGRESS; P6D/P6E NOT STARTED; production readiness DEFERRED. User-completed authenticated acceptance and guarded fixture/Auth cleanup PASS. No credentials stored.

## Automated evidence

Hosted `hosted-checks.sql` 108/108 PASS (rollback). Two simultaneous `concurrency-edit-{1,2}.sql` sessions after guarded setup produced 1/0, winner actor/token verified, exact fixture cleaned. Treasury and directly affected Account isolated Chromium PASS. P6C behavior (including existing master regressions), P6A boundary, build/lint PASS (0 errors/4 existing warnings). DB lint clean, all 33 migrations aligned, final linked dry-run up to date, diff/secret review PASS. Global 14 Companies/14 settings, missing/orphan 0/0. See [phase record](../../P6C_SLICE_10_TREASURY_DISPLAY_NAME.md) for evidence and limits. These are automated results, not authenticated hosted browser acceptance.

## Accepted authenticated browser evidence (2026-09-21)

User-completed hosted acceptance **PASS**, accepted separately from the earlier automated evidence. Closure reran no verification or hosted queries.

- ACCOUNTING_ADMIN name-only Treasury mutation, including ACTIVE/INACTIVE rename; code/type/status/GL/Project/bank/reference/notes protected.
- Stale two-tab conflict and Alpha/Beta isolation PASS.
- ACCOUNTANT and MANAGEMENT_VIEWER read-only; PROJECT_MANAGER sees assigned Project Treasury only, without Edit; assignment revoke/restore PASS. PROCUREMENT, DATA_ENTRY and SYSTEM_ADMIN see no Treasury rows.
- Downgrade while editing, membership revocation, and profile revocation/no-company PASS.
- Focus/tab return, draft preservation, keyboard, RTL and 390px viewport PASS; Account name regression PASS. Financial routes remained unwritable.
- Final guarded cleanup/verify accepted: fixture_companies=0, fixture_accounts=0, fixture_treasuries=0, fixture_projects=0, fixture_memberships=0, fixture_assignments=0, browser_auth=0, companies=14, settings=14, missing=0, orphan=0.

Only the supplied browser evidence is claimed. No financial/P6D behavior, Staging/Production action, stored credentials or Slice 11 work. One local closure commit authorized: `Complete P6C Slice 10 treasury display name`; no push. Production readiness remains DEFERRED.

## Historical fixture reference — cleaned

The fixture used only MakerACC-Development (`eqnzueginpkskbnqvgoc`) and `p6c-s10-browser@example.test`. Setup/role/authority/cleanup SQL templates retain empty UUID placeholders and no credentials. No browser fixture remains live. These scripts are retained for traceability, not a request to recreate the fixture.

All IDs use prefix `80200000-0000-4000-8000-0000000000` plus the suffix below:

| Suffix | Resource | Scope |
|---|---|---|
| a1 / a2 | Alpha / Beta Company | codes P6C-S10-BROWSER-A/B; matching lowercase slugs |
| b1 | Alpha Bank Treasury | code 0001, INACTIVE, company-wide, GL d1; Bank Alpha / reference 000123 / Keep notes |
| b2 | Alpha Cash Treasury | code 0002, ACTIVE, Project c1, GL d2 |
| b3 | Beta Cash Treasury | code 0003, ACTIVE, company-wide, GL d3 |
| d1 / d2 / d3 | Required ASSET GL Accounts | Alpha GL1/GL2; Beta GL3 |
| c1 | Alpha Project | P1 |
| e1 | Alpha Project assignment | c1, fixture actor |

Settings/memberships are keyed by Company and actor. These GL Accounts are required Treasury masters, with no balances or postings. No financial document fixture was used.

## Evidence limits

Authenticated hosted browser acceptance passed according to the user; the preceding automated results remain separately identified. Lost responses require refresh/review, never resubmission by assumption. Unchanged tabs retain snapshots until refresh. Staging/Production and financial cutover remain excluded; production readiness DEFERRED.
