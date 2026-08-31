import { useT } from "../i18n/I18nContext";
import { AuthFrame } from "./AuthFrame";
import { useAuth } from "./AuthContext";

export function AuthErrorPage() {
  const t = useT();
  const { retry, signOut } = useAuth();
  return (
    <AuthFrame>
      <h1 className="text-2xl font-semibold">{t("auth.identityErrorTitle")}</h1>
      <p className="mt-3 text-sm leading-6 text-slate-600">{t("auth.identityError")}</p>
      <div className="mt-6 flex gap-3">
        <button type="button" onClick={retry} className="rounded-lg bg-blue-700 px-4 py-2 text-sm font-medium text-white">{t("auth.retry")}</button>
        <button type="button" onClick={() => void signOut()} className="rounded-lg border border-slate-300 px-4 py-2 text-sm font-medium">{t("auth.signOut")}</button>
      </div>
    </AuthFrame>
  );
}
