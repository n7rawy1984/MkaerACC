// Presentation only. Never infer day/month order, derive a date from source_month,
// or change an imported/reviewed value. Non-ISO input requires source evidence.
export function sourceDatePresentation(value: string | null | undefined, locale: "en" | "ar") {
  const raw = value ?? "";
  const unknown = !raw;
  const valid = /^\d{4}-\d{2}-\d{2}$/.test(raw) && !raw.startsWith("0000-")
    && Number.isFinite(Date.parse(raw + "T00:00:00Z"))
    && new Date(raw + "T00:00:00Z").toISOString().slice(0, 10) === raw;
  if (!valid) return {
    status: unknown ? "UNKNOWN" as const : "UNRESOLVED" as const,
    iso: null,
    label: unknown ? locale === "ar" ? "غير معروف" : "Unknown"
      : `${raw} — ${locale === "ar" ? "تاريخ ملتبس أو غير صالح؛ راجع المصدر" : "Ambiguous or invalid date; verify source"}`,
  };
  const named = new Intl.DateTimeFormat(locale === "ar" ? "ar-AE" : "en-GB", {
    day: "2-digit", month: "long", year: "numeric", calendar: "gregory", timeZone: "UTC",
  }).format(new Date(raw + "T00:00:00Z"));
  return { status: "KNOWN" as const, iso: raw, label: `${raw} · ${named}` };
}
