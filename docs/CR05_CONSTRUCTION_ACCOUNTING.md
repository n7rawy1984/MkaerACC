# CR-05 — Construction accounting and WIP

Local implementation and isolated verification only. Production baseline is CR04 `99305ef4ec79b441f8014308d23d52e43f53675d`, confirmed deployed by the Product Owner. Hosted canonical history is aligned through102; linked read-only dry-run lists only103. No hosted financial writes, migrations, push or deployment occurred during CR05.

## Implemented accounting boundary

Project remains an analytic dimension. Customer contracts, evidence events and canonical-document links extend the existing commercial documents and private financial-command registry; they do not form another GL. Existing canonical journal/reversal, AR, AP, Treasury, Inventory, Payroll and subcontract commands perform financial effects. Customer settlements made from the existing AR interface inherit construction traceability. Existing Company/accounting-period/final-lock, permissions, request hashing, Company transaction locks and immutable-history controls remain authoritative.

An Accounting Admin approves a contract's recognition policy, obligation, consideration, dates and retention right. One integrated performance obligation per Project is supported. Over-time recognition requires explicit IFRS15 35(a),35(b) or35(c) evidence and supported cumulative certified output. Point-in-time recognition requires complete evidenced control transfer. Neither invoices nor customer cash automatically earn revenue. The ordinary AR sales command cannot bypass the construction policy for its Project. Existing Project customer financial events require a separately scoped opening/adoption assessment before a new contract can be created.

Approved same-obligation variations revise total consideration without creating revenue. A recognition entry cannot exceed both approved output and remaining supported consideration. Changes involving separate obligations, standalone selling-price allocation or unsupported modification accounting are rejected for separate assessment.

Contract position is earned revenue minus unconditional net billings. Recognition consumes contract liability before increasing contract asset. Billing consumes contract asset before creating contract liability. Customer advances use the existing Customer Advance liability and allocation/refund commands. Unconditional customer retention is a separate receivable; conditional retention remains a contract asset until its condition is met. Retention release does not recreate revenue. Deposits require explicit evidence that no advance tax-point posting is necessary; taxable customer advances remain outside this bounded workflow.

Invoice VAT supports evidenced zero treatment or documented5% invoice VAT, without inventing tax evidence. The fictional simulation explicitly uses non-taxable/zero-tax facts; it imposes no tax or recognition policy on Maker.

## Selective contract-cost assets

WIP here means an eligible future-performance contract-cost asset, distinct from Inventory and the IFRS15 contract asset for earned consideration. Costs of work already performed remain expenses. Capitalization requires an actual unreversed Project expense GL line, future-performance evidence, supported recovery, exclusion from other asset standards and an expected release date within the contract. Previously capitalized source amounts cannot be reused. No general overhead allocation is invented.

Opening WIP allocates an already-certified, unallocated opening WIP GL asset to a Project: Dr WIP(Project), Cr WIP(unallocated). It never invents opening equity or assets. Global Company source bounds prevent reuse across Projects. Release/impairment debits configured COGS and credits WIP. Review records supported recoverability; insufficient recovery must be impaired first. Overdue balances are highlighted, remain auditable and prevent contract closeout while outstanding. Valuation remains an accountant responsibility; there is no automatic write-off, automated actuarial estimate or new fiscal-close policy.

WIP cost-source details may include Payroll. Full source costs, margin, WIP details and their reversals require existing `payroll.manage` scope. Management Viewer receives read-only customer/revenue balances with cost data redacted in RPC, direct-table RLS and exports. No privilege or real Company policy is granted by this migration.

## Operational path

Open an existing Project's details → Construction accounting & WIP → Load construction account. Use the existing Customer workspace to establish the Customer role and ordinary typed controls; an Accounting Admin maps the four new unused controls through the scoped construction setup. No account is silently created/remapped. Contract policy → supported event → server accounting preview → Approve & Post, or metadata approval where no journal is required. Frozen request intent supports identical retry after uncertain network outcomes. Existing customer/subcontract/GL links and shared bilingual PDF/Excel exports remain available.

Reversals retain original immutable journals. Reverse later construction billing/recognition/WIP dependencies first. Settled billing cannot be directly reversed; existing cash receipts are preserved. WIP source correction and physical stock recovery are blocked until dependent capitalization/releases are resolved. No automatic correction of real posted events is authorized.

## Actual isolated result

The coherent construction lifecycle and independent expected entries are recorded in `cr05/construction.json`; `CR05_ACCOUNTING_LEARNING_REPORT.md` lists every event, its expected accounting and actual journal IDs. Customer advance, material receipt/AP match/issue, direct services, allocated Payroll, subcontract advance/certification/recovery/retention, progress billing, revenue, selective WIP, cash settlements and contract closeout use one disposable fictional Company.

| Measure | Interim AED | Final AED |
|---|---:|---:|
| Earned revenue | 40,000 | 100,000 |
| Unconditional net billing | 30,000 | 100,000 |
| Customer cash received including advances | 25,000 | 100,000 |
| Recognized costs | 26,000 | 30,500 |
| Project margin | 14,000 | 69,500 |
| Contract asset | 10,000 | 0 |
| Contract liability | 0 | 0 |
| Customer retention | 3,000 | 0 |
| WIP schedule and Project GL | 4,500 | 0 |

Final Bank168,000 + Inventory2,000 = assets170,000 = liabilities0 + certified opening equity100,500 + profit69,500. Cash Flow opening100,000 + operating68,000 = closing168,000. Trial Balance debit=credit413,000. Customer AR, Supplier AP, Payroll payable, customer/subcontract advances and both retentions settle to zero. Supplier invoice matching, stock issues, Payroll payment and subcontract advance recovery do not recreate costs. The500 certified opening WIP is released into current costs; future-stage4,000 is temporarily capitalized and later released. Original fixture journals and the original65-scenario archive remain preserved.

33 distinct lifecycle events create29 new journals; the certified opening adds one, giving30 Company journals. Auxiliary policy, reversal, impairment, authorization and browser scenarios are separate evidence, not added to the coherent lifecycle's journal count. Original65-scenario evidence is preserved rather than presented as rerun/integrated acceptance.

## Verified / deferred / not applicable

- Business/accounting: VERIFIED for the explicitly supported policies and independent coherent answer key. Separate-obligation allocation, taxable deposits, complex settled-billing credit/rebill chains and existing-customer-history adoption remain DEFERRED.
- Security/authorization: VERIFIED by focused local role/tenant/direct-write/privacy tests, scoped function/grant review and native concurrency checks. Existing Production authority unchanged.
- Database: VERIFIED locally; additive Migration103 PREPARED, NOT APPLIED. New tables force RLS and deny direct browser mutations; public privileged functions use a fixed empty search path, private primitives remain private. No seeds or financial backfill. Exact checksum in verification JSON.
- Deployment: DEFERRED. Explicit103 hosted approval/activation/preservation must precede compatible frontend publication; Production runtime acceptance follows publication. No automatic publication.
- Testing: VERIFIED with focused financial/control/report/native and real bilingual local browser evidence; final TypeScript/Production build status in verification JSON. Screenshots reviewed at1366×768 and390px. Existing bundle-size advisory is a nonblocking limitation.
- Documentation: VERIFIED for this bounded local result. No claim of full commercial acceptance or Maker operational completion.
- Real-company transaction processing: NOT APPLICABLE; none authorized/performed. Full Production audit and restoration rehearsal remain separate deferred gates.

Contract closeout does not silently administratively close the Project. Existing Project lifecycle, outstanding subcontract-work/Payroll assignment and bank-reconciliation guards continue to apply. No fabricated subcontract completion or bank statement is introduced merely to force administrative closure.

Next approved work: CR06 remaining essential accounting scenarios, then CR07 integrated fictional-company acceptance. Preserve all original commercial, Maker Payroll/operational, entity-onboarding, security/operations, DR and USB requirements; no next milestone was started.

Policy references: [IFRS Interpretations Committee, June2019 — costs to fulfil](https://www.ifrs.org/news-and-events/updates/ifric/2019/ifric-update-june-2019/), [official IFRS15 agenda decision](https://www.ifrs.org/content/dam/ifrs/supporting-implementation/agenda-decisions/2019/ifrs-15-costs-to-fulfil-a-contract-june-2019.pdf). These explain the distinction between future-performance resources and costs of satisfied performance; contract-specific legal criteria still require actual evidence.
