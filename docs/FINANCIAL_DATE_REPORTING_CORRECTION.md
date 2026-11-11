# Financial date and monthly reporting correction — 2026-11-11

## Scope and actual cause

Presentation/reporting correction built on the existing canonical source, accounting and reporting modules. `HistoricalImports`, `HistoricalOverview`, `CycleFoundation` and `sourceMonthMetric` defaulted to SOURCE worksheet grouping. GENERAL `sourceMonth` also fell back to worksheet month when the actual date was missing. `sourceDatePresentation` appended a translated named date to ISO, and financial tables/export builders printed ISO directly. No demonstrated incorrect canonical posting/recognition rule was found or changed.

Transaction-source monthly reporting now uses an existing audited completion.date override when explicitly present, otherwise source_date, strictly validated as a real ISO calendar date. An explicit empty/null/ambiguous override stays unconfirmed; no worksheet fallback or guessed parsing. The labelled unknown group retains records/totals and is available through the review filter. The dashboard shows its separate unknown count; unknowns never enter dated monthly totals. Optional worksheet grouping is clearly labelled provenance analysis. Payroll salary-period reporting remains distinct. GL/Treasury/Project accounting reports continue to filter by canonical posting_date; only date display changes.

A shared pure calendar formatter displays DD/MM/YYYY once in EN/AR, using integer calendar validation and string slicing, never Date/UTC conversion. Source original evidence stays unchanged and separately labelled; raw-evidence views and native ISO-backed date inputs retain original representations. Affected source lists/details, expense drafts/read views, Custody/funding, Treasury history, contractor/retention/supplier payment confirmations and financial export rows/ranges reuse this formatter. Audit timestamps and domain recognition/filter/input/command values are unchanged. Historical exports now include separate worksheet month, source file and source ID columns.

## Read-only Maker impact

Capture2026-11-11T06:08:10Z on verified project eqnzueginpkskbnqvgoc, Company matched against existing Maker identity.370 sources retained:345 General,25 Payroll.2 General records differ between worksheet month2026-09 and effective transaction month2026-08;25 General dates are unconfirmed.320 valid normalized ISO evidence comparisons show0 conflicts. This validates internal normalized evidence consistency, not independent certification of raw evidence or missing dates. No normalized-date repair is proposed. Original serial/text evidence was not rewritten or silently reinterpreted. No broad audit, financial data entry, hosted fixture, migration or mutation was performed.

Exact IDs, review status and legacy Expense/Payroll link fields for2 mismatches/25 undated sources are in the operator-only local `docs/financial-date-impact-preview.local` (excluded from Git), with private capture outside the release. This date diagnostic does not certify canonical document-claim/posting state or authorize any working-metadata edit; eligibility must be revalidated by existing audited commands. The publishable verification contains counts only. No sources are deleted, merged, reimported, duplicated or moved; no journal/payment/date/balance changes. Read-only transactions prohibit hosted writes. If subsequent evidence establishes an incorrect unposted working date, preview its exact source/document/report impact and obtain explicit Production authorization before using the existing audited completion workflow. Raw source evidence and posted journals remain immutable.

## Focused evidence and reproduction

23 pure/model/report checks PASS in Pacific/Kiritimati (UTC+14); the original20 core checks also passed Pacific/Honolulu (UTC-10).12 actual-component browser checks exercise source lists, overview and financial dashboard with deterministic synthetic rows and mocked authenticated reads.4 actual Excel/PDF artifacts pass EN/AR checks. The October worksheet/09November and September worksheet/01October examples, month boundaries, invalid/leap/ambiguous/missing/cleared dates, reviewed overrides, exact monthly totals, source provenance and posting-date distinction are covered. Browser financial mutation calls/external requests/runtime errors:0. Excel selected rows, dates and provenance checked; PDF print-preview text and generated artifacts checked. No new hosted authorization or financial mutation path exists; existing roles, RLS, grants, commands and schema are untouched.

```bash
FINANCIAL_DATE_EVIDENCE_DIR=/tmp/narvo-date-check TZ=Pacific/Kiritimati node scripts/verify-financial-dates.mjs
FINANCIAL_DATE_EVIDENCE_DIR=/tmp/narvo-date-check node scripts/verify-financial-dates-browser.mjs
FINANCIAL_DATE_EVIDENCE_DIR=/tmp/narvo-date-check python3 scripts/verify-financial-date-artifacts.py
npm run build
```

Production build and typecheck PASS. Focused lint:0 errors, existing React lifecycle/dependency warnings retained; no unrelated refactoring. Existing production dependency boundary PASS (263 files), focused secret scan and git diff --check PASS. All89 canonical migration files are byte-identical to release89; read-only hosted versions/names/SQL align1–89. No new migration, so applying/dry-running a new schema change is not applicable. Existing completed accounting/concurrency/audits were reused rather than repeated. Build retains the existing nonblocking large-chunk notice. No browser/manual Production acceptance is claimed.

## Lifecycle and delivery

Business/date reporting VERIFIED locally. Security/authorization VERIFIED for unchanged role/tenant/command paths and synthetic read-only UI; full security audit remains deferred. Database VERIFIED compatible/no changes; accounting command/schema changes NOT APPLICABLE. Deployment configuration/build compatibility VERIFIED locally; publish/deploy/live acceptance DEFERRED. Testing and documentation VERIFIED. Maker evidence completion and final operational acceptance DEFERRED. Backup restoration/USB remain deferred, not reopened.

Isolated branch `release/financial-date-reporting` at `/tmp/narvo-financial-dates-release-20261111`, based directly on existing GitHub main89 a01def446424ef7a71951bb03efc9598850f15c8. No push/deploy. Root workspace unrelated changes preserved; do not push its older mixed branch. Release commit identity is supplied in the delivery response/root receipt after committing. Owner fast-forward publishes only the isolated candidate; no force push. No hosted migration is needed. After publication, review dated monthly sources and25 unconfirmed dates; any real correction needs the separate scoped approval above.

Canonical roadmap order remains Maker operational review/acceptance → Green, Villa13 and Al Mazraa onboarding → the entire original commercial ERP roadmap, preserving all35 requirement families and deferred requirements.
