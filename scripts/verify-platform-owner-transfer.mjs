// Review preparation only: disposable local database, no hosted connection.
import assert from 'node:assert/strict';
import {readFileSync} from 'node:fs';
import {platformTestDatabase} from './verify-platform-database.mjs';
const sql=readFileSync('docs/release/development-owner-transfer.sql','utf8');
const previous='e1ef565b-c54d-4b52-bba3-360a03da7aa3';
const target='ebcf7115-6cd9-49be-af25-8e57b5befd75';
const other='d0000000-0000-4000-8000-000000000001';
const company='d0000000-0000-4000-8000-000000000002';
const targetSession='d0000000-0000-4000-8000-000000000003';
const oldSession='d0000000-0000-4000-8000-000000000004';
const operation='d362061b-17d0-4eb2-9a9b-3d690fc8a817';
const {db}=await platformTestDatabase();let checks=0;
const q=async(s,args=[]) => (await db.query(s,args)).rows;
const check=(v,label)=>{assert(v,label);checks++;};
const approved=(project='eqnzueginpkskbnqvgoc')=>sql.replace('begin;\n',`begin;\nselect set_config('narvo.verified_project_ref','${project}',true);\nselect set_config('narvo.owner_transfer_approval','${operation}',true);\n`);
async function snapshot() {
  const result={};
  for(const table of ['auth.users','auth.sessions','auth.mfa_factors','public.profiles','public.companies','public.company_memberships','public.journal_entries','public.journal_lines','public.accounts']) {
    result[table]=(await q(`select md5(coalesce(jsonb_agg(to_jsonb(t) order by to_jsonb(t)::text),'[]'::jsonb)::text) hash from ${table} t`))[0].hash;
  }
  return result;
}
async function denied(source,code,label) {
  const before=await q('select user_id,status,platform_role,platform_access_epoch from private.system_administrators order by user_id');
  await assert.rejects(db.exec(source),e=>e.code===code,label);await db.exec('rollback');
  assert.deepEqual(await q('select user_id,status,platform_role,platform_access_epoch from private.system_administrators order by user_id'),before);
  check((await q('select count(*)::int n from private.platform_events'))[0].n===0,label+' is atomic and unaudited on failure');
}
try {
  for(const [uid,email] of [[previous,'previous@example.invalid'],[target,'intended@example.invalid'],[other,'accountant@example.invalid']]) {
    await q('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,email]);
  }
  await q('insert into auth.sessions(id,user_id,aal) values($1,$2,\'aal1\'),($3,$4,\'aal2\')',[targetSession,target,oldSession,previous]);
  await q('insert into private.system_administrators(user_id,created_by,updated_by) values($1,$1,$1)',[previous]);
  await q("insert into public.companies(id,code,name) values($1,'TRANSFER-TEST','Synthetic protected Company')",[company]);
  await q("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'ACCOUNTING_ADMIN')",[company,other]);
  const accountDebit='d0000000-0000-4000-8000-000000000005';
  const accountCredit='d0000000-0000-4000-8000-000000000006';
  const journal='d0000000-0000-4000-8000-000000000007';
  await q("insert into public.accounts(id,company_id,code,name,account_type) values($1,$3,'1100','Synthetic asset','ASSET'),($2,$3,'5100','Synthetic cost','EXPENSE')",[accountDebit,accountCredit,company]);
  await db.exec('begin');
  await q("insert into public.journal_entries(id,company_id,journal_reference,posting_date,description,source_type,source_id,posting_purpose) values($1,$2,'TRANSFER-TEST-1',current_date,'Synthetic immutable history','TEST',$1,'POST')",[journal,company]);
  await q('insert into public.journal_lines(company_id,journal_entry_id,line_number,account_id,debit_minor,credit_minor) values($1,$2,1,$3,12345,0),($1,$2,2,$4,0,12345)',[company,journal,accountDebit,accountCredit]);
  await db.exec('commit');

  await denied(sql,'42501','missing execution approval rejected');
  await denied(approved('wrong-project'),'42501','wrong verified project rejected');
  await db.exec('set role authenticated');
  await assert.rejects(db.exec(approved()),e=>e.code==='42501');await db.exec('rollback;reset role');checks++;
  await q("update private.system_administrators set status='INACTIVE' where user_id=$1",[previous]);
  await denied(approved(),'23514','source authority drift rejected');
  await q("update private.system_administrators set status='ACTIVE' where user_id=$1",[previous]);
  await q("update public.profiles set status='INACTIVE' where user_id=$1",[target]);
  await denied(approved(),'23514','inactive target rejected');
  await q("update public.profiles set status='ACTIVE' where user_id=$1",[target]);
  await q('update auth.users set email_confirmed_at=null where id=$1',[target]);
  await denied(approved(),'23514','unconfirmed target rejected');
  await q('update auth.users set email_confirmed_at=now(),banned_until=now()+interval \'1 day\' where id=$1',[target]);
  await denied(approved(),'23514','banned target rejected');
  await q('update auth.users set banned_until=null where id=$1',[target]);
  await q('insert into private.system_administrators(user_id) values($1)',[other]);
  await denied(approved(),'23514','additional registry history rejected');
  await q('delete from private.system_administrators where user_id=$1',[other]);
  await q("insert into public.company_memberships(company_id,user_id,role) values($1,$2,'MANAGEMENT_VIEWER')",[company,target]);
  await denied(approved(),'23514','unexpected target membership rejected');
  await q('delete from public.company_memberships where user_id=$1',[target]);
  await db.exec('alter table private.system_administrators disable trigger platform_registry_epoch');
  await denied(approved(),'23514','missing epoch advancement rolls back entire transfer');
  await db.exec('alter table private.system_administrators enable trigger platform_registry_epoch');

  const before=await snapshot();
  const epoch=(await q('select platform_access_epoch from private.system_administrators where user_id=$1',[previous]))[0].platform_access_epoch;
  await db.exec(approved());
  const registry=await q('select user_id,status,platform_role,platform_access_epoch from private.system_administrators order by user_id');
  check(registry.length===2&&registry.filter(x=>x.status==='ACTIVE').length===1,'exactly one ACTIVE owner; original history retained');
  check(registry.some(x=>x.user_id===previous&&x.status==='INACTIVE'&&BigInt(x.platform_access_epoch)===BigInt(epoch)+1n),'old authority is inactive with advanced epoch');
  check(registry.some(x=>x.user_id===target&&x.status==='ACTIVE'&&x.platform_role==='PLATFORM_OWNER'),'selected existing Auth identity authorized');
  assert.deepEqual(await snapshot(),before);checks++;
  const audit=await q('select actor_id,action,target_id,request_id,metadata from private.platform_events');
  check(audit.length===1&&audit[0].actor_id===target&&audit[0].request_id===operation&&audit[0].metadata.application_mfa_bypassed===false,'one explicit operational audit event with truthful attribution');

  const as=async(uid,session,query)=>db.transaction(async tx=>{
    await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:uid,session_id:session,aal:'aal1'})]);
    await tx.exec('set local role authenticated');return (await tx.query(query)).rows;
  });
  check((await as(target,targetSession,'select public.get_platform_context() result'))[0].result.step_up_required===true,'transferred identity still requires real MFA');
  await assert.rejects(as(target,targetSession,'select public.get_platform_overview()'),e=>e.code==='42501'&&e.message==='MFA_REQUIRED');checks++;
  await assert.rejects(as(previous,oldSession,'select public.get_platform_context()'),e=>e.code==='42501');checks++;
  check((await as(target,targetSession,'select count(*)::int n from public.journal_entries'))[0].n===0,'owner transfer grants no Company financial visibility');
  const afterRegistry=await q('select to_jsonb(a) data from private.system_administrators a order by user_id');
  await assert.rejects(db.exec(approved()),e=>e.code==='23514');await db.exec('rollback');
  assert.deepEqual(await q('select to_jsonb(a) data from private.system_administrators a order by user_id'),afterRegistry);
  check((await q('select count(*)::int n from private.platform_events'))[0].n===1,'replay fails without duplicate effects or audit');
  console.log(`PASS: ${checks} guarded owner-transfer assertions. Local disposable PostgreSQL only; Auth/profile/MFA/session, memberships and balanced financial history preserved; real MFA still required. NO hosted transfer.`);
} finally {await db.close();}
