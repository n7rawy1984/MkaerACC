# Commercial sales and fulfillment

Baseline: Product Owner confirms `e5abbcec6500c826f2058dc0b85734a87b64c332` published and migrations through113 applied. Work is isolated in `release/commercial-sales-fulfillment`; original repository changes are preserved.

## Delivered operational scope

`/sales` is registered in the protected Company workspace and bilingual navigation. Accounting Admin/Accountant operate; Management Viewer reads. Existing foundation/subscription readiness gates new sales. Existing customer enrollment, material/UOM approval and dedicated AR/Revenue/VAT/COGS/Inventory controls must already be configured; no configuration or financial master is invented.

- **Quotation:** multiple existing materials, exact purchase/sales units, quantity, price, discount, explicitly evidenced VAT including zero, Customer/optional Project association, validity and customer reference. Draft→Review→Approve; approved quotation revisions retain prior versions/reasons. Conversion snapshots the approved quotation/version into one editable order. Expired/duplicate conversions are rejected.
- **Order:** direct or approved-quotation entry, editable draft, reviewed confirmation, history, customer terms/reference, outstanding quantities and cancellation of remaining commitments. Original quote/order versions never change. No quotation/order creates a journal, payable, stock movement, VAT recognition or revenue.
- **Delivery:** select outstanding order lines, quantities and Company warehouses; draft→review→approve/post. Multiple partial deliveries use the exact approved UOM ratio. Canonical Inventory issues verify availability, current chronological dates, periods, customer, valuation and Company. All selected lines commit atomically; no partial leftover documents if any line fails. COGS is debited and Inventory credited once.
- **Invoice:** select eligible delivered lines, due date and actual invoice evidence. One idempotent submission can bill multiple eligible lines; **each stock issue creates its own canonical goods invoice** under the existing one-issue/one-invoice rule. Net/VAT derive from confirmed order prices and cumulative delivered quantities. The invoice uses its actual delivery recognition date, debits AR, credits Revenue/output VAT and does not issue stock again. Direct canonical AR entry cannot override the agreed managed delivery net/VAT. Duplicate financial links are constrained in the database.
- **Collection:** invoice links open existing Customer Accounts with Customer, invoice and receipt action selected and loaded. Canonical receipts, advances, credit application, statements, aging, GL reconciliation and audited correction controls are reused. Canonical journal links open the existing journal-filtered transactions report.
- **Returns:** actual billed deliveries can be returned in the original sales unit with date/evidence. Canonical Inventory returns restore recorded cost; canonical customer credit reduces AR or creates available customer credit, never automatically refunds cash. Both operations commit atomically. Return credit minor units now allocate cumulatively to avoid stranded cents. No historical journal changes.
- **Reports:** all paginated sales documents, quoted/ordered lines, original/base units, delivered quantities, outstanding commitments, invoice/journal links and recognized margin supported by actual revenue/credit and stock-return cost evidence. Cancelled remainders retain their historical deliveries through stable order document identity. Shared bilingual Excel and printable PDF infrastructure is reused.

## Exact limits

This completes the supported goods orchestration, not every possible sales policy. Do not represent these as implemented:

1. A **single consolidated invoice across multiple issues**, or billing a fraction of one already-posted issue, is not supported by the existing canonical one-issue/one-invoice model. Partial billing selects complete delivery lines; plan physical partial deliveries accordingly.
2. Stock sales require Company warehouses and Company orders. Project association is retained on quotation/order records, but Project-linked goods fulfillment is explicitly blocked by the existing stock/revenue policy; construction service/WIP recognition remains in its existing workflow.
3. No invoice-before-delivery policy, negative stock, automatic cash refund, unsupported FX or service/noncatalog fulfillment is introduced. Inventory retains its existing current chronological period restriction and six-decimal quantities.
4. An independently returned **unbilled** issue is not silently invoiced as fully delivered; it requires audited accounting resolution. A reversed invoice remains visible and is not silently rebilled. Price-credit/physical-return combinations must still satisfy canonical remaining-value controls; zero-value financial credits are never invented.
5. External customer transmission and new attachment entity categories are outside this milestone. Existing private document controls remain unchanged.
6. Genuine hosted Auth/runtime verification is deferred until explicitly authorized Migration114 activation and compatible frontend publication. Local browser Auth is a clearly identified synthetic adapter around actual production components and canonical SQL, not hosted acceptance.

## Safety and evidence

Migration114 `20261202120000_sales_fulfillment.sql` is additive and **NOT APPLIED**. It creates immutable tenant-owned operational events, request receipts, delivery/invoice relationships, canonical orchestration/read commands and focused dependency guards. It makes one forward correction to the existing private goods-return credit limit, preserving all existing function grants/search paths/security modes. There is no seed, financial backfill, Storage policy change or real Company mutation.

See [verification](sales-fulfillment-verification.json), [actual fictional accounting results/journals](sales-evidence/accounting.json), [focused controls](sales-evidence/controls.json), [independent concurrent sessions](sales-evidence/concurrency.json), [bilingual workflows](sales-evidence/browser.json), [final rendering/handoff](sales-evidence/final-smoke.json) and [actual export contents](sales-evidence/exports.json).

Independent accounting answer key: after15 delivered units, one unit returned, four goods invoices and a partial collection: net revenue AED330; VAT16.50; AR306.50; COGS140; Inventory1,860; recognized gross margin190. All actual journals balance and AR subledger equals its GL control. Separate exact-UOM/discount/rounding/period/readiness and native competing-session fixtures are not combined into these balances. Original CR07 and procurement simulations were not rerun.

Lifecycle: **VERIFIED locally** business/accounting for stated scope; authorization/RLS/direct-write/concurrency; database compatibility/preservation; focused runtime/browser/export checks; documentation. **DEFERRED** explicit hosted114 activation/preservation, compatible publication, genuine hosted smoke and the limits above. **NOT APPLICABLE** real-company postings/configuration, new accounting engine, AI, unrelated refactors or reopening deferred backup restore/USB work.

Release order: authorize only114 → essential hosted preflight/activation/preservation → explicitly publish compatible frontend → genuine authorized Company smoke. Never publish frontend against a database missing114. No migration, push or deployment is automatic.
