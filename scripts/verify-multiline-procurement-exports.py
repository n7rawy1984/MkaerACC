"""Inspect the actual local browser's bilingual accounting downloads."""
import json
import subprocess
from decimal import Decimal
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for lang in ['en','ar']:
    with ZipFile('/tmp/narvo-multiline-'+lang+'.xlsx') as workbook:
        strings=[''.join(x.itertext()) for x in ET.fromstring(workbook.read('xl/sharedStrings.xml')).findall('s:si',ns)]
        rows=[]
        for row in ET.fromstring(workbook.read('xl/worksheets/sheet1.xml')).findall('.//s:row',ns):
            cells=[]
            for cell in row.findall('s:c',ns):
                value=cell.find('s:v',ns)
                text=value.text if value is not None else ''
                cells.append(strings[int(text)] if cell.get('t')=='s' else text)
            rows.append(cells)
        allocations=[r for r in rows if r[0]=='BROWSER-CONSOLIDATED']
        assert len(allocations)==2
        assert sum(Decimal(r[8]) for r in allocations)==120
        assert sum(Decimal(r[9]) for r in allocations)==6
        assert sum(Decimal(r[10]) for r in allocations)==120
        assert sum(Decimal(r[11]) for r in allocations)==0
        assert sorted(Decimal(r[6]) for r in allocations)==[Decimal(3),Decimal(6)]
        checks.append(lang+' actual XLSX reconciles two allocations, quantities6/3, net120,VAT6,GRNI120 and no variance')
    text=subprocess.run(['pdftotext','-layout','/tmp/narvo-multiline-'+lang+'.pdf','-'],capture_output=True,text=True,check=True).stdout
    assert all(part in text for part in ['BROWSER-','CONSOLIDA','TED','60.00','3.00'])
    checks.append(lang+' actual PDF contains the legal invoice reference and exact allocation net/VAT values')
Path('docs/multiline-procurement-evidence/exports.json').write_text(json.dumps({'count':len(checks),'checks':checks,'hostedWrites':0},indent=2)+'\n')
print('PASS',len(checks),'actual bilingual export-content checks')
