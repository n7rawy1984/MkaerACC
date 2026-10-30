import assert from 'node:assert/strict';
import { readFile } from 'node:fs/promises';
import { callbackInput } from '../src/platform/callbackInput.ts';
import { establishCallbackSession, assertPasswordSession } from '../src/platform/callbackSession.ts';

let checks = 0;
const base = 'https://maker-eosin.vercel.app/auth/callback';
const invitation = 'c0000000-0000-4000-8000-000000000001';
// Only substitute the two documented scalar placeholders; this is a URL contract
// test, not a claim to execute Supabase's hosted Go template renderer.
for (const type of ['invite', 'recovery']) {
  const template = await readFile(`supabase/templates/platform-${type}.html`, 'utf8');
  assert(!/ConfirmationURL|<script|<img|\.Token\s/.test(template)); checks++;
  const redirect = base + (type === 'invite' ? `?invitation_id=${invitation}` : '');
  const rendered = template.replaceAll('{{ if .RedirectTo }}{{ .RedirectTo }}{{ else }}{{ .SiteURL }}/auth/callback{{ end }}', redirect).replaceAll('{{ .RedirectTo }}', redirect).replaceAll('{{ .TokenHash }}', 'synthetic-hash');
  const url = new URL(rendered.match(/href="([^"]+)"/)[1].replaceAll('&amp;', '&'));
  assert.equal(url.origin, 'https://maker-eosin.vercel.app'); checks++;
  assert.equal(url.pathname, '/auth/callback'); checks++;
  assert.deepEqual(callbackInput(url), { kind: 'token', tokenHash: 'synthetic-hash', type }); checks++;
  assert.equal(url.searchParams.get('invitation_id'), type === 'invite' ? invitation : null); checks++;
}
const recoveryTemplate = await readFile('supabase/templates/platform-recovery.html', 'utf8');
const fallback = recoveryTemplate.replaceAll('{{ if .RedirectTo }}{{ .RedirectTo }}{{ else }}{{ .SiteURL }}/auth/callback{{ end }}', 'https://maker-eosin.vercel.app/auth/callback').replaceAll('{{ .TokenHash }}', 'synthetic-hash');
assert.equal(callbackInput(new URL(fallback.match(/href="([^"]+)"/)[1].replaceAll('&amp;', '&'))).type, 'recovery'); checks++;
assert.deepEqual(callbackInput(new URL(base + '?code=synthetic-code')), { kind: 'code', code: 'synthetic-code' }); checks++;
assert.deepEqual(callbackInput(new URL(base + `?invitation_id=${invitation}`)), { kind: 'session' }); checks++;
for (const query of [
  '?token_hash=a&type=invite&code=b', '?token_hash=a&type=invite&type=recovery',
  '?code=a&code=b', '?token_hash=a&token_hash=b&type=invite', '?code=',
  '?token_hash=a&type=magiclink', '?token_hash=a', '?type=recovery',
  '?error=access_denied', '?error_code=otp_expired', '?error_description=denied',
  '#access_token=synthetic', '?code=a#access_token=synthetic',
  `?invitation_id=${invitation}&invitation_id=${invitation}`,
]) { assert.throws(() => callbackInput(new URL(base + query)), /Unsupported callback/); checks++; }
const html = await readFile('index.html', 'utf8');
assert(html.indexOf('name="referrer" content="no-referrer"') < html.indexOf('src="/src/main.tsx"')); checks++;
const preview = JSON.parse(await readFile('deploy/platform-preview.vercel.json', 'utf8'));
assert(preview.rewrites.some(rule => rule.source === '/(.*)' && rule.destination === '/index.html')); checks++;
assert(preview.headers.find(rule => rule.source === '/(.*)').headers.some(h => h.key === 'Referrer-Policy' && h.value === 'no-referrer')); checks++;
assert(preview.headers.find(rule => rule.source === '/auth/callback').headers.some(h => h.key === 'Cache-Control' && h.value.includes('no-store'))); checks++;
// Model the provider's single-use verification contract, without real users/tokens.
let used = false, session = null, valid = true, codeType = 'recovery';
const user = { id: 'synthetic-user' };
const client = { auth: {
  verifyOtp: async ({token_hash}) => {
    if (used || token_hash !== 'synthetic-valid') return { data: { session: null, user: null }, error: new Error('Invalid/expired') };
    used = true; session = { user, access_token: 'synthetic-session' };
    return { data: { session, user }, error: null };
  },
  exchangeCodeForSession: async () => ({ data: { session, user, redirectType: codeType }, error: null }),
  getSession: async () => ({ data: { session }, error: null }),
  getUser: async () => ({ data: { user: valid ? user : null }, error: valid ? null : new Error('Revoked') }),
} };
const recoveryUrl = new URL(base + '?token_hash=synthetic-valid&type=recovery');
const proof = await establishCallbackSession(client, recoveryUrl);
assert.equal(proof.userId, user.id); checks++;
await assert.rejects(establishCallbackSession(client, recoveryUrl)); checks++;
await assert.rejects(establishCallbackSession(client, new URL(base + '?token_hash=synthetic-expired&type=recovery'))); checks++;
assert.equal(await establishCallbackSession(client, new URL(base)), null); checks++;
valid = false; await assert.rejects(assertPasswordSession(client, proof)); checks++;
valid = true; session = { user, access_token: 'different-session' };
await assert.rejects(assertPasswordSession(client, proof)); checks++;
session = null; await assert.rejects(assertPasswordSession(client, proof)); checks++;
await assert.rejects(establishCallbackSession(client, new URL(base + '?code=synthetic-code'))); checks++;
session = { user, access_token: 'synthetic-session' };
codeType = 'signup'; assert.equal(await establishCallbackSession(client, new URL(base + '?code=synthetic-code')), null); checks++;
codeType = 'recovery'; assert.equal((await establishCallbackSession(client, new URL(base + '?code=synthetic-code'))).userId, user.id); checks++;
console.log(`PASS: ${checks} callback/template assertions; synthetic inputs, no network or emails. Hosted rendering/delivery remains unverified.`);
