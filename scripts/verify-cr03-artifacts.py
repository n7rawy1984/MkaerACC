"""Inspect actual bilingual CR03 downloads; no database/network mutations."""
import zipfile,xml.etree.ElementTree as E,subprocess,json
from pathlib import Path
checks=[];root=Path('/tmp/narvo-cr03-evidence')
for locale in ['en','ar']:
 with zipfile.ZipFile(root/('bank-'+locale+'.xlsx'))as z:
  x=E.fromstring(z.read('xl/worksheets/sheet1.xml'));ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};numbers=[c.find('s:v',ns).text for c in x.findall('.//s:c',ns)if c.get('t')not in['s','inlineStr']and c.find('s:v',ns)is not None];assert numbers.count('10595')>=3 and numbers.count('0')>=3
 checks.append(locale+' actual XLSX numeric balances/difference match AED10595 and zero')
 text=subprocess.check_output(['pdftotext',str(root/('bank-'+locale+'.pdf')),'-']).decode();assert'10595.00'in text or'10,595.00'in text
 checks.append(locale+' actual PDF text includes independently reconciled AED10595')
for locale in ['en','ar']:
 with zipfile.ZipFile(root/('reconciled-'+locale+'.xlsx'))as z:
  x=E.fromstring(z.read('xl/worksheets/sheet1.xml'));ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'};numbers=[c.find('s:v',ns).text for c in x.findall('.//s:c',ns)if c.get('t')not in['s','inlineStr']and c.find('s:v',ns)is not None];assert numbers.count('11195')>=2
  content=''.join(z.read(n).decode(errors='ignore')for n in z.namelist()if n.endswith('.xml'));assert 'Demo Bank'in content
 checks.append(locale+' final XLSX identifies Bank scope and independently reconciled AED11195')
(root/'artifacts.json').write_text(json.dumps({'checks':checks},indent=2));print('PASS',len(checks),'actual exported artifact checks')
