"""Read actual generated exports; no accounting or hosted operations."""
import json, subprocess, zipfile, xml.etree.ElementTree as ET
from pathlib import Path
out=Path('/tmp/narvo-cr07-evidence');checks=[]
for locale in ['en','ar']:
 p=out/f'statements-final-{locale}.xlsx'
 with zipfile.ZipFile(p) as z:
  sheets=[n for n in z.namelist() if n.startswith('xl/worksheets/sheet') and n.endswith('.xml')]
  assert len(sheets)==3
  values=[float(c.text) for n in sheets for c in ET.fromstring(z.read(n)).iter('{http://schemas.openxmlformats.org/spreadsheetml/2006/main}v') if c.text and c.text.replace('.','',1).replace('-','',1).isdigit()]
  assert all(any(abs(v-n)<0.00001 for v in values) for n in [105232.66,104470.16,762.50,-1529.84])
  if locale=='ar': assert any(b'rightToLeft="1"' in z.read(n) or b'rightToLeft="true"' in z.read(n) for n in sheets)
 checks.append(locale+' actual rendered Excel: three financial statements and exact independent assets/equity/tax/loss')
 text=subprocess.check_output(['pdftotext','-layout',str(out/f'statements-final-{locale}.pdf'),'-']).decode().replace(',','')
 assert '105232.66' in text and '104470.16' in text and '1529.84' in text
 checks.append(locale+' actual rendered PDF contains final independent assets/equity/loss')
json.dump({'checks':checks,'hostedWrites':0},open(out/'exports.json','w'),ensure_ascii=False,indent=2)
print('\n'.join(checks))
