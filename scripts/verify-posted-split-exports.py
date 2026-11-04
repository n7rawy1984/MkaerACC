"""Inspect actual bilingual ledger export artifacts, including original/corrected/delta evidence."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-posted-split-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for v in ['Synthetic correction Company','CORRECTED-LOG-1','P-ONE','P-TWO','PCC-','SYN-40']:assert v in xml,v
  sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'))
  if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
  rows=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   for row in E.fromstring(z.read(name)).findall('.//s:row',ns):
    values=[c.find('s:v',ns).text for c in row if c.find('s:v',ns) is not None and c.get('t') not in ['s','str','inlineStr']]
    if values:rows.append(values)
  for row in [['184.07','58.57','125.5'],['41.83','25.1','-16.73'],['41.83','100.4','58.57'],['41.84','0','-41.84']]:assert row in rows,row
  checks.append(locale+' Excel: exact Company/Project totals and before/after/net audit evidence')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for v in ['CORRECTED-LOG-1','125.50','25.10','100.40','41.84','16.73','PCC-']:assert v in compact,v
 checks.append(locale+' PDF: exact source/correction amounts and audit references')
Path('/tmp/narvo-posted-split-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS four bilingual artifact inspections')
