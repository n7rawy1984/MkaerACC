"""Inspect synthetic workbooks emitted by verify-premium-exports.mjs."""
from pathlib import Path
from zipfile import ZipFile
import json
import xml.etree.ElementTree as ET
ns={'x':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
    for kind in ['financial','payroll']:
        with ZipFile('/tmp/narvo-premium-system/'+kind+'-'+locale+'.xlsx') as z:
            sheet=ET.fromstring(z.read('xl/worksheets/sheet1.xml'))
            styles=z.read('xl/styles.xml').decode()
            strings=z.read('xl/sharedStrings.xml').decode()
            assert 'EDF3FF' in styles and '16243B' in styles, (locale,kind,'brand')
            if kind=='payroll':
                assert '123.45' in strings and 'Synthetic employee' in strings
            else:
                assert any(c.find('x:v',ns) is not None and c.find('x:v',ns).text=='123.45' for c in sheet.findall('.//x:c',ns) if c.attrib.get('t')!='s')
            direction=sheet.find('x:sheetViews/x:sheetView',ns).attrib.get('rightToLeft','0')
            assert (direction in ['1','true'])==(locale=='ar')
        checks.append(locale+' '+kind+' XLSX restrained brand, exact values and direction verified')
Path('/tmp/narvo-premium-system/export-artifacts.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS',len(checks),'branded export artifact checks')
