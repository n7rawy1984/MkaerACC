import assert from 'node:assert/strict';
import {readFileSync,writeFileSync,mkdirSync} from 'node:fs';
import ts from 'typescript';
const load=p=>{const m={exports:{}};new Function('module','exports',ts.transpileModule(readFileSync(p,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(m,m.exports);return m.exports;};
const {dashboardAED}=load('src/dashboard/dashboardSummary.ts'),{sourceDatePresentation}=load('src/historical/sourceDatePresentation.ts');const checks=[];
for(const [minor,expected] of [['6500000','65,000.00 AED'],['0','0.00 AED'],['1','0.01 AED'],['-1','-0.01 AED'],['-105','-1.05 AED'],['9007199254740993','90,071,992,547,409.93 AED'],['9223372036854775807','92,233,720,368,547,758.07 AED'],['-9223372036854775808','-92,233,720,368,547,758.08 AED']]){assert.equal(dashboardAED(minor),expected);checks.push('Exact AED '+minor);}
for(const locale of ['en','ar']){
 for(const iso of ['2026-08-01','2026-01-08','2024-02-29','0001-01-01']){const d=sourceDatePresentation(iso,locale);assert.equal(d.status,'KNOWN');assert.equal(d.iso,iso);assert(d.label.startsWith(iso+' · '));checks.push(locale+': known ISO '+iso);}
 assert.notEqual(sourceDatePresentation('2026-08-01',locale).label,sourceDatePresentation('2026-01-08',locale).label);checks.push(locale+': August1 distinct from January8');
 for(const value of ['08/01/2026','01/08/2026','2026-02-30','2026-13-01','2026-8-1','2026-08-01T00:00:00Z','0000-01-01','46300',' 2026-08-01 ']){const d=sourceDatePresentation(value,locale);assert.equal(d.status,'UNRESOLVED');assert.equal(d.iso,null);assert(d.label.includes(value));checks.push(locale+': unresolved input preserved '+value);}
 for(const value of [null,undefined,'']){const d=sourceDatePresentation(value,locale);assert.equal(d.status,'UNKNOWN');assert.equal(d.iso,null);checks.push(locale+': missing date not inferred');}
}
// Preview fields must not alter the actual source-review or posting handlers.
mkdirSync('/tmp/narvo-m1',{recursive:true});
const baseline=process.env.M1_BASELINE_SHA256?JSON.parse(readFileSync(process.env.M1_BASELINE_SHA256,'utf8')):{};const crypto=await import('node:crypto');
const protectedFiles=Object.keys(baseline).filter(p=>p.startsWith('supabase/')||p.startsWith('src/platform/')||p.startsWith('src/financial/')&&p!=='src/financial/TreasuryExpensePost.tsx'||p==='src/historical/sourceModel.ts'||p==='src/historical/sourcePosting.ts'||p==='src/historical/useHistoricalSources.ts'||p==='src/master/subcontractCreationRepository.ts');
for(const p of protectedFiles)assert.equal(crypto.createHash('sha256').update(readFileSync(p)).digest('hex'),baseline[p],p);
if(protectedFiles.length)checks.push('Protected Platform Owner, SQL, Edge, repositories, amounts, provenance and source-posting files unchanged');
writeFileSync('/tmp/narvo-m1/unit-result.json',JSON.stringify({status:'PASS',checks:checks.length,details:checks,protected_files:protectedFiles.length,hosted:false},null,2));console.log(`PASS: ${checks.length} exact-money/date/preservation checks; ${protectedFiles.length} protected source hashes unchanged.`);
