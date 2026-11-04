import {CustodyReconciliation} from '../reports/CustodyReconciliation';
import {ContentSection,LoadingState,ErrorState} from '../workspace/workspaceUi';
import ExecutiveDashboard from "../dashboard/ExecutiveDashboard";
import { ExpenseReadPanel } from "../financial/ExpenseReadPanel";
import { SupplierPaymentPanel } from "../financial/SupplierPaymentPanel";
import { SubcontractorAdvancePanel } from "../financial/SubcontractorAdvancePanel";
import { SubcontractorPaymentPanel } from "../financial/SubcontractorPaymentPanel";
import { RetentionReleasePanel } from "../financial/RetentionReleasePanel";
import { RetentionPaymentPanel } from "../financial/RetentionPaymentPanel";
import { SubcontractorCertificatePanel } from "../financial/SubcontractorCertificatePanel";
import { AccountNamesPanel } from "../master/AccountNamesPanel";
import { ProjectsList } from "../master/ProjectsList";
import { CompanyProfilePanel } from "../master/CompanyProfilePanel";
import { PartiesList } from "../master/PartiesList";
import { ExpenseCategoriesList } from "../master/ExpenseCategoriesList";
import { SubcontractsList } from "../master/SubcontractsList";
import { TreasuryNamesPanel } from "../master/TreasuryNamesPanel";
import { useAuth } from "../auth/AuthContext";
import { useT } from "../i18n/I18nContext";
import { useProductionMasterData } from "../master/productionMasterDataContext";

export default function TenantReadyApplication({ view }: { view: "dashboard" | "expenses" | "supplierPayments" | "subcontractorAdvances" | "subcontractorCertificates" | "subcontractorPayments" | "retentionReleases" | "retentionPayments" | "companyProfile" | "projects" | "parties" | "expenseCategories" | "accounts" | "treasuryAccounts" | "subcontracts" | "deferred" }) {
  const t = useT();
  const { state } = useAuth();
  const masterData = useProductionMasterData();
  if (state.phase !== "TENANT_READY") return null;
  return <div className="workspace-module-content">
        {view === "dashboard" ? <ExecutiveDashboard /> : view === "expenses" ? <ExpenseReadPanel /> : view === "supplierPayments" ? <SupplierPaymentPanel /> : view === "subcontractorAdvances" ? <SubcontractorAdvancePanel /> : view === "subcontractorCertificates" ? <SubcontractorCertificatePanel /> : view === "subcontractorPayments" ? <SubcontractorPaymentPanel /> : view === "retentionReleases" ? <RetentionReleasePanel /> : view === "retentionPayments" ? <RetentionPaymentPanel /> : view === "deferred" ? (
          <ContentSection className="workspace-master-module">
            <h2>{t("auth.tenantReadyTitle")}</h2>
            <p className="mt-3 leading-7 text-slate-600">{t("auth.cutoverPending")}</p>
          </ContentSection>
        ) : (
          <ContentSection className="workspace-master-module">

            {masterData.phase === "LOADING" && <LoadingState>{t("productionMaster.loading")}</LoadingState>}
            {masterData.phase === "MISSING_COMPANY" && <p role="alert" className="mt-4 rounded-lg border border-amber-200 bg-amber-50 px-4 py-3 text-sm text-amber-900">{t("productionProjects.companyUnavailable")}</p>}
            {masterData.phase === "ERROR" && <ErrorState>{t("productionMaster.error")}</ErrorState>}
            {view === "subcontracts" && <p className="mt-3 text-sm text-slate-500">{t("productionMaster.subcontractsMetadataScope")}</p>}
            {view === "subcontracts" && masterData.phase === "READY" && <SubcontractsList />}
            {view === "accounts" && masterData.phase === "READY" && <AccountNamesPanel />}
            {view === "treasuryAccounts" && masterData.phase === "READY" && <><TreasuryNamesPanel /><CustodyReconciliation /></>}
            {view === "projects" && masterData.phase === "READY" && <ProjectsList />}
            {view === "companyProfile" && masterData.phase === "READY" && <CompanyProfilePanel />}
            {view === "parties" && masterData.phase === "READY" && <PartiesList />}
            {view === "expenseCategories" && masterData.phase === "READY" && <ExpenseCategoriesList />}
          </ContentSection>
        )}
    </div>;
}
