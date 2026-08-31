import { useT } from "../i18n/I18nContext";
import { AuthFrame } from "./AuthFrame";
import { useAuth } from "./AuthContext";

export function CompanySelectPage() {
  const t = useT();
  const { state, chooseCompany, signOut } = useAuth();
  if (state.phase !== "SELECTING_COMPANY") return null;
  return (
    <AuthFrame>
      <h1 className="text-2xl font-semibold">{t("auth.selectCompany")}</h1>
      <p className="mt-2 text-sm text-slate-600">{t("auth.selectCompanyHint")}</p>
      <div className="mt-6 space-y-3">
        {state.memberships.map((membership) => (
          <button key={membership.membershipId} type="button" onClick={() => chooseCompany(membership.companyId)} className="flex w-full items-center justify-between rounded-xl border border-slate-200 p-4 text-start hover:border-blue-400 hover:bg-blue-50">
            <span><span className="block font-medium">{membership.companyName}</span><span className="mt-1 block text-xs text-slate-500">{membership.companyCode}</span></span>
            <span className="text-xs text-slate-600">{membership.role}</span>
          </button>
        ))}
      </div>
      <button type="button" onClick={() => void signOut()} className="mt-6 text-sm font-medium text-slate-600 underline">{t("auth.signOut")}</button>
    </AuthFrame>
  );
}
