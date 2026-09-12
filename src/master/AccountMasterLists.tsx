import { useT } from "../i18n/I18nContext";
import { findVisibleAccount } from "./accountPresentation";
import type { ProductionAccount, ProductionTreasuryAccount } from "./masterTypes";

function AccountReference({ accounts, companyId, accountId }: { accounts: ProductionAccount[]; companyId: string; accountId: string }) {
  const t = useT();
  const account = findVisibleAccount(accounts, companyId, accountId);
  return <><bdi>{accountId}</bdi><span className="block">{account ? <bdi>{account.code} · {account.name}</bdi> : t("productionMaster.accountDetailsUnavailable")}</span></>;
}

export function AccountsList({ accounts }: { accounts: ProductionAccount[] }) {
  const t = useT();
  if (accounts.length === 0) return <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.accountsEmpty")}</p>;
  return (
    <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionMaster.accounts")}>
      {accounts.map((account) => (
        <li key={account.id} className="break-words py-4 first:pt-0 last:pb-0">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <p className="font-medium text-slate-900"><bdi>{account.code} · {account.name}</bdi></p>
            <span className="text-sm text-slate-600">{t(`productionMaster.accountType.${account.accountType}`)} · {t(`partyStatus.${account.status}`)}</span>
          </div>
          <dl className="mt-2 space-y-2 text-sm text-slate-500">
            <div><dt className="font-medium">{t("productionMaster.parentAccount")}</dt><dd>{account.parentAccountId === null ? t("productionMaster.noParent") : <AccountReference accounts={accounts} companyId={account.companyId} accountId={account.parentAccountId} />}</dd></div>
            <div><dt className="inline font-medium">{t("productionMaster.requiresParty")}: </dt><dd className="inline">{t(account.requiresParty ? "productionMaster.yes" : "productionMaster.no")}</dd></div>
            {account.systemKey !== null && <div><dt className="inline font-medium">{t("productionMaster.systemAccount")}: </dt><dd className="inline"><bdi>{account.systemKey}</bdi></dd></div>}
          </dl>
        </li>
      ))}
    </ul>
  );
}

export function TreasuryAccountsList({ treasuryAccounts, accounts }: { treasuryAccounts: ProductionTreasuryAccount[]; accounts: ProductionAccount[] }) {
  const t = useT();
  if (treasuryAccounts.length === 0) return <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.treasuryAccountsEmpty")}</p>;
  return (
    <ul className="mt-5 divide-y divide-slate-200" aria-label={t("productionMaster.treasuryAccounts")}>
      {treasuryAccounts.map((treasury) => (
        <li key={treasury.id} className="break-words py-4 first:pt-0 last:pb-0">
          <div className="flex flex-wrap items-start justify-between gap-3">
            <p className="font-medium text-slate-900"><bdi>{treasury.code} · {treasury.name}</bdi></p>
            <span className="text-sm text-slate-600">{t(`treasuryType.${treasury.type}`)} · {t(`partyStatus.${treasury.status}`)}</span>
          </div>
          <dl className="mt-2 space-y-2 text-sm text-slate-500">
            <div><dt className="font-medium">{t("productionMaster.permanentGlAccount")}</dt><dd><AccountReference accounts={accounts} companyId={treasury.companyId} accountId={treasury.glAccountId} /></dd></div>
            {([
              ["projectId", treasury.projectId], ["bankName", treasury.bankName],
              ["accountReference", treasury.accountReference], ["notes", treasury.notes],
            ] as const).map(([field, value]) => value !== null && <div key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline"><bdi>{value}</bdi></dd></div>)}
          </dl>
        </li>
      ))}
    </ul>
  );
}
