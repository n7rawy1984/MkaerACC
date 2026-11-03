import { useContext, useEffect, useState, type ReactNode } from "react";
import { WorkspaceSubscriptionContext, type CompanySubscription as Subscription } from "../workspace/workspaceSubscriptionContext";
import { getSupabaseClient } from "../lib/supabase";
import { useI18n } from "../i18n/I18nContext";

function useSubscriptionRead(companyId: string) {
  const [result, setResult] = useState<{ companyId: string; row: Subscription | null } | null>(null);
  useEffect(() => {
    let alive = true;
    const api = getSupabaseClient() as unknown as { rpc(name: string, args: Record<string, string>): PromiseLike<{ data: unknown; error: unknown }> };
    const load = () => { void Promise.resolve().then(() => api.rpc("get_my_company_subscription", { target_company_id: companyId })).then(({ data, error }) => {
      if (!alive) return;
      const d = data as Subscription | null;
      const valid = !error && d?.company_id === companyId && ["UNMANAGED", "TRIAL", "ACTIVE", "EXPIRED", "CANCELLED", "SCHEDULED"].includes(d.state) && ["FULL", "LIMITED"].includes(d.access);
      setResult({ companyId, row: valid ? d : null });
    }, () => { if (alive) setResult({ companyId, row: null }); }); };
    load(); const timer = window.setInterval(load, 60000); window.addEventListener("focus", load);
    return () => { alive = false; window.clearInterval(timer); window.removeEventListener("focus", load); };
  }, [companyId]);
  return {companyId, loaded: result?.companyId === companyId, row: result?.companyId === companyId ? result.row : null};
}
export function CompanySubscriptionProvider({companyId,children}:{companyId:string;children:ReactNode}) {
  const result=useSubscriptionRead(companyId);
  return <WorkspaceSubscriptionContext.Provider value={result}>{children}</WorkspaceSubscriptionContext.Provider>;
}
function StandaloneStatus({companyId}:{companyId:string}) { const result=useSubscriptionRead(companyId);return result.loaded ? <SubscriptionBanner row={result.row}/> : null; }
export function CompanySubscriptionStatus({companyId}:{companyId:string}) {
  const shared=useContext(WorkspaceSubscriptionContext);
  return shared?.companyId === companyId ? shared.loaded ? <SubscriptionBanner row={shared.row}/> : null : <StandaloneStatus companyId={companyId}/>;
}
function SubscriptionBanner({row}:{row:Subscription|null}) {
  const {locale}=useI18n();
  if (!row) return <p role="status">{locale === "ar" ? "تعذر التحقق من حالة الاشتراك. أعد تحميل الصفحة." : "Subscription status could not be verified. Reload to check."}</p>;
  const states = locale === "ar" ? { UNMANAGED: "غير منضم", TRIAL: "تجريبي", ACTIVE: "نشط", EXPIRED: "منتهٍ", CANCELLED: "ملغى", SCHEDULED: "لم يبدأ" } : { UNMANAGED: "Not enrolled", TRIAL: "Trial", ACTIVE: "Active", EXPIRED: "Expired", CANCELLED: "Cancelled", SCHEDULED: "Not started" };
  return <aside role="status" className="border-b border-slate-200 bg-slate-50 px-6 py-3 text-sm">
    <b>{locale === "ar" ? "الاشتراك: " : "Subscription: "}{row.state === "UNMANAGED" && row.access === "FULL" ? locale === "ar" ? "شركة داخلية" : "Internal company" : states[row.state as keyof typeof states]}</b>
    {row.ends_on && <> · {locale === "ar" ? "صالح حتى: " : "Valid through: "}<bdi dir="ltr">{row.ends_on}</bdi> · {locale === "ar" ? "موعد التجديد: " : "Renewal due: "}<bdi dir="ltr">{row.renewal_due_on}</bdi></>}
    {row.access === "LIMITED" && <p>{locale === "ar" ? "القراءة وتسوية الالتزامات القائمة وعكسها وصيانة بياناتها متاحة حسب الدور. الأعمال الجديدة تحتاج اكتمال التهيئة واشتراكًا صالحًا." : "Reads, existing settlements/reversals and existing-master maintenance remain available under your role. New business requires completed commercial onboarding and an effective subscription."}</p>}
    {row.state === "UNMANAGED" && <p>{row.access === "FULL" ? locale === "ar" ? "وصول الشركة الداخلية القائم متاح دون اشتراك تجاري مطلوب." : "Existing internal Company access remains available; a commercial subscription is not required." : locale === "ar" ? "الإعداد التجاري قيد الاستكمال. تواصل مع مالك المنصة لإتمام التهيئة." : "Commercial setup is pending. Contact the Platform Owner to complete onboarding."}</p>}
  </aside>;
}
