"""Inspect XLSX files downloaded by the serverless historical-source UI fixture."""
from decimal import Decimal
from pathlib import Path
import zipfile
import xml.etree.ElementTree as ET

NS = {'s': 'http://schemas.openxmlformats.org/spreadsheetml/2006/main'}

def workbook(kind):
    archive = zipfile.ZipFile('/tmp/makeracc-' + kind + '-export.xlsx')
    assert '#,##0.00' in archive.read('xl/styles.xml').decode()
    return archive

def cells(archive, sheet):
    tree = ET.fromstring(archive.read(f'xl/worksheets/sheet{sheet}.xml'))
    return {c.attrib['r']: c for c in tree.findall('.//s:c', NS)}

def money(cell):
    assert cell.attrib.get('t', 'n') == 'n', 'Money must be a numeric Excel cell'
    amount = Decimal(cell.find('s:v', NS).text)
    assert amount * 100 == (amount * 100).to_integral_value()
    return amount

for kind in ['general', 'payroll', 'overview']:
    archive = workbook(kind)
    totals = cells(archive, 1)
    outflow = Decimal('0' if kind == 'payroll' else '320')
    payroll = Decimal('0' if kind == 'general' else '62500')
    assert money(totals['B7']) == money(totals['C7']) == outflow
    assert money(totals['B10']) == money(totals['C10']) == payroll
    if kind == 'general':
        assert money(totals['B8']) == Decimal('500')
        assert money(totals['B9']) == Decimal('80.25')
        assert len(ET.fromstring(archive.read('xl/worksheets/sheet2.xml')).findall('s:sheetData/s:row', NS)) == 229
    if kind == 'payroll':
        register = cells(archive, 2)
        assert sum(money(c) for ref, c in register.items() if ref.startswith('H') and int(ref[1:]) >= 7) == payroll
        assert sum(money(c) for ref, c in register.items() if ref.startswith('I') and int(ref[1:]) >= 7) == payroll

filtered = workbook('filtered')
assert money(cells(filtered, 1)['B7']) == 0
assert money(cells(filtered, 1)['B8']) == 500
assert len(ET.fromstring(filtered.read('xl/worksheets/sheet2.xml')).findall('s:sheetData/s:row', NS)) == 7
journals = workbook('journals')
assert money(cells(journals, 1)['B7']) == money(cells(journals, 1)['C7']) == Decimal('125.50')
for column in ['D', 'E']:
    assert sum(money(c) for ref, c in cells(journals, 3).items() if ref.startswith(column) and int(ref[1:]) >= 7) == Decimal('125.50')
for kind in ['general', 'payroll', 'overview', 'journals']:
    for language in ['en', 'ar']:
        path = Path(f'/tmp/makeracc-{kind}-{language}.pdf')
        assert path.read_bytes().startswith(b'%PDF-') and path.stat().st_size > 10000
print('PASS: numeric formatted monetary XLSX cells, exact separate controls, 223/25 rows, filtered export, balanced journal export, eight English/Arabic PDF artifacts.')
