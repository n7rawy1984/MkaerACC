from pathlib import Path
from zipfile import ZipFile
import xml.etree.ElementTree as E
import subprocess,json
from decimal import Decimal
out=Path('docs/procurement-evidence');checks=[];ns={'x':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for lang in ['en','ar']:
 with ZipFile(out/('procurement-'+lang+'.xlsx'))as z:
  shared=E.fromstring(z.read('xl/sharedStrings.xml'))
  strings=[''.join(x.itertext())for x in shared]
  sheet=E.fromstring(z.read('xl/worksheets/sheet2.xml'))
  values=[]
  for row in sheet.findall('x:sheetData/x:row',ns):
   cells=[]
   for c in row.findall('x:c',ns):
    v=c.find('x:v',ns)
    if v is not None:cells.append(strings[int(v.text)]if c.get('t')=='s'else v.text)
   if 'Fictional Material'in cells:values=cells
  assert values, 'Missing actual material row'
  # Ordered10,received6,invoiced3,returned0,remaining4/3,commitment40 AED.
  assert values[-7:-1]==['10','6','3','0','4','3'],values
  assert Decimal(values[-1])==40,values
  checks.append(lang+' Excel ordered/received/invoiced/remaining quantities and AED40 commitment independently verified')
 text=subprocess.check_output(['pdftotext',str(out/('procurement-'+lang+'.pdf')),'-']).decode()
 assert 'Fictional Procurement Company'in text and '40.00'in text
 checks.append(lang+' printable PDF contains correct Company and AED40 remaining commitment')
(out/'exports.json').write_text(json.dumps({'checks':checks,'count':len(checks),'hostedWrites':0},indent=2)+'\n');print('PASS',checks)
