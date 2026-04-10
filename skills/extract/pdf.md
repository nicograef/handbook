# PDF Extraction

## Dependencies

Install as needed:

```bash
pip install pdfplumber pytesseract pdf2image
```

System requirement for OCR: `tesseract-ocr` must be installed (`apt install tesseract-ocr` / `brew install tesseract`).

## Text Extraction

Use pdfplumber as the default. It handles most digitally-created PDFs reliably.

```python
import pdfplumber

with pdfplumber.open("file.pdf") as pdf:
    for page in pdf.pages:
        text = page.extract_text()
```

If `extract_text()` returns `None` or empty strings, the PDF is likely scanned — fall back to OCR.

## OCR Fallback (Scanned PDFs)

```python
from pdf2image import convert_from_path
import pytesseract

images = convert_from_path("scanned.pdf", dpi=300)
for img in images:
    text = pytesseract.image_to_string(img)
```

Use `dpi=300` for a good quality/speed balance. Increase to `400` for small-font documents.

## Table Extraction

pdfplumber detects tables automatically:

```python
with pdfplumber.open("file.pdf") as pdf:
    for page in pdf.pages:
        for table in page.extract_tables():
            # table is a list of rows, each row a list of cell strings
            header, *rows = table
```

To convert to a DataFrame:

```python
import pandas as pd

with pdfplumber.open("file.pdf") as pdf:
    table = pdf.pages[0].extract_tables()[0]
    df = pd.DataFrame(table[1:], columns=table[0])
```

If table detection is poor, tune with `table_settings`:

```python
page.extract_tables(table_settings={
    "vertical_strategy": "text",
    "horizontal_strategy": "text",
})
```

## Metadata Extraction

```python
with pdfplumber.open("file.pdf") as pdf:
    meta = pdf.metadata  # dict with Title, Author, CreationDate, etc.
```

Common keys: `Title`, `Author`, `Subject`, `Creator`, `Producer`, `CreationDate`, `ModDate`.

## Structured Knowledge Extraction

To extract headings, sections, and hierarchical content, combine text extraction with font-size analysis:

```python
import pdfplumber

def extract_structured(path):
    sections = []
    with pdfplumber.open(path) as pdf:
        for page in pdf.pages:
            chars = page.chars
            lines = {}
            for c in chars:
                top = round(c["top"], 1)
                lines.setdefault(top, []).append(c)

            for top in sorted(lines):
                line_chars = sorted(lines[top], key=lambda c: c["x0"])
                text = "".join(c["text"] for c in line_chars)
                avg_size = sum(c["size"] for c in line_chars) / len(line_chars)
                sections.append({"text": text.strip(), "font_size": avg_size})
    return sections
```

Classify by font size: the largest sizes are typically headings (H1 > H2 > body).

## Decision Guide

| Scenario | Approach |
|----------|----------|
| Digital PDF, text only | `pdfplumber` → `extract_text()` |
| Digital PDF with tables | `pdfplumber` → `extract_tables()` |
| Scanned / image PDF | `pdf2image` + `pytesseract` |
| Need metadata | `pdfplumber` → `.metadata` |
| Need document structure | Font-size analysis (see above) |
| Mixed (some pages scanned) | Try pdfplumber first, OCR per page if text is empty |

## Handling Mixed PDFs

```python
import pdfplumber
from pdf2image import convert_from_path
import pytesseract

def extract_all_pages(path):
    results = []
    with pdfplumber.open(path) as pdf:
        for i, page in enumerate(pdf.pages):
            text = page.extract_text()
            if text and text.strip():
                results.append(text)
            else:
                images = convert_from_path(path, first_page=i+1, last_page=i+1, dpi=300)
                results.append(pytesseract.image_to_string(images[0]))
    return results
```
