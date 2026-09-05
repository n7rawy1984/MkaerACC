import type { ReactNode } from "react";
import { TenantSettingsPresentationProvider } from "./TenantSettingsContext";

export function DemoTenantSettingsProvider({ children }: { children: ReactNode }) {
  return (
    <TenantSettingsPresentationProvider state={{
      phase: "READY",
      settings: {
        companyId: "company_main",
        tenantSlug: "co-001-company-main",
        appDisplayName: "Contracting Accounts Demo",
        effectiveDisplayName: "Contracting Accounts Demo",
        defaultLocale: "en",
        logoUrl: null,
        faviconUrl: null,
        primaryColor: "#0f172a",
        accentColor: "#2563eb",
      },
    }}>
      {children}
    </TenantSettingsPresentationProvider>
  );
}
