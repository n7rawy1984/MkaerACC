import { existsSync, readFileSync, readdirSync, statSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";

const repositoryRoot = resolve(import.meta.dirname, "..");
const extensions = [".ts", ".tsx", ".js", ".jsx"];

function resolveImport(fromFile, specifier) {
  if (!specifier.startsWith(".")) return null;
  const base = resolve(dirname(fromFile), specifier);
  if (existsSync(base) && extname(base)) return base;
  for (const extension of extensions) if (existsSync(`${base}${extension}`)) return `${base}${extension}`;
  for (const extension of extensions) if (existsSync(resolve(base, `index${extension}`))) return resolve(base, `index${extension}`);
  throw new Error(`Cannot resolve ${specifier} from ${fromFile}`);
}

function staticGraph(entry) {
  const visited = new Set();
  const visit = (file) => {
    if (visited.has(file)) return;
    visited.add(file);
    const source = readFileSync(file, "utf8");
    const imports = /(?:^|\n)\s*import(?:\s+type)?(?:[\s\S]*?\sfrom\s*)?["']([^"']+)["'];?/g;
    for (const match of source.matchAll(imports)) {
      const imported = resolveImport(file, match[1]);
      if (imported) visit(imported);
    }
  };
  visit(entry);
  return visited;
}

function filesBelow(directory) {
  return readdirSync(directory).flatMap((name) => {
    const path = resolve(directory, name);
    return statSync(path).isDirectory() ? filesBelow(path) : [path];
  });
}

const masterRoot = resolve(repositoryRoot, "src/master");
const masterFiles = filesBelow(masterRoot);
const forbiddenMasterText = [
  "localStorage", "AppDataContext", "/storage/", "/seed/", "postingEngine", "/ledger",
  "journal_entries", "journal_lines", "post_expense", "post_supplier_payment",
  "custody_advances", "supplier_payments", "subcontractor_payments", ".delete(",
  "service_role", "SUPABASE_SERVICE_ROLE", "SECRET_KEY",
  ".upsert(", ".rpc(",
];
for (const file of masterFiles) {
  const source = readFileSync(file, "utf8");
  for (const forbidden of forbiddenMasterText) {
    if (source.includes(forbidden)) throw new Error(`Production master module contains forbidden text ${forbidden}: ${file}`);
  }
}

const repositorySource = readFileSync(resolve(masterRoot, "masterRepositories.ts"), "utf8");
for (const required of [
  '.from("companies")', '.eq("id", activeCompanyId)',
  '.from("projects")', '.eq("company_id", activeCompanyId)',
]) {
  if (!repositorySource.includes(required)) throw new Error(`Missing explicit tenant query boundary: ${required}`);
}

const allowedTables = new Set(["companies", "projects", "parties", "expense_categories", "accounts", "treasury_accounts", "subcontracts"]);
for (const file of masterFiles) {
  const source = readFileSync(file, "utf8");
  for (const match of source.matchAll(/\.from\(["']([^"']+)["']\)/g)) {
    if (!allowedTables.has(match[1])) throw new Error(`Out-of-slice table: ${match[1]}`);
  }
  const isCategoryMutation = file === resolve(masterRoot, "expenseCategoryMutations.ts");
  const isOtherPartyMutation = file === resolve(masterRoot, "otherPartyNameMutations.ts");
  const isEmployeePartyMutation = file === resolve(masterRoot, "employeePartyNameMutations.ts");
  const isCustodianPartyMutation = file === resolve(masterRoot, "custodianPartyNameMutations.ts");
  const isOwnerPartyMutation = file === resolve(masterRoot, "ownerPartyNameMutations.ts");
  const isSubcontractorPartyMutation = file === resolve(masterRoot, "subcontractorPartyNameMutations.ts");
  const isTreasuryMutation = file === resolve(masterRoot, "treasuryNameMutations.ts");
  const isAccountMutation = file === resolve(masterRoot, "accountNameMutations.ts");
  const isProjectMutation = file === resolve(masterRoot, "projectMetadataMutations.ts");
  const isCompanyMutation = file === resolve(masterRoot, "companyProfileMutations.ts");
  const isSupplierMutation = file === resolve(masterRoot, "supplierPartyMutations.ts");
  if (/\.(upsert|delete|rpc)\s*\(/.test(source) || (!isCategoryMutation && !isSupplierMutation && !isCompanyMutation && !isProjectMutation && !isAccountMutation && !isTreasuryMutation && !isOtherPartyMutation && !isEmployeePartyMutation && !isCustodianPartyMutation && !isOwnerPartyMutation && !isSubcontractorPartyMutation && /\.(insert|update)\s*\(/.test(source))) throw new Error(`Mutation/RPC outside approved repositories: ${file}`);
  if (isAccountMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "accounts"))) throw new Error("Account writer exceeds name UPDATE boundary");
  if (isOtherPartyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties"))) throw new Error("OTHER Party writer exceeds name UPDATE boundary");
  if (isEmployeePartyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties"))) throw new Error("EMPLOYEE Party writer exceeds name UPDATE boundary");
  if (isCustodianPartyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties"))) throw new Error("CUSTODIAN Party writer exceeds name UPDATE boundary");
  if (isSubcontractorPartyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties"))) throw new Error("SUBCONTRACTOR Party writer exceeds name UPDATE boundary");
  if (isOwnerPartyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties"))) throw new Error("OWNER Party writer exceeds name UPDATE boundary");
  if (isTreasuryMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "treasury_accounts"))) throw new Error("Treasury writer exceeds name UPDATE boundary");
  if (isProjectMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "projects"))) throw new Error("Project writer exceeds metadata UPDATE boundary");
  if (isCompanyMutation && (/\.insert\s*\(/.test(source) || [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "companies"))) throw new Error("Company writer exceeds metadata UPDATE boundary");
  if (isCategoryMutation && [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "expense_categories")) throw new Error("Category writer accesses another table");
  if (isSupplierMutation && [...source.matchAll(/\.from\(["']([^"']+)["']\)/g)].some((m) => m[1] !== "parties")) throw new Error("Supplier writer accesses another table");
}
for (const [name, table] of [["readActiveCompanyParties", "parties"], ["readActiveCompanyExpenseCategories", "expense_categories"], ["readActiveCompanyAccounts", "accounts"], ["readActiveCompanyTreasuryAccounts", "treasury_accounts"], ["readActiveCompanySubcontracts", "subcontracts"]]) {
  const body = repositorySource.split(`export async function ${name}(`)[1]?.split("export ")[0];
  for (const required of [`.from("${table}")`, '.eq("company_id", activeCompanyId)', 'row.company_id === activeCompanyId']) {
    if (!body?.includes(required)) throw new Error(`Missing ${name} boundary: ${required}`);
  }
}

const providerSource = readFileSync(resolve(masterRoot, "ProductionMasterDataProvider.tsx"), "utf8");
for (const guard of ["requestGeneration", "scopeKey", "mounted", "liveSession.session?.user.id !== userId", "${userId}:${activeCompanyId}:${role}", "scopedState.scopeKey === scopeKey", "readActiveCompanyParties", "readActiveCompanyExpenseCategories", "readActiveCompanyAccounts", "readActiveCompanyTreasuryAccounts", "readActiveCompanySubcontracts"]) {
  if (!providerSource.includes(guard)) throw new Error(`Missing stale-response/session guard: ${guard}`);
}

const authSource = readFileSync(resolve(repositoryRoot, "src/auth/AuthContext.tsx"), "utf8");
for (const required of [
  'const preserveReadyState = background && stateRef.current.phase === "TENANT_READY"',
  'if (preserveReadyState && backgroundGenerationRef.current !== null) return',
  'if (!preserveReadyState) setState({ phase: "LOADING_IDENTITY" })',
  'revalidate(undefined, true)',
  'event === "SIGNED_IN" && sameKnownUser',
  'preserveReadyState && sameReadyAuthority(current, profile, memberships, activeTenant)',
  'if (claimsError || claimsData?.claims?.sub !== userId)',
  'clearProtectedState()',
  'chooseCompany: (companyId) => revalidate(companyId)',
]) {
  if (!authSource.includes(required)) throw new Error(`Missing Auth revalidation boundary: ${required}`);
}
if (!authSource.includes('if (isCurrent() && !preserveReadyState) setState({ phase: "IDENTITY_LOAD_ERROR" })')) {
  throw new Error("Background revalidation does not preserve the current tenant-ready UI on a transient load failure");
}
const redundantSignedInGuard = authSource.indexOf('event === "SIGNED_IN" && sameKnownUser');
const foregroundLoadingTransition = authSource.indexOf('setState({ phase: "LOADING_IDENTITY" })', redundantSignedInGuard);
if (redundantSignedInGuard < 0 || foregroundLoadingTransition < 0 || redundantSignedInGuard > foregroundLoadingTransition) {
  throw new Error("Redundant same-user SIGNED_IN events are not guarded before the foreground loading transition");
}
if ((authSource.match(/revalidate\(undefined, true\)/g) ?? []).length !== 2) {
  throw new Error("Focus and visibility handlers must share the coalesced background-revalidation path");
}

const protectedApplicationSource = readFileSync(resolve(repositoryRoot, "src/auth/ProtectedApplication.tsx"), "utf8");
for (const required of [
  'key={`${state.profile.userId}:${state.activeTenant.companyId}`}',
  'activeCompanyId={state.activeTenant.companyId}',
  'role={state.activeTenant.role}',
  'key={`${state.profile.userId}:${state.activeTenant.companyId}:${state.activeTenant.role}`}',
  'path="/parties"',
  'path="/expense-categories"',
  'path="/accounts"',
  'path="/treasury-accounts"',
  'path="/subcontracts"',
]) {
  if (!protectedApplicationSource.includes(required)) throw new Error(`Missing Company-change master invalidation boundary: ${required}`);
}

const demoGraph = staticGraph(resolve(repositoryRoot, "src/app/DemoApplication.tsx"));
for (const file of demoGraph) {
  if (file.replaceAll("\\", "/").includes("/src/master/")) {
    throw new Error(`Demo graph imports a production master module: ${file}`);
  }
}

const productionGraph = staticGraph(resolve(repositoryRoot, "src/auth/ProtectedApplication.tsx"));
for (const file of productionGraph) {
  const normalized = file.replaceAll("\\", "/");
  for (const forbidden of ["/src/state/", "/src/storage/", "/src/seed/", "/src/accounting/postingEngine", "/src/accounting/ledger", "/src/app/DemoApplication"] ) {
    if (normalized.includes(forbidden)) throw new Error(`Production graph imports forbidden demo/financial module: ${file}`);
  }
}

console.log(`P6C Company/Projects/Parties/Expense Categories/Accounts/Treasury/Subcontracts boundary verified across ${masterFiles.length} master modules, ${productionGraph.size} production modules, and ${demoGraph.size} demo modules.`);

await import("./verify-p6c-behavior.mjs");
