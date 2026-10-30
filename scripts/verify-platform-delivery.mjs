import assert from 'node:assert/strict';
import {readFile} from 'node:fs/promises';
import {deliveryHandler} from '../supabase/functions/platform-invitation-delivery/handler.mjs';
const id='c0000000-0000-4000-8000-000000000001',lease='c0000000-0000-4000-8000-000000000002';let checks=0,sends=0,finishes=[];
const make=patch=>deliveryHandler({appOrigin:'https://app.example.invalid',authorize:async()=>{},claim:async()=>({id,email:'synthetic@example.invalid',lease_id:lease}),deliver:async(email,url)=>{sends++;assert.equal(email,'synthetic@example.invalid');assert.equal(url,`https://app.example.invalid/auth/callback?invitation_id=${id}`);},finish:async(...args)=>{finishes.push(args);},...patch});
const request=(patch={})=>new Request('https://service.example.invalid',{method:'POST',headers:{authorization:'Bearer synthetic-fixture-only',origin:'https://app.example.invalid','content-type':'application/json',...patch.headers},body:JSON.stringify(patch.body??{invitation_id:id})});
let response=await make()(request());assert.equal(response.status,200);assert.equal((await response.json()).status,'DELIVERED');assert.equal(sends,1);assert.equal(finishes[0][2],'DELIVERED');checks+=4;
for(const req of [request({headers:{origin:'https://foreign.example.invalid'}}),request({body:{invitation_id:id,email:'forged@example.invalid'}}),request({body:{invitation_id:'bad'}}),new Request('https://service.example.invalid',{method:'POST',body:'{}'})]){response=await make()(req);assert(response.status>=400);checks++;}
for(const patch of [{authorize:async()=>{throw Error('Denied');}},{claim:async()=>{throw Error('Stale MFA');}}]){response=await make(patch)(request());assert.equal(response.status,403);checks++;}
assert.equal(sends,1);checks++;
response=await make({deliver:async()=>{throw Error('Never expose provider detail');}})(request());assert.equal(response.status,502);assert.equal(finishes.at(-1)[2],'AUTH_DELIVERY_FAILED');assert(!(await response.text()).includes('provider detail'));checks+=3;
response=await make({finish:async()=>{throw Error('Lost acknowledgement');}})(request());assert.equal(response.status,503);assert.equal((await response.json()).error,'DELIVERY_UNCERTAIN');checks+=2;
response=await make({appOrigin:''})(request());assert.equal(response.status,503);checks++;
response=await make()(new Request('https://service.example.invalid',{method:'OPTIONS',headers:{origin:'https://app.example.invalid'}}));assert.equal(response.status,204);checks++;
const example=await readFile('supabase/functions/platform-invitation-delivery/.env.example','utf8');
const approvedOrigin=example.match(/^PLATFORM_APP_ORIGIN=(.+)$/m)?.[1];
assert.equal(approvedOrigin,'https://maker-eosin.vercel.app');checks++;
let preparedRedirect;
response=await make({appOrigin:approvedOrigin,deliver:async(_email,url)=>{preparedRedirect=url;}})(request({headers:{origin:approvedOrigin}}));
assert.equal(response.status,200);checks++;
assert.equal(preparedRedirect,`${approvedOrigin}/auth/callback?invitation_id=${id}`);checks++;
console.log(`PASS: ${checks} trusted-delivery contract assertions; mocked ports only, zero emails/network requests.`);

const sendsBefore=sends;
response=await make({claim:async()=>{throw Error('MFA_REQUIRED');}})(request());
assert.equal(response.status,403);assert.equal((await response.json()).error,'MFA_REQUIRED');assert.equal(sends,sendsBefore);
console.log('PASS: stale-MFA delivery returns safe actionable code before any email attempt.');
