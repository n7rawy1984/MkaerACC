import type { ReactNode } from "react";

type BadgeTone = "slate" | "green" | "amber" | "red" | "blue" | "pending";

const TONE_STYLES: Record<BadgeTone, string> = {
  slate: "bg-slate-100 text-slate-600",
  green: "bg-emerald-100 text-emerald-700",
  amber: "bg-amber-100 text-amber-700",
  red: "bg-rose-100 text-rose-700",
  blue: "bg-blue-100 text-blue-700",
  pending: "",
};

export function Badge({ children, tone = "slate" }: { children: ReactNode; tone?: BadgeTone }) {
  return (
    <span
      className={`inline-flex items-center rounded-full px-2.5 py-0.5 text-xs font-medium ${TONE_STYLES[tone]} erp-badge erp-badge-${({slate:"neutral",green:"success",amber:"warning",red:"danger",blue:"info",pending:"pending"} as const)[tone]}`}
    >
      {children}
    </span>
  );
}
