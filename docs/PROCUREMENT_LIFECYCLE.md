# Procurement lifecycle — receipt-first implementation

This extends the published Purchase Orders V1 release `c61810366f677b9101012a264eadd84df48d78bf`. GitHub main was verified at that exact SHA; Vercel deployment was not independently checked. Hosted107 is applied; linked dry-run lists only prepared108. No hosted business mutations, push or deployment occurred.

## Operational workflow

`/procurement` is registered in the existing protected Company application and Inventory navigation. The existing PO register links back to it. English and Arabic share the same components and server commands.

- Requisition: save editable Company/Project requests, material or service descriptions, exact base quantities, units and required date; submit → review → accountant approval, rejection or audited cancellation. Editing submitted/reviewed content returns to Draft.
- RFQ: use an approved requisition; register up to20 actual Supplier quotations against its identical requested quantities. Compare exact line prices, quoted VAT, delivery, payment terms and external quotation references. No email is sent. Unknown quotation VAT must be completed explicitly, rather than silently assumed zero.
- Authorized selection records Supplier/reason/quotation and generates one canonical PO Draft. An approved requisition can also convert directly with explicit Supplier and prices. A requisition cannot generate a second order through a different conversion path. Existing PO review/issue controls remain authoritative.
- Receive an issued PO line, select warehouse, actual date, base quantity and unique delivery-line reference. Full, partial and multiple receiving use canonical Inventory SAVE/REVIEW/POST. Ordered quantity is rechecked under Company serialization at execution, not trusted from the earlier preview. Wrong Project/warehouse and over-receipts fail closed.
- Match all or part of an actual GRNI receipt to a Supplier credit invoice, with its true invoice number, due date, net amount, purchase category and supported tax evidence. Preview → review → authorized execute. The existing Inventory match requires Accounting Admin and reversal permission; Accountants can prepare/review eligible invoices. Settlement remains in existing Supplier AP, rather than another payment form.
- Existing immutable Inventory and Expense reversals are composed atomically for invoice correction. Receipts cannot reverse underneath active matches/returns. Outside corrections remain visible through effective canonical status; incomplete external correction chains show Needs accounting review.

## Accounting policy and canonical integration

PR, RFQ and unfulfilled PO documents are **nonfinancial**. A quotation's VAT is comparison metadata, never input tax recognition.

The supported policy is **receipt first**. Receipt recognizes agreed PO net cost: Dr Inventory / Cr GRNI, Supplier dimension. Canonical moving-average movements and fiscal/annual controls remain the only stock valuation engine. Receiving does not recognize AP, recoverable VAT, payments or Project consumption.

Invoice posting reuses `post_supplier_invoice`, `post_expense` and canonical Inventory MATCH. The Expense cost leg is cleared by MATCH, yielding Dr GRNI / Dr supported input VAT / Cr Supplier AP without another stock or cash movement and without duplicate Project cost. Partial matches allocate original carrying value cumulatively with exact final rounding. Complete preview includes every final debit/credit account. Invoice quantity cannot exceed the remaining receipt. Unsupported invoice-first cases are rejected; no artificial receipt is generated.

A net invoice/carrying-price difference uses the **existing Inventory variance control**, with explicit Accounting Admin review and a specific reason. This is the supported reviewed price-variance treatment, not automatic retrospective stock revaluation or a claim to implement every alternative accounting policy. Missing tax invoices never create recoverable VAT.

CR04 physical returns and credits remain canonical. Partial-invoice return limits and proportional net/VAT are calculated against the particular matched invoice quantity. The return selector identifies receipt **and** invoice. A returned invoiced tranche does not block invoicing the unrelated unbilled receipt remainder. Credits, allocations, refunds and reversal dependencies are preserved.

## Reporting and safety

Complete Company totals are independent of register pagination: requested/approved, ordered/received/invoiced/returned/remaining quantities and unreceived commitments. Commitments exclude VAT and are not AP balances. Recorded delivery counts distinguish actual due-dated receipts and on-time receipts; no unsupported Supplier rating is inferred. Shared bilingual Excel and printable PDF exports use the same data.

Migration108 adds an empty append-only forced-RLS event table and scoped functions/PO cancellation guard; it forward-extends canonical Inventory/AP matching and returns. No seed/backfill or financial DML is executed by activation. Existing grants and search paths remain unchanged. Actor/membership checks, exact money, idempotent request receipts, optimistic versions, Company locks, tenant validation, open periods and immutable journals remain authoritative. Browser session storage contains only actor/Company-bound frozen retry envelopes; no local business ledger or hosted fallback.

## Bounded limitations and publication gates

- Canonical goods receipt has one Material/base-unit line per document; use an actual unique delivery-line reference. One invoice document matches one receipt, including a partial quantity. Consolidated Supplier invoices spanning several receipts are not implemented; do not fabricate different invoice identities to circumvent duplicate protection.
- Service requests and POs are supported; stock receiving requires catalog Materials. Service invoicing remains the existing AP workflow. Alternate-UOM ordering and issued-PO amendments remain outstanding.
- Receipt evidence is an actual reference/text. No new secure attachment upload service or external RFQ delivery is claimed.
- Receipt-first recognition and reviewed variance expensing are the supported policy. Invoice-first and retrospective stock-price revaluation are not enabled.
- Local actual component/browser execution uses synthetic Auth transport to disposable canonical PostgreSQL commands. This is not hosted authenticated acceptance. Activate108 only with explicit authorization, publish compatible code and perform a targeted authenticated route smoke afterward.
- Maker, Green, Villa13, Farm, all real financial data and prior CR07 evidence were untouched. All broader original roadmap and deferred recovery requirements remain preserved.

## Definition of Done for this bounded release

Business/accounting, security/authorization, local database/migration execution, focused testing and documentation: VERIFIED against the recorded evidence. Deployment/hosted108 and genuine post-release route smoke: DEFERRED pending owner action. Real Company accounting changes and new operational/recovery infrastructure: NOT APPLICABLE. See [verification](procurement-verification.json) and [evidence](procurement-evidence/).
