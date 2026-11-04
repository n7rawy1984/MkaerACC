import { CompanyWorkspaceShell } from "../workspace/CompanyWorkspaceShell";
import { AccountingCycle } from "../workspace/AccountingCycle";
import { WorkspaceReports } from "../workspace/WorkspaceReports";
import { CompanySubscriptionProvider, CompanySubscriptionStatus } from "../master/CompanySubscriptionStatus";
import PayrollApplication from "../payroll/PayrollApplication";
import AttendanceApplication from "../attendance/AttendanceApplication";
import { Navigate, Route, Routes, useLocation } from "react-router-dom";
import PlatformApplication from "../platform/PlatformApplication";
import AuthCallback from "../platform/AuthCallback";
import RecoveryRequest from "../platform/RecoveryRequest";
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
  const location = useLocation();
  // Platform authority and invitation completion do not depend on Company membership.
  const callbackParams = new URLSearchParams(location.search);
  const callbackFragment = new URLSearchParams(location.hash.slice(1));
  const recoveryLanding = ["token_hash", "code", "error", "error_code", "error_description"].some(key => callbackParams.has(key)) || callbackParams.get("type") === "recovery" || ["access_token", "refresh_token", "error", "type"].some(key => callbackFragment.has(key));
  if (location.pathname === "/auth/callback" || recoveryLanding) return <AuthCallback client={getSupabaseClient()} />;
  if (location.pathname === "/auth/recovery") return <RecoveryRequest client={getSupabaseClient()} />;
  if (location.pathname === "/platform" || location.pathname.startsWith("/platform/")) return <PlatformApplication client={getSupabaseClient()} />;
  if (state.phase === "INITIALIZING_AUTH" || state.phase === "LOADING_IDENTITY") return <LoadingPage />;
  if (state.phase === "SIGNED_OUT") return <Routes><Route path="/login" element={<LoginPage />} /><Route path="*" element={<Navigate to="/login" replace />} /></Routes>;
  if (state.phase === "NO_ACTIVE_COMPANY") return <Routes><Route path="/no-company" element={<NoCompanyPage />} /><Route path="*" element={<Navigate to="/no-company" replace />} /></Routes>;
  if (state.phase === "SELECTING_COMPANY") return <Routes><Route path="/select-company" element={<CompanySelectPage />} /><Route path="*" element={<Navigate to="/select-company" replace />} /></Routes>;
  if (state.phase === "IDENTITY_LOAD_ERROR") return <Routes><Route path="/auth-error" element={<AuthErrorPage />} /><Route path="*" element={<Navigate to="/auth-error" replace />} /></Routes>;
  if (state.activeTenant.role === "FOREMAN") return <><CompanySubscriptionStatus key={`${state.profile.userId}:${state.activeTenant.companyId}`} companyId={state.activeTenant.companyId} /><Routes><Route path="/attendance" element={<AttendanceApplication />} /><Route path="*" element={<Navigate to="/attendance" replace />} /></Routes></>;
  return (
    <SupabaseTenantSettingsProvider key={`${state.profile.userId}:${state.activeTenant.companyId}`} client={getSupabaseClient()} profile={state.profile} tenant={state.activeTenant}>
      <ProductionMasterDataProvider onCompanyProfileRefreshed={syncCompanyLegalName} key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} role={state.activeTenant.role} client={getSupabaseClient()} userId={state.profile.userId} activeCompanyId={state.activeTenant.companyId}>
        <CompanySubscriptionProvider key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`} companyId={state.activeTenant.companyId}>
        <CompanyWorkspaceShell><Routes>
          <Route path="/payroll" element={<PayrollApplication embedded />} />
          <Route path="/attendance" element={<AttendanceApplication embedded />} />
          <Route path="/accounting-cycle" element={<AccountingCycle />} />
          <Route path="/accounting-reports" element={<WorkspaceReports />} />
          <Route path="/login" element={<Navigate to="/" replace />} />
          <Route path="/no-company" element={<Navigate to="/" replace />} />
          <Route path="/select-company" element={<Navigate to="/" replace />} />
          <Route path="/auth-error" element={<Navigate to="/" replace />} />
          <Route path="/" element={<TenantReadyApplication view="dashboard" />} />
          <Route path="/company-profile" element={<TenantReadyApplication view="companyProfile" />} />
          <Route path="/projects" element={<TenantReadyApplication view="projects" />} />
          <Route path="/parties" element={<TenantReadyApplication view="parties" />} />
          <Route path="/historical-imports" element={<Navigate to="/expenses" replace />} />
          <Route path="/expenses" element={<TenantReadyApplication view="expenses" />} />
          <Route path="/supplier-payments" element={<TenantReadyApplication view="supplierPayments" />} />
          <Route path="/subcontractor-advances" element={<TenantReadyApplication view="subcontractorAdvances" />} />
          <Route path="/subcontractor-certificates" element={<TenantReadyApplication view="subcontractorCertificates" />} />
          <Route path="/subcontractor-payments" element={<TenantReadyApplication view="subcontractorPayments" />} />
          <Route path="/retention-releases" element={<TenantReadyApplication view="retentionReleases" />} />
          <Route path="/retention-payments" element={<TenantReadyApplication view="retentionPayments" />} />
          <Route path="/expense-categories" element={<TenantReadyApplication view="expenseCategories" />} />
          <Route path="/accounts" element={<TenantReadyApplication view="accounts" />} />
          <Route path="/subcontracts" element={<TenantReadyApplication view="subcontracts" />} />
          <Route path="/financial-evidence" element={<TenantReadyApplication view="financialEvidence" />} />
          <Route path="/custody" element={<TenantReadyApplication view="custody" />} />
          <Route path="/treasury-accounts" element={<TenantReadyApplication view="treasuryAccounts" />} />
          <Route path="*" element={<TenantReadyApplication view="deferred" />} />
        </Routes></CompanyWorkspaceShell>
        </CompanySubscriptionProvider>
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
