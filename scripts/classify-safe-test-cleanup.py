"""Offline classification of sanitized read-only inventory. Produces no executable cleanup."""
import json,collections,hashlib,os
from pathlib import Path
os.umask(0o077)
R=Path('/tmp/narvo-cleanup-assessment-20261102')
load=lambda n:json.loads((R/n).read_text())
def save(n,d):
 p=R/n;p.write_text(json.dumps(d,indent=2,ensure_ascii=False)+'\n');p.chmod(0o600)
p=load('inventory.json');refs=load('user-reference-counts.json');counts=load('company-counts.json');provenance=load('company-fixture-provenance.json');user_provenance={x['id']:x for x in load('user-fixture-provenance.json')};cat=load('catalog.json')
companies={c['id']:c for c in p['companies']};by_code={c['code']:c for c in companies.values()}
maker=by_code['MAKER']['id'];stage=by_code['NARVO-INVITE-TEST-20261101']['id']
admins=[m['user_id']for m in p['memberships']if m['company_id']==maker and m['role']=='ACCOUNTING_ADMIN' and m['status']=='ACTIVE'];viewers=[m['user_id']for m in p['memberships']if m['company_id']==maker and m['role']=='MANAGEMENT_VIEWER' and m['status']=='ACTIVE'];assert len(admins)==len(viewers)==1
inv=[i for i in p['invitations']if i['company_id']==stage and i['state']=='ACCEPTED'];assert len(inv)==1 and inv[0]['accepted_by']in inv[0]['matching_auth_ids']
core=set(admins+viewers+[a['user_id']for a in p['administrators']]+[inv[0]['accepted_by']])
# All memberships of the explicitly protected accounting/owner/invited identities survive.
keep_companies={maker,stage}|{m['company_id']for m in p['memberships']if m['user_id']in core}
assert len(keep_companies)==3
candidate_companies={x['id']for x in provenance if x['all_member_auths_have_verified_phase_pattern'] and x['memberships']==x['same_run_auth_memberships']}
assert len(candidate_companies)==12 and not candidate_companies&keep_companies
review_companies=set(companies)-candidate_companies-keep_companies
company_details=[]
for cid,c in companies.items():
 table_counts={t:next((x['rows']for x in v if x['company_id']==cid),0)for t,v in counts.items()}
 financial=table_counts.get('public.journal_entries',0)>0 or table_counts.get('public.historical_source_records',0)>0 or table_counts.get('private.financial_command_requests',0)>0
 if cid in candidate_companies:assert not financial
 company_details.append(c|{'classification':'KEEP' if cid in keep_companies else 'CANDIDATE_DELETE' if cid in candidate_companies else 'REVIEW_REQUIRED','protection_status':'PERMANENT_EXCLUSION' if cid in keep_companies else 'NOT_AUTHORIZED_FOR_CLEANUP','recommended_action':'retain unchanged' if cid in keep_companies else 'owner-approved archival after recovery; physical deletion unsupported' if cid in candidate_companies else 'retain; immutable financial/lifecycle review required','nonzero_table_dependencies':{k:v for k,v in table_counts.items()if v},'all_company_table_counts':table_counts,'financial_or_source_history':financial})
foreign=collections.defaultdict(list);ref_companies=collections.defaultdict(set);reasons=collections.defaultdict(set)
for key,values in refs.items():
 if key.startswith(('auth.','public.profiles.')):continue
 for v in values:
  u=v['user_id'];cid=v.get('company_id');foreign[u].append({'reference':key,**v})
  if cid:ref_companies[u].add(cid)
  if cid in keep_companies:reasons[u].add('protected Company relationship: '+key)
  if cid in review_companies and key not in ['public.company_memberships.user_id','public.project_assignments.user_id']:reasons[u].add('retained financial Company attribution: '+key)
for cid in keep_companies:
 for key in ['created_by','updated_by']:
  if companies[cid][key]:reasons[companies[cid][key]].add('protected Company '+key)
for u in core:reasons[u].add('explicit protected identity/administrator relationship')
shared={u for u,v in ref_companies.items()if len(v)>1}
for u in shared:reasons[u].add('SHARED_IDENTITY: used across Companies; no Auth deletion')
protected=set(reasons)
# User of uncertain personal ownership is held, never guessed from a name.
uncertain={u['id']for u in p['users']if not u['fixture_email_hint'] and u['id']not in core}
profile={x['user_id']:x for x in p['profiles']};nonfk=load('non-fk-identity-counts.json')
users=[];candidate_users=set()
for u in p['users']:
 uid=u['id'];proof=user_provenance[uid]
 eligible=not foreign[uid] and uid not in protected and profile[uid]['status']=='INACTIVE' and proof['reserved_test_domain'] and proof['fixture_prefix']=='P2_VERIFICATION'
 if eligible:candidate_users.add(uid)
 classification='SHARED_IDENTITY' if uid in shared else 'REVIEW_REQUIRED' if uid in uncertain else 'KEEP' if uid in protected else 'CANDIDATE_DELETE' if eligible else 'REVIEW_REQUIRED'
 users.append(u|{'classification':classification,'protection_status':'PROTECTED_PENDING_REVIEW' if uid in uncertain else 'EXCLUDED_AUTH_DELETION' if uid in protected else 'CANDIDATE_ONLY' if eligible else 'REVIEW_REQUIRED','protected':uid in protected,'protection_reasons':sorted(reasons[uid]),'profile_status':profile[uid]['status'],'company_ids':sorted(ref_companies[uid]),'membership_ids':[x['id']for x in p['memberships']if x['user_id']==uid],'application_references':foreign[uid],'non_fk_identity_rows':{k:sum(v['rows']for v in vals if v['user_id']==uid)for k,vals in nonfk.items()},'fixture_provenance':proof,'execution_supported':False})
assert len(candidate_users)==9 and not candidate_users&protected
save('company-classification.json',company_details);save('user-classification.json',users)
allow={'version':1,'status':'CLEANUP_BLOCKED_NOT_EXECUTION_AUTHORIZATION','company_candidate_ids':sorted(candidate_companies),'auth_candidate_ids':sorted(candidate_users),'company_preferred_future_action':'archival via existing owner command after recovery/approval','company_physical_deletion_supported':False,'auth_deletion_supported_by_console':False,'auth_profile_restrict_blocker':True,'required':'Recheck exact snapshot, sealed denylist, backup/restore evidence and owner approvals; no blanket patterns or automatic expansion'};save('candidate-allowlist.json',allow)
deny={'version':1,'immutable_proposal':True,'snapshot_as_of':p['as_of'],'protected_company_ids':sorted(keep_companies),'protected_auth_user_ids':sorted(protected),'core_explicit_identity_ids':sorted(core),'protected_access_closure_user_ids':sorted({u for u,rs in reasons.items()if any(x.startswith('protected Company')for x in rs)}|core),'protected_pending_review_ids':sorted(uncertain),'protected_membership_ids':[m['id']for m in p['memberships']if m['company_id']in keep_companies or m['user_id']in core],'protected_administrator_records':p['administrators'],'protected_mfa_factor_metadata':p['mfa_factors'],'protected_invitation_ids':[i['id']for i in inv],'protected_provision_company_ids':[x['company_id']for x in p['provisions']if x['company_id']in keep_companies],'protected_subscription_company_ids':[x['company_id']for x in p['subscriptions']if x['company_id']in keep_companies],'immutable_retention_rules':['All rows belonging to the3 protected Companies, including masters, source data, financial records, settings and memberships','Auth identities/profiles/MFA/authentication data of every protected UUID; retain associated historical attribution','All existing journal entries/lines, posted business documents/reversals and financial-command receipts, across all Companies','All existing platform, historical-source, attendance and payroll audit/security evidence; no audit pruning','Global permissions/role mappings, platform administrators, existing canonical migrations, schema/RLS/grants/functions and recovery configuration'],'existing_platform_event_ids':[x['id']for x in p['platform_events']],'storage_policy':'No objects/buckets currently; future unknown ownership defaults to REVIEW_REQUIRED','change_control':'Do not edit this version. Any future protection expansion requires a new version/digest; explicit critical exclusions cannot be relaxed by a cleanup batch.'}
path=R/'protected-denylist.immutable.v1.json';assert not path.exists(),'Do not overwrite sealed denylist';path.write_text(json.dumps(deny,indent=2)+'\n');path.chmod(0o400);digest=hashlib.sha256(path.read_bytes()).hexdigest();(R/'protected-denylist.sha256').write_text(digest+'  protected-denylist.immutable.v1.json\n');(R/'protected-denylist.sha256').chmod(0o400)
summary={'status':'CLEANUP_BLOCKED','companies':dict(collections.Counter(x['classification']for x in company_details)),'users':dict(collections.Counter(x['classification']for x in users)),'protected_company_count':len(keep_companies),'protected_auth_user_count_including_shared_holds':len(protected),'core_identity_count':len(core),'protected_access_closure_count':len(deny['protected_access_closure_user_ids']),'historical_attribution_additional_count':len(protected)-len(deny['protected_access_closure_user_ids'])-len(shared-protected),'protected_pending_review_count':len(uncertain),'candidate_company_count':len(candidate_companies),'candidate_auth_count':len(candidate_users),'denylist_sha256':digest,'expected_counts_after_this_read_only_session':{'companies':18,'auth_users':290,'profiles':290,'memberships':281},'expected_counts_after_future_archive_only':{'companies':18,'active_companies':5,'inactive_companies':13,'auth_users':290,'profiles':290,'memberships':281,'platform_entities':13,'platform_events':25,'platform_requests':20},'hypothetical_counts_after_separately_designed9_auth_removal':{'companies':18,'auth_users':281,'profiles':281,'memberships':281},'hypothetical_counts_after_unsupported12_company_physical_removal':{'companies':6,'memberships':230,'note':'Arithmetic only; no supported/authorized execution path; Auth identities never follow Company removal automatically.'}}
# Distinguish69 access/history holds from one additional shared-only identity.
summary['historical_attribution_additional_count']=sum(1 for u,rs in reasons.items()if u not in deny['protected_access_closure_user_ids'] and any(x.startswith('retained financial')for x in rs));summary['shared_only_additional_hold_count']=len(protected-set(deny['protected_access_closure_user_ids'])-{u for u,rs in reasons.items()if any(x.startswith('retained financial')for x in rs)})
save('classification-summary.json',summary)
print('CLASSIFICATION',summary['companies'],summary['users'],'protected Auth',len(protected),'sealed denylist',digest)
