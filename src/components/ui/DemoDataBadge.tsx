import { Info } from "lucide-react";

const EXPLANATION =
  "Sample historical transactions loaded for system demonstration. These are not approved opening balances.";

export function DemoDataBadge() {
  return (
    <span
      title={EXPLANATION}
      className="inline-flex cursor-default items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800"
    >
      <Info size={13} />
      Demo Historical Data
    </span>
  );
}
