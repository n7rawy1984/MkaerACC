"""Small release checkpoint only; no repeated Company/Auth inventory or hosted writes."""
from pathlib import Path
import os,json,urllib.parse,subprocess
REF='eqnzueginpkskbnqvgoc';R=Path('/tmp/narvo-r0-release-20261102');entry=[]
for line in (Path.home()/'.pgpass').read_text().splitlines():
 a=line.split(':')
 if len(a)==5 and REF in a[0]and a[2]=='postgres'and a[3]=='postgres':entry.append(a)
assert len(entry)==1;u=urllib.parse.urlsplit(Path('supabase/.temp/pooler-url').read_text().strip());assert u.username=='postgres.'+REF and u.port==5432
env={k:v for k,v in os.environ.items()if not k.startswith('PG')};env.update({'PGHOST':u.hostname,'PGPORT':'5432','PGUSER':u.username,'PGDATABASE':'postgres','PGPASSWORD':entry[0][4],'PGSSLMODE':'verify-full','PGSSLROOTCERT':str(R/'supabase-root-ca.crt'),'PGCONNECT_TIMEOUT':'10'})
sql="""begin transaction isolation level repeatable read read only;set local statement_timeout=10000;
select json_build_object('as_of',statement_timestamp(),'read_only',current_setting('transaction_read_only'),
 'hosted_migrations',(select count(*) from supabase_migrations.schema_migrations),
 'pending65_absent',not exists(select 1 from supabase_migrations.schema_migrations where version='20261102120000'),
 'readiness_helper_absent',to_regprocedure('private.company_commercial_readiness(uuid)') is null,
 'maker_seed_matches',(select count(*)=1 from public.companies c where c.code='MAKER' and c.status='ACTIVE' and not exists(select 1 from private.platform_events e where e.target_id=c.id and e.action='create_entity')),
 'maker_unenrolled',not exists(select 1 from private.company_subscriptions s join public.companies c on c.id=s.company_id where c.code='MAKER'));
commit;"""
p=subprocess.run(['psql','-X','-w','-qAt','-c',sql],env=env,capture_output=True,text=True,timeout=30);assert p.returncode==0,'Read-only checkpoint failed; diagnostics suppressed';r=json.loads(next(x for x in p.stdout.splitlines()if x.startswith('{')));assert r['read_only']=='on'and r['hosted_migrations']==64 and all(r[k]for k in ['pending65_absent','readiness_helper_absent','maker_seed_matches','maker_unenrolled']);Path('docs/release/r0-release-execution/hosted-checkpoint.json').write_text(json.dumps(r,indent=2)+'\n');print('READ ONLY checkpoint PASS:64 migrations,65 absent,exact Maker seed still eligible/unenrolled')
