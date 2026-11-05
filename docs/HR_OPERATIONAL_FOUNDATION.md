**Release update 2026-11-05:** migration81 is now APPLIED and read-only hosted postflight PASS. The prior25006 blocker is resolved by a private STABLE non-locking read authorization helper; financial command locks remain unchanged. Original local checks plus21 focused real PostgREST/native regressions passed. Frontend publication remains pending the owner's push/Vercel confirmation. See `docs/HR_OPERATIONAL_RELEASE.md`; earlier local-only status below is the implementation checkpoint, superseded for hosted activation only.

# Essential HR, Attendance and Payroll — local operational increment

Status: local implementation; migration 81 NOT applied hosted; no Git publication or deployment authorized. The prior expense milestone's uncommitted source files remain preserved. This increment extends H1/H2/H3; H4 and full HR are not declared complete.

## Supported business events and policy

Employee registration reuses the Company Party master and Employee/person roles. Payroll profiles retain operator identifiers and descriptive information. New append-only dated terms carry employment intervals, monthly basic/recurring allowances, ISO weekdays, one scheduled shift (including overnight), unpaid breaks and default Project. Amendments take effect later than their predecessor and cannot alter locked payroll history. An ENDED version takes effect the day after its recorded last employment date.

An Accounting Admin must explicitly approve Company cutover and the supported `SCHEDULED_MINUTES` policy in Asia/Dubai. No automatic adoption or change to existing Lite periods occurs. Cutover cannot reinterpret existing payroll periods, reviewed/locked attendance or Lite exceptions. Existing Lite absence and calculation semantics remain available before cutover.

For the supported policy each effective monthly component is prorated over that term's full-month scheduled working minutes, weighted by each employed day's expected minutes (nominal) and actual regular work plus approved paid-leave minutes (earned). Each employee/component rounds once to AED minor units, using exact PostgreSQL numeric intermediates and BIGINT stored money. No statutory daily divisor, overtime multiplier or leave entitlement is presumed. Calendar rest/holiday overrides remove expected minutes; missing facts never prove attendance. Overtime requires an explicitly evidenced approved earned amount. Operator approval of this policy is required before real Company use.

## Operational workflow

1. Register/reuse Employees in Parties; maintain existing payroll identifiers/profiles.
2. Accounting Admin approves cutover, account mappings and dated employment terms. Setup can reuse approved stable-key accounts or explicitly create named/coded missing accounts; it creates no opening amount. Used unrelated accounts cannot be repurposed. Optional employee advance receivable must be a dedicated ASSET requiring Party.
3. Record explicit daily actual facts in the month matrix: present/absence, paid/unpaid leave, partial minutes, rest/holiday, overnight/break intervals and site. One actual interval and one site per employee/day are supported. Selecting a scheduled interval as actual requires an explicit operator action and evidence. Bounded bulk selection previews at most 100 cells and saves atomically.
4. Complete all eligible employment days, resolve stale facts and confirm revision-bound monthly review. Corrections append versions, invalidate review and never manufacture financial entries.
5. Refresh the existing Payroll draft; inspect earned components, minutes, adjustments, recovery and cash entitlement. Confirm derived site allocation and supported adjustment classification; review; Accounting Admin posts the completed month through canonical payroll commands.
6. Record actual Treasury/Bank salary payments, including partial payments, against the existing entitlement. Treasury funds controls and once-only request semantics remain active.
7. Correct through dependent payment reversal, payroll/recovery reversal, corrected facts/review and replacement payroll. Posted snapshots and journals remain immutable.

Employee salary advances are independent approved receivables: Dr employee advance asset / Cr actual Treasury. An explicit recovery agreement sets the monthly cap and an approved per-month plan. Payroll recognizes full earned salary cost / salary payable once. Recovery posts a separate Dr salary payable / Cr employee receivable journal. Actual salary payments clear only remaining cash entitlement. Reversing payroll also reverses its recoveries; advance reversal is blocked while recoveries remain live. A reversed advance no longer contributes an unposted recovery plan.

Labor cost is split between actual daily Project/Company weights using deterministic largest-remainder allocation of the one recognized amount; the total exactly equals earned payroll cost. Advances, recoveries and payments add no labor expense. Existing project-cost reporting reads those canonical journals and preserves reversal/source traceability; access restrictions can hide payroll and are disclosed in the report.

## Authorization and privacy

Existing Company membership and permissions remain authoritative. Admin approves terms/policy/accounts/advances/recovery and posts/reverses payroll. Authorized Accountant can read HR/payroll, review, prepare and use existing permitted settlement commands. Explicit attendance capture retains `attendance.record`; no permission is added to the ordinary Accountant. Management Viewer has no payroll navigation, HR component, historical PAYROLL source/audit rows, payroll tables or confidential payroll/advance/recovery journal lines. General historical sources retain their existing visibility. New tables force RLS; browser direct writes and private helper execution are denied.

Foreman’s existing Lite path is preserved. The new explicit mode currently uses the payroll-authorized Accounting Admin operator; a salary-free explicit Foreman entry adapter is deferred, rather than granting Foreman access to employment pay. Before choosing cutover, confirm this operating model is acceptable. No Management salary visibility is introduced.

Requests freeze actor/Company/business inputs and hashes with Company serialization, optimistic versions and append-only evidence. The browser stores only unresolved command intent in actor/Company-scoped session storage; it retries the identical request and locks changes while outcome is uncertain. It does not cache a business ledger. Session changes clear displayed HR data; malformed pending intent fails closed.

## Screens and output

The new HR workspace is mounted in authenticated Attendance and Payroll screens, reusing existing components/styles and five themes. It provides employment history, readiness mappings, calendar overrides, explicit month matrix with keyboard/bulk controls, review and advance/recovery actions. Existing Payroll draft, posting, settlement and reversal screens remain in use.

Attendance XLSX and printable PDF include Company/month, explicit unknown/stale status, actual/expected/leave/unpaid/overtime minutes, evidence and review status. Payroll register XLSX/PDF uses hours/minutes, earned amounts, combined labeled reductions/recoveries and net cash entitlement for the new mode; legacy registers retain original columns/semantics. Individual posted payslips include components, earned cost, separate recovery, actual payment history, remaining payable and immutable journal references. Existing project-cost XLSX/PDF reports provide posted labor/source/reversal visibility. A confirmed narrow-screen table compression defect was corrected with minimum table widths inside the existing scroll regions; no report calculations changed. PDF uses the existing browser print/Save PDF infrastructure, not a statutory payslip certification.

## Deferred and operational prerequisites

Not implemented: statutory UAE wage/leave/termination calculations, WPS/bank submission format, legal deduction caps, leave-balance accrual, multiple shifts/sites within one day, salary-free explicit Foreman delegation, full fiscal close, HR document storage redesign, or Maker data preparation/import. No legal/WPS compliance is claimed. Unsupported treatment requires approved policy, not invented journal lines.

Before controlled release: authorize migration/application release separately; verify exact hosted history/target and reviewed SQL hash, preservation and current backup scope; migrate before publishing matching frontend; perform read-only postflight and human visual/operator acceptance. Then separately approve real Company payroll policy, mappings, employment data and evidence. No real employee attendance, salary, advance or opening values are seeded by migration.

The approved five-phase strategy remains: complete essential operational modules → prepare Maker Excel → import and verify → daily operations → broader commercial roadmap. This task stays in phase 1.

## Verification and lifecycle status

Focused evidence is recorded in `docs/hr-operational-verification.json` after execution. Actual test counts/results and limitations must be read there; historical Lite campaigns are reused as context and were not rerun wholesale.

Business/accounting, security/authorization, database, testing and documentation: local verification only, subject to the recorded evidence. Deployment/hosted activation and real Company acceptance: DEFERRED. Final disaster-recovery rehearsal and comprehensive pre-go-live integrity audit remain separate future gates; no restoration rehearsal was performed here.

Executed result (2026-11-05): **56 main database checks + 4 excluded-employee recovery regressions, 5 real native PostgreSQL concurrency scenarios, 18 actual browser checks and 14 generated XLSX/PDF artifact checks PASS**. Production build PASS (existing large-chunk warning); focused lint PASS with no warnings/errors; production import boundary, focused secret-pattern scan and diff whitespace check PASS. Arabic mobile screenshots were inspected and the confirmed table compression corrected. Final linked read-only dry-run lists only migration81; exact hosted1–80 SQL history and the final tested81 hash are recorded in the JSON evidence. No hosted writes.

| Lifecycle category | Disposition |
|---|---|
| Business/accounting | VERIFIED locally for the documented supported policy; actual Company approvals/data DEFERRED |
| Security/authorization | VERIFIED locally: tenant, role, historical privacy, private helper and direct-write boundaries |
| Database | VERIFIED local canonical81 on PGlite and native PostgreSQL; hosted alignment VERIFIED read-only; activation DEFERRED |
| Deployment | DEFERRED; no commit, push, migration application or frontend deployment authorized |
| Testing | VERIFIED local automated/native/browser/artifacts/build; human operational acceptance DEFERRED |
| Documentation | VERIFIED roadmap, requirements, handoff and phase evidence reconciled; full H1–H4 completion not claimed |

Final correction regression also proves that an excluded retained payroll draft row cannot post an old recovery or silently discharge its employee advance. The excluded evidence remains visible to authorized staff; the outstanding receivable is preserved. The final SQL hash and read-only alignment were rechecked after this SQL-only guard. Browser/artifact/build results are retained for the unchanged application paths; this reuse is explicit in the evidence.

Reproduce focused local checks with `node scripts/verify-hr-operations.mjs`, `node scripts/verify-hr-excluded-recovery.mjs`, `node scripts/verify-hr-races.mjs`, `node scripts/verify-hr-browser.mjs`, `python3 scripts/verify-hr-exports.py` and `npm run build`. Native concurrency uses the already available disposable embedded PostgreSQL runner under `/tmp/narvo-priority-native`; browser checks require local Chromium and a localhost fixture server. These scripts do not accept hosted database credentials. Generated synthetic PDF/XLSX/screenshots remain under `/tmp/narvo-hr-*`; no business data or credentials are bundled.
