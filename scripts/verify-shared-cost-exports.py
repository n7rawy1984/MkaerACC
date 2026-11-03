"""Validate actual browser-produced allocation artifacts and reconciled amounts."""
import json
import subprocess
import re
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
    path='/tmp/narvo-shared-'+locale
    with ZipFile(path+'.xlsx') as z:
        xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
        for value in ['Synthetic correction Company','PCC-','P-ONE','P-TWO','Equipment hours','OPERATING-LOG-1','Shared equipment consumption','hours']:
            assert value in xml,value
        sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'))
        values=[c.find('s:v',ns).text for c in sheet.findall('.//s:c',ns) if c.find('s:v',ns) is not None and c.get('t') not in ['s','str','inlineStr']]
        assert values==['133.34','100','33.34','33.33','0','33.33','33.33','0','33.33','200','100','100'],values
        if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['1','true']
        checks.append(locale+' Excel exact source/project/overhead allocation and total 100 AED; basis/driver/audit/RTL')
    text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode()
    for value in ['Synthetic correction Company','PCC-','P-ONE','P-TWO','Equipment hours','OPERATING-LOG-1','33.34','33.33','100.00']:
        assert re.sub(r'\s','',value) in re.sub(r'\s','',text),value
    checks.append(locale+' PDF retains allocation basis, driver, Project/source references and exact amounts')
Path('/tmp/narvo-shared-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS: shared allocation bilingual Excel/PDF artifacts')
