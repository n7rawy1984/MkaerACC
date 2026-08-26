import { useMemo, useState } from "react";
import { ChevronDown, ChevronUp, HandCoins, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { ACCOUNTS } from "../accounting/chartOfAccounts";
import { custodianBalance, ownerCurrentBalance, partyLedger } from "../accounting/ledger";
import { useT } from "../i18n/I18nContext";
import type { Party } from "../domain/types";

function PersonCard({
  party,
  balance,
  balanceLabel,
  accountId,
  normalSide,
  increaseLabel,
  decreaseLabel,
  journalEntries,
  icon: Icon,
}: {
  party: Party;
  balance: number;
  balanceLabel: string;
  accountId: string;
  normalSide: "DEBIT" | "CREDIT";
  increaseLabel: string;
  decreaseLabel: string;
  journalEntries: ReturnType<typeof useAppData>["journalEntries"];
  icon: typeof Wallet;
}) {
  const t = useT();
  const [open, setOpen] = useState(false);
  const lines = useMemo(
    () => (open ? partyLedger(journalEntries, accountId, party.id, normalSide) : []),
    [open, journalEntries, accountId, party.id, normalSide],
  );

  return (
    <Card>
      <button
        onClick={() => setOpen((v) => !v)}
        className="flex w-full items-center justify-between px-5 py-4 text-left"
      >
        <div className="flex items-center gap-3">
          <div className="flex h-10 w-10 items-center justify-center rounded-lg bg-slate-100 text-slate-500">
            <Icon size={18} />
          </div>
          <div>
            <p className="text-sm font-semibold text-slate-900">{party.name}</p>
            <p className="text-xs text-slate-400">{party.notes ?? party.type}</p>
          </div>
        </div>
        <div className="flex items-center gap-3">
          <div className="text-right">
            <p className="text-xs text-slate-400">{balanceLabel}</p>
            <p className={`text-sm font-semibold ${balance < 0 ? "text-rose-600" : "text-slate-900"}`}>
              {formatAED(balance)}
            </p>
          </div>
          {open ? <ChevronUp size={16} className="text-slate-400" /> : <ChevronDown size={16} className="text-slate-400" />}
        </div>
      </button>
      {open && (
        <div className="divide-y divide-slate-100 border-t border-slate-100">
          {lines.length === 0 && (
            <p className="px-5 py-4 text-sm text-slate-400">{t("people.noLedgerActivity")}</p>
          )}
          {lines.map((l, i) => {
            const isIncrease = normalSide === "DEBIT" ? l.debit > 0 : l.credit > 0;
            const amount = isIncrease
              ? normalSide === "DEBIT"
                ? l.debit
                : l.credit
              : normalSide === "DEBIT"
                ? l.credit
                : l.debit;
            return (
              <div key={i} className="flex items-center justify-between px-5 py-2.5 text-sm">
                <div>
                  <p className="text-slate-700">{l.description}</p>
                  <p className="text-xs text-slate-400">
                    {formatDate(l.date)} · {l.reference}
                  </p>
                </div>
                <div className="text-right">
                  <p className="text-slate-600">
                    {isIncrease ? increaseLabel : decreaseLabel} {formatAED(amount)}
                  </p>
                  <p className="text-xs font-medium text-slate-500">{t("people.balance", { amount: formatAED(l.balance) })}</p>
                </div>
              </div>
            );
          })}
        </div>
      )}
    </Card>
  );
}

export function OwnersCustodians() {
  const t = useT();
  const { parties, journalEntries } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);

  return (
    <div>
      <PageHeader title={t("people.title")} subtitle={t("people.subtitle")} />

      <div className="space-y-6">
        <div>
          <h2 className="text-sm font-semibold text-slate-900">{t("people.ownersHeader")}</h2>
          <p className="text-xs text-slate-400">{t("people.ownersSubtitle")}</p>
          <div className="mt-3 space-y-3">
            {owners.map((o) => (
              <PersonCard
                key={o.id}
                party={o}
                balance={ownerCurrentBalance(journalEntries, o.id)}
                balanceLabel={t("people.owedToOwner")}
                accountId={ACCOUNTS.OWNER_CURRENT}
                normalSide="CREDIT"
                increaseLabel={t("people.owed")}
                decreaseLabel={t("people.settled")}
                journalEntries={journalEntries}
                icon={HandCoins}
              />
            ))}
          </div>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-slate-900">{t("people.custodiansHeader")}</h2>
          <p className="text-xs text-slate-400">{t("people.custodiansSubtitle")}</p>
          <div className="mt-3 space-y-3">
            {custodians.map((c) => (
              <PersonCard
                key={c.id}
                party={c}
                balance={custodianBalance(journalEntries, c.id)}
                balanceLabel={t("people.balanceHeld")}
                accountId={ACCOUNTS.ADVANCE_CUSTODY}
                normalSide="DEBIT"
                increaseLabel={t("people.received")}
                decreaseLabel={t("people.spent")}
                journalEntries={journalEntries}
                icon={Wallet}
              />
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
