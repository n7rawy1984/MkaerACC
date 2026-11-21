# Multi-line procurement accounting

## Scope and release boundary

Continues published `dc0ebd72c70a9280bdf6d590022ee98903cae041`; hosted111 activation is verified in the prior activation record and singleton112 linked dry-run. This is a local implementation milestone. No real financial, employee, Company, Supplier or operational records were changed. No hosted migration, push or deployment occurred. Original `develop/narvo` dirty/untracked work is preserved in its original directory; the release is isolated.

Existing PR/RFQ/PO, Inventory, GRNI, AP, VAT, Treasury, private-document, fiscal/reversal and request/Company serialization infrastructure is reused. There is one canonical stock and accounting engine. Single-line workflows and posted history remain supported; no data backfill or account configuration occurs.

## Practical workflow

* Open an issued PO → **Receive multiple items**. The PO is retained by the deep link. Select actual ordered Materials, quantities and destination warehouses; units and prices come from immutable approved order lines. Zero quantities omit undelivered lines. Warehouse/Project and available quantities are validated in the database. Review the line values and aggregate Dr Inventory / Cr GRNI → confirm once.
* One physical receipt groups canonical receipt lines atomically. Its actual delivery reference remains on the parent; derived `reference / line N` child identities satisfy existing receiving-source uniqueness without weakening it. Each line has its own stock movement and journal, linked to the parent, PO and line. A second partial delivery is another physical document. Supplier delivery statistics and register pagination count physical documents, not hidden child lines.
* Open Supplier Invoices → **Match multiple goods receipts to one invoice**. Select receipt lines and actual full/partial quantities, net amounts, verified per-line ZERO/5%/manual VAT and any approved price difference. Multiple compatible POs/deliveries are supported. Review quantities, GRNI carrying amounts, line net/VAT/variance and aggregate accounting → Approve & Execute.
* There is one actual invoice number, canonical AP invoice, due date and Supplier balance. Existing Supplier Payments, advances/credits and statements use that same invoice ID. Existing private-document panels recognize receipt/invoice parent IDs and preserve their posted evidence.
* Accountants prepare/review within existing permissions; Accounting Admin authorization remains required for Inventory invoice matching and price variances. Posted correction uses dependency-aware canonical reversals; return/credit/payment dependencies and closed periods cannot be bypassed. Reversal is atomic across all affected lines. No posted journal is edited.

Receipt confirmation accepts the entered quantities into stock; the existing system has no separate inspection/quarantine ledger. Received and accepted stock quantities therefore coincide. Ordered, accepted/received, invoiced, returned, remaining-to-receive and unbilled quantities remain distinct measures; a return does not silently reopen an invoice for billing again.

## Accounting and source integrity

Canonical AP recognition initially posts the existing invoice cost/VAT/AP journal; each approved canonical Inventory MATCH clears its receipt's GRNI and offsets only its allocated invoice cost. The aggregate preview shows the resulting GRNI/VAT/variance/AP entry. This preserves the existing recognition architecture and leaves no duplicate Inventory or Project expense. Price differences follow the existing approved Inventory variance-control policy; this milestone does not introduce a new costing policy.

Immutable Company-scoped `procurement_invoice_lines` records authorize exact receipt/quantity/net/VAT matches. Browser roles cannot insert, change or delete them. Private receipt-group lineage is inaccessible directly. An invoice cannot be capitalized again through another stock receipt, matched to an unapproved receipt, or posted again under another request. Existing Supplier invoice-number uniqueness, receipt uniqueness, GL balancing, moving-average chronology, period locks, actor/membership controls and canonical funding checks remain authoritative. Leading-zero PO line aliases are rejected to preserve cumulative quantity limits. Lost-response retries and independent competing requests are tested.

Returns reference the original receipt and single AP invoice. Credit calculation uses that allocation's original net/VAT and matched quantity, never the full consolidated header amount. Current carrying value still follows canonical moving average. Return, credit, payment and correction histories remain immutable and traceable.

Bilingual Excel/PDF use existing exports. Global posted allocation history includes all lines independently of register pagination, with actual invoice references, receipts, quantities, net, VAT, GRNI and variance. Reversed history is labeled rather than discarded. Operational quantity/commitment reporting remains global.

## Verified isolated results

[Exact evidence](multiline-procurement-verification.json) records the focused assertions and actual local scenarios. Two Materials/two partial deliveries first recognize Inventory200.00 / GRNI200.00. Partial consolidated invoices recognize AP214.20, VAT10.20 and approved variance4.00, fully clearing GRNI without additional stock/cost. A one-unit return of the selected second allocation credits its own22.00 net +1.10VAT; Inventory180.00, AP191.10, VAT9.10, variance2.00 and GRNI0 reconcile.

Two further compatible PO receipts consolidate under one invoice with offsetting individual price differences −1.00/+1.00. Final stock210.00 +variance2.00 +VAT10.60 =AP222.60; GRNI0. A10.00 actual fictional Treasury part-payment settles that invoice without cost/stock recognition; canonical returned-payment correction restores the checkpoint. Incompatible Supplier/Project and cross-Company operations, unapproved variance, missing tax evidence, excess/duplicate quantities, direct line forging and closed-period correction are rejected. Existing private evidence association is verified. Every journal balances.

Native concurrency uses independent PostgreSQL backends with observed lock waits. Actual production React workflows run in local fictional canonical SQL with synthetic Auth transport; they are not a genuine hosted Auth acceptance claim. Arabic/English posting, desktop/mobile layouts, deep links and actual exported workbook/PDF values are verified. Prior CR07, HR and procurement simulation suites were not replayed.

## Boundaries and next action

Up to50 lines/document; one PO per receiving document. One Company, Supplier, currency and Project per consolidated invoice, with multiple POs supported inside that boundary. Mixed-Project invoices require existing allocation architecture to be extended separately; no dimension is dropped. PO base units remain authoritative; alternate-UOM ordering, inspection/quarantine, service receipt conversion, invoice-first business, issued amendments and authorized over-receiving policy remain separate scope. No new tax eligibility facts are inferred.

VERIFIED: supported local business/accounting, security/authorization, additive database preservation, focused accounting/concurrency/UI/export evidence, TypeScript/Production build/lint and documentation. DEFERRED: explicit112 activation/preservation, compatible publication and authorized hosted runtime smoke. NOT APPLICABLE: real business postings, new Company setup, another CR07 cycle or deferred restoration/USB tasks. Entire original commercial roadmap remains preserved.

Migration112 `20261130120000_multiline_procurement.sql` is **PREPARED / NOT APPLIED**. It creates two empty immutable lineage/allocation tables, constrained function extensions and preserves existing grants/RLS. The linked dry-run lists only112. Activate only after explicit Product Owner authorization and focused preservation checks, then publish the compatible release. No push/deploy is automatic.
