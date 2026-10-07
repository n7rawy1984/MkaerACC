// Operator-only SQL generator. Never imported by the browser; never connects to a database.
import { readFileSync, writeFileSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
export function provisioningSql(input, { rollback = false } = {}) {
  const allowed = ['operator_user_id', 'initial_admin_user_id', 'code', 'name', 'legal_name', 'trn', 'address', 'notes', 'tenant_slug', 'default_locale', 'app_display_name', 'logo_url', 'favicon_url', 'primary_color', 'accent_color'];
  if (!input || Array.isArray(input) || typeof input !== 'object' || Object.keys(input).some(k => !allowed.includes(k))) throw new Error('Unsupported Company input');
  const data = {};
  for (const [k, v] of Object.entries(input)) {
    if (v !== null && typeof v !== 'string') throw new Error(`${k} must be text or null`);
    data[k] = v === null ? null : v.trim();
  }
  for (const k of ['operator_user_id', 'initial_admin_user_id']) if (!uuid.test(data[k] ?? '')) throw new Error(`${k} must be an existing Auth user UUID`);
  for (const [k, max] of [['code', 50], ['name', 200]]) if (!data[k] || [...data[k]].length > max) throw new Error(`Invalid ${k}`);
  if (!/^[a-z0-9]+(?:-[a-z0-9]+)*$/.test(data.tenant_slug ?? '') || data.tenant_slug.length < 3 || data.tenant_slug.length > 63) throw new Error('Invalid tenant_slug');
  if (!['en', 'ar'].includes(data.default_locale)) throw new Error('default_locale must be en or ar');
  if (data.app_display_name && [...data.app_display_name].length > 200) throw new Error('Invalid app_display_name');
  for (const k of ['logo_url', 'favicon_url']) if (data[k] && (data[k].length > 2048 || !/^https:\/\/[^\s]+$/.test(data[k]))) throw new Error(`Invalid ${k}`);
  for (const k of ['primary_color', 'accent_color']) if (data[k] && !/^#[0-9a-f]{6}$/i.test(data[k])) throw new Error(`Invalid ${k}`);
  // Single-quoted JSON with doubled quotes, standard_conforming_strings explicitly enabled.
  const payload = JSON.stringify(data).replaceAll("'", "''");
  let delimiter = '$provision$';
  while (payload.includes(delimiter)) delimiter = delimiter.replace('$provision', '$provision_');
  return `-- Reviewed operator-only provisioning. Execute only after MFA/fresh-session verification.
-- No existing Company or membership is updated. Replay/duplicate code or slug fails atomically.
begin;
set local standard_conforming_strings = on;
do ${delimiter}
declare
  p jsonb := '${payload}'::jsonb;
  operator_id uuid := (p->>'operator_user_id')::uuid;
  admin_id uuid := (p->>'initial_admin_user_id')::uuid;
  company_id_new uuid;
begin
  if current_user not in ('postgres', 'service_role') then
    raise exception 'Trusted operator connection required' using errcode = '42501';
  end if;
  perform 1 from private.system_administrators a join public.profiles pf on pf.user_id=a.user_id
    where a.user_id=operator_id and a.status='ACTIVE' and pf.status='ACTIVE' for share of a,pf;
  if not found then raise exception 'Active registered platform operator required' using errcode='42501'; end if;
  perform 1 from public.profiles where user_id=admin_id and status='ACTIVE' for share;
  if not found then raise exception 'Initial administrator requires an existing active Auth profile' using errcode='42501'; end if;
  insert into public.companies(code,name,legal_name,trn,address,notes,status,created_by,updated_by)
    values(p->>'code',p->>'name',nullif(p->>'legal_name',''),nullif(p->>'trn',''),nullif(p->>'address',''),nullif(p->>'notes',''),'ACTIVE',operator_id,operator_id)
    returning id into company_id_new;
  insert into public.company_settings(company_id,tenant_slug,default_locale,app_display_name,logo_url,favicon_url,primary_color,accent_color,created_by,updated_by)
    values(company_id_new,p->>'tenant_slug',(p->>'default_locale')::public.app_locale,nullif(p->>'app_display_name',''),nullif(p->>'logo_url',''),nullif(p->>'favicon_url',''),coalesce(nullif(p->>'primary_color',''),'#0f172a'),coalesce(nullif(p->>'accent_color',''),'#2563eb'),operator_id,operator_id);
  insert into public.company_memberships(company_id,user_id,role,status,created_by,updated_by)
    values(company_id_new,admin_id,'ACCOUNTING_ADMIN','ACTIVE',operator_id,operator_id);
  raise notice 'Company provisioned: %, code: %; initial ACCOUNTING_ADMIN: %',company_id_new,p->>'code',admin_id;
end;
${delimiter};
${rollback ? 'rollback' : 'commit'};
`;
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [inputPath, outputPath, option] = process.argv.slice(2);
  if (!inputPath || !outputPath || (option && option !== '--rollback')) throw new Error('Usage: node scripts/admin/provision-company.mjs input.json output.sql [--rollback]');
  writeFileSync(outputPath, provisioningSql(JSON.parse(readFileSync(inputPath, 'utf8')), { rollback: option === '--rollback' }), { flag: 'wx', mode: 0o600 });
  console.log('Operator SQL generated. No database connection or mutation performed.');
}
