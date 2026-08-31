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

function LoadingPage() {
  const t = useT();
  return <AuthFrame><p className="text-center text-sm text-slate-600" role="status">{t("auth.loading")}</p></AuthFrame>;
}

function RoutedApplication() {
  const { state } = useAuth();
  if (state.phase === "INITIALIZING_AUTH" || state.phase === "LOADING_IDENTITY") return <LoadingPage />;
  if (state.phase === "SIGNED_OUT") return <Routes><Route path="/login" element={<LoginPage />} /><Route path="*" element={<Navigate to="/login" replace />} /></Routes>;
  if (state.phase === "NO_ACTIVE_COMPANY") return <Routes><Route path="/no-company" element={<NoCompanyPage />} /><Route path="*" element={<Navigate to="/no-company" replace />} /></Routes>;
  if (state.phase === "SELECTING_COMPANY") return <Routes><Route path="/select-company" element={<CompanySelectPage />} /><Route path="*" element={<Navigate to="/select-company" replace />} /></Routes>;
  if (state.phase === "IDENTITY_LOAD_ERROR") return <Routes><Route path="/auth-error" element={<AuthErrorPage />} /><Route path="*" element={<Navigate to="/auth-error" replace />} /></Routes>;
  return <Routes><Route path="/login" element={<Navigate to="/" replace />} /><Route path="*" element={<TenantReadyApplication />} /></Routes>;
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
