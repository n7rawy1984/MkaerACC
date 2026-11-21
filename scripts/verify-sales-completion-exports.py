"""Validate actual bilingual invoice downloads against an independent three-line answer key."""
import json, zipfile, xml.etree.ElementTree as E, subprocess
from decimal import Decimal
from pathlib import Path
ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
    with zipfile.ZipFile('/tmp/narvo115-'+locale+'.xlsx') as z:
        shared=[''.join(x.itertext()) for x in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)] if 'xl/sharedStrings.xml' in z.namelist() else []
        sheets=sorted(p for p in z.namelist() if p.startswith('xl/worksheets/sheet') and p.endswith('.xml'))
        assert len(sheets)==2
        tables=[]
        for sheet in sheets:
            rows=[]
            for row in E.fromstring(z.read(sheet)).findall('.//m:sheetData/m:row',ns):
                cells=[]
                for cell in row.findall('m:c',ns):
                    v=cell.find('m:v',ns); inline=cell.find('m:is',ns)
                    value=v.text if v is not None else ''.join(inline.itertext()) if inline is not None else ''
                    cells.append(shared[int(value)] if cell.get('t')=='s' else value)
                rows.append(cells)
            tables.append(rows)
        assert tables[0][-1][2:5]==['130','6.5','136.5'],tables[0]
        rows=tables[1][-3:]
        assert [r[2] for r in rows]==['2','1','3'],rows
        assert all(r[3]=='UNIT' for r in rows)
        assert sum(Decimal(r[5]) for r in rows)==Decimal('130')
        assert sum(Decimal(r[6]) for r in rows)==Decimal('6.50')
        assert 'Fictional Project' in tables[0][-1] and tables[0][-1][-1]
        checks.append(locale+' actual Excel: one invoice, three quantities2/1/3, net130/VAT6.50/total136.50, Project and journal')
    text=subprocess.check_output(['pdftotext','-layout','/tmp/narvo115-'+locale+'.pdf','-'],text=True)
    assert all(s in text for s in ['130.00','6.50','136.50','Fictional Sales Company','Fictional Project']),text
    assert len(text)>800
    checks.append(locale+' actual PDF: rendered consolidated invoice130.00+6.50=136.50 with Company/Project')
Path('docs/sales-completion-evidence/exports.json').write_text(json.dumps({'checks':checks,'expected':{'netAED':'130.00','vatAED':'6.50','grossAED':'136.50','lineQuantities':['2','1','3']},'files':'Actual browser XLSX downloads and Chromium-rendered PDF; every worksheet inspected'},indent=2)+'\n')
print('\n'.join('PASS '+c for c in checks))
