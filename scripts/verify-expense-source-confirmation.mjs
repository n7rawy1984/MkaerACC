import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {createRequire} from 'node:module';
const require=createRequire(import.meta.url),ts=require('typescript');
function load(path,mocks={}){const module={exports:{}};const code=ts.transpileModule(readFileSync(new URL('../'+path,import.meta.url),'utf8'),{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022,jsx:ts.JsxEmit.ReactJSX}}).outputText;new Function('require','module','exports',code)(n=>mocks[n]??require(n),module,module.exports);return module.exports;}
const repository=load('src/financial/expensePostRepository.ts'),id=n=>`90000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const input={date:'2026-09-23',category:id(2),treasury:id(3),description:'Paid supplies',net:'125.50',method:'CASH'};
const calls=[];let accept=false,confirmations=0,vat='ZERO';
globalThis.window={sessionStorage:{},confirm(message){confirmations++;assert.ok(message.includes('125.50 AED'));return accept;}};
const OriginalFormData=globalThis.FormData;globalThis.FormData=class{get(name){return input[name]??'';}};
let stateIndex=0;
const React={useEffect(){},useRef:v=>({current:v}),useState(initial){const value=typeof initial==='function'?initial():initial;return [stateIndex++===8?vat:value,()=>{}];}};
// Substitute only side effects and UI hooks; run real normalization and submit implementation.
const {TreasuryExpensePost}=load('src/financial/TreasuryExpensePost.tsx',{
 react:React,'../i18n/I18nContext':{useT:()=>k=>k},'../lib/supabase':{getSupabaseClient:()=>({auth:{getSession:async()=>({data:{session:{user:{id:id(1)}}}})}})},
 '../master/productionMasterDataContext':{useProductionMasterData:()=>({phase:'READY',projects:[],parties:[],expenseCategories:[{companyId:id(4),id:id(2),status:'ACTIVE'}],treasuryAccounts:[{companyId:id(4),id:id(3),status:'ACTIVE',projectId:null}]})},
 './expensePostRepository':repository,'./expensePostAttempt':{loadAttempt:()=>null,saveAttempt:(_s,a)=>calls.push(a),sendAttempt:async()=>{throw Error('synthetic unresolved');}},
 './expenseRepository':{displayMinor:v=>(BigInt(v)/100n)+'.'+(BigInt(v)%100n).toString().padStart(2,'0')}
});
function find(node,predicate){if(!node||typeof node!=='object')return null;if(predicate(node))return node;for(const child of [node.props?.children].flat(Infinity)){const found=find(child,predicate);if(found)return found;}return null;}
try{
 const tree=TreasuryExpensePost({userId:id(1),companyId:id(4),role:'ACCOUNTING_ADMIN',onPosted(){},source:{id:id(5),date:input.date,description:input.description,treasuryId:id(3),categoryId:id(2),grossMinor:'12550'}});
 assert.equal(find(tree,n=>n.props?.name==='net').props.defaultValue,'125.50');
 const form=find(tree,n=>n.type==='form');form.props.onSubmit({preventDefault(){},currentTarget:{}});
 assert.equal(confirmations,1);assert.equal(calls.length,0,'Cancellation must not persist or send a posting attempt');
 accept=true;form.props.onSubmit({preventDefault(){},currentTarget:{}});assert.equal(calls.length,1);assert.equal(calls[0].input.netMinor,'12550');assert.equal(calls[0].sourceId,id(5));
 await new Promise(resolve=>setTimeout(resolve,0));
 console.log('PASS: exact source prefill; cancel confirmation has no posting attempt; accepted confirmation preserves exact source ID and amount.');
}finally{globalThis.FormData=OriginalFormData;delete globalThis.window;}
