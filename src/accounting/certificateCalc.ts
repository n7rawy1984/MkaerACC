// Pure, decimal-safe calculation for subcontractor progress certificates.
// Shared by the certificate form (live preview) and the approval posting
// logic, so the number the user reviews is exactly the number that gets
// posted — see PART C1 of the Phase 2A spec for the waterfall this encodes:
//
//   Work Value To Date - Previous Certified = Current Work
//   Current Work + Current Variations       = Gross Current Certificate
//   Gross - Retention - Advance Recovery - Deductions = Net Before VAT
//   Net Before VAT + VAT                    = Net Payable

import { addMoney, calcVat, round2, subtractMoney, type VatMode } from "../domain/money";

export interface CertificateCalcInput {
  workValueToDate: number;
  previousCertifiedWork: number;
  currentVariationAmount: number;
  retentionPercent: number;
  advanceRecovery: number;
  deductionAmounts: number[];
  vatMode: VatMode;
  manualVatAmount?: number;
}

export interface CertificateCalcResult {
  currentWorkValue: number;
  grossCurrentValue: number;
  retentionAmount: number;
  totalDeductions: number;
  netBeforeVat: number;
  vatAmount: number;
  netPayable: number;
}

/** Computes every derived figure. Does not clamp negatives — validateCertificate surfaces those as errors instead of hiding them. */
export function calcCertificate(input: CertificateCalcInput): CertificateCalcResult {
  const currentWorkValue = subtractMoney(input.workValueToDate, input.previousCertifiedWork);
  const grossCurrentValue = addMoney(currentWorkValue, input.currentVariationAmount);
  const retentionAmount = round2(grossCurrentValue * (input.retentionPercent / 100));
  const totalDeductions = input.deductionAmounts.reduce((sum, a) => addMoney(sum, a), 0);
  const netBeforeVat = subtractMoney(
    subtractMoney(subtractMoney(grossCurrentValue, retentionAmount), input.advanceRecovery),
    totalDeductions,
  );
  const vat = calcVat({ netAmount: netBeforeVat, vatMode: input.vatMode, manualVatAmount: input.manualVatAmount });

  return {
    currentWorkValue,
    grossCurrentValue,
    retentionAmount,
    totalDeductions,
    netBeforeVat,
    vatAmount: vat.vatAmount,
    netPayable: vat.totalAmount,
  };
}

export interface CertificateValidationContext {
  revisedContractValue: number;
  availableAdvanceBalance: number;
  deductionAmounts: number[];
  taxInvoiceReceived: boolean;
  taxInvoiceNumber?: string;
  taxInvoiceDate?: string;
}

/** All PART J guards that depend on the certificate's own numbers (guards 1, 2, 3, 5, 6) plus
 * the advance-recovery ceiling (guard 4) and the VAT tax-invoice requirement. Referential
 * integrity (guard 9), duplicate approval (7/8) and journal balance (10) are enforced elsewhere. */
export function validateCertificate(
  input: CertificateCalcInput,
  result: CertificateCalcResult,
  ctx: CertificateValidationContext,
): Record<string, string> {
  const errors: Record<string, string> = {};

  if (result.currentWorkValue < 0) {
    errors.workValueToDate = "Work value to date cannot be less than previously certified work";
  }

  const excess = subtractMoney(input.workValueToDate, ctx.revisedContractValue);
  if (excess > 0.01 && input.currentVariationAmount < excess - 0.01) {
    errors.currentVariationAmount =
      "Certified-to-date exceeds the revised contract value — add a variation to cover the difference";
  }

  if (input.retentionPercent < 0 || input.retentionPercent > 100) {
    errors.retentionPercent = "Retention percent must be between 0 and 100";
  }
  if (result.retentionAmount < 0) {
    errors.retentionPercent = "Retention cannot be negative";
  }

  if (input.advanceRecovery < 0) {
    errors.advanceRecovery = "Advance recovery cannot be negative";
  } else if (input.advanceRecovery > ctx.availableAdvanceBalance + 0.01) {
    errors.advanceRecovery = `Cannot recover more than the available advance balance (${ctx.availableAdvanceBalance.toFixed(2)})`;
  }

  ctx.deductionAmounts.forEach((amount, i) => {
    if (amount < 0) errors[`deduction_${i}`] = "Deduction amount cannot be negative";
  });

  if (result.netPayable < 0) {
    errors.netPayable = "Net payable cannot be negative — reduce retention, recovery, or deductions";
  }

  if (result.vatAmount > 0) {
    if (!ctx.taxInvoiceReceived) {
      errors.taxInvoiceReceived = "VAT requires a supplier tax invoice to be on file";
    }
    if (!ctx.taxInvoiceNumber?.trim()) {
      errors.taxInvoiceNumber = "Tax invoice number is required when VAT is charged";
    }
    if (!ctx.taxInvoiceDate) {
      errors.taxInvoiceDate = "Tax invoice date is required when VAT is charged";
    }
  }

  return errors;
}
