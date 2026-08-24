import { NavLink } from "react-router-dom";
import {
  LayoutDashboard,
  Building2,
  Receipt,
  Wallet,
  Truck,
  Users,
  BookText,
  HardHat,
  Hammer,
  RotateCcw,
} from "lucide-react";
import { resetDemoData } from "../../seed/seedData";

const NAV_ITEMS = [
  { to: "/", label: "Dashboard", icon: LayoutDashboard, end: true },
  { to: "/projects", label: "Projects", icon: Building2 },
  { to: "/expenses", label: "Expenses", icon: Receipt },
  { to: "/advances", label: "Advances & Settlements", icon: Wallet },
  { to: "/suppliers", label: "Suppliers", icon: Truck },
  { to: "/subcontractors", label: "Subcontractors", icon: Hammer },
  { to: "/people", label: "Owners & Custodians", icon: Users },
  { to: "/journal", label: "Journal", icon: BookText },
];

function handleResetDemoData() {
  const confirmed = window.confirm(
    "Reset demo data?\n\nThis will erase everything entered in this browser and reload the original sample transactions. This cannot be undone.",
  );
  if (!confirmed) return;
  resetDemoData();
  window.location.href = "/";
}

export function Sidebar() {
  return (
    <aside className="flex h-screen w-64 shrink-0 flex-col border-r border-slate-200 bg-white">
      <div className="flex items-center gap-2.5 px-5 py-5 border-b border-slate-100">
        <div className="flex h-9 w-9 items-center justify-center rounded-lg bg-slate-900 text-white">
          <HardHat size={18} />
        </div>
        <div className="leading-tight">
          <p className="text-sm font-semibold text-slate-900">Contracting Accounts</p>
          <p className="text-xs text-slate-400">Control System</p>
        </div>
      </div>

      <nav className="flex-1 space-y-1 px-3 py-4">
        {NAV_ITEMS.map(({ to, label, icon: Icon, end }) => (
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
            {label}
          </NavLink>
        ))}
      </nav>

      <div className="border-t border-slate-100 px-5 py-4">
        <p className="text-xs text-slate-400">Currency: AED</p>
        <p className="text-xs text-slate-400">Data stored on this device</p>
        <button
          type="button"
          onClick={handleResetDemoData}
          className="mt-3 flex items-center gap-1.5 text-xs font-medium text-slate-400 hover:text-slate-600"
        >
          <RotateCcw size={12} /> Reset Demo Data
        </button>
      </div>
    </aside>
  );
}
