import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { captureSecretMetadata, verifySecretMetadata, providerSecretNames } from './platform-invitation-secret-metadata.mjs';

const hash = value => createHash('sha256').update(value).digest('hex');
const timestamp = '2026-10-31T19:41:12.943Z';
const row = name => ({ name, value: hash(`synthetic-metadata-${name}`), updated_at: timestamp });
const defaults = providerSecretNames.map(row);
const beforeRows = [...defaults, row('EXISTING_CUSTOM_SETTING')];
const before = captureSecretMetadata(beforeRows);
const origin = { name: 'PLATFORM_APP_ORIGIN', value: hash('https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app'), updated_at: timestamp };
const afterRows = [...beforeRows, origin];
let count = 0;
function test(run) { run(); count++; }
const check = rows => verifySecretMetadata(before, captureSecretMetadata(rows), { originState: 'present' });
const change = (name, patch) => afterRows.map(x => x.name === name ? { ...x, ...patch } : x);

test(() => assert.equal(check(afterRows).verified, true));
test(() => assert.equal(check([...afterRows].reverse()).verified, true));
test(() => assert.deepEqual(check(change('SUPABASE_DB_URL', { updated_at: '2026-11-01T00:00:00Z' })).providerTimestampChanges, ['SUPABASE_DB_URL']));
test(() => assert.throws(() => check(change('EXISTING_CUSTOM_SETTING', { updated_at: '2026-11-01T00:00:00Z' }))));
test(() => assert.throws(() => check(change('EXISTING_CUSTOM_SETTING', { value: hash('changed') }))));
test(() => assert.throws(() => check(change('SUPABASE_DB_URL', { value: hash('changed') }))));
test(() => assert.throws(() => check([...afterRows, row('UNAPPROVED_SETTING')])));
test(() => assert.throws(() => check(afterRows.filter(x => x.name !== 'EXISTING_CUSTOM_SETTING'))));
test(() => assert.throws(() => check(afterRows.filter(x => x.name !== 'SUPABASE_DB_URL'))));
test(() => assert.throws(() => check([...afterRows, row('SUPABASE_FUTURE_DEFAULT')])));
test(() => assert.throws(() => check(change('SUPABASE_DB_URL', { extra: true }))));
test(() => assert.throws(() => check(change('SUPABASE_DB_URL', { value: 'not-a-digest' }))));
test(() => assert.throws(() => check([...afterRows, origin])));
test(() => assert.throws(() => check(change('PLATFORM_APP_ORIGIN', { value: hash('wrong-origin') }))));
test(() => assert.throws(() => check(beforeRows)));
test(() => assert.equal(verifySecretMetadata(before, captureSecretMetadata(beforeRows), { originState: 'absent' }).verified, true));
test(() => assert.throws(() => verifySecretMetadata(captureSecretMetadata(afterRows), captureSecretMetadata(afterRows), { originState: 'present' })));
test(() => assert.throws(() => verifySecretMetadata(before, captureSecretMetadata(afterRows), {})));
test(() => { for (const entry of Object.values(before.entries)) assert(!Object.hasOwn(entry, 'value')); });
console.log(`PASS ${count}/${count} local Stage C metadata checks; synthetic digests only, no network or hosted changes.`);
