"""Inspect generated bilingual statement and blank history workbook artifacts."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-custody-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for value in ['Synthetic business Company','Synthetic custodian','2026-10-05','2026-10-15','2026-10-01','2026-10-31','POSTED']:assert value in xml,value
  numbers=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:numbers.append(v.text)
  for value in ['10','3','2','-5','5']:assert value in numbers,(value,numbers)
  checks.append(locale+' Excel: numeric exact opening/spending/returns/signed difference/closing, Company, person, dates, status and RTL/LTR')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for value in ['2026-10-05','2026-10-15','10.00','3.00','2.00','-5.00','5.00','POSTED']:assert value in compact,value
 assert 'SyntheticbusinessCompany' in compact and 'Syntheticcustodian' in compact
 checks.append(locale+' PDF: actual Company/person/source dates/status and signed monetary values remain extractable')
with ZipFile('/tmp/narvo-custody-template-en.xlsx') as z:
 sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'))
 assert len(sheet.findall('s:sheetData/s:row',ns))==6,'Template contains an invented data row'
 xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
 for value in ['Source document','Company ID','Custodian Party ID','Reimbursement minor','Supporting references','Accounting classification','August 2026']:assert value in xml,value
 checks.append('Blank history template: all required evidence fields, August 2026 scope, no invented data rows')
Path('/tmp/narvo-custody-reconciliation-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'custody artifact inspections')
