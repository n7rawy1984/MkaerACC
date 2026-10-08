// Protected onboarding only. Never imported by browser code.
import { readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { resolve } from 'node:path';
import { spawnSync } from 'node:child_process';

export const DEVELOPMENT_PROJECT_REF = 'eqnzueginpkskbnqvgoc';
const root = fileURLToPath(new URL('../../', import.meta.url));
const uuid = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;
const types = ['ASSET', 'LIABILITY', 'EQUITY', 'REVENUE', 'EXPENSE'];
// Canonical account meanings, including the existing SALARY_PAYABLE constraint.
export const systemAccountTypes = Object.freeze({
  INPUT_VAT: 'ASSET', CUSTODY_ADVANCE: 'ASSET', SUBCONTRACTOR_ADVANCE: 'ASSET',
  SUPPLIER_PAYABLE: 'LIABILITY', SUBCONTRACTOR_PAYABLE: 'LIABILITY',
  SUBCONTRACTOR_RETENTION_PAYABLE: 'LIABILITY', SALARY_PAYABLE: 'LIABILITY',
  PROJECT_COST: 'EXPENSE',
  PROJECT_COST_SUBCONTRACTORS: 'EXPENSE', COMPANY_EXPENSE: 'EXPENSE',
});
const own = (object, key) => Object.prototype.hasOwnProperty.call(object, key);
const fieldsOnly = (value, allowed) => value && typeof value === 'object' && !Array.isArray(value)
  && Object.keys(value).every(key => allowed.includes(key));
function textField(value, max, label) {
  if (typeof value !== 'string' || !value.trim() || [...value.trim()].length > max) throw new Error(`Invalid ${label}`);
  return value.trim();
}

export function glProvisioningSql(input, { projectRef, approvedCompanyId, operatorSessionVerified = false, rollback = false } = {}) {
  if (projectRef !== DEVELOPMENT_PROJECT_REF) throw new Error('MakerACC-Development target required');
  if (operatorSessionVerified !== true) throw new Error('Verify protected operator identity, MFA and fresh session first');
  if (!fieldsOnly(input, ['operator_user_id', 'company_id', 'expected_company_code', 'accounts'])) throw new Error('Unsupported provisioning input');
  for (const key of ['operator_user_id', 'company_id']) if (typeof input[key] !== 'string' || !uuid.test(input[key])) throw new Error(`Invalid ${key}`);
  if (typeof approvedCompanyId !== 'string' || !uuid.test(approvedCompanyId)
    || approvedCompanyId.toLowerCase() !== input.company_id.toLowerCase()) throw new Error('Explicitly approved Company UUID must match input');
  const data = { operator_user_id: input.operator_user_id, company_id: input.company_id,
    expected_company_code: textField(input.expected_company_code, 50, 'expected_company_code'), accounts: [] };
  if (!Array.isArray(input.accounts) || !input.accounts.length) throw new Error('Accounts required');
  const codes = new Set(), keys = new Set();
  for (const account of input.accounts) {
    if (!fieldsOnly(account, ['code', 'name', 'account_type', 'system_key', 'requires_party'])) throw new Error('Unsupported account field');
    const code = textField(account.code, 50, 'code'), name = textField(account.name, 200, 'name');
    if (!types.includes(account.account_type)) throw new Error('Invalid canonical account_type');
    const key = account.system_key ?? null;
    if (key !== null && (typeof key !== 'string' || !own(systemAccountTypes, key) || systemAccountTypes[key] !== account.account_type)) throw new Error('Invalid system key/type compatibility');
    if (account.requires_party !== undefined && typeof account.requires_party !== 'boolean') throw new Error('requires_party must be boolean');
    if (codes.has(code.toLowerCase())) throw new Error('Duplicate normalized account code');
    if (key !== null && keys.has(key)) throw new Error('Duplicate system key');
    codes.add(code.toLowerCase()); if (key !== null) keys.add(key);
    data.accounts.push({ code, name, account_type: account.account_type, system_key: key, requires_party: account.requires_party ?? false });
  }
  const payload = JSON.stringify(data).replaceAll("'", "''");
  const typeMap = JSON.stringify(systemAccountTypes);
  let delimiter = '$gl_provision$';
  while (payload.includes(delimiter)) delimiter = delimiter.replace('$gl_provision', '$gl_provision_');
  return `-- DEVELOPMENT ONLY: ${DEVELOPMENT_PROJECT_REF}
-- Protected operator identity/MFA/fresh session verified out of band; UUID is provenance, not login proof.
-- New accounts only. No reassignment, takeover, upsert, financial entry or browser endpoint.
begin;
set local standard_conforming_strings = on;
do ${delimiter}
declare
 p jsonb := '${payload}'::jsonb;
 expected_types jsonb := '${typeMap}'::jsonb;
 operator_id uuid := (p->>'operator_user_id')::uuid;
 company_id_target uuid := (p->>'company_id')::uuid;
 account jsonb; new_id uuid;
begin
 if current_user not in ('postgres','service_role') then
  raise exception 'Trusted operator connection required' using errcode='42501';
 end if;
 perform 1 from private.system_administrators a join public.profiles pf on pf.user_id=a.user_id
  where a.user_id=operator_id and a.status='ACTIVE' and pf.status='ACTIVE' for share of a,pf;
 if not found then raise exception 'ACTIVE registered platform operator/profile required' using errcode='42501'; end if;
 -- Serialize provisioning for this Company and protect against concurrent deactivation.
 perform 1 from public.companies c where c.id=company_id_target
  and c.status='ACTIVE' and c.code=p->>'expected_company_code' for update of c;
 if not found then raise exception 'Expected ACTIVE Company identity required' using errcode='42501'; end if;
 for account in select value from jsonb_array_elements(p->'accounts') loop
  -- Cast against actual hosted enums; unknown future keys fail closed.
  perform (account->>'account_type')::public.account_type;
  if account->>'system_key' is not null then
   perform (account->>'system_key')::public.system_account_key;
   if not (expected_types ? (account->>'system_key'))
    or expected_types->>(account->>'system_key') is distinct from account->>'account_type' then
    raise exception 'System key/type mismatch' using errcode='23514';
   end if;
  end if;
  if exists(select 1 from public.accounts a where a.company_id=company_id_target
   and lower(btrim(a.code))=lower(btrim(account->>'code'))) then
   raise exception 'Account code already exists; no update performed' using errcode='23505';
  end if;
  if account->>'system_key' is not null and exists(select 1 from public.accounts a
   where a.company_id=company_id_target and a.system_key=(account->>'system_key')::public.system_account_key) then
   raise exception 'System key already assigned; no takeover performed' using errcode='23505';
  end if;
  insert into public.accounts(company_id,code,name,account_type,requires_party,system_key,status,created_by,updated_by)
   values(company_id_target,account->>'code',account->>'name',(account->>'account_type')::public.account_type,
    (account->>'requires_party')::boolean,(account->>'system_key')::public.system_account_key,'ACTIVE',operator_id,operator_id)
   returning id into new_id;
  raise notice 'Provisioned GL: %, Company: %, code: %',new_id,company_id_target,account->>'code';
 end loop;
end;
${delimiter};
${rollback ? 'rollback' : 'commit'};
`;
}

if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  const [inputPath, outputPath, ...flags] = process.argv.slice(2);
  const approvalIndex = flags.indexOf('--approved-company-id');
  const approvedCompanyId = approvalIndex < 0 ? undefined : flags[approvalIndex + 1];
  const switches = flags.filter((_, index) => index !== approvalIndex && index !== approvalIndex + 1);
  if (!inputPath || !outputPath || approvalIndex < 0 || !uuid.test(approvedCompanyId ?? '')
    || switches.some(flag => !['--operator-session-verified','--rollback','--apply'].includes(flag))
    || new Set(switches).size !== switches.length || flags.filter(flag => flag === '--approved-company-id').length !== 1) {
    throw new Error('Usage: node scripts/admin/provision-gl-accounts.mjs input.json new-output.sql --approved-company-id UUID --operator-session-verified [--rollback] [--apply]');
  }
  const projectRef = readFileSync(new URL('../../supabase/.temp/project-ref', import.meta.url), 'utf8').trim();
  const sql = glProvisioningSql(JSON.parse(readFileSync(inputPath, 'utf8')), {
    projectRef, approvedCompanyId, operatorSessionVerified: switches.includes('--operator-session-verified'), rollback: switches.includes('--rollback'),
  });
  writeFileSync(outputPath, sql, { flag: 'wx', mode: 0o600 });
  if (!switches.includes('--apply')) console.log('Development GL preview generated only; no database connection or mutation.');
  else {
    const result = spawnSync(`${root}node_modules/.bin/supabase`, ['db','query','--linked','--project-ref',DEVELOPMENT_PROJECT_REF,'--file',resolve(outputPath)], { cwd: root, stdio: 'inherit' });
    if (result.error) throw result.error;
    process.exitCode = result.status ?? 1;
  }
}
