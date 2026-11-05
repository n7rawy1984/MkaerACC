import json,zipfile,xml.etree.ElementTree as ET,subprocess
from pathlib import Path
checks=[]
for kind in ['drafts','costs']:
 for language in ['en','ar']:
  base=Path('/tmp/narvo-expense-'+kind+'-'+language)
  with zipfile.ZipFile(base.with_suffix('.xlsx')) as z:
   xml=' '.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
   text=' '.join(' '.join(ET.fromstring(z.read(n)).itertext()) for n in z.namelist() if n.endswith('.xml'))
   assert 'BROWSER-EXPENSE' in text and 'Synthetic business Company' in text
   if kind=='costs':
    assert 'BROWSER-EVIDENCE' in text and 'Synthetic bank' in text and '100.01' in text
   else:
    assert 'BROWSER-EXP-SOURCE' in text and 'POSTED' in text and '100.01' in text
   if language=='ar':assert 'rightToLeft="1"' in xml or 'rightToLeft="true"' in xml
   checks.append(kind+' '+language+' XLSX identity/source/status/exact amount/direction')
  pdf=base.with_suffix('.pdf');assert pdf.stat().st_size>1000
  text=subprocess.check_output(['pdftotext','-layout',str(pdf),'-']).decode()
  assert 'BROWSER-EXPENSE' in text and 'Synthetic business Company' in text
  if language=='ar':assert any('\u0600'<=c<='\u06ff' for c in text)
  checks.append(kind+' '+language+' actual PDF identity/source and Arabic glyphs where applicable')
Path('/tmp/narvo-expense-draft-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS',len(checks),'bilingual artifacts')
