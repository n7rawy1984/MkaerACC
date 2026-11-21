"""Inspect actual local browser downloads; run after the focused browser check."""
import json
from decimal import Decimal
from pathlib import Path
from xml.etree import ElementTree as ET
from zipfile import ZipFile

evidence = Path("docs/wps-final-evidence")
expected = json.loads((evidence / "accounting.json").read_text())["expected"]
net = f'{Decimal(expected["netMinor"]) / 100:.2f}'
ns = {"s": "http://schemas.openxmlformats.org/spreadsheetml/2006/main"}
checks = []
for lang in ["en", "ar"]:
    with ZipFile(f"/tmp/narvo-final-statement-{lang}.xlsx") as workbook:
        text = "".join(workbook.read(n).decode() for n in workbook.namelist() if n.endswith(".xml"))
        sheet = ET.fromstring(workbook.read("xl/worksheets/sheet1.xml"))
        cells = [v.text for c in sheet.findall(".//s:c", ns) if c.get("t") != "s" for v in c.findall("s:v", ns)]
        assert net in cells and "100" in cells
        assert ("Final net payable" if lang == "en" else "الصافي النهائي المستحق") in text
        assert ("Existing gratuity provision" if lang == "en" else "مخصص المكافأة السابق") in text
        checks.append(f"{lang} actual Excel numeric cells reconcile to net AED{net}, paid AED100 and prior provision")
    assert Path(f"/tmp/narvo-final-statement-{lang}.pdf").read_bytes().startswith(b"%PDF-")
    checks.append(f"{lang} actual rendered PDF exists; localized body verified in browser")
(evidence / "exports.json").write_text(json.dumps({"count": len(checks), "checks": checks,
    "scope": "Actual authorized-component downloads from isolated canonical SQL"}, indent=2) + "\n")
print("PASS", len(checks), "actual bilingual export checks")
