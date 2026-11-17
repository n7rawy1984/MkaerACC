"""Inspect real files produced by the disposable ACW-01 browser acceptance run."""
import json
import subprocess
import xml.etree.ElementTree as ET
import zipfile
from decimal import Decimal, InvalidOperation
from pathlib import Path

out = Path('/tmp/narvo-acw01-acceptance-evidence')
checks = []
namespace = '{http://schemas.openxmlformats.org/spreadsheetml/2006/main}'
for language in ['en', 'ar']:
    with zipfile.ZipFile(out / f'supplier-{language}.xlsx') as archive:
        strings = []
        if 'xl/sharedStrings.xml' in archive.namelist():
            strings = [''.join(item.itertext()) for item in ET.fromstring(archive.read('xl/sharedStrings.xml'))]
        values = []
        for name in archive.namelist():
            if name.startswith('xl/worksheets/sheet') and name.endswith('.xml'):
                for cell in ET.fromstring(archive.read(name)).iter(namespace + 'c'):
                    value = cell.find(namespace + 'v')
                    if value is not None:
                        values.append(strings[int(value.text)] if cell.get('t') == 's' else value.text)
        assert any(f'ACCEPT-5000-{language}' in value for value in values)
        def exact_amount(value):
            try:
                return Decimal(value.replace(',', '')) == Decimal('5000')
            except InvalidOperation:
                return False
        assert any(exact_amount(value) for value in values)
        checks.append(language + ' actual XLSX retains invoice reference and exact AED5000')
        if language == 'ar':
            assert any('\u0600' <= character <= '\u06ff' for character in ''.join(values))
            checks.append('Arabic XLSX retains Unicode headers')
    text = subprocess.check_output(['pdftotext', '-layout', str(out / f'supplier-{language}.pdf'), '-'], text=True)
    assert f'ACCEPT-5000-{language}' in text.replace('\n', ' ')
    assert '5,000.00' in text or '5000.00' in text
    checks.append(language + ' actual PDF retains invoice reference and exact AED5000')
(out / 'export-artifacts.json').write_text(json.dumps({'status': 'PASS', 'checks': checks}, indent=2))
print('\n'.join(checks))
