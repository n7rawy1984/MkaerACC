# MakerACC — Pre-Demo UAT

This file tracks manual checks intentionally deferred from normal Development slice gates.

These items are **not blockers for continued Development, P6C closeout, or starting P6D**.
They must be reviewed before the first serious external company demo/pilot and again as appropriate before Production.

## P6C Slice 16 residual manual sweep

Automated authorization/security/accounting-integrity coverage is already complete and Slice 16 is Development-closed.

Before external demo/pilot, perform a short real-browser confirmation of:

- ACCOUNTING_ADMIN: Subcontract descriptive edit available.
- PROCUREMENT: Subcontract descriptive edit available.
- ACCOUNTANT: read-only.
- MANAGEMENT_VIEWER: read-only.
- PROJECT_MANAGER: assigned-Project visibility only; no edit.
- DATA_ENTRY: no Subcontract rows.
- SYSTEM_ADMIN: no tenant Subcontract rows.
- Open-form downgrade removes stale edit authority after genuine focus/tab revalidation.
- Membership revocation fails closed and restores correctly.
- Company revocation fails closed and restores correctly.
- Profile revocation fails closed and restores correctly.
- Quick EN/AR/RTL and narrow-screen presentation smoke on current release candidate.

If any defect is found, open a focused regression/fix task. Do not retroactively reopen completed slices unless the defect invalidates an accepted architectural/accounting boundary.

## Later gates

- Pre-demo UAT is separate from feature development verification.
- Production still requires the planned Full Production Security & Accounting Integrity Audit.
- Staging/Production promotion remains separately authorized.


## P6D Expense READ presentation smoke

Non-blocking Development follow-up before external demo/pilot:

- Open production `/expenses` with an existing authorized Company/session.
- Confirm populated and empty states.
- Confirm paging, refresh and tenant switching.
- Confirm EN/AR presentation and readable narrow-screen layout.
- Confirm READ remains immutable; permitted roles see only their supported Treasury POST or Expense reversal controls, with no posted-field edit or payment controls.
- Confirm displayed monetary values remain exact and no stale prior-Company rows survive a tenant switch.

This is presentation/UAT coverage only. P6D Expense READ remains Development-complete.

## P6D Checkpoint 2 Treasury POST smoke

Deferred/non-blocking Development operator follow-up, using an existing authorized session (no new Auth fixture): post one synthetic Treasury-funded Expense with invoice/VAT inputs; confirm server-stored net/VAT/gross and journal reference in refreshed Expense READ; refresh without reposting; check EN/AR and narrow-screen presentation. Confirm denied-role absence of the form. Automated uncertainty/reload/same-key and read-only recovery evidence is in the checkpoint record; do not create a fresh expense to retry an unresolved request. No Staging/Production action is authorized by this checklist.

## P6D Checkpoint 3 Expense Reversal smoke

Deferred/non-blocking Development operator follow-up using an existing ACCOUNTING_ADMIN session and a disposable synthetic POSTED Expense: open the reversal action, confirm the immutable-history warning, enter date/reason, explicitly confirm, and verify authoritative `REVERSED` status plus original and reversal journal links after refresh. Refresh again to confirm no duplicate effect; check EN/AR and narrow-screen presentation. Confirm ACCOUNTANT and every other role has no reversal action. Reversal history is permanent, so do not use a retained business fixture. Never start a new reversal request for an unresolved recovery key. No Staging/Production action is authorized by this checklist.


## P6D Checkpoint 4 Supplier Payment smoke

Deferred/non-blocking Development operator follow-up using an existing ACCOUNTING_ADMIN session and disposable synthetic posted Supplier Credit Expenses: open production `/supplier-payments`; confirm exact outstanding values; post one partial multi-Expense Treasury payment after explicit confirmation; verify the stored payment, allocations, journal reference, and reduced outstanding after refresh; refresh again without duplication; reverse the payment and verify authoritative `REVERSED` status plus restored outstanding. Confirm ACCOUNTANT can post but cannot reverse, MANAGEMENT_VIEWER is read-only, all other roles have no accounting access, and EN/AR/RTL plus narrow-screen presentation remain usable. Never start a new post or reversal request while its recovery key is unresolved. The resulting payment and reversal history is permanent, so use only disposable synthetic liabilities. No Staging/Production action is authorized by this checklist.
