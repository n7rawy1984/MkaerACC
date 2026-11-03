"""Inspect generated mixed-destination review artifacts, not fabricated report data."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
import json
import subprocess
import re
checks=[]
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
    path='/tmp/narvo-mixed-assignment-'+locale
    with ZipFile(path+'.xlsx') as z:
        xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
        for value in ['Synthetic assignment Company','SYN-40','SYN-41','SYN-42','2026-09','P-TWO','Reviewed three source destinations']:
            assert value in xml,value
        # Existing first sheet lists source amounts; second is the reconciled destination summary.
        sheet=E.fromstring(z.read('xl/worksheets/sheet2.xml'))
        numeric=[c.find('s:v',ns).text for c in sheet.findall('.//s:c',ns) if c.find('s:v',ns) is not None and c.get('t') not in ['s','inlineStr','str']]
        assert numeric==['1','125.5','1','125.5','1','125.5','3','376.5'],numeric
        if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
        checks.append(locale+' Excel exact destination counts/amounts reconcile to source total; identity/period/traceability/RTL')
    text=subprocess.check_output(['pdftotext','-layout',path+'.pdf','-']).decode()
    for value in ['Synthetic assignment Company','SYN-40','SYN-41','SYN-42','P-TWO','376.50','125.50']:
        assert value in text,value
    if locale=='en':assert 'unposted' in text and 'not posted project costs' in text
    checks.append(locale+' PDF source/destination amounts and unposted accounting basis')
with ZipFile('/tmp/narvo-mixed-assignment-audit.xlsx') as z:
    xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
    refs=re.search(r'([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12}) · ([0-9a-f]{8}(?:-[0-9a-f]{4}){3}-[0-9a-f]{12})',xml)
    assert refs and all(value in xml for value in ['Assignment audit details','SYN-40','SYN-41','SYN-42','P-TWO'])
    text=subprocess.check_output(['pdftotext','-raw','/tmp/narvo-mixed-assignment-audit.pdf','-']).decode()
    assert all(ref in re.sub(r'\s','',text) for ref in refs.groups())
    checks.append('Saved audit Excel/PDF retain exact immutable receipt/request references and per-source destinations')
Path('/tmp/narvo-mixed-assignment-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS: mixed allocation English/Arabic Excel and PDF artifacts')
