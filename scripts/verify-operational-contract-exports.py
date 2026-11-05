import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
checks=[]
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
for locale in ['en','ar']:
    base=Path('/tmp/narvo-operational-contract-'+locale)
    with ZipFile(str(base)+'.xlsx') as z:
        xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
        for token in ['Synthetic business Company','BROWSER-UNIT','BROWSER-MEASURE','SIGNED-100-UNITS','m2','5000']:
            assert token in xml,token
        sheets=[n for n in z.namelist() if re.fullmatch(r'xl/worksheets/sheet[0-9]+\.xml',n)]
        nums=[]
        for name in sheets:
            sheet=E.fromstring(z.read(name))
            if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
            for c in sheet.findall('.//s:c',ns):
                if c.get('t') in [None,'n']:
                    v=c.find('s:v',ns)
                    if v is not None:nums.append(v.text)
        assert '5000' in nums and '50' in nums
        assert 'DRAFT' in xml
        checks.append(locale+' actual Excel company/source, unknown total, draft status, exact cumulative work/rate and sheet direction')
    text=subprocess.check_output(['pdftotext',str(base)+'.pdf','-'],text=True)
    for token in ['BROWSER-UNIT','BROWSER-MEASURE','SIGNED-100-UNITS','5,000.00','50.00']:
        assert token in text,token
    checks.append(locale+' actual PDF source/evidence and exact measured5000 value /50 unit rate')
Path('/tmp/narvo-operational-contract-exports.json').write_text(json.dumps({'status':'PASS','checks':len(checks),'details':checks},indent=2))
print('PASS',len(checks),'bilingual export artifact checks')
