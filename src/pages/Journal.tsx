import { useMemo, useState } from "react";
import { CheckCircle2 } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { Badge } from "../components/ui/Badge";
import { formatAED } from "../domain/money";
import { formatDate, indexById } from "../domain/utils";
import { isBalanced } from "../accounting/postingEngine";
import { inputClassName } from "../components/ui/Field";
import { useT } from "../i18n/I18nContext";
import type { TranslationKey } from "../i18n/en";
import type { JournalSourceType } from "../domain/types";

const SOURCE_KEY: Record<JournalSourceType, TranslationKey> = {
  EXPENSE: "journal.source.EXPENSE",
  ADVANCE: "journal.source.ADVANCE",
  SUPPLIER_PAYMENT: "journal.source.SUPPLIER_PAYMENT",
  CUSTODY_SETTLEMENT: "journal.source.CUSTODY_SETTLEMENT",
  SUBCONTRACTOR_ADVANCE: "journal.source.SUBCONTRACTOR_ADVANCE",
  SUBCONTRACTOR_CERTIFICATE: "journal.source.SUBCONTRACTOR_CERTIFICATE",
  SUBCONTRACTOR_PAYMENT: "journal.source.SUBCONTRACTOR_PAYMENT",
  MANUAL: "journal.source.MANUAL",
};

const ALL = "ALL";

export function Journal() {
  const t = useT();
  const { journalEntries, accounts, parties, projects } = useAppData();
  const [sourceFilter, setSourceFilter] = useState<JournalSourceType | typeof ALL>(ALL);

  const accountsById = useMemo(() => indexById(accounts), [accounts]);
  const partiesById = useMemo(() => indexById(parties), [parties]);
  const projectsById = useMemo(() => indexById(projects), [projects]);

  const entries = useMemo(
    () =>
      [...journalEntries]
        .filter((e) => sourceFilter === ALL || e.sourceType === sourceFilter)
        .sort((a, b) => (a.date < b.date ? 1 : -1)),
    [journalEntries, sourceFilter],
  );

  return (
    <div>
      <PageHeader title={t("journal.title")} subtitle={t("journal.subtitle", { count: journalEntries.length })} />

      <div className="mb-4">
        <select
          value={sourceFilter}
          onChange={(e) => setSourceFilter(e.target.value as JournalSourceType | typeof ALL)}
          className={`${inputClassName} w-56`}
        >
          <option value={ALL}>{t("journal.allSourceTypes")}</option>
          <option value="EXPENSE">{t("journal.source.EXPENSE")}</option>
          <option value="ADVANCE">{t("journal.source.ADVANCE")}</option>
          <option value="SUPPLIER_PAYMENT">{t("journal.source.SUPPLIER_PAYMENT")}</option>
          <option value="CUSTODY_SETTLEMENT">{t("journal.source.CUSTODY_SETTLEMENT")}</option>
          <option value="SUBCONTRACTOR_ADVANCE">{t("journal.source.SUBCONTRACTOR_ADVANCE")}</option>
          <option value="SUBCONTRACTOR_CERTIFICATE">{t("journal.source.SUBCONTRACTOR_CERTIFICATE")}</option>
          <option value="SUBCONTRACTOR_PAYMENT">{t("journal.source.SUBCONTRACTOR_PAYMENT")}</option>
        </select>
      </div>

      <div className="space-y-4">
        {entries.length === 0 && (
          <Card>
            <p className="px-5 py-8 text-center text-sm text-slate-400">{t("journal.noEntriesYet")}</p>
          </Card>
        )}
        {entries.map((entry) => {
          const debitTotal = entry.lines.reduce((s, l) => s + l.debit, 0);
          const creditTotal = entry.lines.reduce((s, l) => s + l.credit, 0);
          const balanced = isBalanced(entry.lines);
          return (
            <Card key={entry.id}>
              <div className="flex items-center justify-between border-b border-slate-100 px-5 py-3">
                <div className="flex items-center gap-3">
                  <p className="text-sm font-semibold text-slate-900">{entry.reference}</p>
                  <Badge tone="slate">{t(SOURCE_KEY[entry.sourceType])}</Badge>
                  <span className="text-xs text-slate-400">{entry.description}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-xs text-slate-400">{formatDate(entry.date)}</span>
                  {balanced ? (
                    <span className="flex items-center gap-1 text-xs font-medium text-emerald-600">
                      <CheckCircle2 size={14} /> {t("journal.balanced")}
                    </span>
                  ) : (
                    <Badge tone="red">{t("journal.unbalanced")}</Badge>
                  )}
                </div>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-xs uppercase tracking-wide text-slate-400">
                    <th className="px-5 py-2 font-medium">{t("journal.colAccount")}</th>
                    <th className="px-5 py-2 font-medium">{t("journal.colDimension")}</th>
                    <th className="px-5 py-2 text-right font-medium">{t("journal.colDebit")}</th>
                    <th className="px-5 py-2 text-right font-medium">{t("journal.colCredit")}</th>
                  </tr>
                </thead>
                <tbody>
                  {entry.lines.map((l, i) => (
                    <tr key={i} className="border-t border-slate-50">
                      <td className="px-5 py-2 text-slate-700">
                        {accountsById[l.accountId]?.code} {accountsById[l.accountId]?.name}
                      </td>
                      <td className="px-5 py-2 text-xs text-slate-400">
                        {[l.projectId && projectsById[l.projectId]?.name, l.partyId && partiesById[l.partyId]?.name]
                          .filter(Boolean)
                          .join(" · ") || "—"}
                      </td>
                      <td className="px-5 py-2 text-right text-slate-900">
                        {l.debit > 0 ? formatAED(l.debit) : ""}
                      </td>
                      <td className="px-5 py-2 text-right text-slate-900">
                        {l.credit > 0 ? formatAED(l.credit) : ""}
                      </td>
                    </tr>
                  ))}
                  <tr className="border-t border-slate-200 font-semibold">
                    <td className="px-5 py-2 text-slate-500" colSpan={2}>
                      {t("journal.total")}
                    </td>
                    <td className="px-5 py-2 text-right text-slate-900">{formatAED(debitTotal)}</td>
                    <td className="px-5 py-2 text-right text-slate-900">{formatAED(creditTotal)}</td>
                  </tr>
                </tbody>
              </table>
            </Card>
          );
        })}
      </div>
    </div>
  );
}
