"""Actual bilingual lifecycle artifacts, with posted financial dependency snapshots."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-project-lifecycle-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for value in ['Synthetic business Company','P-1','Financial Project operational completion','SUB-ONE','SUPPLIER_PAYABLE','SUBCONTRACTOR_RETENTION_PAYABLE']:assert value in xml,value
  values=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:values.append(v.text)
  for value in ['253','-100','-70','-3','15']:assert value in values,(value,values)
  checks.append(locale+' Excel: Company/Project, real audit/operator/reason/date, separate liabilities/advance/retention and exact posted cost')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for value in ['P-1','253.00','100.00','70.00','15.00','SUB-ONE','FinancialProjectoperationalcompletion']:assert value in compact,value
 checks.append(locale+' PDF: readable financial dependency amounts, Project, recorded reason, contract and RTL/LTR print')
Path('/tmp/narvo-project-lifecycle-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'lifecycle artifact inspections')
