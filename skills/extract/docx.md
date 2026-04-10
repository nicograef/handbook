# Word (.docx) Extraction

`.docx` is a ZIP of XML parts and assets. Prefer **`python-docx`** for body text, tables, sections, and core properties; use **`zipfile`** + **`xml.etree.ElementTree`** for embedded media, app/custom properties, and comments.

## Dependencies

```bash
pip install python-docx
```

`lxml` may be pulled in transitively; stdlib `zipfile` and `xml.etree.ElementTree` cover OOXML parts not exposed by python-docx.

## Limits

- **`.doc` (legacy binary)** is not OOXML. Convert with LibreOffice (`soffice --headless --convert-to docx`) or another tool before using this workflow.
- **Tracked changes, complex fields, OLE embeds** may not round-trip through high-level APIs; inspect raw XML under `word/` for full fidelity (best effort).

**"Domain" context**: map to document properties (Subject, Keywords, Category, custom properties)—not automatic semantic classification unless you add NLP separately.

## Text Extraction

```python
from docx import Document

doc = Document("file.docx")
for para in doc.paragraphs:
    text = para.text
```

## Tables

```python
from docx import Document

doc = Document("file.docx")
for table in doc.tables:
    for row in table.rows:
        cells = [cell.text for cell in row.cells]
```

For pandas:

```python
import pandas as pd
from docx import Document

doc = Document("file.docx")
rows = [[cell.text for cell in row.cells] for row in doc.tables[0].rows]
df = pd.DataFrame(rows[1:], columns=rows[0])
```

## Core Metadata

```python
from docx import Document

doc = Document("file.docx")
cp = doc.core_properties
# title, subject, keywords, category, author, last_modified_by,
# created, modified, revision, comments (often unused in OOXML)
meta = {
    "title": cp.title,
    "subject": cp.subject,
    "keywords": cp.keywords,
    "category": cp.category,
    "author": cp.author,
    "last_modified_by": cp.last_modified_by,
    "created": cp.created,
    "modified": cp.modified,
    "revision": cp.revision,
}
```

## Headers and Footers

```python
from docx import Document

doc = Document("file.docx")
for section in doc.sections:
    for part in (section.header, section.footer):
        for para in part.paragraphs:
            _ = para.text
```

## Images (ZIP / media folder)

Reliable: list and read binaries from `word/media/` inside the package.

```python
import zipfile
from pathlib import Path

def iter_media(path):
    with zipfile.ZipFile(path) as z:
        for name in z.namelist():
            if name.startswith("word/media/") and not name.endswith("/"):
                yield name, z.read(name)

# Optional: save to disk
for name, data in iter_media("file.docx"):
    Path(Path(name).name).write_bytes(data)
```

To relate images to document structure, parse `word/_rels/document.xml.rels` (relationship `Target` → `media/imageN.png`).

## App and Custom Properties (XML in ZIP)

```python
import zipfile
import xml.etree.ElementTree as ET

CP = "{http://schemas.openxmlformats.org/officeDocument/2006/custom-properties}"

def parse_app_xml(data: bytes) -> dict:
    root = ET.fromstring(data)
    out = {}
    for child in root:
        tag = child.tag.split("}")[-1]
        if child.text and child.text.strip():
            out[tag] = child.text.strip()
    return out

def parse_custom_xml(data: bytes) -> dict:
    root = ET.fromstring(data)
    out = {}
    for prop in root.findall(f".//{CP}property"):
        name = prop.get("name")
        if not name:
            continue
        # First child under property holds typed value (vt:*)
        for val in prop:
            out[name] = val.text or ""
            break
    return out

def extra_properties(path: str) -> dict:
    result = {"app": {}, "custom": {}}
    with zipfile.ZipFile(path) as z:
        if "docProps/app.xml" in z.namelist():
            result["app"] = parse_app_xml(z.read("docProps/app.xml"))
        if "docProps/custom.xml" in z.namelist():
            result["custom"] = parse_custom_xml(z.read("docProps/custom.xml"))
    return result
```

## Comments (advanced)

`python-docx` does not model comments. Read `word/comments.xml` if present.

```python
import zipfile
import xml.etree.ElementTree as ET

W = "{http://schemas.openxmlformats.org/wordprocessingml/2006/main}"

def ooxml_attr(el, local: str):
    """Resolve namespaced OOXML attributes ({uri}local or plain local)."""
    for k, v in el.attrib.items():
        if k == local or k.endswith("}" + local):
            return v
    return None

def comment_text(comment_el) -> str:
    parts = []
    for t in comment_el.iter(f"{W}t"):
        if t.text:
            parts.append(t.text)
    return "".join(parts).strip()

def extract_comments(path: str) -> list[dict]:
    with zipfile.ZipFile(path) as z:
        if "word/comments.xml" not in z.namelist():
            return []
        root = ET.fromstring(z.read("word/comments.xml"))
    out = []
    for c in root.iter(f"{W}comment"):
        out.append({
            "id": ooxml_attr(c, "id"),
            "author": ooxml_attr(c, "author"),
            "date": ooxml_attr(c, "date"),
            "text": comment_text(c),
        })
    return out
```

## Decision Guide

| Goal | Approach |
|------|----------|
| Body text, tables, sections | `python-docx` |
| Title, author, subject, keywords, dates | `document.core_properties` |
| App stats / template hints | `docProps/app.xml` via ZIP |
| Custom / domain fields | `docProps/custom.xml` via ZIP |
| All embedded images | Enumerate `word/media/*` in ZIP |
