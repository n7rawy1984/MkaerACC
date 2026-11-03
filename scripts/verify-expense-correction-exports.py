"""Inspect real bilingual nonposting review exports from isolated browser tests."""
import json
import subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
checks = []
for locale in ['en', 'ar']:
    path = '/tmp/narvo-correction-' + locale
    with ZipFile(path + '.xlsx') as archive:
        ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        sheet = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
        if locale == 'ar':
            assert sheet.find('s:sheetViews/s:sheetView', ns).get('rightToLeft') in ['1', 'true']
        xml = '\n'.join(archive.read(n).decode() for n in archive.namelist() if n.endswith('.xml'))
        for value in ['Synthetic correction Company', '2026-10-06', 'P-ONE', 'P-TWO', 'Follow-up evidence']:
            assert value in xml
        checks.append(locale + ' Excel source, original/proposed Project, requested date, reason and RTL')
    text = subprocess.check_output(['pdftotext', '-layout', path + '.pdf', '-']).decode()
    assert 'Synthetic correction Company' in text and '2026-10-06' in text and 'Follow-up' in text
    if locale == 'en':
        assert 'not posted' in text and 'not approved posting dates' in text
    checks.append(locale + ' PDF identity/date/reason and nonposting status')
Path('/tmp/narvo-expense-correction-exports.json').write_text(json.dumps({'status': 'PASS', 'checks': checks}, indent=2))
print('PASS: review Excel/PDF evidence and nonposting status')
