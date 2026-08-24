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
import type { JournalSourceType } from "../domain/types";

const SOURCE_LABEL: Record<JournalSourceType, string> = {
  EXPENSE: "Expense",
  ADVANCE: "Advance",
  SUPPLIER_PAYMENT: "Supplier Payment",
  CUSTODY_SETTLEMENT: "Custody Settlement",
  SUBCONTRACTOR_ADVANCE: "Subcontractor Advance",
  SUBCONTRACTOR_CERTIFICATE: "Subcontractor Certificate",
  SUBCONTRACTOR_PAYMENT: "Subcontractor Payment",
  MANUAL: "Manual",
};

const ALL = "ALL";

export function Journal() {
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
      <PageHeader
        title="Journal"
        subtitle={`${journalEntries.length} posted entries · every entry is balanced (debits = credits) by construction`}
      />

      <div className="mb-4">
        <select
          value={sourceFilter}
          onChange={(e) => setSourceFilter(e.target.value as JournalSourceType | typeof ALL)}
          className={`${inputClassName} w-56`}
        >
          <option value={ALL}>All source types</option>
          <option value="EXPENSE">Expense</option>
          <option value="ADVANCE">Advance</option>
          <option value="SUPPLIER_PAYMENT">Supplier Payment</option>
          <option value="CUSTODY_SETTLEMENT">Custody Settlement</option>
          <option value="SUBCONTRACTOR_ADVANCE">Subcontractor Advance</option>
          <option value="SUBCONTRACTOR_CERTIFICATE">Subcontractor Certificate</option>
          <option value="SUBCONTRACTOR_PAYMENT">Subcontractor Payment</option>
        </select>
      </div>

      <div className="space-y-4">
        {entries.length === 0 && (
          <Card>
            <p className="px-5 py-8 text-center text-sm text-slate-400">No journal entries yet.</p>
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
                  <Badge tone="slate">{SOURCE_LABEL[entry.sourceType]}</Badge>
                  <span className="text-xs text-slate-400">{entry.description}</span>
                </div>
                <div className="flex items-center gap-3">
                  <span className="text-xs text-slate-400">{formatDate(entry.date)}</span>
                  {balanced ? (
                    <span className="flex items-center gap-1 text-xs font-medium text-emerald-600">
                      <CheckCircle2 size={14} /> Balanced
                    </span>
                  ) : (
                    <Badge tone="red">Unbalanced</Badge>
                  )}
                </div>
              </div>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-xs uppercase tracking-wide text-slate-400">
                    <th className="px-5 py-2 font-medium">Account</th>
                    <th className="px-5 py-2 font-medium">Dimension</th>
                    <th className="px-5 py-2 text-right font-medium">Debit</th>
                    <th className="px-5 py-2 text-right font-medium">Credit</th>
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
                      Total
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
