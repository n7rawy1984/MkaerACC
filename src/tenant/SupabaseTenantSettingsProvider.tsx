import { useEffect, useRef, useState, type ReactNode } from "react";
import type { SupabaseClient } from "@supabase/supabase-js";
import type { Database } from "../types/database.generated";
import type { AuthProfile, TenantMembership } from "../auth/authTypes";
import { useI18n } from "../i18n/I18nContext";
import { resetTenantPresentation, TenantSettingsPresentationProvider } from "./TenantSettingsContext";
import type { TenantSettingsState } from "./tenantSettings";

export function SupabaseTenantSettingsProvider({ client, profile, tenant, children }: {
  client: SupabaseClient<Database>;
  profile: AuthProfile;
  tenant: TenantMembership;
  children: ReactNode;
}) {
  const [state, setState] = useState<TenantSettingsState>({ phase: "LOADING" });
  const requestRef = useRef(0);
  const { applyLocaleDefault } = useI18n();

  useEffect(() => {
    const request = ++requestRef.current;
    let active = true;
    resetTenantPresentation();
    const load = async () => {
      const { data: sessionData } = await client.auth.getSession();
      if (!active || requestRef.current !== request || sessionData.session?.user.id !== profile.userId) return;
      const { data, error } = await client
        .from("company_settings")
        .select("company_id, tenant_slug, app_display_name, default_locale, logo_url, favicon_url, primary_color, accent_color")
        .eq("company_id", tenant.companyId)
        .maybeSingle();
      const { data: liveSession } = await client.auth.getSession();
      if (!active || requestRef.current !== request || liveSession.session?.user.id !== profile.userId) return;
      if (error) {
        setState({ phase: "ERROR" });
        return;
      }
      if (!data || data.company_id !== tenant.companyId) {
        setState({ phase: "MISSING" });
        return;
      }
      applyLocaleDefault(profile.locale ?? data.default_locale);
      setState({
        phase: "READY",
        settings: {
          companyId: data.company_id,
          tenantSlug: data.tenant_slug,
          appDisplayName: data.app_display_name,
          effectiveDisplayName: data.app_display_name ?? tenant.companyName,
          defaultLocale: data.default_locale,
          logoUrl: data.logo_url,
          faviconUrl: data.favicon_url,
          primaryColor: data.primary_color,
          accentColor: data.accent_color,
        },
      });
    };
    void load();
    return () => {
      active = false;
      requestRef.current += 1;
      resetTenantPresentation();
    };
  }, [applyLocaleDefault, client, profile.locale, profile.userId, tenant.companyId, tenant.companyName]);

  return <TenantSettingsPresentationProvider state={state}>{children}</TenantSettingsPresentationProvider>;
}
