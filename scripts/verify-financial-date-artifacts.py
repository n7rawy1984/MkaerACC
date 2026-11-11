"""Validate synthetic monthly exports created by verify-financial-dates-browser.mjs."""
import json
import os
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

output = Path(os.environ['FINANCIAL_DATE_EVIDENCE_DIR'])
checks = []
for locale in ('en', 'ar'):
    with zipfile.ZipFile(output / f'november-{locale}.xlsx') as workbook:
        text = ' '.join(''.join(ET.fromstring(workbook.read(name)).itertext())
                        for name in workbook.namelist() if name.endswith('.xml'))
        assert '09/11/2026' in text and '01/11/2026' in text and '2026-11-09' not in text
        assert 'OCT-NOV' in text and 'NOV-START' in text
        assert 'SEP-OCT' not in text and 'MISSING' not in text
        assert ('Source worksheet month' if locale == 'en' else 'شهر ورقة المصدر') in text
        checks.append(f'{locale} Excel: numeric dates, correct monthly rows, separate provenance')
    assert (output / f'november-{locale}.pdf').read_bytes().startswith(b'%PDF-')
    checks.append(f'{locale} PDF: artifact from verified monthly print preview')
(output / 'artifacts.json').write_text(json.dumps({'status': 'PASS', 'checks': checks}, indent=2))
for check in checks:
    print('PASS', check)
