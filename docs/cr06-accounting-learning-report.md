# CR06 — Executed accounting gap closure

Local development verification only. Hosted104 is NOT APPLIED. No real Company financial records were changed. CR07 was not started.

The six original baseline failures are preserved in `cr06-evidence/baseline.json`. Additional direct integrations were fixed where the new canonical paths exposed an accounting dependency. Existing65/CR05 evidence is unchanged and was not rerun.

## Fixed blockers

- **FA_MONTH_END** — Disposal at month end accepted without that completed month depreciation.
- **TREASURY_TRANSFER** — No canonical Treasury-to-Treasury transfer command.
- **AP_ASSET** — Asset register only supports separate paid capitalization; cannot adopt a genuine canonical AP acquisition without another outflow.
- **TAX_ADVANCE** — Taxable customer advances rejected; only non-taxable deposits supported.
- **CONTRACT_AR_AMBIGUITY** — Migration103 contract-specific AR call fails with ambiguous kind column.
- **PAID_CONSTRUCTION_CREDIT** — Paid construction bill has no controlled credit-note path.
- **RECOGNITION_CORRECTIONS** — Typed Admin reversals, dependencies, traced one-to-one corrected replacements.
- **ACTUAL_DAY_PREPAYMENTS** — Actual dated continuous service cutoff and exact final remainder.
- **ASSET_SALE** — Atomic existing AR/VAT sale plus retirement; credit/cash settlement and price adjustments.
- **ALLOCATED_SUPPLIER_CREDIT** — Actual price credits follow asset/WIP/consumed costs; prospective depreciation and reversal dependencies.
- **ASSET_CASH_FLOW** — Linked AR collections/acquisition payments are Investing; mixed Supplier payments split without new GL.

## Independently expected versus actual posted entries

Amounts below are AED; every row was executed through existing canonical commands in a disposable fictional Company and compared to an independent debit/credit oracle. Exact resulting journals and lines are in `cr06-evidence/gaps.json`. These are targeted operations, not a replay or claim of final integrated acceptance.

| Executed operation | Expected debits / credits | Actual |
|---|---|---|
| Supplier credit acquisition | COMPANY_EXPENSE: Dr 1,200.00 / Cr 0.00; SUPPLIER_PAYABLE: Dr 0.00 / Cr 1,200.00 | MATCH |
| AP asset capitalization | ASSET_COST: Dr 1,200.00 / Cr 0.00; COMPANY_EXPENSE: Dr 0.00 / Cr 1,200.00 | MATCH |
| Asset AP settlement | SUPPLIER_PAYABLE: Dr 1,200.00 / Cr 0.00; BANK: Dr 0.00 / Cr 1,200.00 | MATCH |
| Documented tax-point advance | BANK: Dr 1,050.00 / Cr 0.00; CUSTOMER_ADVANCE: Dr 0.00 / Cr 1,000.00; OUTPUT_VAT: Dr 0.00 / Cr 50.00 | MATCH |
| Final taxable service invoice | AR: Dr 2,100.00 / Cr 0.00; REVENUE: Dr 0.00 / Cr 2,000.00; OUTPUT_VAT: Dr 0.00 / Cr 100.00 | MATCH |
| Partial tax deposit application | CUSTOMER_ADVANCE: Dr 500.00 / Cr 0.00; OUTPUT_VAT: Dr 25.00 / Cr 0.00; AR: Dr 0.00 / Cr 525.00 | MATCH |
| Unused taxable advance refund | CUSTOMER_ADVANCE: Dr 500.00 / Cr 0.00; OUTPUT_VAT: Dr 25.00 / Cr 0.00; BANK: Dr 0.00 / Cr 525.00 | MATCH |
| Bank transfer | BANK2: Dr 300.00 / Cr 0.00; BANK: Dr 0.00 / Cr 300.00 | MATCH |
| Same transfer request replay | Idempotent replay: no new journal | MATCH |
| Transfer reversal | BANK: Dr 300.00 / Cr 0.00; BANK2: Dr 0.00 / Cr 300.00 | MATCH |
| Paid scheduled asset | ASSET_COST: Dr 1,200.00 / Cr 0.00; BANK: Dr 0.00 / Cr 1,200.00 | MATCH |
| Completed-month depreciation | DEPRECIATION_EXPENSE: Dr 100.00 / Cr 0.00; ACCUMULATED_DEPRECIATION: Dr 0.00 / Cr 100.00 | MATCH |
| Month-end disposal after depreciation | ACCUMULATED_DEPRECIATION: Dr 100.00 / Cr 0.00; DISPOSAL_LOSS: Dr 1,100.00 / Cr 0.00; ASSET_COST: Dr 0.00 / Cr 1,200.00 | MATCH |
| Erroneous disposal reversal | ASSET_COST: Dr 1,200.00 / Cr 0.00; ACCUMULATED_DEPRECIATION: Dr 0.00 / Cr 100.00; DISPOSAL_LOSS: Dr 0.00 / Cr 1,100.00 | MATCH |
| Depreciation correction reversal | ACCUMULATED_DEPRECIATION: Dr 100.00 / Cr 0.00; DEPRECIATION_EXPENSE: Dr 0.00 / Cr 100.00 | MATCH |
| Corrected depreciation | DEPRECIATION_EXPENSE: Dr 100.00 / Cr 0.00; ACCUMULATED_DEPRECIATION: Dr 0.00 / Cr 100.00 | MATCH |
| Accrual recognition | ACCRUAL_EXPENSE: Dr 100.00 / Cr 0.00; ACCRUED_LIABILITY: Dr 0.00 / Cr 100.00 | MATCH |
| Accrual reversal | ACCRUED_LIABILITY: Dr 100.00 / Cr 0.00; ACCRUAL_EXPENSE: Dr 0.00 / Cr 100.00 | MATCH |
| Traced corrected accrual | ACCRUAL_EXPENSE: Dr 90.00 / Cr 0.00; ACCRUED_LIABILITY: Dr 0.00 / Cr 90.00 | MATCH |
| Accrual settlement | ACCRUED_LIABILITY: Dr 90.00 / Cr 0.00; BANK: Dr 0.00 / Cr 90.00 | MATCH |
| Continuous prepaid service | PREPAYMENT: Dr 1,000.00 / Cr 0.00; BANK: Dr 0.00 / Cr 1,000.00 | MATCH |
| Actual-day October cutoff | ACCRUAL_EXPENSE: Dr 459.46 / Cr 0.00; PREPAYMENT: Dr 0.00 / Cr 459.46 | MATCH |
| Final coverage-day amortization | ACCRUAL_EXPENSE: Dr 540.54 / Cr 0.00; PREPAYMENT: Dr 0.00 / Cr 540.54 | MATCH |
| Construction taxable progress bill | AR: Dr 1,050.00 / Cr 0.00; CONTRACT_LIABILITY: Dr 0.00 / Cr 1,000.00; OUTPUT_VAT: Dr 0.00 / Cr 50.00 | MATCH |
| Earned contract revenue | CONTRACT_LIABILITY: Dr 1,000.00 / Cr 0.00; REVENUE: Dr 0.00 / Cr 1,000.00 | MATCH |
| Construction Customer collection | BANK: Dr 1,050.00 / Cr 0.00; AR: Dr 0.00 / Cr 1,050.00 | MATCH |
| Paid progress invoice credit | CONTRACT_ASSET: Dr 100.00 / Cr 0.00; OUTPUT_VAT: Dr 5.00 / Cr 0.00; CUSTOMER_ADVANCE: Dr 0.00 / Cr 105.00 | MATCH |
| Separately evidenced earned-revenue correction | REVENUE: Dr 100.00 / Cr 0.00; CONTRACT_ASSET: Dr 0.00 / Cr 100.00 | MATCH |
| Actual Customer credit refund | CUSTOMER_ADVANCE: Dr 105.00 / Cr 0.00; BANK: Dr 0.00 / Cr 105.00 | MATCH |
| Supplier asset acquisition price credit | SUPPLIER_PAYABLE: Dr 100.00 / Cr 0.00; ASSET_COST: Dr 0.00 / Cr 100.00 | MATCH |
| Credit-funded asset sale | AR: Dr 1,470.00 / Cr 0.00; REVENUE: Dr 1,400.00 / Cr 1,400.00; OUTPUT_VAT: Dr 0.00 / Cr 70.00; ASSET_COST: Dr 0.00 / Cr 1,100.00; DISPOSAL_GAIN: Dr 0.00 / Cr 300.00 | MATCH |
| Asset sale receipt | BANK: Dr 1,470.00 / Cr 0.00; AR: Dr 0.00 / Cr 1,470.00 | MATCH |
| Asset sale price credit | DISPOSAL_GAIN: Dr 100.00 / Cr 0.00; OUTPUT_VAT: Dr 5.00 / Cr 0.00; CUSTOMER_ADVANCE: Dr 0.00 / Cr 105.00 | MATCH |
| Project supplier acquisition | PROJECT_COST: Dr 1,000.00 / Cr 0.00; SUPPLIER_PAYABLE: Dr 0.00 / Cr 1,000.00 | MATCH |
| Partial future-performance capitalization | CONSTRUCTION_WIP: Dr 600.00 / Cr 0.00; PROJECT_COST: Dr 0.00 / Cr 600.00 | MATCH |
| Actual WIP consumption | COGS: Dr 200.00 / Cr 0.00; CONSTRUCTION_WIP: Dr 0.00 / Cr 200.00 | MATCH |
| Supplier price credit across WIP and consumed cost | SUPPLIER_PAYABLE: Dr 100.00 / Cr 0.00; CONSTRUCTION_WIP: Dr 0.00 / Cr 40.00; COGS: Dr 0.00 / Cr 20.00; PROJECT_COST: Dr 0.00 / Cr 40.00 | MATCH |
| Final adjusted WIP release | COGS: Dr 360.00 / Cr 0.00; CONSTRUCTION_WIP: Dr 0.00 / Cr 360.00 | MATCH |
| Prospective asset cost reduction | SUPPLIER_PAYABLE: Dr 120.00 / Cr 0.00; ASSET_COST: Dr 0.00 / Cr 120.00 | MATCH |
| Prospective depreciation after actual price credit | DEPRECIATION_EXPENSE: Dr 90.00 / Cr 0.00; ACCUMULATED_DEPRECIATION: Dr 0.00 / Cr 90.00 | MATCH |
| Reverse latest adjusted depreciation before credit correction | ACCUMULATED_DEPRECIATION: Dr 90.00 / Cr 0.00; DEPRECIATION_EXPENSE: Dr 0.00 / Cr 90.00 | MATCH |
| Correct source price credit after unwinding dependencies | ASSET_COST: Dr 120.00 / Cr 0.00; SUPPLIER_PAYABLE: Dr 0.00 / Cr 120.00 | MATCH |
| Mixed Supplier payment for asset and Project resource | SUPPLIER_PAYABLE: Dr 200.00 / Cr 0.00; BANK: Dr 0.00 / Cr 200.00 | MATCH |

## Reconciled answer key

Period Trial Balance movement: **Dr = Cr AED 27,915.00**. Assets **103,625.00** = liabilities **2,115.00** + recorded equity **100,500.00** + unclosed profit **1,010.00**.

Bank opening **100,000.00**, Operating **280.00**, Investing **-1,030.00**, Financing **0.00**, net **-750.00**, closing **99,250.00**. Both real synthetic Bank accounts are included; transfers net to zero. Asset disposal receipts and acquisition settlements follow canonical document links, including split mixed Supplier payments.

AP and AR subledgers reconcile exactly to their GL control accounts. Contract earned revenue and net billing900, VAT45, actual collection945 remain distinct. WIP after source price credit360, then final release0. No second cost/cash effect was introduced by capitalization or crediting.

## Verification and release boundary

82 accounting/control checks, 7 native PostgreSQL checks and 11 bilingual browser checks passed. Native two-session lock waits verified idempotency and over-credit prevention. All146 pre-existing fixture tables retained their count/hash across104. New RLS/grants and fixed privileged search paths verified. Existing original journals preserved.

TypeScript and Production build PASS. Scoped lint: no errors; the existing generation-ref cleanup warning remains. Existing build chunk-size advisory remains. Screenshots and EN Excel/AR PDF examples are under `cr06-evidence/`; actual rendered English transfer/asset, Arabic deposit/mobile and construction correction screens inspected. No Production browser acceptance is claimed.

Migration104 `20261122120000_essential_accounting_gap_closure.sql`, SHA256 `a269e962138171fef760a80b991d93597c6a380cbcaaed3cc7cd38db5d177630`, is additive and PREPARED / NOT APPLIED. Linked hosted history through103 matches; read-only dry-run lists only104. Activation needs explicit Product Owner authorization, then compatible frontend publication. No push/deploy performed.

## Remaining specialist limitations

- Single integrated construction obligation per Project remains the supported policy. Multi-obligation price allocation, foreign currencies and complex legal contract-history adoption remain specialist work.
- Asset cost adoption supports an authoritative single-cost invoice/Expense. Component accounting, revaluation/impairment models and physical return/reacquisition of an already sold asset require separate supported business workflows; source-linked price credits are supported.
- Continuous prepayments use explicit actual service dates; discrete monthly coverage and asset completed-calendar-month depreciation remain explicit supported policies. Zero-journal physical retirement and sub-cent early service installments are not manufactured into postings.
- Tax-point deposits require actual tax evidence and an original supported rate; dedicated jurisdictional tax returns, statutory classification and restatement policy are not asserted by this milestone.
- CR07 full integrated acceptance, advanced HR/WPS, original commercial operations/security gates, real Maker Payroll, onboarding and deferred restoration/USB requirements remain preserved.

No verified core blocker remains unresolved in this bounded closure. This does not declare the whole commercial roadmap complete or waive CR07, Production acceptance or original operational requirements. Bank feeds/FX and cosmetic reporting customization remain optional/future work.
