import { useMemo, useState } from "react";
import { ChevronDown, ChevronUp, HandCoins, Wallet } from "lucide-react";
import { useAppData } from "../state/AppDataContext";
import { PageHeader } from "../components/layout/AppShell";
import { Card } from "../components/ui/Card";
import { formatAED } from "../domain/money";
import { formatDate } from "../domain/utils";
import { ACCOUNTS } from "../accounting/chartOfAccounts";
import { custodianBalance, ownerCurrentBalance, partyLedger } from "../accounting/ledger";
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
          {lines.length === 0 && <p className="px-5 py-4 text-sm text-slate-400">No ledger activity yet.</p>}
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
                  <p className="text-xs font-medium text-slate-500">Balance {formatAED(l.balance)}</p>
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
  const { parties, journalEntries } = useAppData();
  const owners = useMemo(() => parties.filter((p) => p.type === "OWNER"), [parties]);
  const custodians = useMemo(() => parties.filter((p) => p.type === "CUSTODIAN"), [parties]);

  return (
    <div>
      <PageHeader title="Owners & Custodians" subtitle="Each person's balance with the company, in plain terms" />

      <div className="space-y-6">
        <div>
          <h2 className="text-sm font-semibold text-slate-900">Owners</h2>
          <p className="text-xs text-slate-400">
            Amount the company currently owes each owner for expenses or cash advances they funded personally
          </p>
          <div className="mt-3 space-y-3">
            {owners.map((o) => (
              <PersonCard
                key={o.id}
                party={o}
                balance={ownerCurrentBalance(journalEntries, o.id)}
                balanceLabel="Owed to owner"
                accountId={ACCOUNTS.OWNER_CURRENT}
                normalSide="CREDIT"
                increaseLabel="Owed"
                decreaseLabel="Settled"
                journalEntries={journalEntries}
                icon={HandCoins}
              />
            ))}
          </div>
        </div>

        <div>
          <h2 className="text-sm font-semibold text-slate-900">Custodians</h2>
          <p className="text-xs text-slate-400">Cash advanced to each custodian, minus what they've spent so far</p>
          <div className="mt-3 space-y-3">
            {custodians.map((c) => (
              <PersonCard
                key={c.id}
                party={c}
                balance={custodianBalance(journalEntries, c.id)}
                balanceLabel="Balance held"
                accountId={ACCOUNTS.ADVANCE_CUSTODY}
                normalSide="DEBIT"
                increaseLabel="Received"
                decreaseLabel="Spent"
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
