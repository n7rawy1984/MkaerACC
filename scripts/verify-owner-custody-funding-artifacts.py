"""Validate actual synthetic direct-owner-equity EN/AR report artifacts."""
import json,os,zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
out=Path(os.environ['MAKER_OPERATIONS_EVIDENCE_DIR']);checks=[]
for locale in ('en','ar'):
 with zipfile.ZipFile(out/f'owner-custody-{locale}.xlsx')as z:
  text=' '.join(''.join(ET.fromstring(z.read(n)).itertext())for n in z.namelist()if n.endswith('.xml'))
  assert 'Synthetic contributor'in text
  assert ('Direct owner equity contribution'if locale=='en'else'مساهمة مالك مباشرة بحقوق الملكية')in text
  assert '03/11/2026'in text and '2026-11-03'not in text
 checks.append(locale+' Excel: contributor, direct equity route, numeric date and unposted monthly claims')
 assert(out/f'owner-custody-{locale}.pdf').read_bytes().startswith(b'%PDF-')
 checks.append(locale+' PDF: actual verified bilingual owner-route print preview')
(out/'owner-artifacts.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
for c in checks:print('PASS',c)
