"""Inspect actual CUS-04 bilingual history and Treasury Excel/PDF downloads."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for kind in ['history','treasury']:
 for locale in ['en','ar']:
  path='/tmp/narvo-cus04-'+kind+'-'+locale
  with ZipFile(path+'.xlsx') as z:
   xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
   assert 'Synthetic business Company' in xml
   numbers=[]
   for name in z.namelist():
    if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
    sheet=E.fromstring(z.read(name))
    if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
    for c in sheet.findall('.//s:c',ns):
     v=c.find('s:v',ns)
     if c.get('t') not in ['s','inlineStr'] and v is not None:numbers.append(v.text)
   for n in (['20','5','2'] if kind=='history' else ['1000','20','2','982']):assert n in numbers,(n,numbers)
   if kind=='history':
    for ref in ['BROWSER-FUND','BROWSER-EXP','BROWSER-RETURN','FINALIZED','POSTED']:assert ref in xml,ref
   checks.append(kind+' '+locale+' Excel: numeric exact money, Company, statuses/evidence and direction')
  text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
  assert 'SyntheticbusinessCompany' in compact
  for n in (['20.00','5.00','2.00'] if kind=='history' else ['1,000.00','982.00']):assert n in compact,(n,compact[-300:])
  if kind=='history':
   for ref in ['BROWSER-FUND','BROWSER-EXP','BROWSER-RETURN','FINALIZED']:assert ref in compact,ref
  checks.append(kind+' '+locale+' PDF: actual posted source evidence/status and exact monetary values remain readable')
Path('/tmp/narvo-cus04-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'CUS-04 artifact inspections')
