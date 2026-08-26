import { Info } from "lucide-react";
import { useT } from "../../i18n/I18nContext";

export function DemoDataBadge() {
  const t = useT();
  return (
    <span
      title={t("dashboard.demoDataExplanation")}
      className="inline-flex cursor-default items-center gap-1.5 rounded-full border border-amber-200 bg-amber-50 px-3 py-1.5 text-xs font-medium text-amber-800"
    >
      <Info size={13} />
      {t("dashboard.demoDataBadge")}
    </span>
  );
}
