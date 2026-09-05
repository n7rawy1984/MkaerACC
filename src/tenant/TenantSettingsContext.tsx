/* oxlint-disable react/only-export-components -- provider and hook form one presentation boundary */
import { createContext, useContext, useEffect, type ReactNode } from "react";
import { PLATFORM_PRESENTATION, type TenantSettings, type TenantSettingsState } from "./tenantSettings";

const TenantSettingsContext = createContext<TenantSettingsState>({ phase: "MISSING" });

function applyPresentation(settings: TenantSettings | null) {
  const root = document.documentElement;
  root.style.setProperty("--tenant-primary", settings?.primaryColor ?? PLATFORM_PRESENTATION.primaryColor);
  root.style.setProperty("--tenant-accent", settings?.accentColor ?? PLATFORM_PRESENTATION.accentColor);
  document.title = settings?.effectiveDisplayName ?? PLATFORM_PRESENTATION.displayName;

  let favicon = document.querySelector<HTMLLinkElement>('link[rel="icon"]');
  if (!favicon) {
    favicon = document.createElement("link");
    favicon.rel = "icon";
    document.head.append(favicon);
  }
  favicon.href = settings?.faviconUrl ?? PLATFORM_PRESENTATION.faviconUrl;
}

export function resetTenantPresentation() {
  applyPresentation(null);
}

export function TenantSettingsPresentationProvider({ state, children }: { state: TenantSettingsState; children: ReactNode }) {
  const settings = state.phase === "READY" ? state.settings : null;
  useEffect(() => {
    applyPresentation(settings);
    return resetTenantPresentation;
  }, [settings]);
  return <TenantSettingsContext.Provider value={state}>{children}</TenantSettingsContext.Provider>;
}

export function useTenantSettings(): TenantSettingsState {
  return useContext(TenantSettingsContext);
}
