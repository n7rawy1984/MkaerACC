import {readFileSync,existsSync} from 'node:fs';
import {dirname,resolve,extname,relative} from 'node:path';
import ts from 'typescript';
export function dependencyGraph(entry) {
 const visited=new Set();
 function visit(file){
  if(visited.has(file))return;visited.add(file);
  if(!/\.[cm]?[jt]sx?$/.test(file))return;
  const source=ts.createSourceFile(file,readFileSync(file,'utf8'),ts.ScriptTarget.Latest,true);
  function dependency(spec){
   if(!spec.startsWith('.')){
    if(spec.startsWith('/')||spec.startsWith('@/')||spec.startsWith('~/'))throw Error('Unresolved local dependency alias');
    return; // External packages are not demo application repositories.
   }
   const base=resolve(dirname(file),spec);
   const candidate=[base,...['.ts','.tsx','.js','.jsx','.mjs'].map(e=>base+e),...['index.ts','index.tsx','index.js'].map(n=>resolve(base,n))].find(p=>existsSync(p)&&!!extname(p));
   if(!candidate)throw Error('Unresolved application dependency');visit(candidate);
  }
  function walk(node){
   if((ts.isImportDeclaration(node)||ts.isExportDeclaration(node))&&node.moduleSpecifier){
    if(!ts.isStringLiteralLike(node.moduleSpecifier))throw Error('Nonliteral dependency');dependency(node.moduleSpecifier.text);
   }
   if(ts.isCallExpression(node)&&(node.expression.kind===ts.SyntaxKind.ImportKeyword||(ts.isIdentifier(node.expression)&&node.expression.text==='require'))){
    if(node.arguments.length!==1||!ts.isStringLiteralLike(node.arguments[0]))throw Error('Nonliteral dynamic dependency');dependency(node.arguments[0].text);
   }
   if(ts.isImportEqualsDeclaration(node))throw Error('Unsupported application import');
   ts.forEachChild(node,walk);
  }
  walk(source);
 }
 visit(entry);return visited;
}
// Existing command recovery envelopes only; these files are not local business stores.
const sessionRecoveryFiles=new Set([
 'src/payroll/PayrollPosting.tsx',
 ...['SupplierPaymentReverseAction','SupplierCreditExpensePost','RetentionPaymentReverseAction',
 'SubcontractorAdvancePost','RetentionPaymentPost','SubcontractorAdvanceReverseAction',
 'SubcontractorCertificateApproveAction','TreasuryExpensePost','SubcontractorPaymentPost',
 'SubcontractorPaymentReverseAction','SubcontractorCertificateReverseAction','SupplierPaymentPost',
 'ExpenseReverseAction','RetentionReleasePost','SubcontractorCertificateDraft','RetentionReleaseReverseAction']
 .map(name=>`src/financial/${name}.tsx`),
]);
export function assertProductionBoundary(root){
 const graph=dependencyGraph(resolve(root,'src/auth/ProtectedApplication.tsx'));
 // Global locale/config providers run in both modes and must also stay data-free.
 for(const entry of ['src/i18n/I18nContext.tsx','src/config/productionConfig.ts'])for(const file of dependencyGraph(resolve(root,entry)))graph.add(file);
 for(const file of graph){
  const path=relative(root,file).replaceAll('\\','/');
  if(/^src\/(state|storage|seed|pages)\//.test(path)||path.startsWith('src/components/layout/')||/^src\/accounting\/(postingEngine|ledger)/.test(path)||/^src\/(app\/DemoApplication|tenant\/DemoTenantSettingsProvider)/.test(path))throw Error('Production imports demo business data: '+path);
  if(/\.[cm]?[jt]sx?$/.test(file)){
   const source=readFileSync(file,'utf8');
   if(/\bsessionStorage\b/.test(source)&&!sessionRecoveryFiles.has(path))throw Error('Unapproved production sessionStorage use: '+path);
   if(/\blocalStorage\b/.test(source)&&!['src/auth/AuthContext.tsx','src/i18n/I18nContext.tsx'].includes(path))throw Error('Unapproved production localStorage use: '+path);
  }
 }
 return graph;
}
