from pathlib import Path
from zipfile import ZipFile
from decimal import Decimal
import xml.etree.ElementTree as E
import subprocess,json
out=Path('docs/purchase-orders-evidence');checks=[];ns={'x':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for lang,unit,total in [('en',1200,3000),('ar',850,850)]:
 with ZipFile(out/('order-'+lang+'.xlsx'))as z:
  def numbers(sheet):
   r=E.fromstring(z.read('xl/worksheets/sheet'+str(sheet)+'.xml'))
   return [int(Decimal(c.find('x:v',ns).text)*100)for c in r.findall('.//x:c',ns)if c.get('t')not in('s','inlineStr','str')and c.find('x:v',ns)is not None]
  assert numbers(2)==[unit,total],numbers(2)
  assert numbers(3)==[total],numbers(3)
  checks.append(lang+' Excel exact quoted unit price, line amount and total')
 text=subprocess.check_output(['pdftotext',str(out/('order-'+lang+'.pdf')),'-']).decode()
 assert ('30.00'if lang=='en'else'8.50')in text and 'Fictional Purchasing Company'in text
 checks.append(lang+' printable PDF contains correct Company and amount')
(out/'exports.json').write_text(json.dumps({'checks':checks,'count':len(checks),'hostedWrites':0},indent=2)+'\n');print('PASS',checks)
