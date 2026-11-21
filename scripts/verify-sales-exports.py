"""Check actual browser-produced files against an independently declared fictional delivery answer key."""
import json,zipfile,xml.etree.ElementTree as E,subprocess
from pathlib import Path
ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for locale in ['en','ar']:
    with zipfile.ZipFile('/tmp/narvo-sales-final-'+locale+'.xlsx') as z:
        shared=[]
        if 'xl/sharedStrings.xml' in z.namelist():
            shared=[''.join(x.itertext()) for x in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)]
        sheets=sorted(n for n in z.namelist() if n.startswith('xl/worksheets/sheet') and n.endswith('.xml'))
        assert len(sheets)==4
        allrows=[]
        for sheet in sheets:
            rows=[]
            for row in E.fromstring(z.read(sheet)).findall('.//m:sheetData/m:row',ns):
                cells=[]
                for cell in row.findall('m:c',ns):
                    v=cell.find('m:v',ns)
                    value=v.text if v is not None else ''.join(cell.find('m:is',ns).itertext()) if cell.find('m:is',ns) is not None else ''
                    cells.append(shared[int(value)] if cell.get('t')=='s' else value)
                rows.append(cells)
            allrows.append(rows)
        assert any(len(r)>=8 and r[5:8]==['80','40','40'] for r in allrows[2]),allrows[2]
        assert any(len(r)>=5 and r[2:5]==['10','4','6'] for r in allrows[3]),allrows[3]
        assert any(len(r)>=5 and r[2:5]==['5','2','3'] for r in allrows[3]),allrows[3]
        checks.append(locale+' actual Excel: four sections, billed revenue80/cost40/margin40 and remaining6+3 units')
    text=subprocess.check_output(['pdftotext','-layout','/tmp/narvo-sales-final-'+locale+'.pdf','-'],text=True)
    assert '80.00' in text and '40.00' in text and 'Fictional Sales Company' in text,text
    assert len(text)>800
    checks.append(locale+' actual PDF: rendered Company report with exact80.00 revenue and40.00 cost/margin')
Path('docs/sales-evidence/exports.json').write_text(json.dumps({'checks':checks,'expected':{'revenueAED':80,'costAED':40,'marginAED':40,'remainingUnits':[6,3]},'files':'Actual Chromium downloads/PDF artifacts under /tmp; all worksheets inspected'},indent=2)+'\n')
print('\n'.join('PASS '+c for c in checks))
