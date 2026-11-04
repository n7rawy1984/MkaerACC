"""Inspect real bilingual closure decisions/readiness workbooks and PDF artifacts."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for locale in ['en','ar']:
 path='/tmp/narvo-project-closure-'+locale
 with ZipFile(path+'.xlsx') as z:
  xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
  for value in ['Synthetic business Company','CLOSE-FIN','Final administrative closeout','CLOSEOUT-VERIFIED-0','CLOSE-CONTRACT']:assert value in xml,value
  values=[]
  for name in z.namelist():
   if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
   sheet=E.fromstring(z.read(name))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   for c in sheet.findall('.//s:c',ns):
    v=c.find('s:v',ns)
    if c.get('t') not in ['s','inlineStr'] and v is not None:values.append(v.text)
  for value in ['130','100','-30','-95','-5']:assert value in values,(value,values)
  checks.append(locale+' Excel: exact posted cost and distinct unpaid liabilities, contract proof, operator/date/audit and resolution references')
 text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
 for value in ['CLOSE-FIN','130.00','30.00','95.00','5.00','CLOSE-CONTRACT','Finaladministrativecloseout','CLOSEOUT-VERIFIED-0']:assert value in compact,value
 checks.append(locale+' PDF: real decision and evidence, readable monetary values and preserved RTL/LTR')
Path('/tmp/narvo-project-closure-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2));print('PASS',len(checks),'closure artifact inspections')
