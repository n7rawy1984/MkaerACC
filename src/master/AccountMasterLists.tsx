import{DataWorkspace,TextCell,RecordStatus}from'../workspace/data/DataWorkspace';
import {StatusBadge} from '../workspace/workspaceUi';
import type { ReactNode } from "react";
import { useT,useI18n } from "../i18n/I18nContext";
import { findVisibleAccount } from "./accountPresentation";
import type { ProductionAccount, ProductionTreasuryAccount } from "./masterTypes";

function AccountReference({ accounts, companyId, accountId }: { accounts: ProductionAccount[]; companyId: string; accountId: string }) {
  const t = useT();
  const account = findVisibleAccount(accounts, companyId, accountId);
  return <><bdi dir="ltr">{accountId}</bdi><span className="block">{account ? <><bdi dir="ltr">{account.code}</bdi> · <bdi>{account.name}</bdi></> : t("productionMaster.accountDetailsUnavailable")}</span></>;
}

export function AccountsList({ accounts, renderAction }: { accounts: ProductionAccount[]; renderAction?: (account: ProductionAccount) => ReactNode }) {
  const t = useT();const{locale}=useI18n();
  if (accounts.length === 0) return <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.accountsEmpty")}</p>;
  return (
    <DataWorkspace label={t('productionMaster.accounts')} rows={accounts} titleOf={r=>r.name} search={r=>[r.code,r.name].join(' ')} statusOf={r=>r.status} columns={[{key:'code',label:locale==='ar'?'الرمز':'Code',value:r=>r.code,render:r=><bdi dir="ltr">{r.code}</bdi>},{key:'name',label:locale==='ar'?'الاسم':'Name',value:r=>r.name,render:r=><TextCell value={r.name}/>},{key:'type',label:locale==='ar'?'النوع':'Type',render:r=><span>{t(`productionMaster.accountType.${r.accountType}`)}</span>},{key:'status',label:t('common.status'),render:r=><RecordStatus value={r.status}/>}]} renderDetails={account=><>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <p className="font-medium text-slate-900"><><bdi dir="ltr">{account.code}</bdi> · <bdi>{account.name}</bdi></></p>
            <span className="text-sm text-slate-600">{t(`productionMaster.accountType.${account.accountType}`)}</span><StatusBadge status={account.status}>{t(`partyStatus.${account.status}`)}</StatusBadge>
          </div>
          <dl className="mt-2 space-y-2 text-sm text-slate-500">
            <div><dt className="font-medium">{t("productionMaster.parentAccount")}</dt><dd>{account.parentAccountId === null ? t("productionMaster.noParent") : <AccountReference accounts={accounts} companyId={account.companyId} accountId={account.parentAccountId} />}</dd></div>
            <div><dt className="inline font-medium">{t("productionMaster.requiresParty")}: </dt><dd className="inline">{t(account.requiresParty ? "productionMaster.yes" : "productionMaster.no")}</dd></div>
            {account.systemKey !== null && <div><dt className="inline font-medium">{t("productionMaster.systemAccount")}: </dt><dd className="inline"><bdi dir="ltr">{account.systemKey}</bdi></dd></div>}
          </dl>
          {renderAction?.(account)}
        </>}/>
  );
}

export function TreasuryAccountsList({ treasuryAccounts, accounts, renderAction }: { treasuryAccounts: ProductionTreasuryAccount[]; accounts: ProductionAccount[]; renderAction?: (treasury: ProductionTreasuryAccount) => ReactNode }) {
  const t = useT();const{locale}=useI18n();
  if (treasuryAccounts.length === 0) return <p role="status" className="mt-4 text-sm text-slate-500">{t("productionMaster.treasuryAccountsEmpty")}</p>;
  return (
    <DataWorkspace label={t('productionMaster.treasuryAccounts')} rows={treasuryAccounts} titleOf={r=>r.name} search={r=>[r.code,r.name].join(' ')} statusOf={r=>r.status} columns={[{key:'code',label:locale==='ar'?'الرمز':'Code',value:r=>r.code,render:r=><bdi dir="ltr">{r.code}</bdi>},{key:'name',label:locale==='ar'?'الاسم':'Name',value:r=>r.name,render:r=><TextCell value={r.name}/>},{key:'type',label:locale==='ar'?'النوع':'Type',render:r=><span>{t(`treasuryType.${r.type}`)}</span>},{key:'account',label:t('productionMaster.permanentGlAccount'),render:r=><TextCell value={accounts.find(a=>a.id===r.glAccountId)?.name??t('productionMaster.accountDetailsUnavailable')} secondary={accounts.find(a=>a.id===r.glAccountId)?.code}/>},{key:'status',label:t('common.status'),render:r=><RecordStatus value={r.status}/>}]} renderDetails={treasury=><>
          <div className="flex flex-wrap items-start justify-between gap-3">
            <p className="font-medium text-slate-900"><><bdi dir="ltr">{treasury.code}</bdi> · <bdi>{treasury.name}</bdi></></p>
            <span className="text-sm text-slate-600">{t(`treasuryType.${treasury.type}`)}</span><StatusBadge status={treasury.status}>{t(`partyStatus.${treasury.status}`)}</StatusBadge>
          </div>
          <dl className="mt-2 space-y-2 text-sm text-slate-500">
            <div><dt className="font-medium">{t("productionMaster.permanentGlAccount")}</dt><dd><AccountReference accounts={accounts} companyId={treasury.companyId} accountId={treasury.glAccountId} /></dd></div>
            {([
              ["projectId", treasury.projectId], ["bankName", treasury.bankName],
              ["accountReference", treasury.accountReference], ["notes", treasury.notes],
            ] as const).map(([field, value]) => value !== null && <div key={field}><dt className="inline font-medium">{t(`productionMaster.${field}`)}: </dt><dd className="inline"><bdi dir={field === "projectId" || field === "accountReference" ? "ltr" : "auto"}>{value}</bdi></dd></div>)}
          </dl>
          {renderAction?.(treasury)}
        </>}/>
  );
}
