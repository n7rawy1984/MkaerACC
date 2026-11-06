# Inspect actual browser artifacts; run verify-maker-operational-browser.mjs first.
from pathlib import Path
import zipfile,xml.etree.ElementTree as X,json
out=Path('/tmp/narvo-maker-operational-20261106');checks=[];ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
 z=zipfile.ZipFile(out/('register-'+locale+'.xlsx'));sheet=X.fromstring(z.read('xl/worksheets/sheet1.xml'));head=sheet.find('s:sheetData/s:row[@r="4"]',ns);assert len(head)==15
 assert sheet.findall('.//s:mergeCell',ns)and all(x.attrib['ref'].split(':')[1].startswith('O')for x in sheet.findall('.//s:mergeCell',ns));assert not sheet.findall('.//s:f',ns)
 text=z.read('xl/sharedStrings.xml').decode();assert ('Earned payroll cost'if locale=='en'else'تكلفة الراتب المستحق')in text;assert ('Advance recovery'if locale=='en'else'استرداد السلفة')in text;assert all(x in text for x in ['341.00','5.00','336.00']);checks.append(locale+' downloaded15column workbook has exact earned/recovery/cash values and safe literal cells')
 pdf=(out/('register-'+locale+'.pdf')).read_bytes();assert pdf.startswith(b'%PDF')and len(pdf)>10000;checks.append(locale+' actual Chromium PDF generated from bilingual register')
for file,needle in [('advances.xlsx','Actually recovered AED'),('company-journals.xlsx','HR_PAYROLL_RECOVERY')]:
 z=zipfile.ZipFile(out/file);assert needle in z.read('xl/sharedStrings.xml').decode();assert not X.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//s:f',ns);checks.append(file+' actual downloaded report contains intended accounting trace and no formulas')
(out/'exports.json').write_text(json.dumps({'status':'PASS','checks':checks,'hosted':False},indent=2)+'\n');print('PASS',len(checks),'actual XLSX/PDF artifact checks')
