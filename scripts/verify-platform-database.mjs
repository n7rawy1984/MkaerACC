// Embedded PostgreSQL, synthetic Auth scaffolding, zero hosted connections.
// The pinned development-only engine never enters the application bundle.
import assert from 'node:assert/strict';
import { readFileSync, readdirSync } from 'node:fs';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
const engine = process.env.PLATFORM_PGLITE_PATH ?? resolve('node_modules/@electric-sql/pglite/dist/index.js');
const { PGlite } = await import(pathToFileURL(engine).href);
const { pgcrypto } = await import(pathToFileURL(resolve(engine, '../contrib/pgcrypto.js')).href);
export async function platformTestDatabase(database, {through='99999999999999'}={}) {
 const db = database ?? new PGlite({extensions:{pgcrypto}});
 await db.exec(`create role anon; create role authenticated; create role service_role bypassrls;
 create schema auth; create schema extensions;
 create table auth.users(id uuid primary key, email text,encrypted_password text,email_confirmed_at timestamptz,banned_until timestamptz,raw_user_meta_data jsonb default '{}');
 create table auth.sessions(id uuid primary key,user_id uuid references auth.users(id),not_after timestamptz,factor_id uuid,aal text default 'aal2');
 create table auth.mfa_factors(id uuid primary key default gen_random_uuid(),user_id uuid references auth.users(id),factor_type text,status text);
 create function auth.jwt() returns jsonb language sql stable as $$ select coalesce(nullif(current_setting('request.jwt.claims',true),''),'{}')::jsonb $$;
 create function auth.uid() returns uuid language sql stable as $$ select (auth.jwt()->>'sub')::uuid $$;
 grant usage on schema public,auth to anon,authenticated,service_role;
 grant execute on function auth.jwt(),auth.uid() to anon,authenticated,service_role;
 create function public.rls_auto_enable() returns event_trigger language plpgsql as $$ begin return; end $$;
 create extension pgcrypto with schema extensions;`);
 const files = readdirSync(resolve('supabase/migrations')).filter(f=>f.endsWith('.sql') && f.slice(0,14)<=through).sort();
 for (const file of files) {
  try { await db.exec(readFileSync(resolve('supabase/migrations',file),'utf8')); }
  catch(e) { console.error('Migration failed:',file,e.message); await db.close(); throw e; }
 }
 return { db, files };
}

if (process.argv[1] && import.meta.url===pathToFileURL(resolve(process.argv[1])).href) {
 const {db,files}=await platformTestDatabase();
 try { assert.equal(files.filter(f=>f.startsWith('20261028')).length,4); console.log(`PASS: ${files.length} canonical migrations execute on isolated PostgreSQL (synthetic Auth scaffold).`); }
 finally { await db.close(); }
}
