// Decimal-safe money helpers. All arithmetic that must compare exactly
// (like journal balance checks) is done in integer cents so we never rely
// on uncontrolled floating point equality.

export const toCents = (amount: number): number => Math.round(amount * 100);

export const fromCents = (cents: number): number => cents / 100;

export const round2 = (amount: number): number => fromCents(toCents(amount));

export const addMoney = (...amounts: number[]): number =>
  fromCents(amounts.reduce((sum, a) => sum + toCents(a), 0));

export const subtractMoney = (a: number, b: number): number =>
  fromCents(toCents(a) - toCents(b));

export type VatMode = "ZERO" | "MANUAL" | "AUTO_5";

export const VAT_RATE = 0.05;

export interface VatCalcInput {
  netAmount: number;
  vatMode: VatMode;
  manualVatAmount?: number;
}

export interface VatCalcResult {
  netAmount: number;
  vatAmount: number;
  totalAmount: number;
}

export function calcVat({ netAmount, vatMode, manualVatAmount }: VatCalcInput): VatCalcResult {
  const net = round2(netAmount);
  let vat = 0;
  if (vatMode === "AUTO_5") {
    vat = round2(net * VAT_RATE);
  } else if (vatMode === "MANUAL") {
    vat = round2(manualVatAmount ?? 0);
  }
  return { netAmount: net, vatAmount: vat, totalAmount: addMoney(net, vat) };
}

export function formatAED(amount: number): string {
  return new Intl.NumberFormat("en-AE", {
    style: "currency",
    currency: "AED",
    minimumFractionDigits: 2,
    maximumFractionDigits: 2,
  }).format(round2(amount));
}
