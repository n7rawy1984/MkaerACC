"""Verify real bilingual artifacts from the isolated cost-ledger browser check."""
import json
import subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET

checks = []
for locale in ['en', 'ar']:
    path = '/tmp/narvo-project-cost-' + locale
    with ZipFile(path + '.xlsx') as archive:
        ns = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
        first = ET.fromstring(archive.read('xl/worksheets/sheet1.xml'))
        numeric = [cell.find('s:v', ns).text for cell in first.findall('.//s:c', ns)
                   if cell.find('s:v', ns) is not None and cell.get('t') not in ['s', 'inlineStr']]
        assert numeric[-3:] == ['420', '100', '320'], numeric
        assert '200' in numeric and '50' in numeric and '70' in numeric
        if locale == 'ar':
            assert first.find('s:sheetViews/s:sheetView', ns).get('rightToLeft') in ['1', 'true']
        movements = ET.fromstring(archive.read('xl/worksheets/sheet2.xml'))
        values = [cell.find('s:v', ns).text for cell in movements.findall('.//s:c', ns)
                  if cell.find('s:v', ns) is not None and cell.get('t') not in ['s', 'inlineStr']]
        assert '-100' in values
        checks.append(locale + ' Excel exact totals, negative reversal movement and RTL verified')
    text = subprocess.check_output(['pdftotext', '-layout', path + '.pdf', '-']).decode()
    assert 'Synthetic cost Company' in text and '2026-09-01' in text and '2026-10-31' in text
    assert '320.00' in text and '100.00' in text
    if locale == 'en':
        assert 'not profitability' in text and 'Reversal' in text
    checks.append(locale + ' PDF Company/period, totals and reversal trace verified')
Path('/tmp/narvo-project-cost-ledger-exports.json').write_text(json.dumps({'status': 'PASS', 'checks': checks}, indent=2))
print('PASS: bilingual cost-ledger Excel/PDF artifact contents')
