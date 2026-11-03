import { useEffect, useState } from "react";
import { getSupabaseClient } from "../lib/supabase";
import { useI18n } from "../i18n/I18nContext";

// This status read never provisions and is remounted on Company/identity changes.
export function CompanyAccountingSetupStatus({ companyId }: { companyId: string }) {
  const { locale } = useI18n();
  const [result, setResult] = useState<{ companyId: string; status: string } | null>(null);
  const status = result?.companyId === companyId ? result.status : null;
  useEffect(() => {
    let alive = true;
    const api = getSupabaseClient() as unknown as { rpc(name: string, args: Record<string, string>): PromiseLike<{ data: unknown; error: unknown }> };
    void Promise.resolve(api.rpc("get_company_accounting_setup", { target_company_id: companyId })).then(({ data, error }) => {
      if (!alive) return;
      const row = data as { company_id?: string; accounting_setup?: string } | null;
      setResult({ companyId, status: !error && row?.company_id === companyId && ["INCOMPLETE", "COMPLETE", "UNASSESSED"].includes(row.accounting_setup ?? "") ? row?.accounting_setup ?? "UNAVAILABLE" : "UNAVAILABLE" });
    }, () => { if (alive) setResult({ companyId, status: "UNAVAILABLE" }); });
    return () => { alive = false; };
  }, [companyId]);
  if (!status || status === "UNASSESSED") return null; // Existing books are never classified or blocked.
  const messages = locale === "ar" ? {
    INCOMPLETE: "الشركة مفعلة؛ التأسيس المحاسبي قيد الاستكمال. اطلب من مالك المنصة استكمال تأسيس الشركة الفارغة.",
    COMPLETE: "اكتمل التأسيس المحاسبي الأساسي. التمويل والبيانات التشغيلية ومتطلبات كل عملية خطوات مستقلة.",
    UNAVAILABLE: "تعذر التحقق من حالة التأسيس المحاسبي. أعد تحميل الصفحة للتحقق؛ لم يُنفذ أي تأسيس تلقائي.",
  } : {
    INCOMPLETE: "Company activated; accounting setup pending. Ask the Platform Owner to provision this new empty company.",
    COMPLETE: "Accounting foundation complete. Funding, business masters and each operation's prerequisites remain separate.",
    UNAVAILABLE: "Accounting setup status could not be verified. Reload to check; no automatic provisioning was performed.",
  };
  return <p role="status" className="mb-4 rounded-lg border border-slate-200 p-3 text-sm">{messages[status as keyof typeof messages]}</p>;
}
