# Integrated Accounting Learning Report — 18 November 2026

**Actual local canonical execution**, not hypothetical journals or Production postings. The same fictional Company `35866f1d-2888-40f2-9690-015802ec13a8`, NARVO DEMO — Trading & Contracting LLC, covers 01/10/2026–17/11/2026 (explicit fictional short fiscal year). Original in-memory database had closed: its24 canonical events were restored once as fixture initialization, not the142-check foundation suite. Original evidence below remains unchanged; [ID restoration map](commercial-foundation-restoration-map.json) connects original and restored journals.

**65 distinct operation scenarios,63 journals,3 reversals** in the primary dataset. Four physical counts/transfers create no journal; some settlement/payment events produce paired canonical journals. Journal counts are not scenario counts. Auxiliary Payroll variants use a separate fictional Company (4journals); race/browser/precision clones are not included in these balances.

| Final independent answer key | AED |
|---|---:|
| Closing Trial Balance debit = credit |104,011.00|
| Assets |97,111.00|
| Liabilities |3,011.00|
| Net equity (101,000 contributed less6,900 retained loss) |94,100.00|
| Sales / COGS / gross profit |1,020.00 /60.00 /960.00|
| Total expenses including COGS / net loss |7,920.00 /6,900.00|
| Bank / physical Custody |84,550.00 /9,700.00|
| AR / AP |421.00 /1,300.00|
| Inventory74units / prepaid balance |740.00 /1,100.00|
| Contract advance / payable / retention |400.00 /1,000.00 /150.00|
| Employee advance / salary payable |100.00 /400.00|
| Input VAT / output VAT / accrued liability |100.00 /51.00 /110.00|

Direct cash flow: opening100,000 −operating6,550 −investing200 +actual owner financing1,000 = **94,250**. Certified opening balances are opening cash, never financing receipts. Custody is included only because this fictional fixture explicitly establishes controlled physical cash; an employee receivable is not automatically cash. Bank external-statement reconciliation remains unimplemented; the physical-count command correctly rejects Bank.

[Learning workbook English](commercial-learning-en.xlsx) / [العربية](commercial-learning-ar.xlsx).

[All63 exact journals and every line/dimension](commercial-integrated-journals.csv); [actual statements/GL snapshot](commercial-integrated-snapshot.json); [actual inputs, expected debits/credits and receipts](commercial-integrated-scenarios.json); [focused checks and specialist limits](commercial-completion-verification.json). The original foundation report follows after this current continuation.

## What the new transactions teach

- Earned service invoice1,000 +VAT50: Dr AR1,050 /Cr earned revenue1,000 /Cr VAT50. Receipt400 reduces AR without revenue; deposit200 is a liability until applied; net100/VAT5 credit leaves AR345. A fully paid200 invoice is credited to customer-credit liability and refunded exactly once. Further cash sales/credits are recorded in the exact scenario evidence.
- Goods: ten units delivered cost100 using existing Inventory ISSUE →Dr COGS100 /Cr Inventory100; invoice200+VAT10 →Dr AR210 /Cr revenue200 /Cr VAT10; receipt50 leaves160; four-unit physical return reverses cost40; credit80+VAT4 leaves goods AR76. Ending total AR421, stock74units/value740. No repeated stock cost in the sales invoice.
- Fixed asset1,200 paid →Dr cost /Cr Bank; monthly depreciation100 →Dr depreciation /Cr accumulated depreciation; disposal proceeds1,000 remove cost1,200 and accumulation100, recognize loss100. No asset or accumulation remains.
- Prepayment1,200 covers12 discrete month-end inspection services (not continuous daily insurance); one delivered visit amortizes100, leaving1,100. Accrual300 recognized,200 settled;10 late cutoff cost leaves110 payable. Explicit calendar-month policy is fictional, not silently imposed on real Companies.
- Transfers/counts, shortage/surplus and Project return/reissue reuse Inventory commands; released retention50 is paid without new cost. Original Project cost remains5,300 after annual closing.
- A genuine later-identified owner cash contribution1,000 uses the existing owner/Custody command →Dr physical Custody /Cr Owner Contributions Equity. It does not create Treasury turnover or revenue. Audited year reopening and refinalization incorporate this receipt.
- Annual close transfers the final6,900 loss into retained earnings; two audited reopening reversals preserve every original journal. Final lock rejects backdating; Income Statement retains actual income/cost activity rather than annual clearing transfers. Payroll-derived closing lines remain confidential.
- Auxiliary Payroll scenarios actually verify absence, paid leave, partial hours and overtime: gross5,864.84; paid3,903.23; remaining payable1,961.61. These are auxiliary balances, never added to the main Company.

## Scope and preservation

Hosted financial data, Company configuration, RLS and migration history were not mutated. Maker's370sources/55journals/AED364,365.77 checkpoint is reused historical evidence, not freshly queried. Local native activation verifies preservation of populated accounting and memberships; read-only hosted dry-run lists95–100 only, with latest applied94. All six migrations remain **PREPARED / NOT APPLIED**.

The five requested core modules are operationally implemented locally, but the **entire approved commercial roadmap is NOT complete**. Remaining gaps: external bank reconciliation, supplier physical returns, construction certification/progress/WIP policy, taxable customer advances, specialist asset/prepayment policies, and correction after later-year activity. Full statutory/WPS, operational/security acceptance, onboarding and deferred DR remain separate requirements. No commercial go-live claim.

## Original foundation report — preserved historical evidence

# Fictional accounting learning report — executed foundation cycle

**Commercial readiness: PARTIAL.** This report records actual disposable canonical SQL execution, not Maker transactions and not a complete commercial ERP certification.

Company: **NARVO DEMO — Trading & Contracting LLC**, ID `35866f1d-2888-40f2-9690-015802ec13a8`. Environment: disposable in-process PGlite, no hosted connection. Company/identity/master bootstrap is a synthetic fixture, not proof of commercial onboarding. Test range: **2026-10-01 to 2026-11-17**; Payroll uses the fully elapsed prior month. Fiscal controls were tested separately in disposable SQL/native/browser fixtures, not as a complete single-company full ERP closing cycle.

Fictional assumptions: AED, perpetual moving-average stock; service invoices represent received services; the two supported purchase-tax examples use illustrative 5% recoverable input VAT. These assumptions establish no real tax recovery right, WIP/revenue policy or legal Payroll compliance.

Opening position: Bank Dr AED100,000 / Equity Cr AED100,000, through the existing certified opening workflow. No operating income, invented suspense or subledger opening claims.

## Executed answer key

Each expected entry was specified before business execution. Amounts below are AED. Actual journal amounts matched exactly; all entries balanced. Stock matching and Payroll recovery each require two canonical journals in one business operation.

| Scenario / date | Why this treatment applies | Expected entry | Actual journals | Result |
|---|---|---|---|---|
| OPEN · 2026-10-01<br>Certified bank/capital opening | A certified balanced opening position is capital, not operating income. | Dr BANK 100,000.00<br>Cr EQUITY 100,000.00 | `3f7edc03-0208-4319-9fdd-2bcc6a1e15aa` | PASS |
| FUND · 2026-11-17<br>Bank to Custody advance | Custody is a recoverable asset; moving money into it creates no expense. | Dr CUSTODY_ADVANCE 10,000.00<br>Cr BANK 10,000.00 | `5465937c-2d1c-4484-835f-97ea6420e8f5` | PASS |
| CASH · 2026-11-17<br>Immediate supplies purchase, fictional 5% recoverable VAT | Consumed office supplies create expense; only the fictional supported tax amount is recoverable. | Dr COMPANY_EXPENSE 100.00<br>Dr INPUT_VAT 5.00<br>Cr CUSTODY_ADVANCE 105.00 | `d7d39386-b7bc-40b5-81b1-a1f335063eb8` | PASS |
| BILL1 · 2026-11-17<br>Credit service purchase with supported fictional VAT | Received services are recognized when incurred, with a payable until settlement. | Dr COMPANY_EXPENSE 1,000.00<br>Dr INPUT_VAT 50.00<br>Cr SUPPLIER_PAYABLE 1,050.00 | `4682af9e-d06b-4d79-9299-0b5c25914d77` | PASS |
| BILL2 · 2026-11-17<br>Credit service purchase without recoverable VAT | No recoverable VAT is assumed for this gross-cost scenario. | Dr COMPANY_EXPENSE 500.00<br>Cr SUPPLIER_PAYABLE 500.00 | `82bf1d1f-af81-4e9c-b415-ab2dd26758b2` | PASS |
| PARTIAL · 2026-11-17<br>Partial Supplier payment | A payment reduces a liability; it does not recognize the same service cost again. | Dr SUPPLIER_PAYABLE 400.00<br>Cr BANK 400.00 | `29c30720-b4fd-4f73-a2e2-a744d57ed74e` | PASS |
| MULTI · 2026-11-17<br>One payment across two invoices | One actual payment can settle parts of two invoices without two cash outflows. | Dr SUPPLIER_PAYABLE 800.00<br>Cr BANK 800.00 | `fa9984e0-179b-490c-b06f-9a9b9d225d6c` | PASS |
| FINAL · 2026-11-17<br>Final Supplier settlement | Only the remaining liability is settled, preventing overpayment. | Dr SUPPLIER_PAYABLE 350.00<br>Cr BANK 350.00 | `e272462d-1b2c-4033-9d55-56184f7579af` | PASS |
| ADV · 2026-11-17<br>Supplier advance from Custody | A recoverable Supplier advance is an asset until properly applied. | Dr SUPPLIER_ADVANCE 200.00<br>Cr CUSTODY_ADVANCE 200.00 | `aa6bd2ea-9814-48e8-bdce-9dee4355f4f2` | PASS |
| BILL3 · 2026-11-17<br>Third credit service invoice | The received service creates the cost and payable independently of its advance. | Dr COMPANY_EXPENSE 500.00<br>Cr SUPPLIER_PAYABLE 500.00 | `0503f70d-2a16-4a76-bc62-d8c23d9967e9` | PASS |
| APPLY · 2026-11-17<br>Apply Supplier advance without another payment | Applying an existing advance exchanges balances without new cash or expense. | Dr SUPPLIER_PAYABLE 200.00<br>Cr SUPPLIER_ADVANCE 200.00 | `24a2655e-9cf0-421a-b746-456bdbffb107` | PASS |
| CREDIT · 2026-11-17<br>Service credit note | A supported service credit reduces the original expense and Supplier payable. | Dr SUPPLIER_PAYABLE 50.00<br>Cr COMPANY_EXPENSE 50.00 | `72c1a1a6-3c13-473d-8820-23ede111142d` | PASS |
| STOCK · 2026-11-17<br>Physical receipt against GRNI | Physical receipt capitalizes stock against GRNI; no consumption cost yet. | Dr INVENTORY 1,000.00<br>Cr GRNI 1,000.00 | `da59418a-28c9-4749-9646-16077ec5a8ab` | PASS |
| STOCKBILL · 2026-11-17<br>Credit invoice matched to receipt with fictional VAT | The atomic invoice/match pair clears GRNI and cancels temporary expense, leaving inventory recognized once. | Dr COMPANY_EXPENSE 1,000.00<br>Dr INPUT_VAT 50.00<br>Cr SUPPLIER_PAYABLE 1,050.00<br>Dr GRNI 1,000.00<br>Cr COMPANY_EXPENSE 1,000.00 | `60145bd9-1ba6-4946-9ebc-692e0cfcec06`<br>`80b1bb18-3335-4ab3-8741-27c3e3e18df7` | PASS |
| ISSUE · 2026-11-17<br>Project consumes 20 of 100 units at historical cost | Actual Project consumption releases moving-average stock value into Project cost. | Dr PROJECT_COST 200.00<br>Cr INVENTORY 200.00 | `2565b8ce-f09e-4e4b-a746-03b593885d4d` | PASS |
| CONTRACTADV · 2026-11-17<br>Contract advance, no cost recognition | Paying before certification creates a contract-scoped advance rather than Project cost. | Dr SUBCONTRACTOR_ADVANCE 500.00<br>Cr BANK 500.00 | `e7a1c70c-2587-44e7-9121-658d733e2c15` | PASS |
| CERT · 2026-11-17<br>Certified cost with 10% retention and advance recovery | Certified work creates cost once; retention, recovered advance and ordinary payable remain separate. | Dr PROJECT_COST_SUBCONTRACTORS 2,000.00<br>Cr SUBCONTRACTOR_ADVANCE 100.00<br>Cr SUBCONTRACTOR_RETENTION_PAYABLE 200.00<br>Cr SUBCONTRACTOR_PAYABLE 1,700.00 | `de5310b5-451a-4232-b47b-53e1b2467d55` | PASS |
| CONTRACTPAY · 2026-11-17<br>Partial certified Contractor settlement | Settlement debits certified payable, without repeating certified cost. | Dr SUBCONTRACTOR_PAYABLE 700.00<br>Cr BANK 700.00 | `c60ea8f3-4dc3-4211-8fd2-e522a680a1fa` | PASS |
| PROJECT · 2026-11-17<br>Direct Custody-funded Project expense | A direct paid Project expense debits its cost center and credits the actual Custody holder. | Dr PROJECT_COST 100.00<br>Cr CUSTODY_ADVANCE 100.00 | `6ee13c87-c274-4392-8049-f6c6ce4a29d2` | PASS |
| RETURN · 2026-11-17<br>Custody cash return without changing costs | Returning money reduces Custody and restores Bank without reversing consumed Project costs. | Dr BANK 1,000.00<br>Cr CUSTODY_ADVANCE 1,000.00 | `3e073d2e-812f-4050-99a0-148553cbccac` | PASS |
| EMPADV · 2026-10-02<br>Employee advance, recoverable asset | An employee advance is a receivable, not salary expense. | Dr EMPLOYEE_ADVANCE 200.00<br>Cr BANK 200.00 | `12e4e9d2-1f3b-4d51-bb84-ff3fc757e1a0` | PASS |
| PAYROLL · 2026-10-31<br>Approved payroll with advance recovery | Earned gross salary is cost. A separate recovery journal offsets salary payable against the employee receivable. | Dr PROJECT_COST 3,000.00<br>Cr SALARY_PAYABLE 3,000.00<br>Dr SALARY_PAYABLE 100.00<br>Cr EMPLOYEE_ADVANCE 100.00 | `404cddaf-6b8c-4314-b258-9b96315d92ac`<br>`db9a86a2-0bfb-473f-a83f-331123f2929d` | PASS |
| SALARY · 2026-11-17<br>Partial salary settlement | Partial salary payment reduces accrued payable; the unpaid amount remains a liability. | Dr SALARY_PAYABLE 2,500.00<br>Cr BANK 2,500.00 | `9580b665-8e4f-4495-963d-eedda07477ab` | PASS |
| REVERSE · 2026-11-17<br>Controlled supplies reversal including original VAT | A controlled reversal swaps the original entry, including tax, without editing its history. | Dr CUSTODY_ADVANCE 105.00<br>Cr COMPANY_EXPENSE 100.00<br>Cr INPUT_VAT 5.00 | `a1e80f19-8544-42b4-ac9b-dc78c1c33136` | PASS |

## Ending results

24 unique economic scenarios; **25 distinct journal-backed business sources** (excluding reversal source and all masters/drafts/audit events), **26 posted journals**, **1 reversal**. New Party records are fictional fixture masters only.

| Statement / reconciliation | Independent expected | Actual | Result |
|---|---:|---:|---|
| Ending Trial Balance — debit | 102,900.00 | 102,900.00 | PASS |
| Ending Trial Balance — credit | 102,900.00 | 102,900.00 | PASS |
| Revenue | 0.00 | 0.00 | PASS; no sales workflow executed |
| Operating/Project/Payroll expense | 7,250.00 | 7,250.00 | PASS |
| Net profit / loss | -7,250.00 | -7,250.00 | PASS |
| Assets | 95,650.00 | 95,650.00 | PASS |
| Liabilities | 2,900.00 | 2,900.00 | PASS |
| Recorded equity | 100,000.00 | 100,000.00 | PASS |
| Unclosed cumulative result | -7,250.00 | -7,250.00 | PASS |
| Bank closing | 85,550.00 | 85,550.00 | PASS |
| Custody | 8,700.00 | 8,700.00 | PASS |
| Supplier AP outstanding / GL | 1,300.00 | 1,300.00 | PASS |
| Inventory value / GL (80 units) | 800.00 | 800.00 | PASS |
| Contractor advance | 400.00 | 400.00 | PASS |
| Contractor ordinary payable | 1,000.00 | 1,000.00 | PASS |
| Contractor retention | 200.00 | 200.00 | PASS |
| Employee advance receivable | 100.00 | 100.00 | PASS |
| Salary payable | 400.00 | 400.00 | PASS |
| Customer AR | Not executed | Unavailable | BLOCKED — missing module |
| Full Cash Flow Statement | Not executed | Unavailable | BLOCKED — missing policy/implementation |

Cash movement bridge (not a Cash Flow Statement): Bank 100,000 − Custody funding 10,000 − Supplier payments 1,550 − Contractor advance 500 − Contractor settlement 700 + Custody return 1,000 − Employee advance 200 − Salary payment 2,500 = **85,550**. Custody is a ledger receivable, not automatically a cash equivalent.

## Controls and operational output

Duplicate invoice, unsupported VAT claim, overpayment, repeat reversal, Management Viewer posting, foreign Company posting and direct immutable-journal mutation were rejected atomically. Report scope rejects hidden Payroll, missing accounts/lines, wrong sessions and revoked permission. Separate new period tests verify fiscal date coverage, Admin authority, audited close/reopen, stale/replayed requests, tenant RLS, immutable audit, activation preservation and native close/post concurrency.

Arabic and English rendered statements, actual three-sheet Excel workbooks and printable PDF artifacts were checked. Screenshots: [English statements](screenshots/commercial-foundation/statements-en.png), [Arabic statements](screenshots/commercial-foundation/statements-ar.png), [English fiscal periods](screenshots/commercial-foundation/periods-en.png), [Arabic fiscal periods](screenshots/commercial-foundation/periods-ar.png).

## Remaining program work

Customer sales/receipts/credit/advance cycle; fixed assets/depreciation/disposal; accrual/prepayment schedules; output VAT and dedicated tax reconciliation; complete cash-flow classifications/reporting; annual retained-earnings closing entries; remaining Payroll/Inventory/Contract edge cases and comprehensive single-cycle acceptance remain unfinished. These are not passed or commercially ready. The single [completion register](commercial-readiness-completion.json) preserves the approved roadmap and exact status.

No real Company data/configuration changed, no hosted migration applied, no code pushed or deployed. Migration95 is prepared only. Full original commercial scope and deferred restoration/USB tasks remain retained.
