---
name: extract
description: "Extract text, tables, metadata, and assets from PDF, Word (.docx), and Excel (.xlsx) files. Use when the user wants to read, parse, or extract content from documents."
---

# Document Extraction

Unified skill for extracting content from common document formats. Identify the file type, then follow the corresponding reference.

## Workflow

1. Identify the file format (`.pdf`, `.docx`, `.xlsx` / `.xls`).
2. Follow the format-specific reference:
   - **PDF** → [pdf.md](pdf.md)
   - **Word (.docx)** → [docx.md](docx.md)
   - **Excel (.xlsx)** → [xlsx.md](xlsx.md)
3. Extract the requested content (text, tables, metadata, images — whatever the user needs).
4. Present results in a clean, structured format (Markdown tables, code blocks, or DataFrames as appropriate).

## Format Detection

| Extension | Format | Reference |
|-----------|--------|-----------|
| `.pdf` | PDF (digital or scanned) | [pdf.md](pdf.md) |
| `.docx` | Word (Office Open XML) | [docx.md](docx.md) |
| `.xlsx` | Excel (Office Open XML) | [xlsx.md](xlsx.md) |
| `.doc` | Legacy Word (binary) | Convert to `.docx` first — see [docx.md](docx.md) |
| `.xls` | Legacy Excel (binary) | Convert to `.xlsx` or use `xlrd` — see [xlsx.md](xlsx.md) |

## Constraints

- Do not guess file format from content — use the file extension.
- For legacy `.doc` / `.xls`, convert with LibreOffice (`soffice --headless --convert-to <target>`) before applying the OOXML workflow.
- Install only the dependencies needed for the detected format — do not install all packages upfront.
- When extracting tables, preserve the original structure (merged cells, multi-row headers) unless the user asks for flattening.
- Before presenting results, review extraction quality: check for empty pages, garbled text, or missing tables.
