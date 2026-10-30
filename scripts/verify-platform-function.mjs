// Check the server entrypoint against the installed, pinned SDK without executing it.
// A minimal Deno global declaration supports this offline TypeScript check; it is
// not a Deno runtime/bundling or hosted integration test.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import ts from 'typescript';

const entry = resolve('supabase/functions/platform-invitation-delivery/index.ts');
const source = readFileSync(entry, 'utf8');
const sdk = JSON.parse(readFileSync('node_modules/@supabase/supabase-js/package.json', 'utf8'));
assert.equal(sdk.version, '2.112.4', 'Review Edge SDK pin before changing its local contract check');
assert(source.includes('from "npm:@supabase/supabase-js@2.112.4"'));
const config = readFileSync('supabase/config.toml', 'utf8');
assert(/\[functions\.platform-invitation-delivery\]\s*verify_jwt\s*=\s*true/.test(config), 'Keep gateway JWT verification enabled');

const options = {
  noEmit: true, strict: true, skipLibCheck: true, allowJs: true, checkJs: false,
  target: ts.ScriptTarget.ES2023, module: ts.ModuleKind.ESNext,
  moduleResolution: ts.ModuleResolutionKind.Bundler, types: [],
  lib: ['lib.es2023.d.ts', 'lib.dom.d.ts', 'lib.dom.iterable.d.ts'],
};
const host = ts.createCompilerHost(options);
const originalSourceFile = host.getSourceFile.bind(host);
host.getSourceFile = (file, languageVersion, onError, createNew) => {
  if (resolve(file) !== entry) return originalSourceFile(file, languageVersion, onError, createNew);
  return ts.createSourceFile(file, source + '\ndeclare const Deno: { env: { get(name: string): string | undefined }; serve(handler: (request: Request) => Response | Promise<Response>): unknown };\n', languageVersion, true);
};
host.resolveModuleNames = (names, containingFile) => names.map(name => {
  const specifier = name === 'npm:@supabase/supabase-js@2.112.4' ? '@supabase/supabase-js' : name;
  return ts.resolveModuleName(specifier, containingFile, options, ts.sys).resolvedModule;
});
const diagnostics = ts.getPreEmitDiagnostics(ts.createProgram([entry], options, host));
if (diagnostics.length) {
  for (const d of diagnostics) console.error(`TS${d.code}: ${ts.flattenDiagnosticMessageText(d.messageText, '\n')}`);
  process.exitCode = 1;
} else {
  console.log('PASS: Edge entrypoint TypeScript/SDK contracts and JWT configuration; minimal Deno type shim only, no runtime, network or email execution.');
}
