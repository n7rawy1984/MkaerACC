import { Navigate, Route, Routes } from "react-router-dom";
import { useT } from "../i18n/I18nContext";
import { getSupabaseClient } from "../lib/supabase";
import TenantReadyApplication from "../app/TenantReadyApplication";
import { AuthFrame } from "./AuthFrame";
import { AuthProvider, useAuth } from "./AuthContext";
import { AuthErrorPage } from "./AuthErrorPage";
import { CompanySelectPage } from "./CompanySelectPage";
import { LoginPage } from "./LoginPage";
import { NoCompanyPage } from "./NoCompanyPage";
import { SupabaseTenantSettingsProvider } from "../tenant/SupabaseTenantSettingsProvider";
import { ProductionMasterDataProvider } from "../master/ProductionMasterDataProvider";

function LoadingPage() {
  const t = useT();
  return <AuthFrame><p className="text-center text-sm text-slate-600" role="status">{t("auth.loading")}</p></AuthFrame>;
}

function RoutedApplication() {
  const { state, syncCompanyLegalName } = useAuth();
  if (state.phase === "INITIALIZING_AUTH" || state.phase === "LOADING_IDENTITY") return <LoadingPage />;
  if (state.phase === "SIGNED_OUT") return <Routes><Route path="/login" element={<LoginPage />} /><Route path="*" element={<Navigate to="/login" replace />} /></Routes>;
  if (state.phase === "NO_ACTIVE_COMPANY") return <Routes><Route path="/no-company" element={<NoCompanyPage />} /><Route path="*" element={<Navigate to="/no-company" replace />} /></Routes>;
  if (state.phase === "SELECTING_COMPANY") return <Routes><Route path="/select-company" element={<CompanySelectPage />} /><Route path="*" element={<Navigate to="/select-company" replace />} /></Routes>;
  if (state.phase === "IDENTITY_LOAD_ERROR") return <Routes><Route path="/auth-error" element={<AuthErrorPage />} /><Route path="*" element={<Navigate to="/auth-error" replace />} /></Routes>;
  return (
    <SupabaseTenantSettingsProvider key={`${state.profile.userId}:${state.activeTenant.companyId}`} client={getSupabaseClient()} profile={state.profile} tenant={state.activeTenant}>
      <ProductionMasterDataProvider onCompanyProfileRefreshed={syncCompanyLegalName} key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} role={state.activeTenant.role} client={getSupabaseClient()} userId={state.profile.userId} activeCompanyId={state.activeTenant.companyId}>
        <Routes>
          <Route path="/login" element={<Navigate to="/" replace />} />
          <Route path="/no-company" element={<Navigate to="/" replace />} />
          <Route path="/select-company" element={<Navigate to="/" replace />} />
          <Route path="/auth-error" element={<Navigate to="/" replace />} />
          <Route path="/" element={<TenantReadyApplication view="projects" />} />
          <Route path="/company-profile" element={<TenantReadyApplication view="companyProfile" />} />
          <Route path="/projects" element={<TenantReadyApplication view="projects" />} />
          <Route path="/parties" element={<TenantReadyApplication view="parties" />} />
          <Route path="/expense-categories" element={<TenantReadyApplication view="expenseCategories" />} />
          <Route path="/accounts" element={<TenantReadyApplication view="accounts" />} />
          <Route path="/subcontracts" element={<TenantReadyApplication view="subcontracts" />} />
          <Route path="/treasury-accounts" element={<TenantReadyApplication view="treasuryAccounts" />} />
          <Route path="*" element={<TenantReadyApplication view="deferred" />} />
        </Routes>
      </ProductionMasterDataProvider>
    </SupabaseTenantSettingsProvider>
  );
}

export default function ProtectedApplication() {
  const t = useT();
  let client: ReturnType<typeof getSupabaseClient> | null = null;
  try {
    client = getSupabaseClient();
  } catch {
    // Rendered below so React component construction is never inside try/catch.
  }
  if (!client) return <AuthFrame><div role="alert"><h1 className="text-xl font-semibold">{t("auth.configurationErrorTitle")}</h1><p className="mt-3 text-sm leading-6 text-slate-600">{t("auth.configurationError")}</p></div></AuthFrame>;
  return <AuthProvider client={client}><RoutedApplication /></AuthProvider>;
}
