# Builds e2e/fixtures/clientes.xlsx: a minimal, valid workbook with synthetic
# customers (shared strings and one inline cell). Run: python3 e2e/fixtures/make-xlsx.py
import os
import zipfile

ROWS = [
    ['Nome', 'Telefone', 'E-mail'],
    ['Planilha Um', '(47) 90000-2201', 'um@exemplo.com'],
    ['Planilha Dois', '(47) 90000-2202', ''],
    ['', '(47) 90000-2203', 'sem-nome@exemplo.com'],
]

strings = []
def sid(text):
    if text not in strings:
        strings.append(text)
    return strings.index(text)

cells = []
for r, row in enumerate(ROWS, start=1):
    parts = []
    for c, value in enumerate(row):
        if not value:
            continue
        ref = f'{chr(65 + c)}{r}'
        if r == 3 and c == 1:
            parts.append(f'<c r="{ref}" t="inlineStr"><is><t>{value}</t></is></c>')
        else:
            parts.append(f'<c r="{ref}" t="s"><v>{sid(value)}</v></c>')
    cells.append(f'<row r="{r}">{"".join(parts)}</row>')

sheet = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
         '<worksheet xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main"><sheetData>'
         + ''.join(cells) + '</sheetData></worksheet>')
shared = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
          f'<sst xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" count="{len(strings)}" uniqueCount="{len(strings)}">'
          + ''.join(f'<si><t>{s}</t></si>' for s in strings) + '</sst>')
workbook = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
            '<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" '
            'xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships">'
            '<sheets><sheet name="Clientes" sheetId="1" r:id="rId1"/></sheets></workbook>')
workbook_rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
                 '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
                 '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/worksheet" Target="worksheets/sheet1.xml"/>'
                 '<Relationship Id="rId2" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/sharedStrings" Target="sharedStrings.xml"/>'
                 '</Relationships>')
rels = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
        '<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">'
        '<Relationship Id="rId1" Type="http://schemas.openxmlformats.org/officeDocument/2006/relationships/officeDocument" Target="xl/workbook.xml"/>'
        '</Relationships>')
types = ('<?xml version="1.0" encoding="UTF-8" standalone="yes"?>'
         '<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">'
         '<Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml"/>'
         '<Default Extension="xml" ContentType="application/xml"/>'
         '<Override PartName="/xl/workbook.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet.main+xml"/>'
         '<Override PartName="/xl/worksheets/sheet1.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.worksheet+xml"/>'
         '<Override PartName="/xl/sharedStrings.xml" ContentType="application/vnd.openxmlformats-officedocument.spreadsheetml.sharedStrings+xml"/>'
         '</Types>')

out = os.path.join(os.path.dirname(os.path.abspath(__file__)), 'clientes.xlsx')
with zipfile.ZipFile(out, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('[Content_Types].xml', types)
    z.writestr('_rels/.rels', rels)
    z.writestr('xl/workbook.xml', workbook)
    z.writestr('xl/_rels/workbook.xml.rels', workbook_rels)
    z.writestr('xl/worksheets/sheet1.xml', sheet)
    z.writestr('xl/sharedStrings.xml', shared)
print(out)
