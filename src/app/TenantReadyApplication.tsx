import { LanguageButton } from "../auth/AuthFrame";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { useTenantSettings } from "../tenant/TenantSettingsContext";
import { TenantBrandMark } from "../tenant/TenantBrandMark";

export default function TenantReadyApplication() {
  const t = useT();
  const { state, showCompanySelector, signOut } = useAuth();
  const tenantSettings = useTenantSettings();
  if (state.phase !== "TENANT_READY") return null;
  return (
    <div className="min-h-screen bg-slate-50">
      <header className="border-b border-slate-200 bg-white">
        <div className="mx-auto flex max-w-6xl flex-wrap items-center justify-between gap-4 px-6 py-4">
          <div className="flex items-center gap-3">
            <TenantBrandMark logoUrl={tenantSettings.phase === "READY" ? tenantSettings.settings.logoUrl : null} />
            <div><p className="text-xs font-medium uppercase tracking-wide text-slate-500">{t("auth.activeCompany")}</p><h1 className="text-lg font-semibold">{tenantSettings.phase === "READY" ? tenantSettings.settings.effectiveDisplayName : state.activeTenant.companyName}</h1><p className="text-xs text-slate-500">{state.activeTenant.companyLegalName ?? state.activeTenant.companyName}</p></div>
          </div>
          <div className="flex flex-wrap items-center gap-2">
            <span className="rounded-lg bg-slate-100 px-3 py-2 text-sm"><span className="text-slate-500">{t("auth.role")}:</span> {state.activeTenant.role}</span>
            {state.memberships.length > 1 && <button type="button" onClick={showCompanySelector} className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium">{t("auth.switchCompany")}</button>}
            <LanguageButton />
            <button type="button" onClick={() => void signOut()} className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium">{t("auth.signOut")}</button>
          </div>
        </div>
      </header>
      <main className="mx-auto max-w-4xl px-6 py-16">
        {(tenantSettings.phase === "MISSING" || tenantSettings.phase === "ERROR") && <p role="alert" className="mb-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">{t("auth.tenantSettingsUnavailable")}</p>}
        {tenantSettings.phase === "LOADING" && <p role="status" className="mb-4 text-sm text-slate-500">{t("auth.loadingTenantSettings")}</p>}
        <section className="rounded-2xl border border-[var(--tenant-accent)] bg-white p-8 shadow-sm">
          <h2 className="text-2xl font-semibold">{t("auth.tenantReadyTitle")}</h2>
          <p className="mt-3 leading-7 text-slate-600">{t("auth.cutoverPending")}</p>
        </section>
      </main>
    </div>
  );
}
