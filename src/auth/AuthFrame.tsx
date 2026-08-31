import type { ReactNode } from "react";
import { useI18n } from "../i18n/I18nContext";

export function LanguageButton() {
  const { locale, setLocale } = useI18n();
  return (
    <button type="button" onClick={() => setLocale(locale === "en" ? "ar" : "en")} className="rounded-lg border border-slate-300 px-3 py-2 text-sm font-medium hover:bg-slate-50">
      {locale === "en" ? "العربية" : "English"}
    </button>
  );
}

export function AuthFrame({ children }: { children: ReactNode }) {
  return (
    <main className="flex min-h-screen items-center justify-center p-6">
      <div className="w-full max-w-lg">
        <div className="mb-4 flex justify-end"><LanguageButton /></div>
        <section className="rounded-2xl border border-slate-200 bg-white p-8 shadow-sm">{children}</section>
      </div>
    </main>
  );
}
