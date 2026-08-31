import { readFileSync, existsSync } from "node:fs";
import { dirname, extname, resolve } from "node:path";

const repositoryRoot = resolve(import.meta.dirname, "..");
const extensions = [".ts", ".tsx", ".js", ".jsx"];
const forbiddenSegments = ["/state/", "/storage/", "/seed/", "/pages/", "/components/layout/"];
const forbiddenText = ["ensureSeeded", "ensurePhase2ASeeded"];

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
    const importPattern = /(?:^|\n)\s*import(?:\s+type)?(?:[\s\S]*?\sfrom\s*)?["']([^"']+)["'];?/g;
    for (const match of source.matchAll(importPattern)) {
      const imported = resolveImport(file, match[1]);
      if (imported) visit(imported);
    }
  };
  visit(entry);
  return visited;
}

const appSource = readFileSync(resolve(repositoryRoot, "src/App.tsx"), "utf8");
if (!appSource.includes('lazy(() => import("./app/DemoApplication"))')) {
  throw new Error("DemoApplication is not protected by the approved lazy import boundary");
}

const authGraph = staticGraph(resolve(repositoryRoot, "src/auth/ProtectedApplication.tsx"));
for (const file of authGraph) {
  const normalized = file.replaceAll("\\", "/");
  if (forbiddenSegments.some((segment) => normalized.includes(segment))) {
    throw new Error(`Production Auth statically imports forbidden demo module: ${file}`);
  }
  const source = readFileSync(file, "utf8");
  if (forbiddenText.some((text) => source.includes(text))) {
    throw new Error(`Production Auth contains forbidden demo data access: ${file}`);
  }
}

console.log(`P6A import boundary verified across ${authGraph.size} production-auth modules.`);
