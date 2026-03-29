---
name: xlsx-extract
description: Extract data, formulas, metadata, and assets from Excel .xlsx workbooks, including all worksheets. Use when the user mentions Excel, .xlsx, spreadsheets, workbooks, multiple sheets, or tabular data in Office files.
---

# Excel (.xlsx) Extraction

`.xlsx` is Office Open XML (ZIP + XML). Use **pandas** to load many worksheets at once; use **openpyxl** for per-sheet control, formulas, merged cells, defined names, workbook properties, and large-file streaming.

## Dependencies

```bash
pip install pandas openpyxl
```

For legacy **`.xls`**, use `pip install xlrd` (1.2.x for .xls) or convert to `.xlsx` first—do not assume the same API as below.

## Limits

- **`.xls`** (binary BIFF) is not OOXML; prefer conversion or `xlrd` / LibreOffice.
- **`.xlsm`** (macros): openpyxl reads data; VBA is in `xl/vbaProject.bin` (separate tooling if you need macro source).
- **Calculated values**: `data_only=True` returns values cached at last save; formulas appear as `None` if the file was never opened in Excel and saved.
- **Charts / rich objects**: not fully modeled; embedded images live under `xl/media/` (ZIP) if you need raw files.

## All Worksheets with pandas

Default path when the goal is “everything tabular” across **multiple worksheets**:

```python
import pandas as pd

# dict[str, DataFrame] — one entry per sheet
sheets = pd.read_excel("file.xlsx", sheet_name=None, engine="openpyxl")

for name, df in sheets.items():
    print(name, df.shape)
```

Single sheet by name or index:

```python
df = pd.read_excel("file.xlsx", sheet_name="Summary", engine="openpyxl")
df0 = pd.read_excel("file.xlsx", sheet_name=0, engine="openpyxl")
```

Skip junk rows:

```python
df = pd.read_excel("file.xlsx", sheet_name="Data", header=2, engine="openpyxl")
```

## Per-Sheet Access with openpyxl

Use when you need **formulas**, **merged ranges**, **hidden sheets**, or **read-only** streaming for large files.

```python
from openpyxl import load_workbook

wb = load_workbook("file.xlsx", data_only=False)  # formulas visible
for sheet_name in wb.sheetnames:
    ws = wb[sheet_name]
    for row in ws.iter_rows(values_only=True):
        pass  # tuple of cell values per row
```

**Cached values** (last saved calculation):

```python
wb = load_workbook("file.xlsx", data_only=True)
ws = wb.active
v = ws["B2"].value
```

**Large workbooks** (streaming, read-only):

```python
from openpyxl import load_workbook

wb = load_workbook("large.xlsx", read_only=True, data_only=True)
for ws in wb:
    for row in ws.iter_rows(values_only=True):
        pass
wb.close()
```

## Merged Cells

```python
wb = load_workbook("file.xlsx")
ws = wb["Sheet1"]
for m in ws.merged_cells.ranges:
    print(m)  # e.g. A1:C1 — top-left holds the value in Excel
```

When flattening to a grid, decide whether to duplicate the top-left value into every cell of the range or leave spans explicit.

## Workbook Metadata (core properties)

```python
from openpyxl import load_workbook

wb = load_workbook("file.xlsx")
p = wb.properties
meta = {
    "title": p.title,
    "subject": p.subject,
    "creator": p.creator,
    "keywords": p.keywords,
    "category": p.category,
    "description": p.description,
    "created": p.created,
    "modified": p.modified,
    "last_modified_by": p.last_modified_by,
}
```

## Defined Names (named ranges)

```python
from openpyxl import load_workbook

wb = load_workbook("file.xlsx", data_only=True)
names = []
for dn in wb.defined_names.values():
    names.append({"name": dn.name, "refers_to": dn.attr_text})
```

Resolve a name to a worksheet range when needed via openpyxl’s utilities or by parsing `attr_text` (workbook- vs sheet-scoped names differ).

## Sheet Visibility

```python
wb = load_workbook("file.xlsx")
for name in wb.sheetnames:
    ws = wb[name]
    hidden = ws.sheet_state  # 'visible', 'hidden', or 'veryHidden'
```

Prefer skipping `hidden` / `veryHidden` sheets for “user-facing” extracts unless the task says otherwise.

## Embedded Images (ZIP)

Same idea as `.docx` media:

```python
import zipfile

def iter_xlsx_media(path: str):
    with zipfile.ZipFile(path) as z:
        for n in z.namelist():
            if n.startswith("xl/media/") and not n.endswith("/"):
                yield n, z.read(n)
```

## Excel Table Objects (optional)

If the workbook uses **Insert → Table** (structured tables), openpyxl exposes them per worksheet:

```python
wb = load_workbook("file.xlsx", data_only=True)
ws = wb.active
for t in ws.tables.values():
    ref = t.ref  # e.g. "A1:D10"
```

Most multi-sheet workflows still start with pandas or `iter_rows`; use tables when you need the **named** table and its **exact range**.

## Decision Guide

| Goal | Approach |
|------|----------|
| All worksheets → DataFrames | `pd.read_excel(..., sheet_name=None, engine="openpyxl")` |
| Formulas as strings | `load_workbook(..., data_only=False)` |
| Last saved calculated values | `data_only=True` |
| Very large file, low memory | `read_only=True`, iterate rows, `close()` |
| Merged cells | `ws.merged_cells.ranges` |
| Title, author, dates, keywords | `wb.properties` |
| Named ranges | `wb.defined_names.values()` |
| Skip hidden sheets | Check `ws.sheet_state` |
| Embedded images | `zipfile` → `xl/media/*` |
| Legacy `.xls` | xlrd or convert to `.xlsx` |

## End-to-end Skeleton

```python
import pandas as pd
from openpyxl import load_workbook

def extract_xlsx_knowledge(path: str) -> dict:
    sheets = pd.read_excel(path, sheet_name=None, engine="openpyxl")
    wb = load_workbook(path, data_only=True)
    meta = {
        "title": wb.properties.title,
        "creator": wb.properties.creator,
        "created": wb.properties.created,
        "modified": wb.properties.modified,
        "subject": wb.properties.subject,
        "keywords": wb.properties.keywords,
    }
    visibility = {n: wb[n].sheet_state for n in wb.sheetnames}
    names = [{"name": dn.name, "refers_to": dn.attr_text} for dn in wb.defined_names.values()]
    wb.close()
    return {
        "sheets": {k: v.to_dict(orient="records") for k, v in sheets.items()},
        "sheet_shapes": {k: v.shape for k, v in sheets.items()},
        "workbook_properties": meta,
        "sheet_visibility": visibility,
        "defined_names": names,
    }
```

Adjust serialization (`to_dict`, CSV, Parquet) to the task; keep DataFrames in memory if downstream code needs them.

## Quality

- Before presenting results, run the self-review checklist from AGENTS.md (Quality Principles) — applied to the quality of the extraction artifact. Surface issues in the chat only if found.
- After task completion, include a human-readable summary paragraph alongside the commit message (see AGENTS.md, Git Workflow).
