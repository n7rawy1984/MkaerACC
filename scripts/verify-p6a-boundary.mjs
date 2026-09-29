import {assertProductionBoundary} from "./production-boundary.mjs";
import { readFileSync } from "node:fs";
import { resolve } from "node:path";

const repositoryRoot = resolve(import.meta.dirname, "..");
const forbiddenSegments = ["/state/", "/storage/", "/seed/", "/pages/", "/components/layout/"];
const forbiddenText = ["ensureSeeded", "ensurePhase2ASeeded"];
const forbiddenSettingsMutations = [/\.from\(["']company_settings["']\)[\s\S]{0,400}\.(?:insert|update|delete|upsert)\s*\(/];

const appSource = readFileSync(resolve(repositoryRoot, "src/App.tsx"), "utf8");
if (!appSource.includes('lazy(() => import("./app/DemoApplication"))')) {
  throw new Error("DemoApplication is not protected by the approved lazy import boundary");
}

const authGraph = assertProductionBoundary(repositoryRoot);
for (const file of authGraph) {
  const normalized = file.replaceAll("\\", "/");
  if (forbiddenSegments.some((segment) => normalized.includes(segment))) {
    throw new Error(`Production Auth statically imports forbidden demo module: ${file}`);
  }
  const source = readFileSync(file, "utf8");
  if (forbiddenText.some((text) => source.includes(text))) {
    throw new Error(`Production Auth contains forbidden demo data access: ${file}`);
  }
  if (forbiddenSettingsMutations.some((pattern) => pattern.test(source))) {
    throw new Error(`Production Auth contains a forbidden Company-settings mutation: ${file}`);
  }
}

const protectedApplicationSource = readFileSync(resolve(repositoryRoot, "src/auth/ProtectedApplication.tsx"), "utf8");
for (const obsoleteAuthPath of ["/login", "/no-company", "/select-company", "/auth-error"]) {
  const canonicalRoute = `<Route path="${obsoleteAuthPath}" element={<Navigate to="/" replace />} />`;
  if (!protectedApplicationSource.includes(canonicalRoute)) {
    throw new Error(`TENANT_READY does not canonically replace obsolete Auth-state route: ${obsoleteAuthPath}`);
  }
}

console.log(`P6A import boundary and TENANT_READY canonical routes verified across ${authGraph.size} production-auth modules.`);
