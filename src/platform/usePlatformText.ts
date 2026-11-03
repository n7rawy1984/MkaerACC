import { useI18n } from "../i18n/I18nContext";
import { platformText, type PlatformTextKey } from "./platformText";

export function usePlatformText() { const { locale } = useI18n(); return (key: PlatformTextKey) => platformText[locale][key]; }
