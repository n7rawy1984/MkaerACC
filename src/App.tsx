import { lazy, Suspense } from "react";
import { useT } from "./i18n/I18nContext";

const DemoApplication = lazy(() => import("./app/DemoApplication"));
const ProtectedApplication = lazy(() => import("./auth/ProtectedApplication"));

type AppMode = "local-demo" | "supabase-auth";

function resolveAppMode(): { mode: AppMode | null; error: boolean } {
  const configuredMode = import.meta.env.VITE_APP_DATA_MODE;
  if (configuredMode === "supabase-auth") return { mode: configuredMode, error: false };
  if (configuredMode === "local-demo" && import.meta.env.DEV) return { mode: configuredMode, error: false };
  return { mode: null, error: true };
}

function AppLoading() {
  const t = useT();
  return <main className="flex min-h-screen items-center justify-center p-6"><p className="text-sm text-slate-600" role="status">{t("auth.loading")}</p></main>;
}

function ConfigurationError() {
  const t = useT();
  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <section className="w-full max-w-lg rounded-2xl border border-red-200 bg-white p-8 shadow-sm" role="alert">
        <h1 className="text-xl font-semibold text-slate-900">{t("auth.configurationErrorTitle")}</h1>
        <p className="mt-3 text-sm leading-6 text-slate-600">{t("auth.configurationError")}</p>
      </section>
    </main>
  );
}

export default function App() {
  const resolved = resolveAppMode();
  if (resolved.error || !resolved.mode) return <ConfigurationError />;

  return (
    <Suspense fallback={<AppLoading />}>
      {resolved.mode === "local-demo" ? <DemoApplication /> : <ProtectedApplication />}
    </Suspense>
  );
}
