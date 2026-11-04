import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
checks=[];ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
 path='/tmp/narvo-operational-finance-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for value in ['Synthetic business Company','BROWSER-ACTUAL-CURRENT','BROWSER-DIRECT-CAPITAL','BROWSER-PERSONAL-CLAIM','Original signed receipt']:assert value in xml,value
  nums=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:nums.append(v.text)
  for value in ['20000','1000','10']:assert value in nums,value
  checks.append(locale+' Excel: Company, original references, classifications, exact numeric amounts and direction')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for value in ['BROWSER-ACTUAL-CURRENT','BROWSER-DIRECT-CAPITAL','BROWSER-PERSONAL-CLAIM','20,000.00','1,000.00','10.00']:assert value in compact,value
 checks.append(locale+' PDF: actual classified funding/claim documents, exact amounts and source trace')
Path('/tmp/narvo-operational-finance-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'posted-finance artifact inspections')
