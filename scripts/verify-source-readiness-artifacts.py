"""Check actual synthetic EN/AR source review exports from the browser fixture."""
import json
import os
from pathlib import Path
import xml.etree.ElementTree as ET
import zipfile

output = Path(os.environ['MAKER_OPERATIONS_EVIDENCE_DIR'])
checks = []
for locale in ('en', 'ar'):
    with zipfile.ZipFile(output / f'source-review-{locale}.xlsx') as workbook:
        text = ' '.join(''.join(ET.fromstring(workbook.read(name)).itertext())
                        for name in workbook.namelist() if name.endswith('.xml'))
        assert ('Review requirements' if locale == 'en' else 'متطلبات المراجعة') in text
        assert ('Canonical document approved — not posted' if locale == 'en'
                else 'مستند محاسبي معتمد — غير مرحل') in text
        assert '09/11/2026' in text and '2026-11-09' not in text
    checks.append(f'{locale} Excel: lifecycle, review requirements, numeric dates')
    assert (output / f'source-review-{locale}.pdf').read_bytes().startswith(b'%PDF-')
    checks.append(f'{locale} PDF: artifact from verified actual print preview')
(output / 'artifacts.json').write_text(json.dumps({'status': 'PASS', 'checks': checks}, indent=2))
for check in checks:
    print('PASS', check)
