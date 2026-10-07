// Development-only protected operator tooling. Never imported by browser code.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { spawnSync } from 'node:child_process';
import { resolve } from 'node:path';

export const DEVELOPMENT_PROJECT_REF = 'eqnzueginpkskbnqvgoc';
const root = fileURLToPath(new URL('../../', import.meta.url));
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function bootstrapSql(input, { projectRef, operatorSessionVerified = false, rollback = false } = {}) {
  if (projectRef !== DEVELOPMENT_PROJECT_REF) throw new Error('MakerACC-Development target required');
  // Attestation documents the protected operator check, not proof of application authentication.
  if (operatorSessionVerified !== true) throw new Error('Verify authorized operator identity, MFA and fresh protected session first');
  const fields = ['platform_admin_user_id', 'operator_user_id'];
  if (!input || typeof input !== 'object' || Array.isArray(input) || Object.keys(input).some(k => !fields.includes(k))) throw new Error('Only existing identity UUIDs accepted');
  for (const k of fields) if (typeof input[k] !== 'string' || !uuid.test(input[k])) throw new Error(`${k} must be an existing Auth UUID`);
  return `-- DEVELOPMENT ONLY: ${DEVELOPMENT_PROJECT_REF}
-- First-administrator exception: protected operator/MFA authorization verified out of band.
-- UUID attribution is not login proof. Execute only through the guarded Development CLI.
begin;
do $bootstrap$
declare
  target_id uuid := '${input.platform_admin_user_id}'::uuid;
  operator_id uuid := '${input.operator_user_id}'::uuid;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'Trusted operator connection required' using errcode='42501';
  end if;
  -- Serialize first-bootstrap calls without adding a permanent database object.
  perform pg_catalog.pg_advisory_xact_lock(718026, 1);
  if exists(select 1 from private.system_administrators where status='ACTIVE') then
    raise exception 'First administrator already bootstrapped; no replacement or elevation performed' using errcode='23514';
  end if;
  if exists(select 1 from private.system_administrators where user_id=target_id) then
    raise exception 'Target registry history already exists; reactivation requires separate authorization' using errcode='23514';
  end if;
  -- profiles.user_id FK proves the Auth identity exists; no auth.users SELECT privilege needed.
  perform 1 from public.profiles p
    where p.user_id=target_id and p.status='ACTIVE' for share of p;
  if not found then raise exception 'Target requires existing Auth identity and ACTIVE profile' using errcode='42501'; end if;
  -- profiles.user_id FK proves the Auth identity exists; no auth.users SELECT privilege needed.
  perform 1 from public.profiles p
    where p.user_id=operator_id and p.status='ACTIVE' for share of p;
  if not found then raise exception 'Operator requires existing Auth identity and ACTIVE profile' using errcode='42501'; end if;
  insert into private.system_administrators(user_id,status,created_by,updated_by)
    values(target_id,'ACTIVE',operator_id,operator_id);
  raise notice 'Development first platform administrator registered: %',target_id;
end;
$bootstrap$;
${rollback ? 'rollback' : 'commit'};
`;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [inputPath, outputPath, ...flags] = process.argv.slice(2);
  if (!inputPath || !outputPath || flags.some(f => !['--operator-session-verified', '--rollback', '--apply'].includes(f)) || new Set(flags).size !== flags.length) throw new Error('Usage: node scripts/admin/bootstrap-development-platform-admin.mjs input.json new-output.sql --operator-session-verified [--rollback] [--apply]');
  const linkedRef = readFileSync(new URL('../../supabase/.temp/project-ref', import.meta.url), 'utf8').trim();
  const sql = bootstrapSql(JSON.parse(readFileSync(inputPath, 'utf8')), { projectRef: linkedRef, operatorSessionVerified: flags.includes('--operator-session-verified'), rollback: flags.includes('--rollback') });
  writeFileSync(outputPath, sql, { flag: 'wx', mode: 0o600 });
  if (!flags.includes('--apply')) {
    console.log('Development SQL generated only. No database connection or user elevation. Review inputs and SQL before authorized execution.');
  } else {
    // Explicit fixed project ref, not mutable linked selection. No caller-provided SQL or credentials.
    const result = spawnSync(`${root}node_modules/.bin/supabase`, ['db', 'query', '--linked', '--project-ref', DEVELOPMENT_PROJECT_REF, '--file', resolve(outputPath)], { cwd: root, stdio: 'inherit' });
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
  }
}
