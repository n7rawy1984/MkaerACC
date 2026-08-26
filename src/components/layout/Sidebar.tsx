import { NavLink } from "react-router-dom";
import {
  LayoutDashboard,
  Briefcase,
  Building2,
  Landmark,
  Receipt,
  Wallet,
  Truck,
  Users,
  BookText,
  HardHat,
  Hammer,
  RotateCcw,
  Languages,
} from "lucide-react";
import { resetDemoData } from "../../seed/seedData";
import { useI18n, type Locale } from "../../i18n/I18nContext";
import type { TranslationKey } from "../../i18n/en";

const NAV_ITEMS: { to: string; labelKey: TranslationKey; icon: typeof LayoutDashboard; end?: boolean }[] = [
  { to: "/", labelKey: "nav.dashboard", icon: LayoutDashboard, end: true },
  { to: "/company", labelKey: "nav.company", icon: Briefcase },
  { to: "/projects", labelKey: "nav.projects", icon: Building2 },
  { to: "/treasury", labelKey: "nav.treasury", icon: Landmark },
  { to: "/expenses", labelKey: "nav.expenses", icon: Receipt },
  { to: "/advances", labelKey: "nav.advances", icon: Wallet },
  { to: "/suppliers", labelKey: "nav.suppliers", icon: Truck },
  { to: "/subcontractors", labelKey: "nav.subcontractors", icon: Hammer },
  { to: "/people", labelKey: "nav.people", icon: Users },
  { to: "/journal", labelKey: "nav.journal", icon: BookText },
];

export function Sidebar() {
  const { t, locale, setLocale } = useI18n();

  function handleResetDemoData() {
    const confirmed = window.confirm(t("sidebar.resetConfirm"));
    if (!confirmed) return;
    resetDemoData();
    window.location.href = "/";
  }

  return (
    <aside className="flex h-screen w-64 shrink-0 flex-col border-e border-slate-200 bg-white">
      <div className="flex items-center gap-2.5 px-5 py-5 border-b border-slate-100">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-900 text-white">
          <HardHat size={18} />
        </div>
        <div className="leading-tight">
          <p className="text-sm font-semibold text-slate-900">{t("app.title")}</p>
          <p className="text-xs text-slate-400">{t("app.subtitle")}</p>
        </div>
      </div>

      <nav className="flex-1 space-y-1 px-3 py-4">
        {NAV_ITEMS.map(({ to, labelKey, icon: Icon, end }) => (
          <NavLink
            key={to}
            to={to}
            end={end}
            className={({ isActive }) =>
              [
                "flex items-center gap-3 rounded-lg px-3 py-2.5 text-sm font-medium transition-colors",
                isActive
                  ? "bg-slate-900 text-white"
                  : "text-slate-600 hover:bg-slate-100 hover:text-slate-900",
              ].join(" ")
            }
          >
            <Icon size={17} strokeWidth={2} />
            {t(labelKey)}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-slate-100 px-5 py-4">
        <div className="mb-3 flex items-center gap-1.5">
          <Languages size={13} className="text-slate-400" />
          <div className="flex overflow-hidden rounded-md border border-slate-200 text-xs font-medium">
            {(["en", "ar"] as Locale[]).map((option) => (
              <button
                key={option}
                type="button"
                onClick={() => setLocale(option)}
                aria-pressed={locale === option}
                className={
                  locale === option
                    ? "bg-slate-900 px-2.5 py-1 text-white"
                    : "bg-white px-2.5 py-1 text-slate-500 hover:bg-slate-50"
                }
              >
                {option === "en" ? "EN" : "عربي"}
              </button>
            ))}
          </div>
        </div>
        <p className="text-xs text-slate-400">{t("sidebar.currency")}</p>
        <p className="text-xs text-slate-400">{t("sidebar.dataStoredLocally")}</p>
        <button
          type="button"
          onClick={handleResetDemoData}
          className="mt-3 flex items-center gap-1.5 text-xs font-medium text-slate-400 hover:text-slate-600"
        >
          <RotateCcw size={12} /> {t("sidebar.resetDemoData")}
        </button>
      </div>
    </aside>
  );
}
