import json,zipfile,xml.etree.ElementTree as ET,subprocess
from pathlib import Path
checks=[]
for kind in ['attendance','register','costs']:
 for lang in ['en','ar']:
  base=Path('/tmp/narvo-hr-'+kind+'-'+lang)
  with zipfile.ZipFile(base.with_suffix('.xlsx')) as z:
   xml=' '.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
   text=' '.join(' '.join(ET.fromstring(z.read(n)).itertext()) for n in z.namelist() if n.endswith('.xml'))
   assert 'Synthetic' in text and '2026-10' in text
   if kind=='register':assert '336.00' in text and '341.00' in text and '5.00' in text
   if kind=='attendance':assert '480' in text and '2026-10-31' in text
   if kind=='costs':
    assert '341' in text and '0.00' in xml and ('Payroll' in text or 'رواتب' in text)
   if lang=='ar':assert 'rightToLeft="1"' in xml or 'rightToLeft="true"' in xml
   checks.append(kind+' '+lang+' XLSX identity, period, exact amounts/minutes and RTL where applicable')
for kind in ['attendance','register','payslip','costs']:
 for lang in ['en','ar']:
  base=Path('/tmp/narvo-hr-'+kind+'-'+lang);pdf=base.with_suffix('.pdf');assert pdf.stat().st_size>1000
  text=subprocess.check_output(['pdftotext','-layout',str(pdf),'-']).decode()
  assert 'Synthetic' in text and '2026-10' in text
  if lang=='ar':assert any('\u0600'<=c<='\u06ff' for c in text)
  if kind=='payslip':assert '336.00' in text and '341.00' in text and '5.00' in text
  checks.append(kind+' '+lang+' actual PDF identity/period and Arabic glyphs where applicable')
Path('/tmp/narvo-hr-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS',len(checks),'artifact checks')
