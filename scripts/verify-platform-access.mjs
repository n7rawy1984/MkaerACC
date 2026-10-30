import assert from 'node:assert/strict';
import { callPlatform, readPlatformContext, readPlatformOverview, readAuthenticatedPlatformContext, platformAuthRequest, transport, PlatformError } from '../src/platform/platformApi.ts';
let checks = 0;
const failed = error => ({rpc: async () => ({data:null,error})});
for (const [message,reason] of [['Denied','unauthorized'],['Session revoked','session_revoked']]) {
  await assert.rejects(readPlatformContext(failed({code:'42501',message})), e => {
    assert(e instanceof PlatformError); assert.equal(e.kind,'denied');
    assert.equal(e.operation,'get_platform_context'); assert.equal(e.code,'42501'); assert.equal(e.reason,reason);
    return true;
  }); checks++;
}
await assert.rejects(callPlatform(failed({code:'42501',message:'MFA_REQUIRED'}),'get_platform_overview'), e => e.kind==='mfa' && e.operation==='get_platform_overview'); checks++;
// Arbitrary provider text is neither retained nor rendered as a diagnostic.
await assert.rejects(readPlatformContext(failed({code:'unsafe synthetic details',message:'private synthetic details'})), e => e.code===undefined && e.reason===undefined && !JSON.stringify(e).includes('private synthetic')); checks++;
const owner={user_id:'b0000000-0000-4000-8000-000000000001',role:'PLATFORM_OWNER',step_up_required:true};
assert.deepEqual(await readPlatformContext({rpc:async()=>({data:owner,error:null})}),owner); checks++;
for (const data of [null,{...owner,role:'SYSTEM_ADMIN'},{...owner,step_up_required:undefined}]) {
  await assert.rejects(readPlatformContext({rpc:async()=>({data,error:null})}),e=>e.kind==='denied' && e.code==='INVALID_RESPONSE'); checks++;
}
let rpcCalls=0;
const stalledAuth={auth:{getSession:()=>new Promise(()=>{})},rpc:()=>{rpcCalls++;return Promise.resolve({data:owner,error:null});}};
await assert.rejects(readAuthenticatedPlatformContext(stalledAuth,{timeoutMs:15}),e=>e.operation==='auth_session'&&e.code==='REQUEST_TIMEOUT'); checks++;
assert.equal(rpcCalls,0); checks++;
await assert.rejects(readAuthenticatedPlatformContext({auth:{getSession:async()=>({data:{session:null},error:null})}},{timeoutMs:15}),e=>e.operation==='auth_session'&&e.code==='SIGN_IN_REQUIRED'); checks++;
let requestSignal;
await assert.rejects(readPlatformContext({rpc:(_name,_args,options)=>{requestSignal=options.signal;return new Promise(()=>{});}},{timeoutMs:15}),e=>e.operation==='get_platform_context'&&e.code==='REQUEST_TIMEOUT'); checks++;
assert.equal(requestSignal.aborted,true); checks++;
const controller=new AbortController();
const cancelled=readPlatformContext({rpc:()=>new Promise(()=>{})},{signal:controller.signal,timeoutMs:1000});
controller.abort();await assert.rejects(cancelled,e=>e.code==='REQUEST_CANCELLED'); checks++;
let attachedSignal;
const sdk={rpc:()=>({then:done=>Promise.resolve(done({data:owner,error:null})),abortSignal(signal){attachedSignal=signal;return this;}})};
assert.deepEqual(await readPlatformContext(transport(sdk)),owner); checks++;
assert(attachedSignal instanceof AbortSignal); checks++;
await assert.rejects(callPlatform({rpc:()=>new Promise(()=>{})},'get_platform_overview',undefined,{timeoutMs:15}),e=>e.operation==='get_platform_overview'&&e.code==='REQUEST_TIMEOUT'); checks++;
await assert.rejects(platformAuthRequest('mfa_factors',()=>new Promise(()=>{}),{timeoutMs:15}),e=>e.operation==='mfa_factors'&&e.code==='REQUEST_TIMEOUT'); checks++;
await assert.rejects(platformAuthRequest('mfa_verify',async()=>({error:{code:'mfa_verification_failed'}})),e=>e.operation==='mfa_verify'&&e.code==='mfa_verification_failed'); checks++;
await assert.rejects(platformAuthRequest('auth_session',async()=>({error:{code:'refresh_token_not_found'}})),e=>e.operation==='auth_session'&&e.code==='refresh_token_not_found'&&e.reason==='session_revoked'); checks++;
const overview={entities:0,active:0,customers:0,users:1,pending_setup:0,pending_invitations:0,delivery_failures:0,suspended:0,archived:0,checked_at:'2026-10-29T13:00:00Z'};
assert.deepEqual(await readPlatformOverview({rpc:async()=>({data:overview,error:null})}),overview); checks++;
for (const data of [null,{}, {...overview,users:'1'}, {...overview,checked_at:'invalid'}]) {
  await assert.rejects(readPlatformOverview({rpc:async()=>({data,error:null})}),e=>e.operation==='get_platform_overview'&&e.code==='INVALID_RESPONSE'); checks++;
}
console.log(`PASS: ${checks} platform access assertions; bounded Auth/RPC waits, cancellation, SDK abort propagation, exact errors and MFA/owner enforcement. No network.`);
