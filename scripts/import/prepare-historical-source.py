"""Read the approved final XLSX/review package; produce immutable source payloads.
Usage: python3 prepare-historical-source.py PACKAGE_DIRECTORY OUTPUT_JSON
No database connection, accounting mutations or employee provisioning.
"""
import sys,json,re,hashlib,zipfile,xml.etree.ElementTree as E
from pathlib import Path
from decimal import Decimal

def sheet(path):
 z=zipfile.ZipFile(path); ns={'m':'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}
 shared=[''.join(t.itertext()) for t in E.fromstring(z.read('xl/sharedStrings.xml')).findall('m:si',ns)] if 'xl/sharedStrings.xml' in z.namelist() else []
 rows=[]
 for row in E.fromstring(z.read('xl/worksheets/sheet1.xml')).findall('.//m:sheetData/m:row',ns):
  d={}
  for c in row:
   v=c.find('m:v',ns);i=c.find('m:is',ns)
   d[re.sub(r'\d','',c.attrib['r'])]=shared[int(v.text)] if c.attrib.get('t')=='s' else ''.join(i.itertext()) if i is not None else v.text if v is not None else None
  rows.append(d)
 headers=rows.pop(0)
 return [(r,{headers[k]:r.get(k) for k in headers}) for r in rows]
def minor(value):
 if value in (None,''):return None
 n=Decimal(value)*100
 if n!=n.to_integral_value() or n<0 or n>9000000000000000:raise ValueError('Invalid monetary evidence')
 return str(int(n))
def prepare(directory):
 p=Path(directory);review=p/'Real_Data_Foundation_Review_Expenses_Payroll_No_Farm.md';text=review.read_text(); report={}
 for line in text.splitlines():
  if line.startswith('| G-') or line.startswith('| P-'):
   a=[v.replace('\\|','|').strip() for v in re.split(r'(?<!\\)\|',line)[1:-1]];report[a[0]]=a
 output=[]
 for filename,kind in [('03_General_Expenses_Aug_Sep_2026_No_Farm_Only.xlsx','GENERAL'),('01_Payroll_Sep_2026_Clean.xlsx','PAYROLL')]:
  file=p/filename;digest=hashlib.sha256(file.read_bytes()).hexdigest()
  if f'`{digest}`' not in text:raise ValueError('Workbook hash does not match approved review')
  for row,raw in sheet(file):
   if kind=='GENERAL':
    if row.get('A') not in ('2026-08','2026-09') or not (row.get('B') or '').isdigit():continue
    ref=f"G-{row['A']}-{row['B']}";a=report[ref]
    record=dict(record_type=kind,source_month=row['A'],source_reference=ref,source_date=row.get('D') or None,description=row.get('L') or '',outflow_minor=minor(row.get('K')),funding_minor=minor(row.get('J')),payroll_net_minor=None,
     classification=dict(nature=a[9],category_proposal=a[10],project_decision=a[11],workflow=a[13],holds=a[14],review_id=ref))
    if (row.get('D') or '')!=a[4] or (row.get('L') or '')!=a[5]:raise ValueError('Source/report evidence mismatch')
   else:
    if not (row.get('A') or '').isdigit():continue
    ref=f"P-{row['A']}";a=report[ref]
    record=dict(record_type=kind,source_month='2026-09',source_reference=ref,source_date=None,description=row.get('B') or '',outflow_minor=None,funding_minor=None,payroll_net_minor=minor(row.get('R')),
     classification=dict(workflow=a[11],holds=a[12],review_id=ref))
    if (row.get('B') or '')!=a[1]:raise ValueError('Employee source/report mismatch')
   record.update(source_file=filename,source_hash=digest,raw_source=raw);output.append(record)
 general=[r for r in output if r['record_type']=='GENERAL'];payroll=[r for r in output if r['record_type']=='PAYROLL']
 assert len(general)==223 and len(payroll)==25 and len({(r['source_file'],r['source_reference']) for r in output})==248
 for month,count,total in [('2026-08',135,18211192),('2026-09',88,11339412)]:
  rr=[r for r in general if r['source_month']==month];assert len(rr)==count and sum(int(r['outflow_minor'] or 0) for r in rr)==total
 assert sum(int(r['payroll_net_minor'] or 0) for r in payroll)==5379833
 return output
if __name__=='__main__':
 records=prepare(sys.argv[1]);Path(sys.argv[2]).write_text(json.dumps(records,ensure_ascii=False,indent=2));print('Verified: 223 General + 25 Payroll; exact source controls match. No accounting posted.')
