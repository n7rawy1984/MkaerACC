# HR, Attendance and Payroll — migration81 activation and release handoff

2026-11-05. Product Owner authorized the bounded read-only RPC correction, focused verification, canonical81 activation and one isolated local release commit. The owner performs the authenticated GitHub push. No push, Vercel deployment or new project was attempted.

## Actual database result

- Existing shared project `eqnzueginpkskbnqvgoc` verified healthy and correctly linked.
- **Migration81 APPLIED:** `20261105120000_hr_operational_foundation.sql`, SHA256 `b60e0bee43d16a5b7c7f6a5fef225582db0c84085dd9e914608b0ee35046f44f`.
- Canonical hosted1–80 SQL and all29 direct function bodies matched before activation. An isolated canonical1–81 CLI package, forced-read-only dry-run listing only81, then `migration up --linked` applied that sole approved pending migration. No blanket migration push, reset, manual schema patch or data backfill.
- Activation: 2026-11-05T11:29:39.961068+00:00. Read-only postflight: 2026-11-05T11:29:54.034913+00:00. Canonical1–81 aligns and no migration remains pending.
- All75 existing financial/business/access/Auth/profile/membership/MFA/Owner table fingerprints match the fresh pre-activation baseline. The fingerprint of legacy payroll rows omits only the newly added null `hr_basis` column, so existing values are compared exactly. No accounting command, journal, payment, source import, employee setup, membership or subscription mutation occurred.
- Nine public HR tables are empty, force RLS, have SELECT-only payroll permission policies and immutable evidence triggers. The private receipt table is empty and inaccessible to browser roles. Private helpers deny authenticated/anonymous/service-role execution; public RPC grants and fixed search paths are verified. Existing financial helper definitions, locks, journal guards, permissions and all unchanged dependencies remain intact. The only CHECK extension retains the exact old half-unit rule for null-HR legacy rows.
- Legacy payroll source comparison has zero mismatches; every journal remains balanced. Admin and Accountant read-only HR/profile queries succeed. Management Viewer has no payroll permission and now reads **zero historical PAYROLL source and audit rows** (previously25 sources/one audit row for the retained Company). Current HR data was not fabricated.

## Exact compatibility correction

The previous release stopped before activation because STABLE `read_hr_workspace` called `private.operational_finance_actor`; that write helper takes three `FOR SHARE` locks, producing SQLSTATE25006 under read-only execution. PostgREST runs STABLE GET/POST RPCs read-only: [official transaction reference](https://docs.postgrest.org/en/stable/references/transactions.html#access-mode-on-functions).

Unapplied81 was corrected by adding private STABLE `hr_read_actor` and redirecting only `read_hr_workspace`. The read helper preserves the same authenticated identity, active Company/profile/membership, Accountant/Admin role and `payroll.manage` checks at the statement snapshot, without row locks. The public projection remains STABLE/SECURITY DEFINER; the helper is private, invoker-scoped and has no browser EXECUTE grant. Financial commands retain the original locking helper. Reconstructing the prior migration text yields its exact approved SHA256 `9a8ef8b96a4eb5596021b19ec8442a6a64e855c78a9bc37cd3a6c8555d605abd`; no previously applied migration or write-command source was edited.

## Focused evidence

Original60 database/five concurrency/18 browser/14 artifact checks and production build/focused lint are reused for unchanged application/accounting behavior. The added21 checks use official standalone PostgREST16.5, actual signed synthetic JWT GET/POST requests and disposable native PostgreSQL. They verify Admin/Accountant success, anonymous/Viewer/tenant denial, inactive profile/membership denial, historical source/audit privacy, legacy read compatibility, unchanged financial tables after reads, private STABLE grants, real financial row-lock blocking, and canonical payroll posting/partial payment/payment reversal/payroll reversal with restored advance balance and balanced journals. No full historical campaign was repeated. See `docs/hr-readonly-rpc-verification.json` and the complete manifest in `docs/hr-operational-verification.json`.

## Recovery and scope limits

Existing encrypted migration75 database/roles exports remain available and match recorded sizes/SHA256/scope evidence. They predate76–81 and are not a current81 recovery point. Restoration remains untested; no guarantee or rehearsal is claimed. The Product Owner's active-development risk-based policy remains in force; full DR verification remains a final operational-readiness gate. Frontend rollback cannot undo this migration or subsequent posted financial events. Durable database defects require approved forward correction; financial corrections use canonical reversals.

The new payroll mode remains explicitly opt-in. No Company policy, mappings, terms, attendance, opening values or payroll transactions were seeded. Actual Company approval/evidence/setup and operational acceptance remain required. Legal/WPS, statutory leave/rates/termination, intraday multi-site/multi-shift, salary-free explicit Foreman delegation and full fiscal closing remain deferred. This release is not final Maker Go-Live certification. No Maker Excel processing occurred.

## Isolated publication handoff

Existing repository `n7rawy1984/MkaerACC`, current verified GitHub main `1fac514ab4e9bfc5d208cee0d3acc943ea00429b`. Isolated release directory `/tmp/narvo-hr-payroll-release-20261105`, dedicated branch `release/hr-attendance-payroll-81`. Only the HR milestone, bounded fix, migration81, focused evidence/tests and directly necessary canonical documentation are included; exact allowlist is `files` in `docs/hr-operational-verification.json`. Source development branch/uncommitted work is preserved. Temporary tools, protected fingerprints, credentials, .env, backups, node_modules and Supabase .temp are excluded.

Local commit SHA is returned in the final handoff and private release record to avoid self-reference in the commit. Owner command after reviewing that commit:

`git -C /tmp/narvo-hr-payroll-release-20261105 push origin HEAD:main`

Normal fast-forward only. If main advances, stop and reconcile; never force-push. Preserve this `/tmp` worktree if publication is delayed. GitHub push, exact Vercel deployed SHA/ID, existing maker Production target and Ready state remain to be confirmed by the owner. No publication is claimed.

After deployment, inspect authenticated Employee terms/setup, explicit attendance matrix/review, Payroll profiles/draft/accounting/history, advances/recoveries, payslips and attendance/register/labor reports. Verify Viewer denial, Accountant permissions, Arabic RTL/English LTR and narrow/desktop layouts. Initial Production smoke is non-mutating; any actual setup, attendance, posting, payment or reversal needs real approved business evidence, not synthetic Production records.
