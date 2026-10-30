// Offline allowlist guard only. Does not connect, deploy, apply SQL or read secrets.
import assert from 'node:assert/strict';
import { readFile, readdir } from 'node:fs/promises';
import { execFileSync } from 'node:child_process';
import { createHash } from 'node:crypto';

const target = 'eqnzueginpkskbnqvgoc';
const approvedHead = '9da8612ac0f9e9e92efa0b9eb417af0311cfc2e3';
const reviewedPlatformMigrations = {
  '20261028120000_platform_control_plane.sql': 'd28121ca9a804e35721de8656b1ffa5545c7edc2f35d49df0a6b9fed8a27ebbb',
  '20261028121000_platform_commands.sql': '7f53d28b7347efb0249c4ad31e1d16a0c0062508aea4242714746c9a9d0e004b',
  '20261028122000_platform_invitations.sql': '2e5cfb32416e2009ea2ffe5f6e303cbd5310c5e6173b46925f37858d39110fe4',
  '20261028123000_platform_invitation_revocation.sql': '923fb86fd9ea7dfaa917749ebc48abcbcd252fa9cc735f907f91e7dce4e16c26',
};
const git = (...args) => execFileSync('git', args, { maxBuffer: 16 * 1024 * 1024 });
let stage = 'arguments';
try {
  assert.equal(process.argv.length, 2);
  stage = 'HEAD';
  assert.equal(git('rev-parse', 'HEAD').toString().trim(), approvedHead);
  stage = 'linked target';
  assert.equal((await readFile('supabase/.temp/project-ref', 'utf8')).trim(), target);
  stage = 'local allowlist';
  const files = (await readdir('supabase/migrations')).filter(name => name.endsWith('.sql')).sort();
  assert.equal(files.length, 60);
  assert.deepEqual(files.slice(56), Object.keys(reviewedPlatformMigrations));
  stage = 'original canonical history';
  const originals = git('ls-tree', '-r', '--name-only', approvedHead, '--', 'supabase/migrations').toString().trim().split('\n').filter(name => name.endsWith('.sql'));
  assert.equal(originals.length, 56);
  assert.deepEqual(files.slice(0, 56), originals.map(path => path.split('/').at(-1)).sort());
  for (const path of originals) assert((await readFile(path)).equals(git('show', `${approvedHead}:${path}`)));
  stage = 'reviewed platform hashes';
  for (const [file, hash] of Object.entries(reviewedPlatformMigrations)) assert.equal(createHash('sha256').update(await readFile(`supabase/migrations/${file}`)).digest('hex'), hash);
  console.log(JSON.stringify({ offline_guard: 'PASS', target, original_migrations_unchanged: 56, reviewed_platform_allowlist: reviewedPlatformMigrations, remote_migration_state: 'not queried by this offline guard', hosted_connection: false, activation_authorized_by_guard: false }, null, 2));
} catch {
  console.error(`FAIL: release guard at ${stage}. No hosted action performed; inspect the reviewed release state and filesystem access.`);
  process.exitCode = 1;
}
