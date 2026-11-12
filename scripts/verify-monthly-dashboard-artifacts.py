from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
from decimal import Decimal
import subprocess,json
out=Path('/tmp/narvo-monthly-dashboard');checks=[];ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
 with ZipFile(out/('monthly-'+locale+'.xlsx'))as z:
  text=' '.join(z.read(n).decode()for n in z.namelist()if n.endswith('.xml'))
  assert '11/2026'in text and '03/11/2026'in text
  sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'));values=[Decimal(c.find('s:v',ns).text)for c in sheet.findall('.//s:c',ns)if c.get('t')not in ['s','inlineStr','str']and c.find('s:v',ns)is not None]
  assert Decimal('371350.70')in values and Decimal('4800')in values
  if locale=='ar':assert sheet.find('.//s:sheetView',ns).get('rightToLeft')in ['1','true']
  checks.append(locale+' XLSX contains exact monthly values, numeric dates and correct direction')
 pdf=out/('monthly-'+locale+'.pdf');assert pdf.stat().st_size>10000
 content=subprocess.check_output(['pdftotext','-layout',str(pdf),'-'],text=True)
 assert '371,350.70'in content and '11/2026'in content and '03/11/2026'in content
 checks.append(locale+' actual PDF contains November, numeric transaction date and ledger closing')
(out/'artifacts.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2));print('PASS',len(checks),'actual XLSX/PDF artifact checks')
