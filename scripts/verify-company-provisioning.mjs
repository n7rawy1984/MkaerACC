import assert from 'node:assert/strict';
import { writeFileSync } from 'node:fs';
import { provisioningSql } from './admin/provision-company.mjs';
const user='90ad5a98-2550-4c34-8455-cb904bcf76ab';
const base={operator_user_id:user,initial_admin_user_id:user,code:'SYNTHETIC-COMPANY-PROVISION-CHECK',name:'Synthetic tenant — شركة اختبار',tenant_slug:'synthetic-company-provision-check',default_locale:'ar'};
let checks=0;
const check=fn=>{fn();checks++;};
check(()=>assert(provisioningSql(base).endsWith('commit;\n')));
check(()=>assert(provisioningSql(base,{rollback:true}).endsWith('rollback;\n')));
for(const patch of [{role:'SYSTEM_ADMIN'},{status:'INACTIVE'},{currency:'USD'},{operator_user_id:'bad'},{initial_admin_user_id:null},{code:' '},{name:'x'.repeat(201)},{tenant_slug:'INVALID'},{default_locale:'fr'},{logo_url:'javascript:alert(1)'},{accent_color:'red'}])check(()=>assert.throws(()=>provisioningSql({...base,...patch})));
check(()=>assert(provisioningSql({...base,name:"O'Brien $provision$ \\ '\nشركة"}).includes('do $provision_$')));
check(()=>assert(provisioningSql({...base,name:"O'Brien"}).includes("O''Brien")));
check(()=>assert(!/insert into public\.(accounts|expenses|journal_entries|parties|projects|treasury_accounts)/i.test(provisioningSql(base))));
console.log(`${checks} focused generator checks passed`);
if(process.argv.includes('--hosted-sql')) {
 const body=input=>provisioningSql(input).split('do ')[1].split('\ncommit;')[0];
 const block=input=>'do '+body(input);
 const quote=s=>"'"+s.replaceAll("'","''")+"'";
 const reject=(label,input)=>`select pg_temp.expect_reject(${quote(label)},${quote(block(input))});\n`;
 let sql=`begin;\ncreate temporary table before_snapshot as select 'demo' as key, md5(string_agg(row_to_json(c)::text,'' order by id)) as hash from public.companies c where code='V1-DEMO-20260929' union all select 'journals',md5(string_agg(row_to_json(j)::text,'' order by id)) from public.journal_entries j;\ncreate function pg_temp.check_ok(label text, passed boolean) returns void language plpgsql as $$begin if passed is distinct from true then raise exception 'FAIL: %',label; end if; end;$$;\ncreate function pg_temp.expect_reject(label text, command text) returns void language plpgsql as $$begin begin execute command; exception when insufficient_privilege or unique_violation or check_violation then return; end; raise exception 'Unexpected success: %',label;end;$$;\n`;
 sql+=reject('unregistered operator',base);
 sql+=`insert into private.system_administrators(user_id,status) values('${user}','ACTIVE') on conflict(user_id) do update set status='ACTIVE';\n`;
 sql+=`update public.profiles set status='INACTIVE' where user_id='${user}';\n`+reject('inactive operator profile',base)+`update public.profiles set status='ACTIVE' where user_id='${user}';\n`;
 sql+=block(base)+'\n';
 sql+=`select pg_temp.check_ok('atomic three-row Company foundation', (select count(*)=1 from public.companies c join public.company_settings s on s.company_id=c.id join public.company_memberships m on m.company_id=c.id where c.code='${base.code}' and c.status='ACTIVE' and m.status='ACTIVE' and m.role='ACCOUNTING_ADMIN' and m.user_id='${user}' and s.default_locale='ar' and c.created_by='${user}' and m.created_by='${user}' and s.created_by='${user}'));\n`;
 sql+=reject('duplicate code atomic rejection',base);
 sql+=block({...base,code:'SYNTHETIC-COMPANY-ESCAPING-CHECK',tenant_slug:'synthetic-company-escaping-check',name:"O'Brien $provision$ \\ شركة"})+'\n';
 sql+=`select pg_temp.check_ok('literal SQL metacharacters preserved',(select name='O''Brien $provision$ \\ شركة' from public.companies where code='SYNTHETIC-COMPANY-ESCAPING-CHECK'));\n`;
 sql+=reject('duplicate slug atomic rejection',{...base,code:base.code+'-2'});
 sql+=reject('missing initial Auth profile',{...base,code:base.code+'-3',tenant_slug:base.tenant_slug+'-3',initial_admin_user_id:'ffffffff-ffff-4fff-8fff-ffffffffffff'});
 sql+=`update private.system_administrators set status='INACTIVE' where user_id='${user}';\n`+reject('inactive operator',{...base,code:base.code+'-4',tenant_slug:base.tenant_slug+'-4'})+`update private.system_administrators set status='ACTIVE' where user_id='${user}';\n`;
 sql+=`select set_config('request.jwt.claim.sub','${user}',true);\n`;
 for(const role of ['ACCOUNTING_ADMIN','MANAGEMENT_VIEWER','SYSTEM_ADMIN']) {
  sql+=`update public.company_memberships set role='${role}' where company_id=(select id from public.companies where code='${base.code}');\nset local role authenticated;\n`;
  sql+=reject(role+' cannot run operator procedure',{...base,code:base.code+'-5',tenant_slug:base.tenant_slug+'-5'});
  sql+=`select pg_temp.expect_reject('${role} Company INSERT','insert into public.companies(code,name) values(''UNAUTHORIZED'',''Unauthorized'')');\nselect pg_temp.expect_reject('${role} membership INSERT','insert into public.company_memberships(company_id,user_id,role) select id,''${user}'',''ACCOUNTING_ADMIN'' from public.companies limit 1');\nselect pg_temp.check_ok('${role} own tenant settings visible',(select count(*)=1 from public.company_settings where tenant_slug='${base.tenant_slug}'));\nreset role;\n`;
 }
 sql+=`insert into public.companies(code,name) values('SYNTHETIC-COMPANY-FOREIGN-CHECK','Synthetic foreign tenant');\nselect set_config('request.jwt.claim.sub','${user}',true);\nselect set_config('app.current_company_id',(select id::text from public.companies where code='SYNTHETIC-COMPANY-FOREIGN-CHECK'),true);\nset local role authenticated;\nselect pg_temp.check_ok('selected foreign tenant grants no read',(select count(*)=0 from public.companies where code='SYNTHETIC-COMPANY-FOREIGN-CHECK'));\nreset role;\n`;
 sql+=`select pg_temp.check_ok('failed attempts left no partial Companies',(select count(*)=1 from public.companies where code like '${base.code}%'));\n`;
 // Inspect only counts for the new fixture across tenant-owned tables, not financial flows.
 sql+=`do $$declare t record; n bigint; cid uuid; begin select id into cid from public.companies where code='${base.code}'; for t in select table_name from information_schema.columns where table_schema='public' and column_name='company_id' and table_name not in ('company_settings','company_memberships') loop execute format('select count(*) from public.%I where company_id=$1',t.table_name) into n using cid; if n<>0 then raise exception 'Provisioning created unexpected rows in %',t.table_name;end if;end loop;end;$$;\n`;
 sql+=`select pg_temp.check_ok('demo identity unchanged',(select hash from before_snapshot where key='demo')=(select md5(string_agg(row_to_json(c)::text,'' order by id)) from public.companies c where code='V1-DEMO-20260929'));\nselect pg_temp.check_ok('all journal history unchanged',(select hash from before_snapshot where key='journals')=(select md5(string_agg(row_to_json(j)::text,'' order by id)) from public.journal_entries j));\nselect 'PASS: atomic Company foundation, role denials, isolation, no business records, unchanged demo/journals' as result;\nrollback;\n`;
 writeFileSync('/tmp/company-provisioning-hosted-checks.sql',sql,{mode:0o600});
}
