import assert from 'node:assert/strict';
import {readFileSync,readdirSync} from 'node:fs';
import {execFileSync} from 'node:child_process';
import {randomUUID} from 'node:crypto';
import {platformTestDatabase} from './verify-platform-database.mjs';
const candidate='20261031120000_platform_invitation_onboarding.sql';
const names=readdirSync('supabase/migrations').filter(x=>x.endsWith('.sql')&&x.slice(0,14)<=candidate.slice(0,14)).sort();assert.equal(names.length,62);assert.equal(names.at(-1),candidate);
const base='16cf326ca8ca68837892acbefdeffb43c7616640';
const old=execFileSync('git',['ls-tree','-r','--name-only',base,'--','supabase/migrations']).toString().trim().split('\n');assert.equal(old.length,61);
for(const file of old) assert(readFileSync(file).equals(execFileSync('git',['show',`${base}:${file}`])));
const {db}=await platformTestDatabase();let checks=0;const check=(v,label)=>{assert(v,label);checks++;};
const id=n=>`c1000000-0000-4000-8000-${String(n).padStart(12,'0')}`;
const owner=id(1),recipient=id(2),other=id(3),company=id(4),foreign=id(5);
const as=(actor,sql,args=[],session=id(100+Number(actor.slice(-4))))=>db.transaction(async tx=>{
 await tx.query("select set_config('request.jwt.claims',$1,true)",[JSON.stringify({sub:actor,session_id:session,aal:'aal2',amr:[{method:'totp',timestamp:Math.floor(Date.now()/1000)}]})]);await tx.exec('set local role authenticated');return(await tx.query(sql,args)).rows;
});
const deny=async(fn,label)=>{await assert.rejects(fn,e=>e.code==='42501',label);checks++;};
try {
 for(const uid of [owner,recipient,other]){await db.query('insert into auth.users(id,email,email_confirmed_at) values($1,$2,now())',[uid,uid+'@example.invalid']);await db.query('insert into auth.sessions(id,user_id) values($1,$2)',[id(100+Number(uid.slice(-4))),uid]);}
 await db.query('insert into private.system_administrators(user_id) values($1)',[owner]);await db.query("insert into auth.mfa_factors(user_id,factor_type,status) values($1,'totp','verified')",[owner]);await db.query('update auth.sessions set factor_id=(select id from auth.mfa_factors where user_id=$1) where user_id=$1',[owner]);
 for(const cid of [company,foreign]) await db.query('insert into public.companies(id,code,name) values($1,$2,$2)',[cid,cid]);
 const invite=(await as(owner,"select public.platform_invitation_command('invite',$1,$2::jsonb) result",[randomUUID(),JSON.stringify({company_id:company,email:recipient+'@example.invalid',role:'ACCOUNTANT'})]))[0].result.id;
 const read=()=>as(recipient,'select public.get_my_platform_invitation($1) result',[invite]);
 const initial=(await read())[0].result;check(initial.password_required&&initial.state==='PENDING'&&initial.company_id===company,'passwordless verified recipient sees only own invitation context');
 check((await db.query('select count(*)::int n from public.company_memberships')).rows[0].n===0,'read never creates membership');
 await deny(()=>as(other,'select public.get_my_platform_invitation($1)',[invite]),'wrong recipient cannot enumerate Company');
 await deny(()=>as(recipient,'select public.get_my_platform_invitation($1)',[randomUUID()]),'unknown ID denied');
 await deny(()=>as(recipient,'select public.get_my_platform_invitation($1)',[invite],randomUUID()),'missing live session denied');
 await db.query('update auth.sessions set not_after=now()-interval \'1 second\' where user_id=$1',[recipient]);await deny(read,'expired session denied');await db.query('update auth.sessions set not_after=null where user_id=$1',[recipient]);
 await db.query("update auth.users set encrypted_password='synthetic-noncredential' where id=$1",[recipient]);check((await read())[0].result.password_required===false,'password presence derived server-side, not browser flag');
 const accepted=(await as(recipient,'select public.accept_platform_invitation($1) company_id',[invite]))[0].company_id;check(accepted===company,'existing acceptance RPC grants intended Company only');
 check((await read())[0].result.state==='ACCEPTED','reload/uncertain acceptance reconciles authoritative result');
 check((await as(recipient,'select public.accept_platform_invitation($1) company_id',[invite]))[0].company_id===company,'duplicate acceptance is idempotent');
 check((await db.query('select count(*)::int n from public.company_memberships where user_id=$1',[recipient])).rows[0].n===1,'exactly one membership');
 check((await as(recipient,'select count(*)::int n from public.companies where id=$1',[foreign]))[0].n===0,'foreign Company remains invisible');
 await db.query("update private.platform_invitations set expires_at=now()-interval '1 second' where id=$1",[invite]);await deny(read,'expired invitation read rejected');await deny(()=>as(recipient,'select public.accept_platform_invitation($1)',[invite]),'expired invitation acceptance rejected');
 await db.query("update private.platform_invitations set expires_at=now()+interval '1 day',state='REVOKED' where id=$1",[invite]);await deny(read,'revoked invitation read rejected');await deny(()=>as(recipient,'select public.accept_platform_invitation($1)',[invite]),'revoked acceptance rejected');
 check((await db.query("select has_function_privilege('anon','public.get_my_platform_invitation(uuid)','execute') a,has_function_privilege('service_role','public.get_my_platform_invitation(uuid)','execute') s")).rows.every(r=>!r.a&&!r.s),'no anonymous/service execute');
 check((await db.query('select count(*)::int n from public.journal_entries')).rows[0].n===0,'no financial postings');
 console.log(`PASS: ${checks} recipient onboarding SQL assertions, exact62-file allowlist/prior61 bytes unchanged. Isolated synthetic PostgreSQL only.`);
} finally {await db.close();}
