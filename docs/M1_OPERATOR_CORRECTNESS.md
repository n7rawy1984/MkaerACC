# M1 — Company workspace operator correctness

2026-11-01. Local presentation work only. No hosted requests, records, migrations, deployments or Git-history operations. Existing Development backend and Platform Owner controls are outside this batch. Final verification results are recorded below and in `docs/release/local-m1-operator-result.json`; intermediate results do not establish a completed build.

## Diagnoses and bounded changes

### Money — confirmed presentation defect

`SubcontractsList.tsx` rendered `originalContractValueMinor` and `approvedVariationsMinor` directly and translated their labels as “minor units”. Thus `6500000` appeared instead of `65,000.00 AED`. Related subcontract creation already accepts AED and parses exact minor-unit strings; certificate/payment paths already use monetary presentation. No duplicate accounting system or calculation was needed.

The two list values now reuse the existing exact signed `dashboardAED` formatter. English/Arabic labels describe business amounts. BigInt/string storage, creation parsers, VAT, retention basis points, recognition and posting inputs are unchanged. Signed variations, zero, one minor unit and values beyond Number.MAX_SAFE_INTEGER are covered. The legacy demo `domain/money.ts` number-based helpers were deliberately not imported into the authenticated financial path.

### Date — confirmed UI ambiguity, historical intent unresolved

The recorded operator example is `G-2026-08-20` / ROUND STAMP / AED60. The reported native input displayed `08/01/2026`; the operator intended **1 August 2026** and reported a manual correction. That screenshot alone does not establish the underlying stored date or prove a day/month swap.

The inspected path is:

1. `scripts/import/prepare-historical-source.py` reads raw XLSX XML cell/shared-string values. Column D becomes `source_date` unchanged and must match the approved review row. This preparer does not infer DMY/MDY or interpret Excel number formats/serial dates.
2. `scripts/import/historical-source-sql.mjs` loads the payload into PostgreSQL's `date` column. This is the canonical imported `source_date`; the source's raw values remain in `raw_source`.
3. An independently saved reviewer override is `completion.date`. `sourceValue` chooses that override when present; original imported data remains separate.
4. The original listing localized ISO values using a named month, but the edit form used a browser-native date picker. Its visible month/day order depends on browser locale; `.value` remains ISO. Regex-only list validation also allowed invalid calendar dates to normalize in JavaScript.

Added a presentation-only strict ISO/calendar classifier and UTC/Gregorian named-month formatter. It never parses slash dates, Excel serials, timestamps or source-month guesses. Known ISO values show both `YYYY-MM-DD` and a localized named month. Missing input is Unknown; non-ISO/impossible dates retain their literal evidence and an unresolved warning. No financial/reporting-month calculation or import/posting parser changed.

The edit/details panel separately shows stored imported date, saved review date and current selected input, with a browser-locale explanation. Original workbook values remain in Source details. The source table now uses the same strict presentation. Existing ISO input values and save payloads are unchanged.

**Evidence/decision still required:** the original workbook cell/type/number format, approved review/payload and actual row/audit before/after for `G-2026-08-20` are not available as local original evidence in this batch. No hosted read or correction was performed. Obtain those records and accountant confirmation before deciding whether any historical date needs correction. Never infer a correction from August source grouping, slash display, or a screenshot. No historical dates were reinterpreted, rewritten or bulk-corrected.

### Save visibility — reproduced white-on-white defect

A real-CSS isolated Chromium reproduction measured both text and background as `rgb(255,255,255)` on the historical source edit Save button. The shared secondary class included `bg-white`; the appended primary class also included `bg-blue-700`/`text-white`. Tailwind's generated ordering selected white background. Class order in the HTML did not fix it.

Separated common geometry from secondary/primary colors so the save control has one background. It now reads **Save changes / حفظ التعديلات**, uses matching accessible names, visible **Saving changes…** state, `aria-busy`, disabled protection and a sticky action area within the existing form. Existing uncertainty/error feedback and lock/version/identity guards are preserved and tested. Clear copy states that this saves source review only; it neither posts accounting nor makes a payment.

The separate New Expense form already had a readable **Post expense / ترحيل المصروف** button and correct translations. It was not the reproduced blank control. Added matching accessible naming, focus/size treatment and explanatory text: posting creates the accounting entry and is not saving an independent draft. No new draft, save/post implementation, financial confirmation or permission model was introduced.

## Files in this batch

Runtime:

- `src/master/SubcontractsList.tsx`
- `src/historical/sourceDatePresentation.ts` (new)
- `src/historical/SourceEditor.tsx`
- `src/historical/HistoricalImports.tsx`
- `src/financial/TreasuryExpensePost.tsx`
- `src/i18n/en.ts`, `src/i18n/ar.ts`

Verification:

- `scripts/verify-m1-operator.mjs` (new)
- `scripts/verify-m1-operator-browser.mjs` (new)
- `scripts/fixtures/m1-operator-correctness.tsx` (new synthetic transport)
- `scripts/verify-historical-source-interactions.mjs`: existing Save selectors updated to the explicit Save changes accessible name; test assertions were not removed.

Documentation/evidence: this record, the structured result, synthetic captures and current handoff/roadmap checkpoint. Existing dirty work is preserved; no package/dependency or Platform Owner file is changed by M1.

## Verification and limits

- Exact money/date/preservation checks:43 PASS, including signed BIGINT extremes, leap/invalid/missing/slash dates and154 unchanged protected source hashes.
- Focused Chromium matrix:77 PASS, real components/CSS/translations; EN/AR RTL,1440/390px,125%/200% CSS zoom, contrast>=4.5, source-save busy/error/exact payload/version behavior, viewer denial, no posting from review, and en-US/Los Angeles versus en-GB/Dubai date-value stability.
- Existing source-confirmation and command/idempotency checks PASS.
- Existing ordinary Treasury Expense POST browser regression PASS, including lost-response recovery, readback/no-repost, role/tenant boundaries and Arabic narrow layout.
- Existing subcontract metadata browser regression PASS, including exact update/version payloads, stale edits, recovery and role/tenant/focus behavior.
- Source-review save/confirm handlers and Treasury Expense state/normalization/validation/confirmation/idempotency/submission/recovery blocks are byte-identical to the pre-M1 package. All canonical SQL/Edge/Platform Owner files remain unchanged.
- Final build/lint and evidence reconciliation are recorded in the final checkpoint below.

Only synthetic clients were used; browser requests outside the local fixture were blocked. No hosted workflow, original workbook reimport, business posting or historical-data correction was executed. Existing historical browser export suite was not rerun in full; its updated Save selectors passed syntax validation. Firefox/Safari and real assistive-technology/manual owner acceptance are not claimed. Narrow screenshots are synthetic fixture data, not Maker financial records.

## Final verified local checkpoint

**LOCAL IMPLEMENTATION VERIFIED; ORIGINAL HISTORICAL DATE INTENT UNRESOLVED.** [Machine-readable result](release/local-m1-operator-result.json). The final77-assertion browser run includes the finalized fixture/captures and zero runtime errors. Agent visually reviewed actual EN/AR date evidence, narrow primary save actions and exact AED list values.

`npm run build` **PASS**, exit0,2737 modules; existing large-chunk advisory retained (authenticated bundle798.64kB minified/175.24kB gzip). `npm run lint` **PASS**, exit0, the same10 pre-existing warnings and no new warning. Syntax and `git diff --check` pass. No dependencies/package scripts changed.

Business/accounting **VERIFIED** for presentation boundaries; actual historical date correction **DEFERRED pending original evidence/accountant approval**. Security/authorization **VERIFIED** for unchanged protected handlers plus focused synthetic regressions. Database work **NOT APPLICABLE**; migrations/Edge/Platform Owner sources unchanged. Deployment **DEFERRED**. Testing **VERIFIED** within the documented local scope; manual hosted/Firefox/Safari/screen-reader acceptance **DEFERRED**. Documentation **VERIFIED**. This is not a commercial or Production readiness declaration.

[Before white-on-white](release/m1-operator-correctness/before-save.png), [English fixed action](release/m1-operator-correctness/save-en-390.png), [Arabic fixed action](release/m1-operator-correctness/save-ar-390.png), [English date evidence](release/m1-operator-correctness/date-evidence-en.png), [Arabic date evidence](release/m1-operator-correctness/date-evidence-ar.png), [exact subcontract AED](release/m1-operator-correctness/subcontracts-en.png). All captures use synthetic records.

Next checkpoint is owner review of local M1 changes. Preview deployment and any historical-data correction require separate approval. Resolving the historical date case still requires the original workbook and read-only source/audit evidence. Do not begin M2 or other roadmap work from this result.
