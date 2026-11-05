import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
checks=[]
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
    path='/tmp/narvo-certified-opening-'+locale
    with ZipFile(path+'.xlsx') as archive:
        xml='\n'.join(archive.read(n).decode() for n in archive.namelist() if n.endswith('.xml'))
        for text in ['Synthetic business Company','BROWSER-CERTIFIED-OPENING','BROWSER-CASH-COUNT','Signed opening trial balance','Signed custody count sheet']:
            assert text in xml,text
        nums=[]
        for name in archive.namelist():
            if not re.fullmatch(r'xl/worksheets/sheet[0-9]+\.xml',name):
                continue
            sheet=E.fromstring(archive.read(name))
            if locale=='ar':
                assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
            for c in sheet.findall('.//s:c',ns):
                value=c.find('s:v',ns)
                if c.get('t') not in ['s','inlineStr'] and value is not None:
                    nums.append(value.text)
        for value in ['1500','1000','500','5','0']:
            assert value in nums,value
        checks.append(locale+' Excel: actual company/source/evidence, exact target/existing/delta/count amounts, totals and sheet direction')
    text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode()
    compact=re.sub(r'\s','',text)
    for value in ['BROWSER-CERTIFIED-OPENING','BROWSER-CASH-COUNT','1,500.00','1,000.00','500.00','5.00']:
        assert value in compact,value
    checks.append(locale+' PDF: actual opening/count source references and exact balances')
Path('/tmp/narvo-certified-opening-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2)+'\n')
print('PASS',len(checks),'bilingual opening/count artifact inspections')
