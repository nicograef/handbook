# Audiobook Pipeline for ElevenReader

Turn a codebase, its Markdown docs, and web research into an EPUB you listen to in
[ElevenReader](https://elevenreader.io/).

The conversion is the easy half. The value comes from the writing step, which adds the
theory the source docs never contain. See
[.claude/skills/audiobook/](../.claude/skills/audiobook/SKILL.md).

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
[Chrome extension](https://elevenreader.io/text-to-speech-chrome-extension) saves a web page
straight into the library.

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
- An ElevenReader account, signed in on the web and on the phone.
- The `audiobook` skill available (symlink tier or handbook plugin, see
  [claude-plugin.md](claude-plugin.md)).

## Step 1 — Install pandoc

```bash
sudo apt-get install -y pandoc     # Debian / Ubuntu
brew install pandoc                # macOS
pandoc --version | head -1         # expect 3.x
```

## Step 2 — Copy the filter into the project

The filter is the render-time safety net for anything the writing step missed.

```bash
mkdir -p tools audiobook
cp <handbook>/templates/strip-visuals.lua tools/
echo '*.epub' >> .gitignore
```

See [templates/strip-visuals.lua](../templates/strip-visuals.lua) for what it removes.

## Step 3 — Generate the chapters

Run the skill in the project whose system you want to understand.

```
/audiobook database indexes in this service
```

It scopes the subject, reads the code, researches the missing theory, and writes one
Markdown file per chapter into `audiobook/`. Approve the outline before it writes.

Then add the book metadata:

```bash
cat > audiobook/meta.yml <<'YAML'
---
title: <book title>
creator: <your name>
lang: de
---
YAML
```

`lang` drives the EPUB language tag. Use `de` for German narration.

## Step 4 — Render the EPUB

```bash
FILTER=tools/strip-visuals.lua \
  <handbook>/scripts/md-to-epub.sh audiobook/ book.epub
```

The script lints first and prints `file:line` for every element a narrator cannot speak.
Fix those in the chapter source, then run it again. `STRICT=1` turns findings into an error.

Output ends with words and minutes per chapter. Chapters far off 8 to 15 minutes need a
split or a merge.

```bash
STRICT=1 <handbook>/scripts/md-to-epub.sh audiobook/ book.epub   # gate before upload
```

## Step 5 — Load it into ElevenReader

1. Open [elevenreader.io](https://elevenreader.io/) and sign in.
2. Upload `book.epub`. The library syncs to the phone app.
3. Pick a **multilingual** voice. A German-only voice mangles the English terms.
4. Listen to the first chapter before committing to the rest.

## Step 6 — Optional: GenFM

The GenFM button inside an opened document turns it into a two-host podcast dialogue.

- Accepts EPUB, PDF, TXT, HTML, or a URL.
- Useful for a second pass on material you already heard once.
- Source: [ElevenLabs on GenFM](https://help.elevenlabs.io/hc/en-us/articles/30727178607505-How-do-I-use-GenFM).

## Verify

```bash
# 1. Lint is clean and the EPUB builds.
STRICT=1 <handbook>/scripts/md-to-epub.sh audiobook/ book.epub

# 2. Nothing unspeakable survived: no code, no table markup, no URLs.
pandoc audiobook/*.md --from gfm --to plain --lua-filter tools/strip-visuals.lua | less

# 3. The split worked: one xhtml file per chapter.
unzip -l book.epub | grep -c 'text/ch'
ls audiobook/*.md | wc -l          # must match
```

Expected: lint clean, plain text reads as continuous prose, both counts equal.

## Troubleshooting

```bash
# "pandoc 3.0 or newer required" → the distro package is 2.x.
# Install the release binary from github.com/jgm/pandoc/releases instead.

# Chapters do not split → the file has no H1, or more than one.
grep -c '^# ' audiobook/*.md    # expect exactly 1 per file

# A sentence ends mid-air after rendering → a stripped URL or footnote left a hole.
# The lint named the line. Rewrite the sentence, do not patch the EPUB.

# Title shows as the filename → meta.yml is missing or not valid YAML.
pandoc --metadata-file audiobook/meta.yml -f markdown -t plain /dev/null   # exit 0 = valid
```

---

See also:
- [.claude/skills/audiobook/SKILL.md](../.claude/skills/audiobook/SKILL.md) — writes the chapters
- [.claude/skills/audiobook/listenability.md](../.claude/skills/audiobook/listenability.md) — prose rules for the ear
- [.claude/skills/audiobook/german-narration.md](../.claude/skills/audiobook/german-narration.md) — German prose, English terms
- [templates/strip-visuals.lua](../templates/strip-visuals.lua) — pandoc filter
- [scripts/md-to-epub.sh](../scripts/md-to-epub.sh) — lint and render
