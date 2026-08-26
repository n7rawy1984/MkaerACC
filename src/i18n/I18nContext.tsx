import { createContext, useCallback, useContext, useEffect, useMemo, useState, type ReactNode } from "react";
import en, { type TranslationKey } from "./en";
import ar from "./ar";

export type Locale = "en" | "ar";

const DICTIONARIES: Record<Locale, Record<TranslationKey, string>> = { en, ar };

// Same "cas:v1:" prefix convention as every other localStorage key in this app (see
// storage/storageDriver.ts) even though locale isn't a domain repository — it's a user
// preference, not accounting data, but keeping it under one namespace avoids key collisions
// and makes "what does this app store in localStorage" answerable in one place.
const LOCALE_STORAGE_KEY = "cas:v1:locale";

function readStoredLocale(): Locale {
  try {
    const raw = window.localStorage.getItem(LOCALE_STORAGE_KEY);
    return raw === "ar" ? "ar" : "en";
  } catch {
    return "en";
  }
}

/** Fills `{placeholder}` tokens in a translated string from `vars`. Any token without a
 * matching var is left as-is rather than silently dropped, so a missing var is obvious in the UI
 * instead of producing a subtly wrong sentence. */
function interpolate(template: string, vars?: Record<string, string | number>): string {
  if (!vars) return template;
  return template.replace(/\{(\w+)\}/g, (match, key: string) => {
    const value = vars[key];
    return value === undefined ? match : String(value);
  });
}

interface I18nContextValue {
  locale: Locale;
  setLocale: (locale: Locale) => void;
  dir: "ltr" | "rtl";
  t: (key: TranslationKey, vars?: Record<string, string | number>) => string;
}

const I18nContext = createContext<I18nContextValue | null>(null);

export function I18nProvider({ children }: { children: ReactNode }) {
  const [locale, setLocaleState] = useState<Locale>(readStoredLocale);
  const dir = locale === "ar" ? "rtl" : "ltr";

  useEffect(() => {
    document.documentElement.lang = locale;
    document.documentElement.dir = dir;
  }, [locale, dir]);

  const setLocale = useCallback((next: Locale) => {
    setLocaleState(next);
    try {
      window.localStorage.setItem(LOCALE_STORAGE_KEY, next);
    } catch {
      // localStorage can throw in private-browsing/quota-exceeded edge cases — the in-memory
      // locale switch above already succeeded, only persistence across reloads is lost.
    }
  }, []);

  const t = useCallback(
    (key: TranslationKey, vars?: Record<string, string | number>) => {
      const dictionary = DICTIONARIES[locale];
      // Falls back to English if a key is somehow missing from the active dictionary at
      // runtime — ar.ts's Record<TranslationKey, string> type already guarantees this never
      // happens for a build that typechecks, but this keeps a stale/partial bundle from crashing.
      const template = dictionary[key] ?? en[key] ?? key;
      return interpolate(template, vars);
    },
    [locale],
  );

  const value = useMemo<I18nContextValue>(() => ({ locale, setLocale, dir, t }), [locale, setLocale, dir, t]);

  return <I18nContext.Provider value={value}>{children}</I18nContext.Provider>;
}

export function useI18n(): I18nContextValue {
  const ctx = useContext(I18nContext);
  if (!ctx) throw new Error("useI18n must be used within I18nProvider");
  return ctx;
}

/** Convenience hook for components that only need the translate function. */
export function useT(): I18nContextValue["t"] {
  return useI18n().t;
}
