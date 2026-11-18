# CR05 Accounting Learning Report

Actual isolated canonical accounting. No real Company entries. The independent expected answer key was declared before execution. Existing65-scenario evidence is preserved.

33 lifecycle events,29 new journals plus one already-certified opening =30 Company journals. No journal is fabricated to balance a report.

| Event | Independent expected debit / credit (AED) | Actual journal IDs |
|---|---|---|
| Contract policy | Audited metadata; no journal | None |
| Certified WIP opening allocation | Dr CONSTRUCTION_WIP 500.00; Cr CONSTRUCTION_WIP 500.00 | `69ec0603-e7e8-40e4-bd95-0efda6c69e32` |
| Customer advance | Dr BANK 20,000.00; Cr CUSTOMER_ADVANCE 20,000.00 | `28544193-ac19-45c4-aeb0-1efec61ec2f7` |
| Material receipt | Dr INV 5,000.00; Cr GRNI 5,000.00 | `637fca1c-1b9e-47e7-bef2-c106a335f2e4` |
| Supplier material invoice and match | Dr PROJECT_COST 5,000.00; Cr PROJECT_COST 5,000.00; Cr SUPPLIER_PAYABLE 5,000.00; Dr GRNI 5,000.00 | `9d564a5c-fb39-4d59-8c09-4598ceea694d`, `d74ab365-ee07-4d14-a78d-7034dfecc18a` |
| Project material issue | Dr PROJECT_COST 3,000.00; Cr INV 3,000.00 | `2fac5aa8-919e-4f09-983d-2649a698c9d4` |
| Direct Project expense | Dr PROJECT_COST 1,000.00; Cr BANK 1,000.00 | `fde3909a-6dc7-4df5-85e3-44defd347e92` |
| Project labor payroll accrual | Dr PROJECT_COST 2,000.00; Cr SALARY_PAYABLE 2,000.00 | `def4f1dd-c8f7-44c3-90f2-7423215f7a36` |
| Payroll liability payment | Dr SALARY_PAYABLE 2,000.00; Cr BANK 2,000.00 | `f53e02de-eac2-4268-a4c2-ef98713f8dca` |
| Subcontractor advance | Dr SUBCONTRACTOR_ADVANCE 5,000.00; Cr BANK 5,000.00 | `d05c0e85-4954-47f2-bf76-32dcbc1a9480` |
| Certified subcontractor work | Dr PROJECT_COST_SUBCONTRACTORS 20,000.00; Cr SUBCONTRACTOR_ADVANCE 5,000.00; Cr SUBCONTRACTOR_RETENTION_PAYABLE 2,000.00; Cr SUBCONTRACTOR_PAYABLE 13,000.00 | `bcb6e3bb-1897-49cd-bc72-eb7dfd8a94e0` |
| Customer progress certificate | Audited metadata; no journal | None |
| Progress billing | Dr AR 27,000.00; Dr CUSTOMER_RETENTION 3,000.00; Cr CONTRACT_LIABILITY 30,000.00 | `41d0f4f4-bdbb-4b26-9c54-849964e8ef54` |
| Apply customer advance | Dr CUSTOMER_ADVANCE 20,000.00; Cr AR 20,000.00 | `f810a55e-51c4-49c1-b33f-14ee76e1fc15` |
| Supported revenue recognition | Dr CONTRACT_LIABILITY 30,000.00; Dr CONTRACT_ASSET 10,000.00; Cr REVENUE 40,000.00 | `21064423-22ae-4c3d-b571-84d6c9679d27` |
| Customer partial collection | Dr BANK 5,000.00; Cr AR 5,000.00 | `1394de9a-35b8-46de-8697-6e1c93462155` |
| Future-stage setup cost | Dr PROJECT_COST 4,000.00; Cr BANK 4,000.00 | `e6859b61-60e8-48cd-b9be-a7ea6a175ee9` |
| Eligible future-cost capitalization | Dr CONSTRUCTION_WIP 4,000.00; Cr PROJECT_COST 4,000.00 | `fde6ffa8-d780-43dc-93b9-844177d3a82b` |
| Period-end WIP review | Audited metadata; no journal | None |
| Supplier settlement | Dr SUPPLIER_PAYABLE 5,000.00; Cr BANK 5,000.00 | `46cbf2f5-f2f5-4975-b1a9-b1847ca9c5af` |
| Contractor settlement | Dr SUBCONTRACTOR_PAYABLE 13,000.00; Cr BANK 13,000.00 | `d0eab9ef-adb2-4c7b-a6fa-dafa0091c5fc` |
| Contractor retention release | Dr SUBCONTRACTOR_RETENTION_PAYABLE 2,000.00; Cr SUBCONTRACTOR_PAYABLE 2,000.00 | `e7a29212-701b-4b99-8489-952540696ef3` |
| Contractor retention payment | Dr SUBCONTRACTOR_PAYABLE 2,000.00; Cr BANK 2,000.00 | `3dabda1c-d6dd-4a07-8a3d-22357fc7ab06` |
| Completion certification | Audited metadata; no journal | None |
| Completion billing | Dr AR 63,000.00; Dr CUSTOMER_RETENTION 7,000.00; Cr CONTRACT_ASSET 10,000.00; Cr CONTRACT_LIABILITY 60,000.00 | `43a079eb-9b53-4dea-aa40-b7e010a8f9a1` |
| Completion revenue | Dr CONTRACT_LIABILITY 60,000.00; Cr REVENUE 60,000.00 | `87d1c7ad-d997-49b3-8bb1-a68a3505110e` |
| Opening WIP release | Dr COGS 500.00; Cr CONSTRUCTION_WIP 500.00 | `6ce72b1b-ec38-4a30-8581-f1ccca24cd64` |
| Future-stage WIP release | Dr COGS 4,000.00; Cr CONSTRUCTION_WIP 4,000.00 | `4ea8a75e-966b-43d4-8bff-b7f0e0f59381` |
| Customer retention release | Dr AR 10,000.00; Cr CUSTOMER_RETENTION 10,000.00 | `d0bada86-19b4-4900-9728-c092b550a29b` |
| First invoice final collection | Dr BANK 2,000.00; Cr AR 2,000.00 | `933d81a9-1a3f-43a0-b8d4-d0ec8f1b4d79` |
| Final progress collection | Dr BANK 63,000.00; Cr AR 63,000.00 | `8e86a772-23ad-47d4-97f0-e1b6efeb649f` |
| Retention collection | Dr BANK 10,000.00; Cr AR 10,000.00 | `f6c00421-4b90-4b05-b1fa-fc4860100f92` |
| Contract closeout | Audited metadata; no journal | None |

Opening evidence: Dr Bank100,000; Dr supported opening WIP500; Cr Equity100,500. Opening WIP allocation transfers500 to the Project without creating another asset.

Interim: earned40,000 / billed30,000 / received25,000; contract asset10,000, customer retention3,000, WIP4,500, costs26,000 and margin14,000.

Final: earned=billed=received100,000; costs30,500; margin/profit69,500. Bank168,000 + Inventory2,000 = assets170,000 = liabilities0 + equity100,500 + current profit69,500. Trial Balance debit=credit413,000. Cash Flow opening100,000 + operating68,000 = closing168,000. Customer/Supplier/Payroll/Subcontract control balances and WIP all zero.

The actual Project Cost Ledger engine matches30,500. Inventory/AP matching, Payroll liability payment and subcontract advance recovery do not add a second cost. Original fixture journals remain byte-for-byte unchanged.

Full actual journals, lines, subledgers, report results and expected-versus-actual entries: [construction.json](cr05/construction.json). Auxiliary policy, impairment, privacy and concurrent-command checks are in the same evidence directory. These auxiliary journals are separate from the coherent30-journal answer key.

The final integrated all-module acceptance remains CR07. See [policy and limitations](CR05_CONSTRUCTION_ACCOUNTING.md).
