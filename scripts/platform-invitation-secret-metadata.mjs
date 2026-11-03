// Local Stage C verification only. No network, credentials, or hosted mutations.
import { createHash } from 'node:crypto';

export const providerSecretNames = Object.freeze([
  'SUPABASE_ANON_KEY', 'SUPABASE_DB_URL', 'SUPABASE_JWKS',
  'SUPABASE_PUBLISHABLE_KEYS', 'SUPABASE_SECRET_KEYS',
  'SUPABASE_SERVICE_ROLE_KEY', 'SUPABASE_URL',
]);
const providerNames = new Set(providerSecretNames);
const originName = 'PLATFORM_APP_ORIGIN';
const origin = 'https://maker-5mmm1t4w9-n7rawy1984-8059s-projects.vercel.app';
const sha256 = value => createHash('sha256').update(value).digest('hex');
const canonical = value => JSON.stringify(Object.fromEntries(Object.entries(value).sort(([a], [b]) => a.localeCompare(b))));

// API `value` is a digest, not the credential. Retain only its hash plus
// non-secret metadata, never the API value itself. Unknown schema fails closed.
export function captureSecretMetadata(rows) {
  if (!Array.isArray(rows)) throw Error('Invalid secret metadata response');
  const entries = Object.create(null);
  for (const row of rows) {
    if (!row || typeof row !== 'object' || Array.isArray(row)
      || Object.keys(row).sort().join(',') !== 'name,updated_at,value'
      || typeof row.name !== 'string' || !/^[A-Za-z_][A-Za-z0-9_]*$/.test(row.name)
      || typeof row.value !== 'string' || !/^[a-f0-9]{64}$/.test(row.value)
      || typeof row.updated_at !== 'string' || !Number.isFinite(Date.parse(row.updated_at))) {
      throw Error('Unrecognized secret metadata schema');
    }
    if (Object.hasOwn(entries, row.name)) throw Error('Duplicate secret metadata name');
    if (row.name.startsWith('SUPABASE_') && !providerNames.has(row.name)) {
      throw Error('Unreviewed provider metadata name');
    }
    entries[row.name] = {
      kind: providerNames.has(row.name) ? 'provider' : 'user_managed',
      digestFingerprint: sha256(row.value),
      updatedAt: row.updated_at,
      recordFingerprint: sha256(canonical(row)),
    };
  }
  for (const name of providerSecretNames) {
    if (!Object.hasOwn(entries, name)) throw Error('Required provider metadata absent');
  }
  return { schemaVersion: 1, entries };
}

// Run against snapshots captured by this module in the same approved execution.
// Retry baseline requires all seven initialized defaults and no origin setting.
export function verifySecretMetadata(before, after, { originState } = {}) {
  if (!['present', 'absent'].includes(originState)) throw Error('Explicit origin state required');
  if (before.schemaVersion !== 1 || after.schemaVersion !== 1) throw Error('Snapshot schema mismatch');
  if (Object.hasOwn(before.entries, originName)) throw Error('Origin baseline must be absent');
  const names = Object.keys(before.entries).sort();
  const expected = [...names, ...(originState === 'present' ? [originName] : [])].sort();
  if (JSON.stringify(Object.keys(after.entries).sort()) !== JSON.stringify(expected)) {
    throw Error('Unexpected secret metadata addition or removal');
  }
  const providerTimestampChanges = [];
  for (const name of names) {
    const a = before.entries[name], b = after.entries[name];
    if (a.kind !== b.kind || a.digestFingerprint !== b.digestFingerprint) {
      throw Error('Secret digest or ownership changed');
    }
    if (providerNames.has(name)) {
      if (a.updatedAt !== b.updatedAt) providerTimestampChanges.push(name);
    } else if (a.recordFingerprint !== b.recordFingerprint) {
      throw Error('User-managed secret metadata changed');
    }
  }
  if (originState === 'present'
    && after.entries[originName].digestFingerprint !== sha256(sha256(origin))) {
    throw Error('Approved origin digest mismatch');
  }
  return { verified: true, providerTimestampChanges, allDigestsPreserved: true };
}
