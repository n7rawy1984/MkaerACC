from pathlib import Path
import json,hashlib,re
root=Path('docs/release/emerald-enterprise');read=lambda p:json.loads((root/p).read_text())
before=read('before/result.json');bi=read('before/interactions.json');platform=read('after/platform-result.json');company=read('after/company-result.json');refresh=read('after/refresh-result.json');interactions=read('after/interactions.json')
for x in [before,platform,company,refresh]:assert x['status']=='COMPLETE_REVIEW_RESULTS',x.get('error')
for x in [bi,interactions]:assert x['status']=='COMPLETE',x.get('error')
combine=lambda groups:list({(c['key'],c['layout']):c for g in groups for c in g}.values())
r={'status':'LOCAL_IMPLEMENTATION_READY_FOR_HUMAN_VISUAL_REVIEW','before':combine([before['captures'],bi['captures'],read('before/refresh-result.json')['captures']]),'after':combine([platform['captures'],company['captures'],refresh['captures'],interactions['captures']]),'contrast':combine([platform['contrast'],company['contrast'],refresh['contrast'],interactions['contrast']]),'scans':combine([platform['scans'],company['scans'],refresh['scans'],interactions['scans']]),'checks':[],'interaction_checks':interactions['checks'],'hosted_access':False,'deployed':False,'human_visual_approval':False}
replacement={(c['key'],c['layout']) for c in refresh['captures']}
r['checks']=[c for x in [platform,company] for c in x['checks'] if (c['key'],c['layout']) not in replacement]+refresh['checks']
assert len(r['after'])==122,len(r['after']);assert not any(c['failures'] for c in r['contrast']);assert all(c['pass'] for c in r['checks'])
for x in [platform,company,refresh,interactions]:assert not x['errors'] and not x['external']
(root/'result.json').write_text(json.dumps(r,indent=2)+'\n')
tokens=json.load(open('docs/release/enterprise-theme-comparison/tokens.json'))['b']['tokens'];(root/'tokens.json').write_text(json.dumps(tokens,indent=2)+'\n')
# Exact route inventory from actual routing/navigation; no future modules added.
platform_routes=['/platform','/platform/onboarding','/platform/customers','/platform/entities','/platform/entities/:id','/platform/entities/new','/platform/users','/platform/memberships','/platform/invitations','/platform/subscriptions','/platform/audit','/platform/settings']
company_routes=['/','/company-profile','/projects','/parties','/expense-categories','/accounts','/treasury-accounts','/subcontracts','/expenses','/supplier-payments','/subcontractor-advances','/subcontractor-certificates','/subcontractor-payments','/retention-releases','/retention-payments','/attendance','/payroll','/accounting-cycle','/accounting-reports']
inventory={'platform_routes':platform_routes,'company_routes':company_routes,'aliases':{'/historical-imports':'/expenses','/login, /no-company, /select-company, /auth-error':'Existing redirects within TENANT_READY; signed-out/Auth screens outside milestone'},'inline_workflows':['Employee/person masters in /parties','Historical source review and new/credit/correction/reversal UI in /expenses','Payroll profiles/drafts/source review inside /payroll','Subcontract creation and metadata edit in /subcontracts','Customer/Company/subscription forms in PlatformApplication editor','PDF print preview in ReportExport'],'static_only':['FOREMAN standalone Attendance shell: shared scoped primitives inspected; role-specific runtime acceptance deferred','Auth/login/callback/recovery/MFA flows: no functional changes, outside authenticated-console scope','Future custody/fixed assets/inventory/AR/full statements remain labeled unavailable, not implemented'],'route_sources':['src/auth/ProtectedApplication.tsx','src/platform/PlatformApplication.tsx','src/workspace/workspaceNavigation.ts'],'runtime_states':r['after']}
(root/'inventory.json').write_text(json.dumps(inventory,indent=2)+'\n')
b=json.loads((root/'baseline-hashes.json').read_text());hashfile=lambda p:hashlib.sha256(Path(p).read_bytes()).hexdigest();changed=[p for p,h in b.items() if not Path(p).exists() or hashfile(p)!=h]
allowed={'src/platform/platformUi.tsx','src/platform/platform.css','src/workspace/workspace.css','src/workspace/workspaceSuite.css','src/workspace/cycleFoundation.css','src/workspace/workspaceUi.tsx','src/components/ui/Badge.tsx','src/financial/ExpenseReadPanel.tsx','src/index.css','src/reports/ReportExport.tsx','src/reports/financialReport.css','src/tenant/tenantSettings.ts','docs/ENTERPRISE_THEME_COMPARISON.md','PROJECT_HANDOFF.md','PROJECT_ROADMAP.md'}
assert set(changed)<=allowed,changed
protected=[p for p in b if p.startswith('supabase/') or p.startswith('src/auth/') or p.startswith('src/financial/') and p!='src/financial/ExpenseReadPanel.tsx']
assert all(hashfile(p)==b[p] for p in protected)
(root/'preservation.json').write_text(json.dumps({'baseline_files':len(b),'changed_existing_files':changed,'preserved_existing_files':len(b)-len(changed),'protected_files_checked':len(protected),'all_sql_auth_financial_command_files_preserved':True,'source_hashes':{p:hashfile(p) for p in changed if p.startswith('src/')}},indent=2)+'\n')
print('Combined final evidence',len(r['before']),'baseline',len(r['after']),'final',len(r['scans']),'axe scans; preserved protected files',len(protected))
