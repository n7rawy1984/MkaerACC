import assert from 'node:assert/strict';
import {readFileSync, readdirSync} from 'node:fs';
import {createRequire} from 'node:module';
import ts from 'typescript';
const require=createRequire(import.meta.url);
const source=readFileSync(new URL('../src/attendance/attendanceRepository.ts',import.meta.url),'utf8');
const module={exports:{}};
new Function('require','module','exports',ts.transpileModule(source,{compilerOptions:{module:ts.ModuleKind.CommonJS,target:ts.ScriptTarget.ES2022}}).outputText)(require,module,module.exports);
const api=module.exports;
const id=n=>`93000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const entry={id:id(5),company_id:id(1),employee_id:id(3),project_id:id(4),absence_date:'2026-09-01',kind:'HALF_DAY',note:null,voided:false,version:3,created_by:id(2),updated_by:id(2)};
assert.equal(api.absenceHalfUnits([entry,{...entry,kind:'FULL_DAY'},{...entry,voided:true}]),3);
assert.deepEqual(api.exceptionInput(id(1),id(4),id(3),'2026-09-01','FULL_DAY',' note ',entry,true,' reason '),{
 target_company_id:id(1),target_project_id:id(4),target_employee_id:id(3),target_date:'2026-09-01',target_kind:'FULL_DAY',target_note:'note',target_version:3,target_void:true,target_reason:'reason'});
for(const date of ['2026-02-29','2026-09-31','not-a-date'])assert.equal(api.validDate(date),false);
assert(api.validDate('2028-02-29'));
assert.throws(()=>api.exceptionInput(id(1),id(4),id(3),'2026-09-01','HALF_DAY','',entry,false,' '));
assert.throws(()=>api.exceptionInput(id(1),id(4),id(3),'2026-09-01','QUARTER_DAY','',null,false,''));
assert.throws(()=>api.exceptionInput(id(1),id(4),id(3),'2026-09-01','HALF_DAY','',null,true,''));
for(const role of ['FOREMAN','ACCOUNTING_ADMIN','ACCOUNTANT','PROJECT_MANAGER','DATA_ENTRY','PROCUREMENT','MANAGEMENT_VIEWER','SYSTEM_ADMIN']) {
 assert.equal(api.attendanceRole(role),['FOREMAN','ACCOUNTING_ADMIN','ACCOUNTANT'].includes(role));
 assert.equal(api.canCorrectAttendance(role,id(2),entry,false),['FOREMAN','ACCOUNTING_ADMIN'].includes(role));
 assert.equal(api.canCorrectAttendance(role,id(9),entry,false),role==='ACCOUNTING_ADMIN');
 assert.equal(api.canCorrectAttendance(role,id(2),entry,true),false);
}
const {createClient}=require('@supabase/supabase-js');const sent=[];
const client=createClient('https://example.invalid','public-test-key',{auth:{persistSession:false,autoRefreshToken:false,detectSessionInUrl:false},global:{fetch:async(url,init)=>{
 sent.push({url:String(url),body:JSON.parse(init.body)});return new Response(JSON.stringify(id(5)),{headers:{'Content-Type':'application/json'}});
}}});
client.auth.getSession=async()=>({data:{session:{user:{id:id(2)}}},error:null});
const args=api.exceptionInput(id(1),id(4),id(3),'2026-09-01','HALF_DAY','',null,false,'');
assert.equal(await api.attendanceRequest(client,id(2),'save_attendance_exception',args),id(5));
assert(sent[0].url.endsWith('/rpc/save_attendance_exception'));assert.deepEqual(sent[0].body,args);
await assert.rejects(api.attendanceRequest(client,id(8),'save_attendance_exception',args),/session changed/);assert.equal(sent.length,1);
await assert.rejects(api.attendanceRequest(client,id(2),'save_attendance_exception',args,()=>false),/session changed/);assert.equal(sent.length,1);
for(const file of readdirSync(new URL('../src/attendance/',import.meta.url))){
 const text=readFileSync(new URL(`../src/attendance/${file}`,import.meta.url),'utf8');
 assert(!/\.from\(|\.(insert|update|delete|upsert)\(|localStorage|sessionStorage|AppDataContext|service_role/.test(text),file);
}
const routes=readFileSync(new URL('../src/auth/ProtectedApplication.tsx',import.meta.url),'utf8');
assert(routes.indexOf('state.activeTenant.role === "FOREMAN"')<routes.indexOf('<ProductionMasterDataProvider'));
assert(routes.includes('<Navigate to="/attendance" replace />'));
const migration=readFileSync(new URL('../supabase/migrations/20260927121000_attendance_lite.sql',import.meta.url),'utf8');
assert(!/create_journal|reverse_journal|salary_minor|payroll_profile/i.test(migration));
console.log('Attendance focused repository PASS: exact business payload, half units, dates, correction ownership, lock gates, session changes, real SDK transport and no financial/demo/direct-write access.');
