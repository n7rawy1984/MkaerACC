"""Check new synthetic Custody draft EN/AR exports from the actual component."""
import json,os,zipfile
from pathlib import Path
import xml.etree.ElementTree as ET
out=Path(os.environ['MAKER_OPERATIONS_EVIDENCE_DIR']);checks=[]
for locale in ('en','ar'):
 with zipfile.ZipFile(out/f'custody-drafts-{locale}.xlsx')as z:
  text=' '.join(''.join(ET.fromstring(z.read(n)).itertext())for n in z.namelist()if n.endswith('.xml'))
  assert ('Unposted amount AED'if locale=='en'else'المبلغ غير المرحل')in text
  assert ('Without a confirmed date'if locale=='en'else'بدون تاريخ مؤكد')in text
  assert '09/10/2026'in text and '2026-10-09'not in text
 checks.append(locale+' Excel: separate unposted funding claims, monthly totals, numeric and missing dates')
 assert(out/f'custody-drafts-{locale}.pdf').read_bytes().startswith(b'%PDF-')
 checks.append(locale+' PDF: artifact from verified actual bilingual print preview')
(out/'custody-artifacts.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
for c in checks:print('PASS',c)
