"""Read intended Vercel metadata/public configuration and build the frozen candidate locally."""
from pathlib import Path
import subprocess,json,os,re,hashlib,shutil
R=Path('/tmp/narvo-r0-release-20261102');OUT=Path('docs/release/r0-release-execution');PID='prj_n03DWya5Gr1uB82qtY084FvsC7q4';TID='team_HozmwrkzbERtyer2nIT25MWv';SCOPE='?teamId='+TID
CLI=['node','/home/nagham/.npm/_npx/67eb4586ca667318/node_modules/vercel/dist/vc.js']
def get(path):
 p=subprocess.run(CLI+['api',path,'--method','GET'],capture_output=True,text=True,timeout=75,env=dict(os.environ,VERCEL_TELEMETRY_DISABLED='1',NO_COLOR='1'))
 if p.returncode:raise RuntimeError('Read-only Vercel metadata lookup failed; raw response suppressed')
 return json.loads(p.stdout)
p=get('/v9/projects/'+PID+SCOPE);assert p['id']==PID and p['name']=='maker' and p['accountId']==TID
alias=get('/v4/aliases/maker-eosin.vercel.app'+SCOPE);assert alias['deploymentId']==p['targets']['production']['id']=='dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP'
rows=get('/v10/projects/'+PID+'/env'+SCOPE)['envs'];public={};scopes={}
for name in ['VITE_APP_DATA_MODE','VITE_SUPABASE_URL','VITE_SUPABASE_PUBLISHABLE_KEY']:
 entries=[v for v in rows if v['key']==name and 'production'in v['target']and not v.get('gitBranch')];assert len(entries)==1;row=entries[0];public[name]=get('/v1/projects/'+PID+'/env/'+row['id']+SCOPE)['value'];scopes[name]={'production':True,'preview_entries':sum(v['key']==name and 'preview'in v['target']for v in rows),'type':row.get('type')}
assert public['VITE_APP_DATA_MODE']=='supabase-auth' and public['VITE_SUPABASE_URL']=='https://eqnzueginpkskbnqvgoc.supabase.co' and re.fullmatch('sb_publishable_[A-Za-z0-9_-]{20,}',public['VITE_SUPABASE_PUBLISHABLE_KEY'])
(OUT/'vercel-readiness.json').write_text(json.dumps({'project_id':PID,'team_id':TID,'name':p['name'],'current_production':alias['deploymentId'],'production_alias':'maker-eosin.vercel.app','framework':p.get('framework'),'buildCommand':p.get('buildCommand'),'outputDirectory':p.get('outputDirectory'),'environment_variable_scopes':scopes,'public_config_validated':True,'supabase_project':'eqnzueginpkskbnqvgoc','hosted_writes':False,'deployed':False},indent=2)+'\n')
work=R/'production-build';shutil.copytree(R/'source',work);env={k:v for k,v in os.environ.items()if not k.startswith('VITE_')};env.update(public)
results={}
for key,cmd in [('install',['npm','ci','--offline','--no-audit','--no-fund']),('build',['npm','run','build']),('lint',['npm','exec','--offline','--','oxlint','src','scripts/production-boundary.mjs','vite.config.ts'])]:
 result=subprocess.run(cmd,cwd=work,env=env,capture_output=True,text=True,timeout=300);(OUT/(key+'.log')).write_text(result.stdout+result.stderr);results[key]={'exit_code':result.returncode,'pass':result.returncode==0};print(key,'PASS'if result.returncode==0 else 'FAIL',flush=True)
 if result.returncode:break
manifest=json.loads((OUT/'candidate-manifest.json').read_text())['files_sha256'];assert all(hashlib.sha256((R/'source'/f).read_bytes()).hexdigest()==h for f,h in manifest.items())
results['frozen_source_preserved']=True
if results.get('build',{}).get('pass'):
 data=b'\n'.join(f.read_bytes()for f in (work/'dist').rglob('*.js'));refs=set(re.findall(rb'https://([a-z]{20})\.supabase\.co',data));assert refs=={b'eqnzueginpkskbnqvgoc'};assert not re.search(rb'sb_secret_[A-Za-z0-9_-]{20,}|-----BEGIN [A-Z ]*PRIVATE KEY',data)
 results['sole_compiled_supabase_ref']='eqnzueginpkskbnqvgoc';results['build_artifacts_sha256']={str(f.relative_to(work/'dist')):hashlib.sha256(f.read_bytes()).hexdigest()for f in (work/'dist').rglob('*')if f.is_file()};results['commercial_and_emerald_sources_in_manifest']=all(x in manifest for x in ['src/platform/CommercialOnboarding.tsx','src/styles/emerald.css','src/styles/emeraldTokens.css'])
(OUT/'build-result.json').write_text(json.dumps(results,indent=2)+'\n')
