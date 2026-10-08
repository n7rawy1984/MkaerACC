import assert from 'node:assert/strict';
import { mkdtempSync, writeFileSync, readFileSync, statSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { randomUUID } from 'node:crypto';
import { spawnSync } from 'node:child_process';
import { DEVELOPMENT_PROJECT_REF, glProvisioningSql, systemAccountTypes } from './admin/provision-gl-accounts.mjs';

const operator = randomUUID(), company = randomUUID();
const base = { operator_user_id: operator, company_id: company, expected_company_code: 'SYNTHETIC-GL-CHECK',
  accounts: [{ code: 'TEST-ASSET', name: 'Synthetic asset', account_type: 'ASSET' },
    { code: 'TEST-COST', name: 'Synthetic overhead', account_type: 'EXPENSE', system_key: 'COMPANY_EXPENSE' }] };
const options = { projectRef: DEVELOPMENT_PROJECT_REF, approvedCompanyId: company, operatorSessionVerified: true };
let checks = 0;
const check = fn => { fn(); checks++; };
check(() => assert(glProvisioningSql(base, options).endsWith('commit;\n')));
check(() => assert(glProvisioningSql(base, { ...options, rollback: true }).endsWith('rollback;\n')));
for (const patch of [{ projectRef: 'other-project' }, { approvedCompanyId: randomUUID() }, { operatorSessionVerified: false }, { approvedCompanyId: undefined }]) {
  check(() => assert.throws(() => glProvisioningSql(base, { ...options, ...patch })));
}
for (const patch of [{ operator_user_id: 'bad' }, { company_id: 'bad' }, { expected_company_code: ' ' }, { accounts: [] }, { accounts: null }, { currency: 'AED' }]) {
  check(() => assert.throws(() => glProvisioningSql({ ...base, ...patch }, options)));
}
for (const patch of [{ code: ' ' }, { name: 'x'.repeat(201) }, { account_type: 'INVALID' }, { account_type: 'EXPENSE', system_key: 'INPUT_VAT' },
  { system_key: 'UNKNOWN' }, { system_key: 'toString' }, { account_type: 'EQUITY', system_key: 'OWNER_CURRENT' },
  { requires_party: 'false' }, { id: randomUUID() }, { company_id: randomUUID() }, { status: 'INACTIVE' }]) {
  check(() => assert.throws(() => glProvisioningSql({ ...base, accounts: [{ ...base.accounts[0], ...patch }] }, options)));
}
check(() => assert.throws(() => glProvisioningSql({ ...base, accounts: [base.accounts[0], { ...base.accounts[0], code: ' test-asset ' }] }, options)));
check(() => assert.throws(() => glProvisioningSql({ ...base, accounts: [base.accounts[1], { ...base.accounts[1], code: 'OTHER' }] }, options)));
for (const [system_key, account_type] of Object.entries(systemAccountTypes)) {
  check(() => assert(glProvisioningSql({ ...base, accounts: [{ code: 'KEY', name: 'Synthetic', account_type, system_key }] }, options).includes(`"system_key":"${system_key}"`)));
}
check(() => assert(glProvisioningSql({ ...base, accounts: [{ ...base.accounts[0], name: "O'Brien $gl_provision$ \\ شركة" }] }, options).includes('do $gl_provision_$')));
check(() => assert(!/\b(update|delete|alter|grant|revoke)\s+(public\.|private\.|table)/i.test(glProvisioningSql(base, options))));
check(() => assert.deepEqual([...glProvisioningSql(base, options).matchAll(/insert into (\S+)/g)].map(x => x[1]), ['public.accounts(company_id,code,name,account_type,requires_party,system_key,status,created_by,updated_by)']));

const folder = mkdtempSync(join(tmpdir(), 'gl-provisioning-check-'));
const inputPath = join(folder, 'input.json'), outputPath = join(folder, 'preview.sql');
writeFileSync(inputPath, JSON.stringify(base), { mode: 0o600 });
const args = ['scripts/admin/provision-gl-accounts.mjs', inputPath, outputPath, '--approved-company-id', company, '--operator-session-verified', '--rollback'];
check(() => assert.equal(spawnSync(process.execPath, args, { encoding: 'utf8' }).status, 0));
check(() => assert.equal(statSync(outputPath).mode & 0o777, 0o600));
check(() => assert.equal(readFileSync(outputPath, 'utf8'), glProvisioningSql(base, { ...options, rollback: true })));
check(() => assert.notEqual(spawnSync(process.execPath, args, { encoding: 'utf8' }).status, 0));
check(() => assert.notEqual(spawnSync(process.execPath, args.filter(x => x !== '--operator-session-verified'), { encoding: 'utf8' }).status, 0));
console.log(`${checks} focused GL generator/CLI checks passed; preview directory: ${folder}`);

if (process.argv.includes('--hosted-sql')) {
  const operatorIndex = process.argv.indexOf('--operator-user-id');
  const approvedOperator = process.argv[operatorIndex + 1];
  if (operatorIndex < 0 || !/^[0-9a-f-]{36}$/i.test(approvedOperator ?? '')) throw new Error('Existing approved operator UUID required for hosted checks');
  const fixtureCompany = randomUUID(), foreignCompany = randomUUID(), ordinaryActor = randomUUID();
  const fixtureCode = `SYNTHETIC-GL-${fixtureCompany.slice(0, 8)}`;
  const fixture = { ...base, operator_user_id: approvedOperator, company_id: fixtureCompany, expected_company_code: fixtureCode };
  const sqlOptions = { ...options, approvedCompanyId: fixtureCompany };
  const block = input => {
    const sql = glProvisioningSql(input, sqlOptions);
    return sql.slice(sql.indexOf('do '), sql.lastIndexOf('\ncommit;'));
  };
  const quote = value => "'" + value.replaceAll("'", "''") + "'";
  const reject = (label, command, state) => `select pg_temp.reject(${quote(label)},${quote(command)},'${state}');\n`;
  const ok = (label, expression) => `select pg_temp.ok(${quote(label)},${expression});\n`;
  let sql = `begin;
create temporary table gl_results(label text primary key, passed boolean);
grant select,insert on gl_results to authenticated,service_role;
create function pg_temp.ok(label text, passed boolean) returns void language plpgsql as $$begin
 if passed is distinct from true then raise exception 'FAIL: %',label; end if;
 insert into pg_temp.gl_results values(label,true); end;$$;
create function pg_temp.reject(label text, command text, expected_state text) returns void language plpgsql as $$declare actual_state text; begin
 begin execute command; exception when others then get stacked diagnostics actual_state=returned_sqlstate;
  if actual_state=expected_state then insert into pg_temp.gl_results values(label,true); return; end if;
  raise exception 'FAIL: %, expected %, got %',label,expected_state,actual_state;
 end; raise exception 'FAIL: unexpected success: %',label; end;$$;
insert into auth.users(id,email,raw_user_meta_data) values('${ordinaryActor}','synthetic-gl-${ordinaryActor}@example.invalid','{"display_name":"Synthetic GL actor"}');
insert into public.companies(id,code,name) values('${fixtureCompany}','${fixtureCode}','Synthetic GL verification'),('${foreignCompany}','${fixtureCode}-B','Synthetic unrelated Company');
insert into public.company_memberships(company_id,user_id,role) values('${fixtureCompany}','${ordinaryActor}','ACCOUNTING_ADMIN');
`;
  sql += ok('platform operator has no fixture membership', `(select count(*)=0 from public.company_memberships where company_id='${fixtureCompany}' and user_id='${approvedOperator}')`);
  sql += reject('unregistered Company admin rejected on trusted connection', block({ ...fixture, operator_user_id: ordinaryActor }), '42501');
  sql += `insert into private.system_administrators(user_id,status) values('${ordinaryActor}','INACTIVE');\n`;
  sql += reject('inactive operator registry rejected', block({ ...fixture, operator_user_id: ordinaryActor }), '42501');
  sql += `update private.system_administrators set status='ACTIVE' where user_id='${ordinaryActor}';
update public.profiles set status='INACTIVE' where user_id='${ordinaryActor}';\n`;
  sql += reject('inactive operator profile rejected', block({ ...fixture, operator_user_id: ordinaryActor }), '42501');
  sql += `update public.profiles set status='ACTIVE' where user_id='${ordinaryActor}';
update private.system_administrators set status='INACTIVE' where user_id='${ordinaryActor}';\n`;
  for (const role of ['ACCOUNTING_ADMIN', 'SYSTEM_ADMIN', 'ACCOUNTANT']) {
    sql += `update public.company_memberships set role='${role}' where company_id='${fixtureCompany}' and user_id='${ordinaryActor}';
set local request.jwt.claim.sub='${ordinaryActor}';
set local role authenticated;
`;
    sql += reject(`${role} cannot execute protected block`, block(fixture), '42501');
    sql += reject(`${role} cannot directly insert account`, `insert into public.accounts(company_id,code,name,account_type) values('${fixtureCompany}','DENIED','Denied','ASSET')`, '42501');
    sql += reject(`${role} cannot assign system key`, `update public.accounts set system_key='COMPANY_EXPENSE' where company_id='${fixtureCompany}'`, '42501');
    sql += 'reset role;\n';
  }
  sql += reject('wrong Company UUID/code cannot redirect provisioning', block({ ...fixture, expected_company_code: `${fixtureCode}-B` }), '42501');
  sql += `update public.companies set status='INACTIVE' where id='${fixtureCompany}';\n`;
  sql += reject('inactive Company rejected', block(fixture), '42501');
  sql += `update public.companies set status='ACTIVE' where id='${fixtureCompany}';\n`;
  sql += reject('invalid hosted enum rejected', block(fixture).replaceAll('"account_type":"ASSET"', '"account_type":"INVALID"'), '22P02');
  sql += reject('hosted system/type mismatch rejected', block(fixture).replaceAll('"account_type":"EXPENSE"', '"account_type":"ASSET"'), '23514');
  sql += 'set local role service_role;\n' + block(fixture) + '\nreset role;\n';
  sql += ok('ordinary Asset retains no system key', `(select count(*)=1 from public.accounts where company_id='${fixtureCompany}' and code='TEST-ASSET' and account_type='ASSET' and system_key is null and not requires_party and status='ACTIVE')`);
  sql += ok('COMPANY_EXPENSE maps to Expense', `(select count(*)=1 from public.accounts where company_id='${fixtureCompany}' and code='TEST-COST' and account_type='EXPENSE' and system_key='COMPANY_EXPENSE' and status='ACTIVE')`);
  sql += ok('operator provenance retained', `(select count(*)=2 from public.accounts where company_id='${fixtureCompany}' and created_by='${approvedOperator}' and updated_by='${approvedOperator}')`);
  sql += reject('duplicate normalized code rejected', block({ ...fixture, accounts: [{ ...base.accounts[0], code: ' test-asset ' }] }), '23505');
  sql += reject('existing system key cannot be taken over', block({ ...fixture, accounts: [{ ...base.accounts[1], code: 'OTHER-COST' }] }), '23505');
  sql += reject('batch failure atomic', block({ ...fixture, accounts: [{ ...base.accounts[0], code: 'MUST-ROLL-BACK' }, base.accounts[1]] }), '23505');
  sql += ok('failed batch retained no first account', `(select count(*)=0 from public.accounts where company_id='${fixtureCompany}' and code='MUST-ROLL-BACK')`);
  sql += ok('no foreign Company accounts', `(select count(*)=0 from public.accounts where company_id='${foreignCompany}')`);
  sql += `do $$declare t record; n bigint; begin
 for t in select c.relname from pg_catalog.pg_class c join pg_catalog.pg_namespace ns on ns.oid=c.relnamespace
 where ns.nspname='public' and c.relkind in ('r','p') and c.relname not in ('accounts','company_memberships')
 and exists(select 1 from pg_catalog.pg_attribute a where a.attrelid=c.oid and a.attname='company_id' and not a.attisdropped) loop
 execute format('select count(*) from public.%I where company_id=$1',t.relname) into n using '${fixtureCompany}'::uuid;
 if n<>0 then raise exception 'Unexpected business rows in %',t.relname; end if;
 end loop; perform pg_temp.ok('zero financial/business rows in synthetic Company',true); end;$$;
select count(*) as passing_checks, bool_and(passed) as all_passed from gl_results;
rollback;
`;
  const path = join(folder, 'hosted.sql'); writeFileSync(path, sql, { mode: 0o600 });
  writeFileSync(join(folder, 'fixtures.json'), JSON.stringify({ fixtureCompany, foreignCompany, ordinaryActor }), { mode: 0o600 });
  console.log(`Development rollback-only hosted checks: ${path}`);
}
