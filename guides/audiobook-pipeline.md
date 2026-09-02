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

Other ingest paths: paste a URL, paste text, scan with the camera. The
[Chrome extension](https://elevenreader.io/text-to-speech-chrome-extension) saves a web page straight into the library.

| Constraint | Value |
| --- | --- |
| Max per file | 500 pages, then split |
| Free plan | about 10 hours per month |
| Ultra plan | about 11 USD per month, 99 USD per year |
| Library sync | Web, iOS, Android share one account |

The reader does not reliably skip URLs, code blocks, formulas, or image alt text. Whatever
reaches the EPUB gets narrated, so the filtering happens before upload, not in the app.

Source: [ElevenLabs docs on adding content](https://elevenlabs.io/docs/help-center/product/distribution-publishing/eleven-reader/how-do-i-add-content-to-eleven-reader),
[ElevenReader pricing](https://elevenreader.io/pricing).

## Prerequisites

- `pandoc` 3.0 or newer (`--split-level` replaced `--epub-chapter-level` in 3.0).

## Step 1 — Render the EPUB

```bash
STRICT=1 FILTER=<handbook>/templates/strip-visuals.lua \
  <handbook>/scripts/md-to-epub.sh audiobook/ book.epub
```

Drop `STRICT=1` only for hand-written chapters, where warnings are a to-do list.

## Step 2 — Load it into ElevenReader

1. Open [elevenreader.io](https://elevenreader.io/) and sign in.
2. Upload `book.epub`. The library syncs to the phone app.
3. Pick a **multilingual** voice. A German-only voice mangles the English terms.
4. Listen to the first chapter before committing to the rest.

## Step 3 — Optional: GenFM

The GenFM button inside an opened document turns it into a two-host podcast dialogue.

- Accepts EPUB, PDF, TXT, HTML, or a URL.
- Useful for a second pass on material you already heard once.
- Source: [ElevenLabs on GenFM](https://help.elevenlabs.io/hc/en-us/articles/30727178607505-How-do-I-use-GenFM).

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
# "pandoc 3.0 or newer required" → Debian 12 and older ship pandoc 2.x.
# Debian 13 ships 3.1, new enough. Needed only on Debian 12 or older:
# install the release binary from github.com/jgm/pandoc/releases.

# Title shows as UNTITLED → meta.yml is missing (the script warns).
# A YAML error in meta.yml aborts the render instead.
pandoc --metadata-file audiobook/meta.yml -f markdown -t plain /dev/null   # exit 0 = valid
```
