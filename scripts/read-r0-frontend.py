"""Read-only Vercel metadata + public deployed assets; never deploy/promote/configure."""
from pathlib import Path
import subprocess,json,os,urllib.request,re,hashlib
OUT=Path('docs/release/r0-production-impact');PID='prj_n03DWya5Gr1uB82qtY084FvsC7q4';TID='team_HozmwrkzbERtyer2nIT25MWv';SCOPE='?teamId='+TID
CLI=['node','/home/nagham/.npm/_npx/67eb4586ca667318/node_modules/vercel/dist/vc.js']
def get(path):
 assert path.startswith('/') and 'decrypt' not in path
 p=subprocess.run(CLI+['api',path,'--method','GET'],stdout=subprocess.PIPE,stderr=subprocess.PIPE,text=True,timeout=75,env=dict(os.environ,VERCEL_TELEMETRY_DISABLED='1',NO_COLOR='1'))
 if p.returncode:raise RuntimeError('Vercel metadata GET failed; raw response suppressed')
 return json.loads(p.stdout)
p=get('/v9/projects/'+PID+SCOPE);assert p['id']==PID and p['name']=='maker' and p['accountId']==TID
a=get('/v4/aliases/maker-eosin.vercel.app'+SCOPE);did=a['deploymentId'];d=get('/v13/deployments/'+did+SCOPE);rollback=get('/v13/deployments/dpl_DC2wK34FdbWNsVtnqMCzb54uRwDh'+SCOPE)
base='https://maker-eosin.vercel.app';html=urllib.request.urlopen(base,timeout=40).read();entry=re.search(rb'<script[^>]+src="([^"]+\.js)"',html).group(1).decode();bundle=urllib.request.urlopen(base+entry,timeout=40).read();protected=re.search(rb'ProtectedApplication-[A-Za-z0-9_-]+\.js',bundle);assets={entry:hashlib.sha256(bundle).hexdigest()};refs=set(re.findall(rb'https://([a-z]{20})\.supabase\.co',bundle))
if protected:
 path='/assets/'+protected.group().decode();data=urllib.request.urlopen(base+path,timeout=40).read();assets[path]=hashlib.sha256(data).hexdigest();refs.update(re.findall(rb'https://([a-z]{20})\.supabase\.co',data))
r={'project_id':PID,'team_id':TID,'alias':a.get('alias'),'alias_deployment':did,'production_target':p.get('targets',{}).get('production',{}).get('id'),'deployed_ready_state':d.get('readyState'),'matches_prior_accepted_deployment':did=='dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP','html_sha256':hashlib.sha256(html).hexdigest(),'matches_prior_accepted_html':hashlib.sha256(html).hexdigest()=='364140954c5cff976361305995a876edf97e9fb173c1da0f4a517aba8742b039','assets_sha256':assets,'browser_supabase_refs':[x.decode() for x in sorted(refs)],'rollback_candidate':{k:rollback.get(k) for k in ['id','readyState','projectId','target','url']},'hosted_changes':False}
(OUT/'deployed-frontend.json').write_text(json.dumps(r,indent=2)+'\n');print('Frontend',did,d.get('readyState'),'refs',r['browser_supabase_refs'],'rollback',rollback.get('readyState'))
