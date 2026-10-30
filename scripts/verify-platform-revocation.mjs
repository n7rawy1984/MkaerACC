// Permanent P0 regression matrix. All identities and data are synthetic/local.
import assert from 'node:assert/strict';
import {randomUUID} from 'node:crypto';
import {readFileSync} from 'node:fs';
import {resolve} from 'node:path';
import {pathToFileURL} from 'node:url';
import {platformTestDatabase} from './verify-platform-database.mjs';
export async function platformRevocationFixture(db) {
 const owner=randomUUID(),admin=randomUUID(),member=randomUUID();
 const sessions=new Map([[owner,randomUUID()],[admin,randomUUID()],[member,randomUUID()]]);
 const email=`member-${member}@example.invalid`;
 const q=async(sql,args=[]) => (await db.query(sql,args)).rows;
 const claims=uid=>({sub:uid,session_id:sessions.get(uid),aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]});
 async function as(uid,sql,args=[]) { return db.transaction(async tx=>{
  await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify(claims(uid))]);
  await tx.exec('set local role authenticated'); return (await tx.query(sql,args)).rows;
 }); }
 const cmd=(name,input,key=randomUUID())=>as(owner,'select public.platform_admin_command($1,$2,$3::jsonb) r',[name,key,JSON.stringify(input)]).then(r=>r[0].r);
 const inviteCommand=(name,input,key=randomUUID())=>as(owner,'select public.platform_invitation_command($1,$2,$3::jsonb) r',[name,key,JSON.stringify(input)]).then(r=>r[0].r);
 for(const [uid,mail] of [[owner,`owner-${owner}@example.invalid`],[admin,`admin-${admin}@example.invalid`],[member,email]]) {
  await q('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,mail]);
  await q('insert into auth.sessions(id,user_id) values($1,$2)',[sessions.get(uid),uid]);
 }
 await q('insert into private.system_administrators(user_id) values($1)',[owner]);
 const factor=(await q("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified') returning id",[owner]))[0].id;
 await q('update auth.sessions set factor_id=$1 where user_id=$2',[factor,owner]);
 async function entity() {
  const slug=`security-${randomUUID()}`;
  const c=await cmd('create_entity',{code:slug,name:'Synthetic P0 ledger',tenant_slug:slug,locale:'en',entity_kind:'BUSINESS',initial_admin_id:admin});
  await cmd('set_lifecycle',{id:c.id,version:'1',state:'ACTIVE',reason:'Synthetic activation'});return c.id;
 }
 const version=async cid=>String((await q('select version from private.platform_entities where company_id=$1',[cid]))[0].version);
 const membership=async(cid,role,key=randomUUID())=>cmd('set_membership',{company_id:cid,user_id:member,role,version:await version(cid),reason:`Synthetic ${role} decision`},key);
 const invite=(cid,role='ACCOUNTANT',key=randomUUID())=>inviteCommand('invite',{company_id:cid,email,role},key);
 const accept=id=>as(member,'select public.accept_platform_invitation($1) cid',[id]);
 const permissions=async cid=>(await as(member,"select public.is_company_member($1) member,public.has_permission($1,'accounting.view') view,public.has_permission($1,'accounting.post') post",[cid]))[0];
 const status=async(value,key=randomUUID())=>cmd('set_user_status',{id:member,version:(await q('select updated_at::text v from public.profiles where user_id=$1',[member]))[0].v,status:value,reason:`Synthetic user ${value}`},key);
 return {db,q,as,cmd,inviteCommand,owner,admin,member,email,sessions,claims,entity,version,membership,invite,accept,permissions,status};
}
export async function verifyPlatformRevocation(db) {
 const f=await platformRevocationFixture(db);const {q,as,cmd,inviteCommand,owner,admin,member,email,entity,version,membership,invite,accept,permissions,status,sessions}=f;
 let checks=0;
 const check=(v,label)=>{assert(v,label);checks++;};
 const denied=async(fn,label,codes=['42501'])=>{await assert.rejects(fn,e=>codes.includes(e.code),label);checks++;};
 const cid=await entity(),other=await entity();
 const originalGrantKey=randomUUID(),originalGrantInput={company_id:cid,user_id:member,role:'ACCOUNTANT',version:await version(cid),reason:'Synthetic original grant'};
 await cmd('set_membership',originalGrantInput,originalGrantKey);await membership(other,'ACCOUNTANT');
 const unrelated=await entity(),unrelatedInvite=await invite(unrelated);
 const oldKey=randomUUID(),old=await invite(cid,'ACCOUNTANT',oldKey);
 const lease=(await as(owner,'select public.claim_platform_delivery($1) r',[old.id]))[0].r;
 await db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query("select public.finish_platform_delivery($1,$2,'DELIVERED')",[old.id,lease.lease_id]);});
 const revokeKey=randomUUID(); const revokeInput={company_id:cid,user_id:member,role:'REVOKED',version:await version(cid),reason:'Synthetic explicit revocation'};
 await cmd('set_membership',revokeInput,revokeKey);
 for(let n=0;n<3;n++) await denied(()=>accept(old.id),'T01/T02/T03/T05/T06 direct old delivered invitation replay');
 assert.deepEqual(await permissions(cid),{member:false,view:false,post:false});checks++; // T12
 assert.deepEqual(await permissions(other),{member:true,view:true,post:true});checks++; // T07
 await accept(unrelatedInvite.id);check((await permissions(unrelated)).post,'T07 unrelated pending invitation still valid');
 const invalid=(await q('select * from private.platform_invitations where id=$1',[old.id]))[0];
 check(invalid.state==='REVOKED' && invalid.invalidation_reason===revokeInput.reason,'atomic visible invalidation');
 const audit=(await q("select * from private.platform_events where target_id=$1 and action='INVITATION_INVALIDATED'",[old.id]))[0];
 check(audit.actor_id===owner && audit.request_id===revokeKey && audit.metadata.company_id===cid && audit.metadata.reason===revokeInput.reason,'T11 audit correlation');
 await denied(()=>inviteCommand('resend',{id:old.id,version:String(invalid.version)}),'revoked resend',['40001']);
 await invite(cid,'ACCOUNTANT',oldKey); // Receipt replay, no new effect.
 await cmd('set_membership',revokeInput,revokeKey);
 await cmd('set_membership',originalGrantInput,originalGrantKey);
 await denied(()=>accept(old.id),'T14 old request replay remains revoked');
 // Defense independently checks generation even when stale status is forced back by a trusted test operator.
 await q("update private.platform_invitations set state='PENDING' where id=$1",[old.id]);
 await denied(()=>accept(old.id),'independent epoch fence despite stale status');
 await q("update private.platform_invitations set state='REVOKED' where id=$1",[old.id]);
 const fresh=await invite(cid); await accept(fresh.id); await accept(fresh.id);
 check((await permissions(cid)).post,'T04 genuinely new invitation and duplicate acceptance');
 await membership(cid,'REVOKED');await denied(()=>accept(fresh.id),'accepted receipt cannot undo subsequent revoke');
 // Downgrade plus later revocation cannot restore the old stronger role.
 await membership(cid,'ACCOUNTANT');const strong=await invite(cid,'ACCOUNTING_ADMIN');await membership(cid,'MANAGEMENT_VIEWER');
 await denied(()=>accept(strong.id),'old stronger invitation after downgrade');await membership(cid,'REVOKED');
 await denied(()=>accept(strong.id),'old stronger invitation after subsequent revocation');
 // Delivery lease was already issued; an acknowledgement cannot make it valid.
 await membership(cid,'ACCOUNTANT');const inflight=await invite(cid);
 const inflightLease=(await as(owner,'select public.claim_platform_delivery($1) r',[inflight.id]))[0].r;
 await membership(cid,'REVOKED');
 await denied(()=>db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query("select public.finish_platform_delivery($1,$2,'DELIVERED')",[inflight.id,inflightLease.lease_id]);}),'T09 delivery acknowledgment after revoke',['42501','40001']);
 await denied(()=>as(owner,'select public.claim_platform_delivery($1)',[inflight.id]),'T09 worker retry');
 await denied(()=>accept(inflight.id),'T09 acceptance remains denied');
 const deactivated=await invite(cid);await status('INACTIVE');await denied(()=>accept(deactivated.id),'T10 inactive/session revoked');
 await status('ACTIVE');await q('insert into auth.sessions(id,user_id) values($1,$2)',[sessions.get(member),member]);
 await denied(()=>accept(deactivated.id),'T10 reactivation cannot restore old invite');
 const afterEnable=await invite(cid);await accept(afterEnable.id);check((await permissions(cid)).view,'new grant after reenable');await membership(cid,'REVOKED');
 // Suspension/reopening requires a new invite; ordinary existing memberships resume.
 const suspended=await invite(cid);await cmd('set_lifecycle',{id:cid,version:await version(cid),state:'SUSPENDED',reason:'Synthetic suspension'});
 await denied(()=>accept(suspended.id),'suspended invite');
 await cmd('set_lifecycle',{id:cid,version:await version(cid),state:'ACTIVE',reason:'Synthetic reopen'});
 await denied(()=>accept(suspended.id),'reactivation does not revive invitation');
 const issuer=await invite(cid);await q("update private.system_administrators set status='INACTIVE' where user_id=$1",[owner]);
 await denied(()=>accept(issuer.id),'issuer revoked');await q("update private.system_administrators set status='ACTIVE' where user_id=$1",[owner]);
 await denied(()=>accept(issuer.id),'issuer reenabled old invite remains superseded');
 await denied(()=>inviteCommand('resend',{id:issuer.id,version:'1'}),'stale issuer resend');
 await inviteCommand('revoke',{id:issuer.id,version:'1',reason:'Synthetic cleanup'});
 const issuerProfile=await invite(cid);await q("update public.profiles set status='INACTIVE' where user_id=$1",[owner]);
 await q("update public.profiles set status='ACTIVE' where user_id=$1",[owner]);
 await denied(()=>accept(issuerProfile.id),'issuer profile reenabled old invite remains superseded');
 await inviteCommand('revoke',{id:issuerProfile.id,version:'1',reason:'Synthetic cleanup'});
 // Expiration can be renewed by current authority, but never through a denial fence.
 const expired=await invite(cid);await q("update private.platform_invitations set expires_at=now()-interval '1 second' where id=$1",[expired.id]);
 await denied(()=>accept(expired.id),'expired invitation denied');
 await inviteCommand('resend',{id:expired.id,version:'1'});await accept(expired.id);
 check((await permissions(cid)).post,'authorized resend preserves expiration renewal');await membership(cid,'REVOKED');
 // T13 uses the real command and unchanged last-admin policy.
 await denied(async()=>cmd('set_membership',{company_id:cid,user_id:admin,role:'REVOKED',version:await version(cid),reason:'Synthetic last admin'}),'T13 last admin',['23514']);
 // T15 transaction failure after membership mutation and during invalidation audit.
 await membership(cid,'ACCOUNTANT');const rollbackInvite=await invite(cid);const beforeVersion=await version(cid);
 const failureKey=randomUUID();
 const beforeEvents=(await q('select count(*)::int n from private.platform_events'))[0].n;
 const beforeGeneration=await q('select recipient_key,generation from private.platform_access_fences where company_id=$1 order by recipient_key',[cid]);
 await db.exec(`create function private.test_fail_invalidation() returns trigger language plpgsql as $$ begin
 if new.action='INVITATION_INVALIDATED' then raise exception 'Injected rollback' using errcode='P0001'; end if;return new;end $$;
 create trigger test_fail_invalidation before insert on private.platform_events for each row execute function private.test_fail_invalidation();`);
 await denied(()=>membership(cid,'REVOKED',failureKey),'T15 injected failure',['P0001']);
 await db.exec('drop trigger test_fail_invalidation on private.platform_events;drop function private.test_fail_invalidation();');
 check((await q('select count(*)::int n from private.platform_requests where request_id=$1',[failureKey]))[0].n===0 && (await q('select count(*)::int n from private.platform_events'))[0].n===beforeEvents,'T15 reservation/audit rolled back');
 check((await permissions(cid)).post && await version(cid)===beforeVersion,'T15 membership/version rolled back');
 check((await q('select state from private.platform_invitations where id=$1',[rollbackInvite.id]))[0].state==='PENDING','T15 invitation rolled back');
 assert.deepEqual(await q('select recipient_key,generation from private.platform_access_fences where company_id=$1 order by recipient_key',[cid]),beforeGeneration);checks++;
 check((await q('select state from private.platform_delivery_jobs where invitation_id=$1',[rollbackInvite.id]))[0].state==='QUEUED','T15 outbox rolled back');
 await membership(cid,'REVOKED');await denied(()=>accept(rollbackInvite.id),'T15 normal retry succeeds safely');
 // A stable user fence covers preexisting invitation aliases across verified email changes.
 await membership(cid,'ACCOUNTANT');const aliasInvite=await invite(cid);
 await q('update auth.users set email=$1 where id=$2',[`changed-${member}@example.invalid`,member]);
 await membership(cid,'REVOKED');await q('update auth.users set email=$1 where id=$2',[email,member]);
 await denied(()=>accept(aliasInvite.id),'email change/revoke/change-back stale invitation');
 await q("update private.platform_invitations set state='PENDING' where id=$1",[aliasInvite.id]);
 await denied(()=>accept(aliasInvite.id),'stable user generation independently rejects alias replay');
 await q("update private.platform_invitations set state='REVOKED' where id=$1",[aliasInvite.id]);
 const postAlias=await invite(cid);await accept(postAlias.id);check((await permissions(cid)).post,'fresh invite after email-cycle revocation works');await membership(cid,'REVOKED');
 await denied(()=>as(owner,'select * from private.platform_access_fences'),'fence table private');
 await denied(()=>as(member,'update public.profiles set platform_access_epoch=0 where user_id=$1',[member]),'identity epoch direct write denied');
 check((await as(owner,'select public.list_platform_invitations(0,100) r'))[0].r.items.some(i=>i.id===old.id && i.invalidation_reason===revokeInput.reason),'invalidation reason available to authorized administrator');
 await denied(()=>as(member,'select private.lock_platform_authorization()'),'gate helper private');
 console.log(`PASS: ${checks} P0 revocation assertions (T01–T07, T09–T15 and adjacent flows). T08 requires the separate multi-session runner.`);
 return f;
}
export async function verifyPlatformRevocationUpgrade() {
 const {db,files}=await platformTestDatabase(undefined,{through:'20261028122000'});
 try {
  assert.equal(files.length,59);
  const f=await platformRevocationFixture(db),cid=await f.entity();
  await f.membership(cid,'ACCOUNTANT');const old=await f.invite(cid);
  const lease=(await f.as(f.owner,'select public.claim_platform_delivery($1) r',[old.id]))[0].r;
  await db.transaction(async tx=>{await tx.exec('set local role service_role');await tx.query("select public.finish_platform_delivery($1,$2,'DELIVERED')",[old.id,lease.lease_id]);});
  await f.membership(cid,'REVOKED');await f.accept(old.id);
  assert.deepEqual(await f.permissions(cid),{member:true,view:true,post:true});
  const second=await f.entity(),pending=await f.invite(second);
  await db.exec(readFileSync(resolve('supabase/migrations/20261028123000_platform_invitation_revocation.sql'),'utf8'));
  const i=(await f.q('select state,invalidation_reason from private.platform_invitations where id=$1',[pending.id]))[0];
  assert.deepEqual(i,{state:'REVOKED',invalidation_reason:'SECURITY_CORRECTION_REISSUE_REQUIRED'});
  assert.equal((await f.q('select state from private.platform_delivery_jobs where invitation_id=$1',[pending.id]))[0].state,'CANCELLED');
  await assert.rejects(()=>f.accept(pending.id),e=>e.code==='42501');
  const event=(await f.q("select metadata from private.platform_events where target_id=$1 and action='INVITATION_INVALIDATED'",[pending.id]))[0];
  assert.equal(event.metadata.cause,'CANONICAL_MIGRATION');
  const fresh=await f.invite(second);await f.accept(fresh.id);assert.equal((await f.permissions(second)).post,true);
  console.log('PASS: original exploit reproduced on the preceding 59 migrations; forward upgrade preserves history, cancels legacy pending invitations/outbox, audits migration cause, and allows new authorized invitations.');
 } finally {await db.close();}
}
if(process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
 const {db}=await platformTestDatabase();try {await verifyPlatformRevocation(db);}finally{await db.close();}
 await verifyPlatformRevocationUpgrade();
}
