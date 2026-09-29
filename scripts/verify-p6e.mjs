import assert from 'node:assert/strict';
import {readFileSync,mkdtempSync,mkdirSync,writeFileSync,rmSync} from 'node:fs';
import {tmpdir} from 'node:os';import {join,resolve} from 'node:path';
import ts from 'typescript';import {resolveConfig} from 'vite';
import {assertProductionBoundary,dependencyGraph} from './production-boundary.mjs';
const root=resolve(import.meta.dirname,'..');
const module={exports:{}};
new Function('module','exports',ts.transpileModule(readFileSync(join(root,'src/config/productionConfig.ts'),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(module,module.exports);
const {validateApplicationConfig,applicationMode,browserSafeKey}=module.exports;
const jwt=role=>[Buffer.from(JSON.stringify({alg:'HS256',typ:'JWT'})).toString('base64url'),Buffer.from(JSON.stringify({role})).toString('base64url'),'synthetic_signature'].join('.');
const key='sb_publishable_'+ 'synthetic_fixture_1234567890';const env={VITE_APP_DATA_MODE:'supabase-auth',VITE_SUPABASE_URL:'https://example.invalid',VITE_SUPABASE_PUBLISHABLE_KEY:key};
validateApplicationConfig(env,false);validateApplicationConfig({...env,VITE_SUPABASE_PUBLISHABLE_KEY:jwt('anon')},false);
assert(browserSafeKey(key));assert(!browserSafeKey(jwt('authenticated')));
for(const patch of [{VITE_APP_DATA_MODE:undefined},{VITE_APP_DATA_MODE:'invalid'},{VITE_APP_DATA_MODE:'local-demo'},{VITE_SUPABASE_URL:''},{VITE_SUPABASE_URL:'bad'},{VITE_SUPABASE_URL:'http://example.invalid'},{VITE_SUPABASE_PUBLISHABLE_KEY:''},{VITE_SUPABASE_PUBLISHABLE_KEY:'bad'},{VITE_SUPABASE_PUBLISHABLE_KEY:'sb_secret_synthetic'},{VITE_SUPABASE_PUBLISHABLE_KEY:jwt('service_role')},{VITE_OTHER:jwt('service_role')},{VITE_PRIVATE_KEY:'synthetic-only'}])assert.throws(()=>validateApplicationConfig({...env,...patch},false));
assert.equal(applicationMode('local-demo',true),'local-demo');validateApplicationConfig({VITE_APP_DATA_MODE:'local-demo'},true);validateApplicationConfig({...env,VITE_SUPABASE_URL:'http://localhost:54321'},true);
const publicBefore=Object.fromEntries(Object.entries(process.env).filter(([n])=>n.startsWith('VITE_')));
try{
 for(const n of Object.keys(publicBefore))delete process.env[n];Object.assign(process.env,env);
 await resolveConfig({configFile:join(root,'vite.config.ts'),logLevel:'silent'},'build');
 process.env.VITE_SUPABASE_PUBLISHABLE_KEY=jwt('service_role');
 await assert.rejects(resolveConfig({configFile:join(root,'vite.config.ts'),logLevel:'silent'},'build'),e=>!e.message.includes(process.env.VITE_SUPABASE_PUBLISHABLE_KEY)&&/Privileged/.test(e.message));
}finally{for(const n of Object.keys(process.env))if(n.startsWith('VITE_'))delete process.env[n];Object.assign(process.env,publicBefore);}
assertProductionBoundary(root);
const temp=mkdtempSync(join(tmpdir(),'maker-p6e-'));
try{
 for(const d of ['auth','storage','i18n','config'])mkdirSync(join(temp,'src',d),{recursive:true});
 for(const file of ['src/storage/demo.ts','src/i18n/I18nContext.tsx','src/config/productionConfig.ts'])writeFileSync(join(temp,file),'export const value=1;');
 const entry=join(temp,'src/auth/ProtectedApplication.tsx');
 for(const source of ['export const load=()=>import("../storage/demo");','export {value} from "../storage/demo";','export * from "../storage/demo";','import "../storage/demo";']){writeFileSync(entry,source);assert.throws(()=>assertProductionBoundary(temp),/demo business/);}
 writeFileSync(entry,'const name="../storage/demo";export const load=()=>import(name);');assert.throws(()=>dependencyGraph(entry),/Nonliteral/);
 writeFileSync(entry,'export const load=()=>import("../config/productionConfig");');assertProductionBoundary(temp);
 writeFileSync(join(temp,'src/config/productionConfig.ts'),'localStorage.getItem("business-data");');assert.throws(()=>assertProductionBoundary(temp),/localStorage/);
 writeFileSync(join(temp,'src/config/productionConfig.ts'),'sessionStorage.getItem("business-data");');assert.throws(()=>assertProductionBoundary(temp),/sessionStorage/);
}finally{rmSync(temp,{recursive:true,force:true});}
console.log('P6E config/boundary PASS: valid public/legacy-anon keys, invalid/missing config, privileged-key pre-bundle rejection without value disclosure, production demo rejection, dynamic/re-export/nonliteral boundaries and localStorage allowlist.');
