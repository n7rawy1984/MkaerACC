# CR07 — Integrated accounting learning and acceptance report

**NOT READY for unrestricted commercial acceptance.** The connected accounting cycle is executed and reconciled locally; full authenticated application acceptance and hosted105 activation remain gates. No real Company data was modified.

## Environment and result

NARVO DEMO — Trading & Contracting LLC (`a00fff7a-43d8-4775-9f51-05ccd0c7574b`), AED. First short fiscal year 01/09/2026–31/10/2026; October operating review. 85 independently declared business scenarios, 90 persisted journals, 3 linked reversals; 183 distinct focused assertions. Disposable native PostgreSQL independently verifies concurrent settlement and migration preservation. Earlier65/CR05/CR06 archives were preserved rather than replayed.

Actual entries: [journals.csv](cr07-evidence/journals.csv); [complete documents/GL/subledgers](cr07-evidence/actual-ledger.json); [independent answer key](cr07-evidence/independent-answer-key.json); [verification](cr07-integrated-verification.json).

## Documents created

- commercial_documents: 38
- commercial_reversals: 2
- expenses: 10
- supplier_ap_documents: 4
- supplier_payments: 7
- inventory_movements: 9
- construction_contracts: 1
- payroll_entitlements: 2
- bank_statements: 2

Counts are per canonical table, not a count of independent financial effects; source-linked lifecycle records are preserved in the JSON.

## Accounting policy and opening

- **functionalCurrency:** AED
- **vat:** Fictional5% on explicitly evidenced taxable supplies; supported zero-tax documents as marked; gross525 has no VAT recovery
- **stock:** Perpetual moving weighted-average, all acquired units AED10, no negative stock
- **construction:** One integrated obligation; certified output, customer-controlled work, approved variation;12000 earned vs12000 net billings vs12600 gross collections;10% unconditional retention
- **payroll:** October31 days,480 paid scheduled minutes/day, basic3000 each; E1 one unpaid absence/one paid leave; E2 half unpaid day and approved OT10; E1 recovery100 against actual advance200
- **prepayment:** Actual days Oct15–Nov14,310/31=10 per day
- **assets:** Completed calendar months,12 months, residual0
- **cash:** Actual Bank, Cash Treasury and verified controlled physical Custody included. Employee receivables excluded. Interest received classified Operating under explicit fictional policy.
- **opening:** Only initial September inception is certified; October openings carry actual prior canonical invoices/stock/asset journals, not fabricated legacy import
- **closing:** Fictional first short fiscal year Sep1–Oct31; October is the operating review period; final annual close transfers full-year loss once

September incorporation Bank100,000 + Cash5,000 = Capital105,000. Actual prior-period canonical invoices establish October AR1,050 and AP1,040;20 units stock200; asset NBV1,100. Prior bank statement reconciles to98,800. Opening cumulative Trial Balance movement Dr=Cr108,790; assets106,190 = liabilities1,090 + equity105,000 + prior profit100. No legacy subsidiary opening was invented.

## Final expected versus actual statements

All following amounts are AED; every value below passed its independent assertion.

| Result | Expected | Actual |
|---|---:|---:|
| Assets |105,232.66|105,232.66|
| Liabilities |762.50|762.50|
| Equity after annual close |104,470.16|104,470.16|
| Revenue (incl gain/interest) |14,260.00|14,260.00|
| Expenses |15,789.84|15,789.84|
| Fiscal-year loss |1,529.84|1,529.84|
| Unclosed result after close |0.00|0.00|
| October loss |1,629.84|1,629.84|
| Cash Flow opening |103,800.00|103,800.00|
| Operating cash flow |-1,762.34|-1,762.34|
| Investing cash flow |-1,245.00|-1,245.00|
| Financing cash flow |1,000.00|1,000.00|
| Cash Flow closing |101,792.66|101,792.66|

Final cumulative Trial Balance movements Dr=Cr **261,504.20**, including original annual close, its audited reversal and final close; closing balances appear below. Income excludes close/reopen entries, preserving earned income. Opening capital is opening cash, never invented current financing. Internal Bank/Cash/Custody transfers net to zero cash flow.

| Account | Closing debit AED | Closing credit AED |
|---|---:|---:|
|110000 — Demo Bank GL|88,892.66|0.00|
|111000 — Fictional Cash GL|11,900.00|0.00|
|120000 — Fictional INPUT_VAT|160.00|0.00|
|130000 — Fictional CUSTODY_ADVANCE|1,000.00|0.00|
|133000 — Demo EMPLOYEE_ADVANCE|100.00|0.00|
|310000 — Demo EQUITY|0.00|105,000.00|
|315000 — Fictional owner contributions|0.00|1,000.00|
|CR07-ACCUMULATED_DEPRECIATION — CR07-ACCUMULATED_DEPRECIATION|0.00|200.00|
|CR07-ASSET_COST — CR07-ASSET_COST|2,400.00|0.00|
|CR07-OUTPUT_VAT — CR07-OUTPUT_VAT|0.00|762.50|
|CR07-PREPAYMENT — CR07-PREPAYMENT|140.00|0.00|
|CR07-RETAINED_EARNINGS — CR07-RETAINED_EARNINGS|1,529.84|0.00|
|DEMO-inventory — Demo inventory|840.00|0.00|

## Subledger and operational reconciliation

| Control | Independently reconciled ending result |
|---|---|
| Supplier AP / customer AR |Both0; invoices, partial/final settlements, credits, returns, refunds and advances trace to canonical GL; aging0|
| Inventory |84 units, AED840: first warehouse69, second15; GL840; GRNI0|
| Bank |88,892.66; final statement90,682.66 +deposit210 −unpresented2,000; difference0|
| Cash Treasury / physical Custody |11,900 /1,000; Company cash101,792.66; employee receivables excluded|
| Payroll |Gross5,864.84; recovery100; salary payments2,803.23 +2,961.61; salary liability0; employee advance100 remains|
| Contractor |Certified5,000; advance1,000 applied; settlement3,500; retention500 released/paid; payable/advance/retention all0|
| Construction |Earned12,000, net billed12,000, gross collections12,600; contract asset/liability/WIP/retention0; customer contract closed|
| Project |Cost11,864.84, revenue12,000, margin135.16; wages/materials/certification/WIP consumption counted once|
| Fixed Assets |Opening asset1,200 depreciated200 then retired; actual credit sale1,100 +VAT55, gain100; new asset2,400 less200 depreciation =NBV2,200|
| Prepayment/accrual |310/31 actual days;17 days expense170, asset140 remains. Erroneous accrued300 reversed,250 replacement settled; accrued liability0|
| Tax |InputVAT160; OutputVAT762.50; net liability602.50; gross525 has no input claim. Advances relieved once; no statutory return filing asserted|

## Actual transaction lessons and journal evidence

Each entry below matched independently specified account debits/credits and authoritative dates. Inventory physical events with no journal are intentional. Source metadata and canonical document IDs are in the JSON evidence. Debits increase assets/expenses and reduce liabilities/equity/revenue; credits do the converse. Payments settle existing balances rather than recognizing their original cost twice.

### OPEN — Certified incorporation positions

2026-09-01; source `CR07-OPEN`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr100,000.00 / Cr0.00
- CASH: Dr5,000.00 / Cr0.00
- EQUITY: Dr0.00 / Cr105,000.00

Effects: Assets 105,000.00; Liabilities 0.00; Equity 105,000.00; Revenue 0.00; Expenses 0.00; Cash 105,000.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000001 (`f14588f5-0542-4906-9acf-b160b16c81eb`).

### PRE_AR — September earned-service credit invoice

2026-09-15; source `CR07-PRE_AR`. **PASS**. Tax: 5% evidenced output VAT. Canonical source and subsidiary records; one financial effect.

- AR: Dr1,050.00 / Cr0.00
- REVENUE: Dr0.00 / Cr1,000.00
- OUTPUT_VAT: Dr0.00 / Cr50.00

Effects: Assets 1,050.00; Liabilities 50.00; Equity 0.00; Revenue 1,000.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000002 (`1bcd32a0-7883-4077-b5f1-3fe72d87a8b8`).

### PRE_AP — September Supplier service credit invoice

2026-09-15; source `CR07-PRE_AP`. **PASS**. Tax: 5% evidenced recoverable input VAT. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr800.00 / Cr0.00
- INPUT_VAT: Dr40.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr840.00

Effects: Assets 40.00; Liabilities 840.00; Equity 0.00; Revenue 0.00; Expenses 800.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000003 (`f2ac5702-0a06-4c35-920d-0fa413e8d7a3`).

### PRE_ASSET — September asset acquisition

2026-09-15; source `CR07-PRE_ASSET`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ASSET_COST: Dr1,200.00 / Cr0.00
- BANK: Dr0.00 / Cr1,200.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -1,200.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000007 (`daccc709-2154-44d1-8e60-6db7980a1fd9`).

### PRE_STOCK — September physical Inventory receipt

2026-09-16; source `CR07-PRE_STOCK`. **PASS**. Tax: Zero tax. 20 units at AED10; unpaid GRNI.

- INVENTORY: Dr200.00 / Cr0.00
- GRNI: Dr0.00 / Cr200.00

Effects: Assets 200.00; Liabilities 200.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000004 (`410304e5-2790-4f28-ae8e-d94da42b239a`).

### PRE_STOCK_BILL — September receipt-to-invoice match

2026-09-16; source `CR07-PRE_STOCK_BILL`. **PASS**. Tax: Zero tax. Original cost reclassified once; no duplicate Inventory.

- COMPANY_EXPENSE: Dr200.00 / Cr200.00
- GRNI: Dr200.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr200.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000006 (`e3caf998-238f-4f3a-9f1a-334bfdf2d204`), NARVO-DEMO-COMMERCIAL-JE-2026-000005 (`fed703cb-e810-4dd6-b72a-42c3ef94cf4d`).

### PRE_DEPR — September completed-month depreciation

2026-09-30; source `CR07-PRE_DEPR`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- DEPRECIATION_EXPENSE: Dr100.00 / Cr0.00
- ACCUMULATED_DEPRECIATION: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000008 (`840084e7-31c8-4e7b-8b3b-995ce8d50384`).

### OPEN_AP_PAY — Pay September service and stock creditors

2026-10-02; source `CR07-OPEN_AP_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr1,040.00 / Cr0.00
- BANK: Dr0.00 / Cr1,040.00

Effects: Assets -1,040.00; Liabilities -1,040.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -1,040.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000009 (`fe2c439b-3ca3-45c1-9159-d6d4234aa455`).

### OPEN_AR_PAY — Collect September debtor

2026-10-02; source `CR07-OPEN_AR_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr1,050.00 / Cr0.00
- AR: Dr0.00 / Cr1,050.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 1,050.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000010 (`fa78866c-3fa8-423e-948f-bf5416a3d489`).

### EMP_ADV — Employee receivable advance200

2026-10-02; source `CR07-EMP_ADV`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- EMPLOYEE_ADVANCE: Dr200.00 / Cr0.00
- BANK: Dr0.00 / Cr200.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -200.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000065 (`c34b3270-191e-47c4-9e2b-f693e7238bc2`).

### ASSET_BILL — Purchase second asset2400 on Supplier credit

2026-10-02; source `CR07-ASSET_BILL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr2,400.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr2,400.00

Effects: Assets 0.00; Liabilities 2,400.00; Equity 0.00; Revenue 0.00; Expenses 2,400.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000070 (`de52beeb-cc8b-468b-b518-97b432c32141`).

### ASSET_CAP — Adopt existing acquisition cost without new payment

2026-10-02; source `CR07-ASSET_CAP`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ASSET_COST: Dr2,400.00 / Cr0.00
- COMPANY_EXPENSE: Dr0.00 / Cr2,400.00

Effects: Assets 2,400.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses -2,400.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000071 (`a58adf8f-6a7d-42cd-b134-132c3093ffd6`).

### PAID_GROSS — Ordinary paid purchase with unsupported VAT excluded from recovery

2026-10-03; source `CR07-PAID_GROSS`. **PASS**. Tax: Gross525; embedded25 not recoverable, input VAT0. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr525.00 / Cr0.00
- BANK: Dr0.00 / Cr525.00

Effects: Assets -525.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 525.00; Cash -525.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000011 (`0fbdbd7b-ffdc-43fd-ba9e-0d8792832921`).

### SERVICE_AP — October service invoice

2026-10-03; source `CR07-SERVICE_AP`. **PASS**. Tax: 5% recoverable. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr1,000.00 / Cr0.00
- INPUT_VAT: Dr50.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr1,050.00

Effects: Assets 50.00; Liabilities 1,050.00; Equity 0.00; Revenue 0.00; Expenses 1,000.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000012 (`09928a48-0ec0-4991-ab11-716d0d70a150`).

### CUSTODY_FUND — Bank-to-Custodian advance

2026-10-03; source `CR07-CUSTODY_FUND`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- CUSTODY_ADVANCE: Dr5,000.00 / Cr0.00
- BANK: Dr0.00 / Cr5,000.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000041 (`1d79da41-b000-4dfd-9984-09504ea09a43`).

### ASSET_PAY — Settle asset acquisition AP

2026-10-03; source `CR07-ASSET_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr2,400.00 / Cr0.00
- BANK: Dr0.00 / Cr2,400.00

Effects: Assets -2,400.00; Liabilities -2,400.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -2,400.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000072 (`ebe4089b-ec59-4903-b71b-4cd26bb0b9c0`).

### SERVICE_PART — Partial Supplier settlement

2026-10-04; source `CR07-SERVICE_PART`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr400.00 / Cr0.00
- BANK: Dr0.00 / Cr400.00

Effects: Assets -400.00; Liabilities -400.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -400.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000013 (`f3318486-9338-4b0f-96c6-00b06161f9f0`).

### CUSTODY_COST — Actual paid Custody operating cost

2026-10-04; source `CR07-CUSTODY_COST`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr100.00 / Cr0.00
- CUSTODY_ADVANCE: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 100.00; Cash -100.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000042 (`875709f5-e270-4f3b-8390-c5e390bb9941`).

### CR_ADV — Construction tax-point advance2000

2026-10-04; source `CR07-CR_ADV`. **PASS**. Tax: 5% documented advance VAT. Canonical source and subsidiary records; one financial effect.

- BANK: Dr2,100.00 / Cr0.00
- CUSTOMER_ADVANCE: Dr0.00 / Cr2,000.00
- OUTPUT_VAT: Dr0.00 / Cr100.00

Effects: Assets 2,100.00; Liabilities 2,100.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 2,100.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000046 (`7cffea80-5e98-489a-ac1e-03de57882316`).

### SERVICE_FINAL — Final Supplier settlement

2026-10-05; source `CR07-SERVICE_FINAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr650.00 / Cr0.00
- BANK: Dr0.00 / Cr650.00

Effects: Assets -650.00; Liabilities -650.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -650.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000014 (`6b926628-9914-49f6-8655-fb7cc01cac8a`).

### SUP_ADV — Supplier advance, no expense

2026-10-05; source `CR07-SUP_ADV`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_ADVANCE: Dr300.00 / Cr0.00
- BANK: Dr0.00 / Cr300.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -300.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000015 (`bac427c4-a0e8-44e9-9010-aaa1950cc7b2`).

### CUSTODY_RETURN — Return4900 actual Custody cash to Cash Treasury

2026-10-05; source `CR07-CUSTODY_RETURN`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- CASH: Dr4,900.00 / Cr0.00
- CUSTODY_ADVANCE: Dr0.00 / Cr4,900.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000043 (`9db557e1-0184-4bd6-a02f-cf57cab600d2`).

### CON_ADV — Subcontractor advance before work

2026-10-05; source `CR07-CON_ADV`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUBCONTRACTOR_ADVANCE: Dr1,000.00 / Cr0.00
- BANK: Dr0.00 / Cr1,000.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -1,000.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000047 (`edc01359-9342-4438-9ec0-f902ceca171a`).

### ADV_BILL — Actual Supplier service delivered

2026-10-06; source `CR07-ADV_BILL`. **PASS**. Tax: 5% recoverable. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr600.00 / Cr0.00
- INPUT_VAT: Dr30.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr630.00

Effects: Assets 30.00; Liabilities 630.00; Equity 0.00; Revenue 0.00; Expenses 600.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000016 (`5c03286f-0454-4c72-b31d-d422c497faea`).

### SUP_ALLOC — Apply Supplier advance

2026-10-06; source `CR07-SUP_ALLOC`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr300.00 / Cr0.00
- SUPPLIER_ADVANCE: Dr0.00 / Cr300.00

Effects: Assets -300.00; Liabilities -300.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000017 (`42172018-f23a-49da-90a3-f1fc4840e9eb`).

### OWNER — Actual permanent owner equity receipt in Custody

2026-10-06; source `CR07-OWNER`. **PASS**. Tax: No revenue; no registered Share Capital claim. Canonical source and subsidiary records; one financial effect.

- CUSTODY_ADVANCE: Dr1,000.00 / Cr0.00
- OWNER_EQUITY: Dr0.00 / Cr1,000.00

Effects: Assets 1,000.00; Liabilities 0.00; Equity 1,000.00; Revenue 0.00; Expenses 0.00; Cash 1,000.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000044 (`399e8149-797d-41d1-85dc-67164c706e03`).

### SUP_CREDIT — Supported Supplier price/tax credit

2026-10-07; source `CR07-SUP_CREDIT`. **PASS**. Tax: Original 5% credit. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr105.00 / Cr0.00
- COMPANY_EXPENSE: Dr0.00 / Cr100.00
- INPUT_VAT: Dr0.00 / Cr5.00

Effects: Assets -5.00; Liabilities -105.00; Equity 0.00; Revenue 0.00; Expenses -100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000018 (`b69bdfd5-a267-492a-8d4c-504173547048`).

### ADV_FINAL — Settle remaining Supplier invoice

2026-10-07; source `CR07-ADV_FINAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr225.00 / Cr0.00
- BANK: Dr0.00 / Cr225.00

Effects: Assets -225.00; Liabilities -225.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -225.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000019 (`7ccf7018-b2d9-4d64-a54b-b71e0f47945c`).

### TRANSFER_CASH — Bank-to-Cash actual transfer

2026-10-07; source `CR07-TRANSFER_CASH`. **PASS**. Tax: No new tax. Internal cash movement, no net cash flow.

- CASH: Dr2,000.00 / Cr0.00
- BANK: Dr0.00 / Cr2,000.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000045 (`313b7a1b-6f71-40d3-b16b-27fc91baeec6`).

### STOCK — Receive100 units at10

2026-10-08; source `CR07-STOCK`. **PASS**. Tax: No tax on receipt. Canonical source and subsidiary records; one financial effect.

- INVENTORY: Dr1,000.00 / Cr0.00
- GRNI: Dr0.00 / Cr1,000.00

Effects: Assets 1,000.00; Liabilities 1,000.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000020 (`ecde8012-44fd-4950-b8a7-6b422a65358a`).

### STOCK_BILL — Inventory invoice and GRNI matching

2026-10-08; source `CR07-STOCK_BILL`. **PASS**. Tax: 5% recoverable. Canonical source and subsidiary records; one financial effect.

- COMPANY_EXPENSE: Dr1,000.00 / Cr1,000.00
- GRNI: Dr1,000.00 / Cr0.00
- INPUT_VAT: Dr50.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr1,050.00

Effects: Assets 50.00; Liabilities 50.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000021 (`24a1fca2-98e8-43d1-bcce-dbc79ccea28a`), NARVO-DEMO-COMMERCIAL-JE-2026-000022 (`34545390-bf5c-4ee6-95d3-d10a37746400`).

### STOCK_PAY — Pay actual Inventory Supplier invoice

2026-10-09; source `CR07-STOCK_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr1,050.00 / Cr0.00
- BANK: Dr0.00 / Cr1,050.00

Effects: Assets -1,050.00; Liabilities -1,050.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -1,050.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000023 (`4728382f-2007-42df-94fe-d161223927dd`).

### SUP_RETURN — Physically return10 units to Supplier

2026-10-10; source `CR07-SUP_RETURN`. **PASS**. Tax: Dispatch alone does not invent VAT credit. Canonical source and subsidiary records; one financial effect.

- GRNI: Dr100.00 / Cr0.00
- INVENTORY: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities -100.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000024 (`e8fd1565-7df1-456f-b102-aa6e249e0a74`).

### RETURN_CREDIT — Receive Supplier return/tax credit

2026-10-10; source `CR07-RETURN_CREDIT`. **PASS**. Tax: 5% original invoice tax adjustment. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr105.00 / Cr0.00
- GRNI: Dr0.00 / Cr100.00
- INPUT_VAT: Dr0.00 / Cr5.00

Effects: Assets -5.00; Liabilities -5.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000025 (`218b4d5d-fb40-4895-bec1-e11834e51ce6`).

### PROJECT_COST — Direct Project paid cost

2026-10-10; source `CR07-PROJECT_COST`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- PROJECT_COST: Dr300.00 / Cr0.00
- BANK: Dr0.00 / Cr300.00

Effects: Assets -300.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 300.00; Cash -300.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000052 (`d5cd72e7-6a07-4165-8557-b843cfcde4b3`).

### WIP_SOURCE — Actual future-performance Project resource

2026-10-10; source `CR07-WIP_SOURCE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- PROJECT_COST: Dr600.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr600.00

Effects: Assets 0.00; Liabilities 600.00; Equity 0.00; Revenue 0.00; Expenses 600.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000053 (`afdfe4d6-7c58-4e8d-ada2-345651c6cd48`).

### RETURN_REFUND — Receive actual Supplier refund

2026-10-11; source `CR07-RETURN_REFUND`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr105.00 / Cr0.00
- SUPPLIER_PAYABLE: Dr0.00 / Cr105.00

Effects: Assets 105.00; Liabilities 105.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 105.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000026 (`f09fb0f7-b1b3-46c3-bdac-538f76892018`).

### WIP_CAP — Capitalize only400 eligible future cost

2026-10-11; source `CR07-WIP_CAP`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- CONSTRUCTION_WIP: Dr400.00 / Cr0.00
- PROJECT_COST: Dr0.00 / Cr400.00

Effects: Assets 400.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses -400.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000054 (`56ec1f44-2e6d-4ee1-b7f2-4bd25b5e5f06`).

### GOODS_ISSUE — Deliver20 units to Customer

2026-10-12; source `CR07-GOODS_ISSUE`. **PASS**. Tax: COGS only; no duplicate invoice cost. Canonical source and subsidiary records; one financial effect.

- COGS: Dr200.00 / Cr0.00
- INVENTORY: Dr0.00 / Cr200.00

Effects: Assets -200.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 200.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000027 (`62e88b2e-dc68-42a6-8290-0a9767008d89`).

### GOODS_SALE — Credit invoice20 delivered units at30

2026-10-12; source `CR07-GOODS_SALE`. **PASS**. Tax: 5% output. Canonical source and subsidiary records; one financial effect.

- AR: Dr630.00 / Cr0.00
- REVENUE: Dr0.00 / Cr600.00
- OUTPUT_VAT: Dr0.00 / Cr30.00

Effects: Assets 630.00; Liabilities 30.00; Equity 0.00; Revenue 600.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000028 (`9471c631-3c0f-4bf4-806a-51648ab7142f`).

### WIP_PAY — Pay source liability once

2026-10-12; source `CR07-WIP_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUPPLIER_PAYABLE: Dr600.00 / Cr0.00
- BANK: Dr0.00 / Cr600.00

Effects: Assets -600.00; Liabilities -600.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -600.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000055 (`34d99008-b52b-43e7-885d-bac3a2ace396`).

### GOODS_PART — Partial Customer collection

2026-10-13; source `CR07-GOODS_PART`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr300.00 / Cr0.00
- AR: Dr0.00 / Cr300.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 300.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000029 (`bd8c0ba6-c66c-4f79-8292-8cc3185fb37e`).

### GOODS_FINAL — Final Customer collection

2026-10-14; source `CR07-GOODS_FINAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr330.00 / Cr0.00
- AR: Dr0.00 / Cr330.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 330.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000030 (`995b26a8-5ea2-42c5-beed-1cebfceb76ac`).

### GOODS_RETURN — Recover5 actual returned units

2026-10-15; source `CR07-GOODS_RETURN`. **PASS**. Tax: No automatic price/VAT credit. Canonical source and subsidiary records; one financial effect.

- INVENTORY: Dr50.00 / Cr0.00
- COGS: Dr0.00 / Cr50.00

Effects: Assets 50.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses -50.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000031 (`3cb9a706-8c08-4316-a79b-b203db16c059`).

### GOODS_CREDIT — Issue credit for5 units at30

2026-10-15; source `CR07-GOODS_CREDIT`. **PASS**. Tax: Original5% credited; original paid receipt retained. Canonical source and subsidiary records; one financial effect.

- REVENUE: Dr150.00 / Cr0.00
- OUTPUT_VAT: Dr7.50 / Cr0.00
- CUSTOMER_ADVANCE: Dr0.00 / Cr157.50

Effects: Assets 0.00; Liabilities 150.00; Equity 0.00; Revenue -150.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000032 (`e322f301-643b-4b72-967b-27ea31da8f71`).

### PREPAY — Pay310 for31 actual coverage days Oct15–Nov14

2026-10-15; source `CR07-PREPAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- PREPAYMENT: Dr310.00 / Cr0.00
- BANK: Dr0.00 / Cr310.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -310.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000078 (`b558931c-af61-498c-a7e6-9d9428ba5aaa`).

### GOODS_REFUND — Refund actual Customer credit

2026-10-16; source `CR07-GOODS_REFUND`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- CUSTOMER_ADVANCE: Dr157.50 / Cr0.00
- BANK: Dr0.00 / Cr157.50

Effects: Assets -157.50; Liabilities -157.50; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -157.50.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000033 (`a2bf8f36-5517-4876-84ad-31e8d63b78e9`).

### CASH_SALE — Paid ordinary earned service

2026-10-17; source `CR07-CASH_SALE`. **PASS**. Tax: 5% output. Canonical source and subsidiary records; one financial effect.

- BANK: Dr210.00 / Cr0.00
- REVENUE: Dr0.00 / Cr200.00
- OUTPUT_VAT: Dr0.00 / Cr10.00

Effects: Assets 210.00; Liabilities 10.00; Equity 0.00; Revenue 200.00; Expenses 0.00; Cash 210.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000034 (`10429e1c-4d1e-4ad3-af3a-56a6c7e1539c`).

### CUSTOMER_ADV — Documented tax-point advance

2026-10-18; source `CR07-CUSTOMER_ADV`. **PASS**. Tax: 5% tax point, NET deposit300. Canonical source and subsidiary records; one financial effect.

- BANK: Dr315.00 / Cr0.00
- CUSTOMER_ADVANCE: Dr0.00 / Cr300.00
- OUTPUT_VAT: Dr0.00 / Cr15.00

Effects: Assets 315.00; Liabilities 315.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 315.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000035 (`c6fa0933-7819-46e0-9dd8-4d53e9bd5faf`).

### CUSTOMER_BILL — Earn service500 with VAT25

2026-10-19; source `CR07-CUSTOMER_BILL`. **PASS**. Tax: 5% output. Canonical source and subsidiary records; one financial effect.

- AR: Dr525.00 / Cr0.00
- REVENUE: Dr0.00 / Cr500.00
- OUTPUT_VAT: Dr0.00 / Cr25.00

Effects: Assets 525.00; Liabilities 25.00; Equity 0.00; Revenue 500.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000036 (`d0049824-8d71-43e4-815f-af08cc6d30c7`).

### CUSTOMER_APPLY — Apply deposit and tax relief

2026-10-19; source `CR07-CUSTOMER_APPLY`. **PASS**. Tax: Relieve original deposit VAT15; invoiceVAT25 remains. Canonical source and subsidiary records; one financial effect.

- CUSTOMER_ADVANCE: Dr300.00 / Cr0.00
- OUTPUT_VAT: Dr15.00 / Cr0.00
- AR: Dr0.00 / Cr315.00

Effects: Assets -315.00; Liabilities -315.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000037 (`a2d35210-63c6-43a4-91b0-7f3b8eb4a113`).

### CUSTOMER_FINAL — Collect remaining service receivable

2026-10-20; source `CR07-CUSTOMER_FINAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr210.00 / Cr0.00
- AR: Dr0.00 / Cr210.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 210.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000038 (`12c1ffd6-8b34-4df2-9c50-3f6982ff53c8`).

### PROJECT_MAT — Issue10 units to construction

2026-10-20; source `CR07-PROJECT_MAT`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- PROJECT_COST: Dr100.00 / Cr0.00
- INVENTORY: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000039 (`f23c86a3-44b6-47a6-a32b-53fbd5f51009`).

### CON_CERT — Certified subcontract work5000; advance1000, retention500

2026-10-20; source `CR07-CON_CERT`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- PROJECT_COST_SUBCONTRACTORS: Dr5,000.00 / Cr0.00
- SUBCONTRACTOR_ADVANCE: Dr0.00 / Cr1,000.00
- SUBCONTRACTOR_RETENTION_PAYABLE: Dr0.00 / Cr500.00
- SUBCONTRACTOR_PAYABLE: Dr0.00 / Cr3,500.00

Effects: Assets -1,000.00; Liabilities 4,000.00; Equity 0.00; Revenue 0.00; Expenses 5,000.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000048 (`325043d5-9e61-4cf4-bd16-9d65e83ee68c`).

### ACCRUAL — Recognize estimated accrued service300

2026-10-20; source `CR07-ACCRUAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUAL_EXPENSE: Dr300.00 / Cr0.00
- ACCRUED_LIABILITY: Dr0.00 / Cr300.00

Effects: Assets 0.00; Liabilities 300.00; Equity 0.00; Revenue 0.00; Expenses 300.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000080 (`4c4ca439-f2f6-4085-b7d4-b4561c6cb956`).

### ACCRUAL_REVERSE — Audit reverse incorrect estimate

2026-10-20; source `CR07-ACCRUAL_REVERSE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUED_LIABILITY: Dr300.00 / Cr0.00
- ACCRUAL_EXPENSE: Dr0.00 / Cr300.00

Effects: Assets 0.00; Liabilities -300.00; Equity 0.00; Revenue 0.00; Expenses -300.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000081 (`f2b48dea-a7a1-4d11-9298-b630debff8ef`).

### ACCRUAL_REPLACE — Traced actual corrected accrual250

2026-10-20; source `CR07-ACCRUAL_REPLACE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUAL_EXPENSE: Dr250.00 / Cr0.00
- ACCRUED_LIABILITY: Dr0.00 / Cr250.00

Effects: Assets 0.00; Liabilities 250.00; Equity 0.00; Revenue 0.00; Expenses 250.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000082 (`8e7192f5-3f59-49d7-baad-bbc57433f76a`).

### TRANSFER_STOCK — Transfer15 units between warehouses

2026-10-21; source `CR07-TRANSFER_STOCK`. **PASS**. Tax: No new tax. Quantity changes location, Company value unchanged.

No journal: operational metadata / physical transfer only; no invented revenue, expense or cash.

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: None, as expected.

### CON_PAY — Settle certified payable

2026-10-21; source `CR07-CON_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUBCONTRACTOR_PAYABLE: Dr3,500.00 / Cr0.00
- BANK: Dr0.00 / Cr3,500.00

Effects: Assets -3,500.00; Liabilities -3,500.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -3,500.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000049 (`8c1ef3b7-2d4f-4a4c-aff9-9229cc39a410`).

### COUNT — Physical count84 units

2026-10-22; source `CR07-COUNT`. **PASS**. Tax: No new tax. Count evidence alone creates no GL.

No journal: operational metadata / physical transfer only; no invented revenue, expense or cash.

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: None, as expected.

### SHORTAGE — Recognize actual shortage1 unit

2026-10-22; source `CR07-SHORTAGE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- VARIANCE: Dr10.00 / Cr0.00
- INVENTORY: Dr0.00 / Cr10.00

Effects: Assets -10.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 10.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000040 (`fdc727bc-3e56-436d-ad04-0f7e2073f3d4`).

### RET_RELEASE — Release supported retention

2026-10-25; source `CR07-RET_RELEASE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUBCONTRACTOR_RETENTION_PAYABLE: Dr500.00 / Cr0.00
- SUBCONTRACTOR_PAYABLE: Dr0.00 / Cr500.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000050 (`cbd59ce6-6d6d-425e-91d4-be4890849e4a`).

### ACCRUAL_PAY — Settle actual accrued service250

2026-10-25; source `CR07-ACCRUAL_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUED_LIABILITY: Dr250.00 / Cr0.00
- BANK: Dr0.00 / Cr250.00

Effects: Assets -250.00; Liabilities -250.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -250.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000083 (`0aedb93b-ca8e-486a-a9eb-7fcb0e7bc38b`).

### RET_PAY — Pay released retention

2026-10-26; source `CR07-RET_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SUBCONTRACTOR_PAYABLE: Dr500.00 / Cr0.00
- BANK: Dr0.00 / Cr500.00

Effects: Assets -500.00; Liabilities -500.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -500.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000051 (`54c41b3b-60fb-47e4-9a7c-1a1331a0db0e`).

### BANK_FEE — Actual bank statement charge20

2026-10-30; source `CR07-BANK_FEE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK_FEES: Dr20.00 / Cr0.00
- BANK: Dr0.00 / Cr20.00

Effects: Assets -20.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 20.00; Cash -20.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000084 (`05d93ade-c594-4023-b1c9-ba835aff1df7`).

### BANK_INTEREST — Actual bank statement interest10

2026-10-30; source `CR07-BANK_INTEREST`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr10.00 / Cr0.00
- BANK_INTEREST: Dr0.00 / Cr10.00

Effects: Assets 10.00; Liabilities 0.00; Equity 0.00; Revenue 10.00; Expenses 0.00; Cash 10.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000085 (`f7564d11-9522-40a2-930f-468e88672d90`).

### WIP_RELEASE — Release400 on actual performance

2026-10-31; source `CR07-WIP_RELEASE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- COGS: Dr400.00 / Cr0.00
- CONSTRUCTION_WIP: Dr0.00 / Cr400.00

Effects: Assets -400.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 400.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000056 (`7861263e-60a0-4b16-b608-c6513f97672e`).

### CR_BILL1 — Bill10000; unconditional retention1000, VAT500

2026-10-31; source `CR07-CR_BILL1`. **PASS**. Tax: 5% output; retention is separate receivable. Canonical source and subsidiary records; one financial effect.

- AR: Dr9,500.00 / Cr0.00
- CUSTOMER_RETENTION: Dr1,000.00 / Cr0.00
- CONTRACT_LIABILITY: Dr0.00 / Cr10,000.00
- OUTPUT_VAT: Dr0.00 / Cr500.00

Effects: Assets 10,500.00; Liabilities 10,500.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000057 (`e5ec5f82-bf60-44ba-a9cf-a3f9c08e10aa`).

### CR_APPLY — Apply construction advance2000 and VAT100

2026-10-31; source `CR07-CR_APPLY`. **PASS**. Tax: Original deposit tax relief. Canonical source and subsidiary records; one financial effect.

- CUSTOMER_ADVANCE: Dr2,000.00 / Cr0.00
- OUTPUT_VAT: Dr100.00 / Cr0.00
- AR: Dr0.00 / Cr2,100.00

Effects: Assets -2,100.00; Liabilities -2,100.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000058 (`9e7fdfc2-5e04-42c5-ae9b-d4dc5684216d`).

### CR_COLLECT1 — Collect first net progress balance

2026-10-31; source `CR07-CR_COLLECT1`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr7,400.00 / Cr0.00
- AR: Dr0.00 / Cr7,400.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 7,400.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000059 (`58dfe540-1d82-4e37-a593-5b6c1e731194`).

### CR_EARN — Recognize independently certified earned value12000

2026-10-31; source `CR07-CR_EARN`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- CONTRACT_LIABILITY: Dr10,000.00 / Cr0.00
- CONTRACT_ASSET: Dr2,000.00 / Cr0.00
- REVENUE: Dr0.00 / Cr12,000.00

Effects: Assets 2,000.00; Liabilities -10,000.00; Equity 0.00; Revenue 12,000.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000060 (`d609acd8-cf35-43eb-85c1-18fb7bd9fc27`).

### CR_BILL2 — Bill remaining2000 with retention200 and VAT100

2026-10-31; source `CR07-CR_BILL2`. **PASS**. Tax: 5% output. Canonical source and subsidiary records; one financial effect.

- AR: Dr1,900.00 / Cr0.00
- CUSTOMER_RETENTION: Dr200.00 / Cr0.00
- CONTRACT_ASSET: Dr0.00 / Cr2,000.00
- OUTPUT_VAT: Dr0.00 / Cr100.00

Effects: Assets 100.00; Liabilities 100.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000061 (`d447cf7c-5dff-4e96-a2c6-6e43e93f72b8`).

### CR_COLLECT2 — Collect second progress receivable

2026-10-31; source `CR07-CR_COLLECT2`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr1,900.00 / Cr0.00
- AR: Dr0.00 / Cr1,900.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 1,900.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000062 (`79a64642-62aa-486d-af87-6becc23356bd`).

### CR_RET — Release1200 actual Customer retention rights

2026-10-31; source `CR07-CR_RET`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- AR: Dr1,200.00 / Cr0.00
- CUSTOMER_RETENTION: Dr0.00 / Cr1,200.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000063 (`6f4efd42-c164-4108-93a5-b55a497e97ab`).

### CR_RET_PAY — Collect released Customer retention

2026-10-31; source `CR07-CR_RET_PAY`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- BANK: Dr1,200.00 / Cr0.00
- AR: Dr0.00 / Cr1,200.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 1,200.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000064 (`79e321d1-6dec-41a0-8aad-97d47dc74a71`).

### PAYROLL — Two employees; absence/leave/partial hours/overtime; recovery100

2026-10-31; source `CR07-PAYROLL`. **PASS**. Tax: No VAT. Gross5864.84; advance recovery does not reduce salary expense.

- PROJECT_COST: Dr5,864.84 / Cr0.00
- SALARY_PAYABLE: Dr100.00 / Cr5,864.84
- EMPLOYEE_ADVANCE: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities 5,764.84; Equity 0.00; Revenue 0.00; Expenses 5,864.84; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000066 (`b66eb3bf-81fa-42c0-bdd5-7e25c7448f44`), NARVO-DEMO-COMMERCIAL-JE-2026-000067 (`d218a7a1-2352-49bf-b97f-061ab8e3eeae`).

### SALARY1 — Pay first employee net2803.23

2026-10-31; source `CR07-SALARY1`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SALARY_PAYABLE: Dr2,803.23 / Cr0.00
- BANK: Dr0.00 / Cr2,803.23

Effects: Assets -2,803.23; Liabilities -2,803.23; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -2,803.23.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000068 (`e7071e66-2ea4-4f26-a8e1-3513f111c2fc`).

### SALARY2 — Pay second employee net2961.61

2026-10-31; source `CR07-SALARY2`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- SALARY_PAYABLE: Dr2,961.61 / Cr0.00
- BANK: Dr0.00 / Cr2,961.61

Effects: Assets -2,961.61; Liabilities -2,961.61; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash -2,961.61.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000069 (`328a35e8-3706-4047-bce5-a0aa3876aea7`).

### DEPR_OLD — October depreciation on opening asset

2026-10-31; source `CR07-DEPR_OLD`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- DEPRECIATION_EXPENSE: Dr100.00 / Cr0.00
- ACCUMULATED_DEPRECIATION: Dr0.00 / Cr100.00

Effects: Assets -100.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000073 (`d5416d22-9488-4d64-90d8-a44b667cda66`).

### DEPR_NEW — October depreciation on new asset

2026-10-31; source `CR07-DEPR_NEW`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- DEPRECIATION_EXPENSE: Dr200.00 / Cr0.00
- ACCUMULATED_DEPRECIATION: Dr0.00 / Cr200.00

Effects: Assets -200.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 200.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000074 (`2a50ea17-fe97-44ad-8a7d-ff6f5b5995c7`).

### ASSET_SALE — Sell original asset1100 plus VAT55; NBV1000, gain100

2026-10-31; source `CR07-ASSET_SALE`. **PASS**. Tax: 5% asset tax invoice. Atomic sale/retirement; actual collection remains separate.

- AR: Dr1,155.00 / Cr0.00
- REVENUE: Dr1,100.00 / Cr1,100.00
- OUTPUT_VAT: Dr0.00 / Cr55.00
- ACCUMULATED_DEPRECIATION: Dr200.00 / Cr0.00
- ASSET_COST: Dr0.00 / Cr1,200.00
- DISPOSAL_GAIN: Dr0.00 / Cr100.00

Effects: Assets 155.00; Liabilities 55.00; Equity 0.00; Revenue 100.00; Expenses 0.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000075 (`9d9d34c3-5fb5-4e24-aa5c-8b7ca9fc9b52`), NARVO-DEMO-COMMERCIAL-JE-2026-000076 (`e0146dad-caf5-4c57-a1dc-036776b55a59`).

### ASSET_RECEIPT — Collect actual asset sale proceeds

2026-10-31; source `CR07-ASSET_RECEIPT`. **PASS**. Tax: No second output VAT. Investing receipt, not generic operating collection.

- BANK: Dr1,155.00 / Cr0.00
- AR: Dr0.00 / Cr1,155.00

Effects: Assets 0.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 0.00; Cash 1,155.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000077 (`59a40785-af07-4ce3-84d3-1163c264a854`).

### AMORTIZE — Allocate17 actual October days at10

2026-10-31; source `CR07-AMORTIZE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUAL_EXPENSE: Dr170.00 / Cr0.00
- PREPAYMENT: Dr0.00 / Cr170.00

Effects: Assets -170.00; Liabilities 0.00; Equity 0.00; Revenue 0.00; Expenses 170.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000079 (`6eaa23de-725b-402c-9e48-251226feca46`).

### BROWSER_ACCRUAL — Browser entered actual fictional accrual100

2026-10-31; source `CR07-BROWSER_ACCRUAL`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUAL_EXPENSE: Dr100.00 / Cr0.00
- ACCRUED_LIABILITY: Dr0.00 / Cr100.00

Effects: Assets 0.00; Liabilities 100.00; Equity 0.00; Revenue 0.00; Expenses 100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000086 (`5dbe109f-2b44-45d1-ba20-75941fc4028c`).

### BROWSER_REVERSE — Audited browser correction of same fictional accrual

2026-10-31; source `CR07-BROWSER_REVERSE`. **PASS**. Tax: No new tax. Canonical source and subsidiary records; one financial effect.

- ACCRUED_LIABILITY: Dr100.00 / Cr0.00
- ACCRUAL_EXPENSE: Dr0.00 / Cr100.00

Effects: Assets 0.00; Liabilities -100.00; Equity 0.00; Revenue 0.00; Expenses -100.00; Cash 0.00.

Actual journals: NARVO-DEMO-COMMERCIAL-JE-2026-000087 (`d04e4456-01c1-496b-9699-37cd2d3ce0e2`).

## Annual lock and correction

The independent annual closing key clears each revenue/expense balance and debits Retained Earnings1,529.84. Admin-only close/reopen carries reason and reconciliation evidence. Reopen exactly reverses the original close and opens the last fiscal period; finalization again locks the year.

- NARVO-DEMO-COMMERCIAL-JE-2026-000088 / `19fb7853-d028-4579-9b71-87ab4877921f`; reversal of none
- NARVO-DEMO-COMMERCIAL-JE-2026-000089 / `7e9376c9-5371-47dc-a52c-fd185d6574fd`; reversal of 19fb7853-d028-4579-9b71-87ab4877921f
- NARVO-DEMO-COMMERCIAL-JE-2026-000090 / `65ccfe7b-a573-426b-beff-9b2851e9ee2b`; reversal of none

Existing pre-close journals and lines remain byte-for-byte unchanged. Closed stock counts and financial commands reject; backdated moving-average valuation still rejects.

## Verification, defects and limits

Confirmed defect: Inventory enforced the server calendar month rather than open configured fiscal periods, rejecting a valid September receipt. Prepared105 changes only private Inventory planning date validation, preserves chronological valuation and adds fiscal gating for journal-free count/transfer paths; no RLS/grant or financial data changes. Native fixture preserves149 tables. Migration SHA256: `daebec8d16d3cd3cb40a498d91ca770c6a63004a1ed1a286e6702c3fbbd9af16`. Hosted104 is current; linked dry-run lists only105.

Confirmed presentation defect: dates and decimal amounts wrapped in the commercial register. Existing cells now retain a single readable numeric line in RTL/LTR.

Focused new checks cover independent postings, duplicate invoice/stock revenue, excessive payment/return, unsupported VAT, Company/role/Payroll confidentiality, immutable journals, invalid controls, closed periods, annual close/reopen, double reversal, imbalanced private kernel rejection, concurrent settlement and complete financial reconciliation. Unchanged earlier duplicate-cost/payment/replay controls reuse CR03–CR06 evidence; they were not all replayed. TypeScript and Production build pass (non-blocking chunk-size warning).

Actual rendered components performed English entry/classification/preview/post and Arabic audited reversal against persisted canonical commands in this Company. Arabic/English Supplier/Customer selectors, financial statements, PDF/Excel and390px layouts verified. External requests were blocked. The test Auth/master adapters are synthetic, so this is **not full protected-route/Supabase Auth end-to-end acceptance**. XLSX/PDF files and screenshots accompany the evidence.

### Essential remaining gates — NOT READY

- Complete Supabase Auth → full protected application routes → operational posting acceptance was not executed. The rendered tests use actual components/DB commands with a synthetic Auth/master adapter. This is an essential operational acceptance gap, not a financial pass.
- Migration105 remains PREPARED / NOT APPLIED; its Inventory historical-period correction needs explicit hosted authorization and compatible release validation before unrestricted acceptance.

### Specialist/deferred limitations

- Single integrated construction obligation; multi-obligation allocation, claims/variable consideration and onerous-contract specialist cases remain outside verified scope.
- Company onboarding/initial masters use synthetic fixture bootstrap; existing canonical Company configuration commands are exercised, but commercial onboarding UI is not certified.
- Dedicated jurisdictional tax-return filing, statutory compliance certification and final DR/restore rehearsal remain deferred.
- Construction customer contract closeout is executed; administrative Project status closure is not claimed.

Business/accounting, local database/RLS/authorization, focused testing and documentation: VERIFIED for this bounded execution. Hosted105 deployment and full authenticated operational acceptance: DEFERRED, therefore unrestricted commercial go-live is not accepted. Real-Company data changes: NOT APPLICABLE and0. No push/deploy/migration activation performed.

Local isolated release branch `release/cr07-integrated-acceptance`, parent `e8d2efb4f93f47f7a77f2e1dc0522dbf9812767a`; final SHA is the commit containing this report. Exact publication command after authorized activation/acceptance: `git push origin release/cr07-integrated-acceptance:main`.
