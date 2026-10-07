import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { bootstrapSql, DEVELOPMENT_PROJECT_REF } from './admin/bootstrap-development-platform-admin.mjs';
const identity='90ad5a98-2550-4c34-8455-cb904bcf76ab';
const base={platform_admin_user_id:identity,operator_user_id:identity};
const context={projectRef:DEVELOPMENT_PROJECT_REF,operatorSessionVerified:true};
let checks=0;
const check=fn=>{fn();checks++;};
check(()=>assert(bootstrapSql(base,context).endsWith('commit;\n')));
check(()=>assert(bootstrapSql(base,{...context,rollback:true}).endsWith('rollback;\n')));
for(const patch of [{projectRef:'production'},{projectRef:undefined},{operatorSessionVerified:false},{operatorSessionVerified:'true'}])check(()=>assert.throws(()=>bootstrapSql(base,{...context,...patch})));
for(const patch of [{platform_admin_user_id:'invalid'},{operator_user_id:null},{platform_admin_user_id:"'); drop table public.companies;--"},{status:'ACTIVE'},{role:'SYSTEM_ADMIN'},{password:'forbidden-input'}])check(()=>assert.throws(()=>bootstrapSql({...base,...patch},context)));
check(()=>assert.throws(()=>bootstrapSql(null,context)));
check(()=>assert.throws(()=>bootstrapSql([],context)));
check(()=>assert(!/insert into public\./i.test(bootstrapSql(base,context))));
check(()=>assert(!/update |delete |grant |security definer/i.test(bootstrapSql(base,context))));
console.log(`${checks} focused bootstrap generator checks passed`);
if(process.argv.includes('--hosted-sql')) {
 const block=input=>bootstrapSql(input,context).split('begin;\n')[1].replace(/commit;\n$/,'');
 const quote=s=>"'"+s.replaceAll("'","''")+"'";
 // Substitute a verified current synthetic Company member at SQL runtime; no identity chosen for real elevation.
 const dynamic=input=>`replace(${quote(block(input))},'${identity}',(select user_id::text from bootstrap_fixture))`;
 const reject=(label,input=base)=>`select pg_temp.expect_reject('${label}',${dynamic(input)});\n`;
 let sql=`begin;
create temporary table bootstrap_fixture as select m.user_id,m.company_id,m.role,m.status from public.company_memberships m join public.profiles p on p.user_id=m.user_id and p.status='ACTIVE' join public.companies c on c.id=m.company_id where c.code='V1-DEMO-20260929' and m.status='ACTIVE' order by m.id limit 1;
create function pg_temp.check_ok(label text,passed boolean) returns void language plpgsql as $$begin if passed is distinct from true then raise exception 'FAIL: %',label;end if;end;$$;
select pg_temp.check_ok('active demo fixture exists',(select count(*)=1 from bootstrap_fixture));
select pg_temp.check_ok('Development first-bootstrap registry empty',not exists(select 1 from private.system_administrators where status='ACTIVE'));
create temporary table bootstrap_before as select 'companies' as key,md5(string_agg(row_to_json(c)::text,'' order by id)) as hash from public.companies c union all select 'membership_identity',md5(string_agg(id::text||company_id::text||user_id::text,'' order by id)) from public.company_memberships union all select 'journals',md5(string_agg(row_to_json(j)::text,'' order by id)) from public.journal_entries j;
create temporary table bootstrap_memberships_before as select id,role,status from public.company_memberships where user_id=(select user_id from bootstrap_fixture);
create function pg_temp.expect_reject(label text,command text) returns void language plpgsql as $$begin begin execute command;exception when insufficient_privilege or check_violation or unique_violation then return;end;raise exception 'Unexpected success: %',label;end;$$;
`;
 sql+=reject('nonexistent target',{...base,platform_admin_user_id:'ffffffff-ffff-4fff-8fff-ffffffffffff'});
 sql+=reject('nonexistent operator',{...base,operator_user_id:'ffffffff-ffff-4fff-8fff-ffffffffffff'});
 sql+=`update public.profiles set status='INACTIVE' where user_id=(select user_id from bootstrap_fixture);\n`+reject('inactive profile')+`update public.profiles set status='ACTIVE' where user_id=(select user_id from bootstrap_fixture);\n`;
 for(const role of ['ACCOUNTING_ADMIN','MANAGEMENT_VIEWER','SYSTEM_ADMIN']) {
  sql+=`update public.company_memberships set role='${role}' where company_id=(select company_id from bootstrap_fixture) and user_id=(select user_id from bootstrap_fixture);\nselect set_config('request.jwt.claim.sub',(select user_id::text from bootstrap_fixture),true);\n`;
  // Resolve the command before role switch; fixture is operator-only.
  sql+=`select set_config('test.bootstrap_command',${dynamic(base)},true);\nset local role authenticated;\nselect pg_temp.expect_reject('${role} self-elevation',current_setting('test.bootstrap_command'));\nselect pg_temp.expect_reject('${role} direct registry insert','insert into private.system_administrators(user_id) values(auth.uid())');\nreset role;\n`;
 }
 sql+=`select set_config('test.bootstrap_command',${dynamic(base)},true);\nset local role service_role;\ndo $$begin execute current_setting('test.bootstrap_command');end;$$;\nreset role;\nselect pg_temp.check_ok('ACTIVE entry and exact provenance',(select count(*)=1 from private.system_administrators a join bootstrap_fixture f on f.user_id=a.user_id where a.status='ACTIVE' and a.created_by=f.user_id and a.updated_by=f.user_id));\n`;
 sql+=reject('duplicate bootstrap rejected');
 sql+=reject('second first-admin rejected',{...base,platform_admin_user_id:'ffffffff-ffff-4fff-8fff-ffffffffffff'});
 sql+=`update private.system_administrators set status='INACTIVE' where user_id=(select user_id from bootstrap_fixture);\n`+reject('inactive registry history not reactivated')+`update private.system_administrators set status='ACTIVE' where user_id=(select user_id from bootstrap_fixture);\n`;
 sql+=`select set_config('request.jwt.claim.sub',(select user_id::text from bootstrap_fixture),true);\nselect set_config('test.company_id',(select company_id::text from bootstrap_fixture),true);\nset local role authenticated;
select pg_temp.check_ok('Company SYSTEM_ADMIN still cannot post',not public.has_permission(current_setting('test.company_id')::uuid,'accounting.post'));
select pg_temp.check_ok('Company SYSTEM_ADMIN still cannot view accounting',not public.has_permission(current_setting('test.company_id')::uuid,'accounting.view'));
reset role;
update public.company_memberships set status='INACTIVE' where user_id=(select user_id from bootstrap_fixture);
set local role authenticated;
select pg_temp.check_ok('platform identity alone has no Company membership',not public.is_company_member(current_setting('test.company_id')::uuid));
select pg_temp.check_ok('platform identity alone has no accounting permission',not public.has_permission(current_setting('test.company_id')::uuid,'accounting.post'));
select pg_temp.check_ok('platform identity alone sees no Company',(select count(*)=0 from public.companies));
reset role;
`;
 // Restore temporary membership edits before comparing; all fixture work is still rolled back.
 sql+=`update public.company_memberships m set role=b.role,status=b.status from bootstrap_memberships_before b where m.id=b.id;
select pg_temp.check_ok('Company identity/demo unchanged',(select hash from bootstrap_before where key='companies')=(select md5(string_agg(row_to_json(c)::text,'' order by id)) from public.companies c));
`;
 // Updated timestamps from test role changes cannot equal before; compare membership identity/counts instead.
 sql+=`select pg_temp.check_ok('no cross-tenant membership created',(select hash from bootstrap_before where key='membership_identity')=(select md5(string_agg(id::text||company_id::text||user_id::text,'' order by id)) from public.company_memberships));
select pg_temp.check_ok('zero journal effects',(select hash from bootstrap_before where key='journals')=(select md5(string_agg(row_to_json(j)::text,'' order by id)) from public.journal_entries j));
select 'PASS: first-admin bootstrap, trusted execution, role denials, no accounting authority, duplicate/inactive guards; all fixtures rolled back' as result;
rollback;
`;
 writeFileSync('/tmp/development-platform-bootstrap-checks.sql',sql,{mode:0o600});
}
