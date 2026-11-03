"""Freeze reviewed R0 source into a clean local directory. No Git/deployment/hosted operations."""
from pathlib import Path
import json,hashlib,shutil
R=Path('/tmp/narvo-r0-release-20261102');OUT=Path('docs/release/r0-release-execution');OUT.mkdir(parents=True,exist_ok=True)
old=json.loads(Path('docs/release/controlled-production-candidate-manifest.json').read_text())['files_sha256']
emerald=json.loads(Path('docs/release/emerald-enterprise/manifest.json').read_text())['source_hashes'];visual=json.loads(Path('docs/release/r0-commercial-onboarding-visual/manifest.json').read_text())['source_hashes'];e1=json.loads(Path('docs/release/local-commercial-onboarding-result.json').read_text())['source_hashes'];latest={**e1,**visual,**emerald}
files=sorted(set(old)|{str(p)for p in Path('src').rglob('*')if p.is_file()})
changed=[p for p,h in old.items()if hashlib.sha256(Path(p).read_bytes()).hexdigest()!=h];new=sorted(set(files)-set(old));assert set(changed+new)<=set(latest)
for p in changed+new:assert hashlib.sha256(Path(p).read_bytes()).hexdigest()==latest[p],p
source=R/'source';assert not source.exists(),'Do not overwrite a frozen candidate'
for p in files:
 assert not any(x in Path(p).parts for x in ['.git','supabase','fixtures','node_modules']) and not Path(p).name.startswith('.env')
 dest=source/p;dest.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,dest)
manifest={'status':'FROZEN_LOCAL_CANDIDATE','base_accepted_deployment':'dpl_8Jvbmi1GFoVPNhG36CAf1ZGkCfHP','file_count':len(files),'changed_from_accepted':changed,'new_from_accepted':new,'files_sha256':{p:hashlib.sha256((source/p).read_bytes()).hexdigest()for p in files},'pending_migration':'20261102120000_commercial_company_onboarding.sql','migration_sha256':hashlib.sha256(Path('supabase/migrations/20261102120000_commercial_company_onboarding.sql').read_bytes()).hexdigest(),'hosted_actions':False,'data_mode':'supabase-auth; requires separately supplied browser-safe environment','unrelated_work_included':False}
assert manifest['migration_sha256']=='76aef69124d8eccc6b7df8f6152fcddf5f37b7a17934fe3926b674f71d395f67'
(OUT/'candidate-manifest.json').write_text(json.dumps(manifest,indent=2)+'\n');print('FROZEN',len(files),'files;',len(changed),'changed,',len(new),'new; all reviewed hashes match')
# Separate local verification sandbox; excluded from the application deployment manifest.
verify=R/'verification';verify.mkdir();
for p in ['package.json','package-lock.json','vite.config.ts','tsconfig.json','tsconfig.app.json','tsconfig.node.json','postcss.config.js','index.html']:
 if Path(p).exists():shutil.copyfile(p,verify/p)
for p in ['scripts','src','supabase','public']:shutil.copytree(p,verify/p,ignore=shutil.ignore_patterns('.temp','node_modules','*.log'))
(verify/'docs/release').mkdir(parents=True);(verify/'node_modules').symlink_to(Path('node_modules').resolve(),target_is_directory=True)
