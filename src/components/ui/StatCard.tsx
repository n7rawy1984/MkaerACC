import type { LucideIcon } from "lucide-react";
import { formatAED } from "../../domain/money";

interface StatCardProps {
  label: string;
  value: number;
  icon: LucideIcon;
  tone?: "default" | "warning" | "danger";
  hint?: string;
  format?: "currency" | "count";
}

const TONE_STYLES: Record<NonNullable<StatCardProps["tone"]>, string> = {
  default: "bg-slate-100 text-slate-600",
  warning: "bg-amber-100 text-amber-700",
  danger: "bg-rose-100 text-rose-700",
};

const TONE_BORDER: Record<NonNullable<StatCardProps["tone"]>, string> = {
  default: "border-slate-200",
  warning: "border-l-4 border-l-amber-400 border-slate-200",
  danger: "border-l-4 border-l-rose-400 border-slate-200",
};

export function StatCard({ label, value, icon: Icon, tone = "default", hint, format = "currency" }: StatCardProps) {
  return (
    <div className={`rounded-xl border bg-white p-5 shadow-sm ${TONE_BORDER[tone]}`}>
      <div className="flex items-start justify-between">
        <p className="text-xs font-medium uppercase tracking-wide text-slate-400">{label}</p>
        <div className={`flex h-8 w-8 items-center justify-center rounded-lg ${TONE_STYLES[tone]}`}>
          <Icon size={16} />
        </div>
      </div>
      <p className="mt-3 text-2xl font-semibold text-slate-900">
        {format === "currency" ? formatAED(value) : value.toLocaleString("en-AE")}
      </p>
      {hint && <p className="mt-1 text-xs text-slate-400">{hint}</p>}
    </div>
  );
}
