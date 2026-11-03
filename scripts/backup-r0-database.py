"""Authorized read-only encrypted database backup. No migration, restore-to-hosted or writes."""
from pathlib import Path
import os,json,subprocess,datetime,hashlib,urllib.parse,dbus
os.umask(0o077);R=Path('/tmp/narvo-r0-release-20261102');OUT=Path('docs/release/r0-release-execution');REF='eqnzueginpkskbnqvgoc'
entries=[]
for line in (Path.home()/'.pgpass').read_text().splitlines():
 if line and not line.startswith('#'):
  a=line.split(':')
  if len(a)==5 and REF in a[0]and a[2]=='postgres'and a[3]=='postgres':entries.append(a)
assert len(entries)==1
url=urllib.parse.urlsplit(Path('supabase/.temp/pooler-url').read_text().strip());assert url.username=='postgres.'+REF and url.port==5432
cert=R/'supabase-root-ca.crt';assert cert.exists()and b'BEGIN CERTIFICATE'in cert.read_bytes()and b'PRIVATE KEY'not in cert.read_bytes()
env={k:v for k,v in os.environ.items()if not k.startswith('PG')};env.update({'PGHOST':url.hostname,'PGPORT':'5432','PGDATABASE':'postgres','PGUSER':url.username,'PGPASSWORD':entries[0][4],'PGSSLMODE':'verify-full','PGSSLROOTCERT':str(cert),'PGCONNECT_TIMEOUT':'10','PGOPTIONS':'-c statement_timeout=120000 -c lock_timeout=5000'})
probe=subprocess.run(['psql','-X','-w','-qAt','-c',"begin transaction isolation level repeatable read read only;select json_build_object('read_only',current_setting('transaction_read_only'),'version',current_setting('server_version'));commit;"],env=env,capture_output=True,text=True,timeout=25);assert probe.returncode==0,'Verified database connection unavailable';connected=json.loads(next(x for x in probe.stdout.splitlines()if x.startswith('{')));assert connected['read_only']=='on'and connected['version'].startswith('17.')
# Local Secret Service holds the random encryption passphrase; no key file or output.
bus=dbus.SessionBus();svc=dbus.Interface(bus.get_object('org.freedesktop.secrets','/org/freedesktop/secrets'),'org.freedesktop.Secret.Service');_,session=svc.OpenSession('plain',dbus.String('',variant_level=1));collection=dbus.Interface(bus.get_object('org.freedesktop.secrets','/org/freedesktop/secrets/aliases/default'),'org.freedesktop.Secret.Collection')
stamp=datetime.datetime.now(datetime.timezone.utc).strftime('%Y%m%dT%H%M%SZ');locator={'service':'NARVO R0 Recovery','username':REF+'-'+stamp};key=os.urandom(48).hex().encode();properties=dbus.Dictionary({'org.freedesktop.Secret.Item.Label':dbus.String('NARVO R0 encrypted backup '+stamp),'org.freedesktop.Secret.Item.Attributes':dbus.Dictionary(locator,signature='ss')},signature='sv')
try:
 item,prompt=collection.CreateItem(properties,dbus.Struct((session,dbus.ByteArray(b''),dbus.ByteArray(key),dbus.String('text/plain')),signature='oayays'),False);assert str(prompt)=='/','Local keyring prompt pending';check=bytes(dbus.Interface(bus.get_object('org.freedesktop.secrets',item),'org.freedesktop.Secret.Item').GetSecret(session)[2]);assert check==key
finally:dbus.Interface(bus.get_object('org.freedesktop.secrets',session),'org.freedesktop.Secret.Session').Close()
backup=R/'recovery';backup.mkdir(mode=0o700);home=backup/'gpg-home';home.mkdir(mode=0o700)
def gpg_args():
 a,b=os.pipe();os.write(b,key+b'\n');os.close(b);return a,['gpg','--no-options','--homedir',str(home),'--batch','--yes','--no-symkey-cache','--pinentry-mode','loopback','--passphrase-fd',str(a)]
def encrypted_export(label,command):
 dest=backup/(label+'.gpg');fd,args=gpg_args();source=subprocess.Popen(command,env=env,stdout=subprocess.PIPE,stderr=subprocess.PIPE);crypt=subprocess.Popen(args+['--symmetric','--cipher-algo','AES256','--compress-algo','none','--output',str(dest)],stdin=source.stdout,stdout=subprocess.DEVNULL,stderr=subprocess.PIPE,pass_fds=(fd,));os.close(fd);source.stdout.close();_,ce=crypt.communicate(timeout=180);se=source.stderr.read();code=source.wait(timeout=10);ok=code==0 and crypt.returncode==0
 errors=[]
 for line in se.decode(errors='replace').splitlines():
  if 'permission denied' in line.lower():errors.append('permission denied')
  elif 'error:'in line.lower():errors.append('export error; sensitive diagnostics suppressed')
 return {'file':str(dest),'success':ok,'producer_exit':code,'encryption_exit':crypt.returncode,'encrypted_size':dest.stat().st_size if dest.exists()else 0,'sha256':hashlib.sha256(dest.read_bytes()).hexdigest()if dest.exists()else None,'errors':errors}
result={'started_at_utc':datetime.datetime.now(datetime.timezone.utc).isoformat(),'project':REF,'server_version':connected['version'],'explicit_probe_read_only':True,'pg_dump_uses_read_only_repeatable_read_transaction':True,'tls':'verify-full with existing Supabase CA','credential_available':True,'keyring_locator':locator,'exports':{},'hosted_writes':False,'migration_executed':False,'restore_performed':False}
result['exports']['database']=encrypted_export('database.dump',['pg_dump','--no-password','--format=custom','--compress=5','--lock-wait-timeout=5s','--dbname=postgres'])
result['exports']['roles']=encrypted_export('roles.sql',['pg_dumpall','--no-password','--roles-only','--no-role-passwords'])
if result['exports']['database']['success']:
 fd,args=gpg_args();decrypt=subprocess.Popen(args+['--decrypt',result['exports']['database']['file']],stdout=subprocess.PIPE,stderr=subprocess.PIPE,pass_fds=(fd,));os.close(fd);listing=subprocess.run(['pg_restore','--list'],stdin=decrypt.stdout,capture_output=True,timeout=60);decrypt.stdout.close();de=decrypt.stderr.read();dc=decrypt.wait(timeout=10);toc=listing.stdout.decode(errors='replace');result['archive_list_verifies']=listing.returncode==0;result['archive_toc_decrypt_early_close_exit']=dc;result['archive_entries']=len([x for x in toc.splitlines()if x and not x.startswith(';')]);result['critical_sections']={x:any('TABLE DATA '+x+' 'in line for line in toc.splitlines())for x in ['public','private','auth','storage','supabase_migrations']};(backup/'archive-toc.txt').write_text(toc)
result['full_ciphertext_integrity']={}
for label,export in result['exports'].items():
 fd,args=gpg_args();verified=subprocess.run(args+['--output','/dev/null','--decrypt',export['file']],pass_fds=(fd,),capture_output=True,timeout=60);os.close(fd);result['full_ciphertext_integrity'][label]={'decryption_integrity_pass':verified.returncode==0,'exit':verified.returncode}
result['status']='BACKUP_CAPTURED_RESTORE_BLOCKED'if all(x['success']for x in result['exports'].values())and result.get('archive_list_verifies')and all(x['decryption_integrity_pass']for x in result['full_ciphertext_integrity'].values())else 'BACKUP_FAILED'
result['restore_blocker']='No runnable local PostgreSQL/Supabase-compatible restore server or Docker engine is available; client tools alone cannot perform restoration.'
result['finished_at_utc']=datetime.datetime.now(datetime.timezone.utc).isoformat();(backup/'recovery-metadata.json').write_text(json.dumps(result,indent=2)+'\n');(OUT/'recovery-result.json').write_text(json.dumps(result,indent=2)+'\n');print('RECOVERY',result['status'],'database',result['exports']['database']['success'],'roles',result['exports']['roles']['success'],'archive readable',result.get('archive_list_verifies'),flush=True)
