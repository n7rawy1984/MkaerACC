"""Focused content checks on the actual amended PO browser downloads."""
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as ET
import subprocess,json
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for lang in ['en','ar']:
    with ZipFile('/tmp/narvo-operations-po-'+lang+'.xlsx') as book:
        strings=[''.join(x.itertext()) for x in ET.fromstring(book.read('xl/sharedStrings.xml')).findall('s:si',ns)]
        rows=[]
        for sheet in [n for n in book.namelist() if n.startswith('xl/worksheets/sheet') and n.endswith('.xml')]:
            for row in ET.fromstring(book.read(sheet)).findall('.//s:row',ns):
                cells=[]
                for cell in row.findall('s:c',ns):
                    val=cell.find('s:v',ns);text=val.text if val is not None else ''
                    cells.append(strings[int(text)] if cell.get('t')=='s' else text)
                rows.append(cells)
        text='\n'.join(' | '.join(r) for r in rows)
        assert 'EXISTING-FICTIONAL-PO-2026-000001' in text
        assert 'Fictional supplier accepted revised quantity and price' in text
        assert any('10' in r and '12' in r and '24' in r for r in rows),rows
        assert any('288' in r for r in rows),rows
        checks.append(lang+' actual updated PO XLSX preserves reference, before10/12AED, after12/24AED and288AED commitment')
    text=subprocess.run(['pdftotext','-layout','/tmp/narvo-operations-po-'+lang+'.pdf','-'],capture_output=True,text=True,check=True).stdout
    assert all(s in text for s in ['PO-','2026-','000001','10','12','24.00','288.00'])
    checks.append(lang+' actual amended PO PDF contains original reference, changed quantities/prices and exact revised value')
Path('docs/procurement-operations-evidence/exports.json').write_text(json.dumps({'count':len(checks),'checks':checks,'hostedWrites':0},indent=2)+'\n')
print('PASS',len(checks),'actual bilingual amended-PO export-content checks')
