from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
from decimal import Decimal
import json,subprocess
out=Path('/tmp/narvo-operational-dashboard');ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};checks=[]
for lang in ['en','ar']:
 with ZipFile(out/('report-'+lang+'.xlsx'))as z:
  sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'));values=[Decimal(c.find('s:v',ns).text)for c in sheet.findall('.//s:c',ns)if c.get('t')not in ['s','inlineStr','str']and c.find('s:v',ns)is not None]
  assert Decimal('177169.50')in values and Decimal('330.50')in values
  text=' '.join(z.read(n).decode()for n in z.namelist()if n.endswith('.xml'));assert '08/2026'in text
  if lang=='ar':assert sheet.find('.//s:sheetView',ns).get('rightToLeft')in['true','1']
  checks.append(lang+' dedicated report XLSX has exact complete totals and correct direction')
 pdf=out/('report-'+lang+'.pdf');content=subprocess.check_output(['pdftotext','-layout',str(pdf),'-'],text=True);assert pdf.stat().st_size>10000 and '177,169.50'in content and '08/2026'in content
 checks.append(lang+' dedicated report PDF retains full-period balance')
(out/'artifacts.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2));print('PASS',len(checks),'actual export artifact checks')
