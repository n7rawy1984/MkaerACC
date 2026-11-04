"""Inspect actual bilingual statement Excel and print-to-PDF artifacts."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-party-statement-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for v in ['Synthetic business Company','Initial supplier','SUP-1','2026-10-01','2026-10-31','REVERSED',('AED' if locale=='en' else 'درهم')]:assert v in xml,v
  values=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:values.append(v.text)
  for v in ['-100','40','30','-90','-130']:assert v in values,(v,values)
  checks.append(locale+' Excel: exact numeric opening/debits/credits/running/closing, Company/Party/period/source/status and direction')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for v in ['100.00','40.00','30.00','90.00','130.00','REVERSED','SUP-1','2026-10-01','2026-10-31']:assert v in compact,v
 checks.append(locale+' PDF: readable exact financial values, Party/period and current source status')
Path('/tmp/narvo-party-statements-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2))
print('PASS',len(checks),'bilingual statement artifact inspections')
