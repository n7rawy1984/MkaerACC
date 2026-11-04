"""Inspect actual bilingual Party listing/detail artifacts without financial fabrication."""
import json,re,subprocess
from pathlib import Path
from zipfile import ZipFile
from xml.etree import ElementTree as E
ns={'s':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
checks=[]
for kind in ['list','detail']:
 for locale in ['en','ar']:
  path='/tmp/narvo-party-master-'+kind+'-'+locale
  with ZipFile(path+'.xlsx') as z:
   xml='\n'.join(z.read(n).decode() for n in z.namelist() if n.endswith('.xml'))
   for v in ['Synthetic business Company','Initial supplier','000042','100000000000003','شركة نموذجية Example LLC','Net 30 subject to contract']:assert v in xml,v
   if kind=='list':assert 'Initial subcontractor' in xml and 'GB-EXAMPLE-42' in xml
   if kind=='detail':assert 'No new purchasing' in xml and 'Resume purchasing' in xml and 'Verified registration record' in xml
   strings=[''.join(e.itertext()) for e in E.fromstring(z.read('xl/sharedStrings.xml'))]
   trn=strings.index('100000000000003');found=False
   for name in z.namelist():
    if not re.match(r'xl/worksheets/sheet[0-9]+\.xml$',name):continue
    sheet=E.fromstring(z.read(name))
    if locale=='ar':assert sheet.find('s:sheetViews/s:sheetView',ns).get('rightToLeft') in ['true','1']
    for c in sheet.findall('.//s:c',ns):
     v=c.find('s:v',ns)
     if c.get('t')=='s' and v is not None and v.text==str(trn):found=True
   assert found,'TRN must remain an exact text cell'
   checks.append(kind+' '+locale+' Excel: legal/registration/contact/status data, text identifiers, RTL and audit evidence')
  text=subprocess.check_output(['pdftotext','-raw',path+'.pdf','-']).decode();compact=re.sub(r'\s','',text)
  for v in ['000042','100000000000003','Initialsupplier','SyntheticbusinessCompany']:assert v in compact,v
  checks.append(kind+' '+locale+' PDF: Company/party identity, exact identifiers and readable output')
Path('/tmp/narvo-party-master-exports.json').write_text(json.dumps({'status':'PASS','checks':checks},indent=2))
print('PASS eight bilingual Party listing/detail artifact checks')
