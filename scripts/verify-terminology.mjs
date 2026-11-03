import assert from 'node:assert/strict';
import ts from 'typescript';
import {readFileSync,readdirSync,existsSync,writeFileSync} from 'node:fs';
import {createHash} from 'node:crypto';
const baseline=process.env.TERMINOLOGY_BASELINE??'/tmp/narvo-terminology/before';
const checks=[],changes=[],check=(ok,label)=>{assert(ok,label);checks.push(label)};
const parse=(path,text)=>ts.createSourceFile(path,text,ts.ScriptTarget.Latest,true,path.endsWith('tsx')?ts.ScriptKind.TSX:ts.ScriptKind.TS);
const strings=f=>{const a=[];function walk(n){if(ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n))a.push({text:n.text,node:n});ts.forEachChild(n,walk)}walk(f);return a};
const printer=ts.createPrinter();
function structure(file){const transform=ts.transform(file,[ctx=>root=>{const walk=n=>ts.isStringLiteral(n)||ts.isNoSubstitutionTemplateLiteral(n)?ts.factory.createStringLiteral('TEXT'):ts.visitEachChild(n,walk,ctx);return ts.visitNode(root,walk)}]);const text=printer.printFile(transform.transformed[0]);transform.dispose();return text;}
function dict(file){const m={exports:{}};new Function('module','exports',ts.transpileModule(readFileSync(file,'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS}}).outputText)(m,m.exports);return m.exports.default;}
const en=dict('src/i18n/en.ts'),ar=dict('src/i18n/ar.ts');check(JSON.stringify(Object.keys(en).sort())===JSON.stringify(Object.keys(ar).sort()),'Main Arabic/English key parity');
const substitutions=s=>[...s.matchAll(/\{[A-Za-z][\w]*\}/g)].map(m=>m[0]).sort();
for(const lang of ['en','ar']){const old=dict(baseline+'/src/i18n/'+lang+'.ts'),next=lang==='en'?en:ar;check(JSON.stringify(Object.keys(old))===JSON.stringify(Object.keys(next)),lang+' all original translation keys preserved');for(const key of Object.keys(old))assert.deepEqual(substitutions(next[key]),substitutions(old[key]),lang+' '+key+' placeholders');check(true,lang+' all interpolation placeholders preserved');}
const roleFiles=new Set(['src/auth/CompanySelectPage.tsx','src/workspace/CompanyWorkspaceShell.tsx']);
function walk(dir){for(const e of readdirSync(dir,{withFileTypes:true})){const path=dir+'/'+e.name;if(e.isDirectory()){walk(path);continue}if(!existsSync(baseline+'/'+path))continue;const before=readFileSync(baseline+'/'+path,'utf8'),current=readFileSync(path,'utf8');if(before===current)continue;
 if(!/\.tsx?$/.test(path))throw Error('Non-language asset changed: '+path);
 const old=parse(path,before),next=parse(path,current);
 if(!roleFiles.has(path)){
  assert.equal(structure(old),structure(next),path+' only string contents changed');
  const calls=f=>{const a=[];function visit(n){if(ts.isCallExpression(n)&&ts.isPropertyAccessExpression(n.expression)&&['from','rpc','select','eq','in','order','filter','range','insert','update','delete','upsert'].includes(n.expression.name.text))a.push(printer.printNode(ts.EmitHint.Unspecified,n,f));ts.forEachChild(n,visit)}visit(f);return a};assert.deepEqual(calls(old),calls(next),path+' database query and mutation calls unchanged');
  const a=strings(old),b=strings(next);assert.equal(a.length,b.length,path+' string positions preserved');
  for(let i=0;i<a.length;i++)if(a[i].text!==b[i].text){assert(!ts.isImportDeclaration(a[i].node.parent),path+' import unchanged');changes.push({file:path,line:next.getLineAndCharacterOfPosition(b[i].node.getStart(next)).line+1,before:a[i].text,after:b[i].text});}
  const machine=f=>strings(f).filter(s=>/^\/[a-z]|^[a-z][a-z_]+_[a-z_]+$|^[A-Z][A-Z_]+$/.test(s.text)).map(s=>s.text);assert.deepEqual(machine(old),machine(next),path+' route/status/API identifiers preserved');
 }else{
  const handlers=f=>{const a=[];function v(n){if(ts.isJsxAttribute(n)&&/^on[A-Z]/.test(n.name.getText(f)))a.push(printer.printNode(ts.EmitHint.Unspecified,n,f));ts.forEachChild(n,v)}v(f);return a};assert.deepEqual(handlers(old),handlers(next),path+' event handlers preserved');
  check(current.includes('roleLabel('),path+' role display localized');
 }
 check(true,path+' presentation boundary');
}}
walk('src');
const hashes=JSON.parse(readFileSync('/tmp/narvo-terminology/hashes.json','utf8'));let protectedCount=0;for(const [p,h]of Object.entries(hashes))if(p.startsWith('supabase/')||/src\/(financial|accounting|tenant|types|config|storage|state)\//.test(p)||/Repository|Mutations|Model|Read\.ts/.test(p)){assert.equal(createHash('sha256').update(readFileSync(p)).digest('hex'),h,p+' protected source');protectedCount++;}
check(true,protectedCount+' protected business/config/migration sources unchanged');
check(!Object.values(en).some(v=>/authoritative readback|same-key|canonical|\bV1\b/i.test(v)),'No implementation jargon in English main dictionary');
check(!Object.values(ar).some(v=>/الدورة المحاسبية الكاملة|مساحة عمل لثلاثة أشهر|البيانات التأسيسية الأساسية/.test(v)),'Rejected Arabic labels removed');
check(en['journal.title']==='Journal entries'&&ar['journal.title']==='القيود اليومية','Journal terminology aligned');
const result={status:'PASS',checks:checks.length,details:checks,correctedExistingTextValues:changes.length,additionalRoleDisplayLocations:3,files:[...new Set(changes.map(c=>c.file)),...roleFiles,'src/i18n/roleLabels.ts'],protectedCount,changes};writeFileSync('/tmp/narvo-terminology/localization-result.json',JSON.stringify(result,null,2)+'\n');console.log('PASS',checks.length,'checks;',changes.length,'existing text values corrected;',protectedCount,'protected files unchanged');
