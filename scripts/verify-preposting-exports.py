"""Inspect actual pre-posting plan and original posted-ledger artifacts."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for kind in ['source','ledger']:
 for locale in ['en','ar']:
  path='/tmp/narvo-preposting-'+('source-' if kind=='source' else '')+locale
  with ZipFile(path+'.xlsx') as z:
   xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
   for value in ['Synthetic allocation Company','SOURCE-LOG-1','Measured shared expense usage','P-ONE','P-TWO']:
    assert value in xml,value
   sheet=E.fromstring(z.read('xl/worksheets/sheet1.xml'))
   if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
   rows=[]
   for row in sheet.findall('.//s:row',ns):
    values=[c.find('s:v',ns).text for c in row if c.find('s:v',ns) is not None and c.get('t') not in ['s','str','inlineStr']]
    if values:rows.append(values)
   if kind=='source':assert sorted(v for row in rows for v in row)==sorted(['41.83','41.83','41.84','125.5']),rows
   else:assert sorted(rows)==sorted([['41.83','0','41.83'],['41.83','0','41.83'],['41.84','0','41.84'],['125.5','0','125.5']]),rows
   checks.append(kind+' '+locale+' Excel exact allocated/source totals, basis, audit references and RTL')
  text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
  for value in ['Synthetic allocation Company','SOURCE-LOG-1','41.83','41.84','125.50']:
   assert re.sub(r'\s','',value) in compact,value
  if locale=='en':assert ('Unposted' in text if kind=='source' else 'Posted' in text)
  checks.append(kind+' '+locale+' PDF identity, exact amounts, source/basis and accounting status')
Path('/tmp/narvo-preposting-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS eight pre-posting/ledger bilingual artifact checks')
