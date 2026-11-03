// Synthetic ports only: no hosted requests, users, invitations or email delivery.
import assert from 'node:assert/strict';
import { deliveryHandler } from '../supabase/functions/platform-invitation-delivery/handler.mjs';
const primary = 'https://old.example.invalid', added = 'https://new.example.invalid';
const id = 'c0000000-0000-4000-8000-000000000001';
let checks = 0, calls = [], redirect;
const make = (patch = {}) => deliveryHandler({
  appOrigin: primary, additionalOrigins: JSON.stringify([added]),
  authorize: async () => { calls.push('authorize'); },
  claim: async () => { calls.push('claim'); return { id, email: 'test@example.invalid', lease_id: id }; },
  deliver: async (_email, url) => { calls.push('deliver'); redirect = url; },
  finish: async () => { calls.push('finish'); }, ...patch,
});
const options = origin => new Request('https://function.example.invalid', { method: 'OPTIONS', headers: { origin } });
for (const origin of [primary, added]) {
  calls = []; const r = await make()(options(origin));
  assert.equal(r.status, 204); assert.equal(await r.text(), '');
  assert.equal(r.headers.get('Access-Control-Allow-Origin'), origin);
  assert.equal(r.headers.get('Vary'), 'Origin');
  assert.equal(r.headers.get('Access-Control-Allow-Methods'), 'POST, OPTIONS');
  assert.equal(r.headers.get('Access-Control-Allow-Headers'), 'authorization, apikey, content-type, x-client-info');
  assert.equal(r.headers.get('Cache-Control'), 'no-store');
  assert.deepEqual(calls, []); checks += 8;
}
for (const origin of ['https://unknown.example.invalid', `${added}.attacker.invalid`, 'null', 'http://new.example.invalid']) {
  calls = []; const r = await make()(options(origin));
  assert.equal(r.status, 403); assert.notEqual(r.headers.get('Access-Control-Allow-Origin'), origin);
  assert.deepEqual(calls, []); checks += 3;
}
for (const additionalOrigins of ['bad-json', '{}', 'null', '[null]', '[1]', '["*"]', '["https://*.example.invalid"]', '["http://new.example.invalid"]', '["https://new.example.invalid/path"]', '["https://user:password@new.example.invalid"]', '["https://new.example.invalid?query=1"]', '["https://new.example.invalid#fragment"]']) {
  calls = []; const r = await make({ additionalOrigins })(options(primary));
  assert.equal(r.status, 503); assert.deepEqual(calls, []); checks += 2;
}
for (const origin of [primary, added]) {
  calls = []; const r = await make()(new Request('https://function.example.invalid', { method: 'POST', headers: { origin }, body: '{}' }));
  assert.equal(r.status, 403); assert.deepEqual(calls, []); checks += 2;
}
calls = [];
const r = await make()(new Request('https://function.example.invalid', { method: 'POST', headers: { origin: added, authorization: 'Bearer synthetic-only' }, body: JSON.stringify({ invitation_id: id }) }));
assert.equal(r.status, 200); assert.deepEqual(calls, ['authorize', 'claim', 'deliver', 'finish']);
assert.equal(redirect, `${primary}/auth/callback?invitation_id=${id}`); checks += 3;
assert.equal((await make({ additionalOrigins: undefined })(options(primary))).status, 204);
assert.equal((await make({ additionalOrigins: undefined })(options(added))).status, 403); checks += 2;
calls = [];
assert.equal((await make({ authorize: async () => { throw Error('Denied'); } })(new Request('https://function.example.invalid', { method: 'POST', headers: { origin: added, authorization: 'Bearer synthetic-only' }, body: JSON.stringify({ invitation_id: id }) }))).status, 403);
assert.deepEqual(calls, []); checks += 2;
console.log(`PASS: ${checks} origin/auth/callback contract assertions; synthetic ports only, no network or real email.`);
