import type { Locale } from "../i18n/I18nContext";

export const PLATFORM_PRESENTATION = {
  displayName: "Contracting Accounts",
  faviconUrl: "/favicon.svg",
  primaryColor: "#087E68",
  accentColor: "#076B59",
} as const;

export interface TenantSettings {
  companyId: string;
  tenantSlug: string;
  appDisplayName: string | null;
  effectiveDisplayName: string;
  defaultLocale: Locale;
  logoUrl: string | null;
  faviconUrl: string | null;
  primaryColor: string;
  accentColor: string;
}

export type TenantSettingsState =
  | { phase: "LOADING" }
  | { phase: "READY"; settings: TenantSettings }
  | { phase: "MISSING" }
  | { phase: "ERROR" };
