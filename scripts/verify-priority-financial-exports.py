import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-priority-financial-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for value in ['Synthetic business Company','BROWSER-DIRECT','BROWSER-PERSONAL','BROWSER-COUNT','UNPOSTED']:assert value in xml,value
  nums=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:nums.append(v.text)
  for value in ['250','20','0']:assert value in nums,value
  checks.append(locale+' Excel: exact numeric evidence/count values, original references, unposted status, Company and direction')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for value in ['BROWSER-DIRECT','BROWSER-PERSONAL','BROWSER-COUNT','UNPOSTED','250.00','20.00']:assert value in compact,value
 checks.append(locale+' PDF: evidence and review trace, exact money and explicit unposted classification')
Path('/tmp/narvo-priority-financial-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'financial-evidence artifact inspections')
