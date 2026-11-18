# CR-03 — Bank Statement Reconciliation

CR-03 is locally verified, not published. Previous compatible `a5793111454b6493abe49c485f4cc479fada191a` is already GitHub main and Vercel Production; no republication performed. Hosted95–100 remain applied. Migration101 is prepared and requires explicit hosted authorization.

Reuses existing Bank/Treasury account-to-GL mapping, authenticated Company actor/permissions, shared financial locks/idempotency, canonical journal/reversal commands, fiscal/annual controls, numeric dates/money, ReportExport and journal drilldown. Seven evidence/control tables record imported rows and match allocations without parallel financial balances. `/bank-reconciliation` is in the accountant/Admin financial sidebar. Confidential complete Bank balances require Payroll ledger coverage; Management Viewer does not bypass that restriction.

## Actual executed answer key

Separate disposable fictional Company; original65-scenario/63-journal evidence untouched. One certified opening10,000. Earned-service receipts1,000 and300, plus500deposit in transit; actual payment400 and200unpresented. Bank statement movements: +1,000 −400 +100 +200 −10fee +5interest = +895; closing10,895. Two statement amounts100/200 partially settle the posted300receipt. No duplicate cash is created by either allocation.

| Stage | Independently expected AED | Actual AED |
|---|---:|---:|
| Statement opening |10,000.00|10,000.00|
| Statement closing |10,895.00|10,895.00|
| Deposit in transit |500.00|500.00|
| Unpresented payment |200.00|200.00|
| Adjusted statement |11,195.00|11,195.00|
| GL Bank after charges/interest |11,195.00|11,195.00|
| Difference / unmatched statement after matching |0.00 /0.00|0.00 /0.00|

Fee: Dr Bank Charges10 /Cr Bank10. Interest: Dr Bank5 /Cr Interest Income5. Both use approved typed Company account mappings and explicit supported tax treatment, no automatic VAT claim. After dependency-controlled unmatch, canonical reversal exactly debits Bank10/credits Charges10. Original/reversal remain immutable audit but are not fake outstanding deposits/payments. A corrected Expense through existing `post_expense` debits Company cost10/credits Bank10 and is matched to the same real statement charge. Final Bank remains11,195 with zero difference and no duplicate cash. **10actual fictional Company journals** including the opening, initial8journal reconciliation and two correction journals. [Exact journal lines](cr03-bank-reconciliation-journals.csv).

Later statement clears the500deposit without changing its outstanding status on the earlier statement. A separate actual browser Company, without outstanding items, reconciles10,595; Arabic unmatch/reversal/replacement restores that same balance. These separate Companies are not combined.

## Verification and boundaries

**75 passing focused assertions**, with individual names/actual canonical receipts and journal rows in [verification JSON](cr03-bank-reconciliation-verification.json). Includes reference/date matching, ambiguity, partial allocations, duplicates, outstanding items, fees/interest, closed periods, reversal dependencies, actual independent native waits/races, tenant/role/direct-write/RLS safeguards, same-key refresh recovery, stale-file prevention, actual EN/AR browser commands and exported artifacts. Original142foundation and176commercial checks reused, not rerun. TypeScript, Production build and scoped lint pass; existing bundle-size advisory retained. Actual rendered screenshots inspected.

[English reconciled Excel](cr03-bank-reconciliation/reconciled-en.xlsx), [Arabic Excel](cr03-bank-reconciliation/reconciled-ar.xlsx), [English PDF](cr03-bank-reconciliation/reconciled-en.pdf), [Arabic PDF](cr03-bank-reconciliation/reconciled-ar.pdf). Reports identify Bank scope, statement dates, exact reconciliation, GL trace, outstanding items and match audit. Browser samples at10,595 are separately named bank-en/ar exports; reconciled-en/ar files use the main11,195scenario.

Limits are explicit: UTF-8 comma CSV or bounded XLSX1900-date workbooks, no formula execution/1904/XLS/XLSM/FX/feed/OCR. Complete, non-overlapping statement periods with verified opening/closing are required. Partial matching cannot hide fees or netting; different signs/cash effects need correct canonical documents. Other expense/receipt/settlement/tax treatment uses existing appropriate workflows, then matching. Mapping controls need Accounting Admin authorization; no real Company configuration occurred. Finalization requires complete statement matching and zero difference, while actual outstanding book deposits/payments remain reconciled bridge items.

## Release gates

Migration101 `20261119120000_bank_statement_reconciliation.sql`: **PREPARED / NOT APPLIED**, exact SHA256 in verification JSON. Additive seven-table schema, Company-scoped FK identity on existing journal lines, RLS/minimal grants, typed bank commands, immutable audit and final-bank movement guard; no real financial backfill. Fresh linked dry-run shows only101 pending after applied100. Explicit scoped authorization → hosted101 activation/preservation → compatible frontend publication → separately authorized Company fee/interest setup. No hosted data writes, migration application, push or deployment in CR-03.

Next original Commercial Readiness priorities remain supplier physical returns, construction/WIP policy, remaining essential scenarios and final integrated fictional acceptance. Entire commercial readiness is not declared complete; deferred DR/USB and other roadmap requirements remain preserved.
