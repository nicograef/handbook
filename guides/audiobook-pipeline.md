# Audiobook Pipeline for ElevenReader

## What ElevenReader accepts

| Input | Verdict | Why |
| --- | --- | --- |
| **EPUB** | use this | Chapters, table of contents, navigation, images survive |
| HTML | fallback | Structure survives, no chapter navigation |
| TXT | fallback | No parser risk, no structure either |
| DOCX | works | No advantage over EPUB |
| PDF | avoid | Layout extraction reorders columns, tables, formulas |
| Markdown | **not accepted** | Convert it first |

The [Chrome extension](https://elevenreader.io/text-to-speech-chrome-extension) saves a web page straight into the library.

| Constraint | Value |
| --- | --- |
| Max per file | 500 pages, then split |
| Library sync | Web, iOS, Android share one account |
| Pricing | Free plan: 10 h audio/month; Ultra: unlimited (24 h/day fair-use cap) |

The reader does not reliably skip URLs, code blocks, formulas, or image alt text. Whatever
reaches the EPUB gets narrated, so the filtering happens before upload, not in the app.

Source: [ElevenLabs docs on adding content](https://elevenlabs.io/docs/help-center/product/distribution-publishing/eleven-reader/how-do-i-add-content-to-eleven-reader),
[ElevenReader pricing](https://elevenreader.io/pricing).

## Prerequisites

`pandoc` 3.1.10 or newer, the first release that parses GitHub alerts.
Debian 13 and Ubuntu 25.04 or newer ship it:

```bash
sudo apt install pandoc
```

Ubuntu 24.04 (3.1.3) and Debian 12 (2.17) ship older releases.
There, install the `.deb` from [pandoc releases](https://github.com/jgm/pandoc/releases):

```bash
sudo apt install ./pandoc-<version>-1-amd64.deb
```

## Step 1 — Render the EPUB

```bash
STRICT=1 FILTER=<handbook>/templates/strip-visuals.lua \
  <handbook>/scripts/md-to-epub.sh audiobook/ book.epub
```

Drop `STRICT=1` only for hand-written chapters, where warnings are a to-do list.
Each finding names its chapter, not a line: search that chapter for the element.

## Step 2 — Load it into ElevenReader

1. Pick a **multilingual** voice. A German-only voice mangles the English terms.

## Verify

```bash
# 1. Nothing unspeakable survived: no code, no table markup, no URLs.
pandoc audiobook/[0-9][0-9]-*.md --from gfm --to plain \
  --lua-filter <handbook>/templates/strip-visuals.lua | less

# 2. The split worked: one xhtml file per chapter.
unzip -l book.epub | grep -c 'text/ch'
ls audiobook/[0-9][0-9]-*.md | wc -l          # must match
```

Expected: plain text reads as continuous prose, both counts equal.

## Troubleshooting

```bash
# "pandoc 3.1.10 or newer required" → apt pandoc is too old; install the release .deb (Prerequisites).

# A YAML error in meta.yml aborts the render instead.
pandoc --metadata-file audiobook/meta.yml -f markdown -t plain /dev/null   # exit 0 = valid
```
