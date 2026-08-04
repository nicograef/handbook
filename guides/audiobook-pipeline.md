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

It plans, researches, structures, writes, and reviews. Twelve steps with one approval
gate. Full contract: [.claude/skills/audiobook/SKILL.md](../.claude/skills/audiobook/SKILL.md).

| Phase | Steps | Produces |
| --- | --- | --- |
| Understand | 1-3 | Concept list, named gaps |
| Research | 4-5 | `research-plan.md`, `sources.md` |
| Structure | 6 | `PLAN.md`, `terms.yml`, `meta.yml` — **you approve here** |
| Write | 7 | `NN-slug.md` per chapter |
| Review | 8-11 | Correctness, then structure, then language, then a diff re-check |
| Render | 12 | `book.epub` |

The gate is step 6. You see the chapter plan, the question each chapter answers, and the
dependency order before a single chapter is written.

There is no length target at any step. A book runs as long as its subject needs.

`meta.yml` carries `title`, `creator`, and `lang`. Use `lang: de` for German narration.
Chapters are `NN-slug.md`; the prefix sets reading order and keeps the planning
artifacts out of the book.

## Step 4 — Check the term order

Round B of the review runs this. Run it yourself after editing chapters by hand.

```bash
<handbook>/scripts/check-terms.sh audiobook/
```

It reads `audiobook/terms.yml` and fails when a term appears in an earlier chapter than
the one explaining it. That is the most common didactic break, and the only one a script
can find.

## Step 5 — Render the EPUB

```bash
STRICT=1 FILTER=tools/strip-visuals.lua \
  <handbook>/scripts/md-to-epub.sh audiobook/ book.epub
```

`STRICT=1` is the default for skill-written books. The skill resolves every table,
diagram, and code block into prose itself. A lint finding here means step 7 has a bug.
Fix the chapter, do not let the filter strip it.

Drop `STRICT=1` only for hand-written chapters, where warnings are a to-do list.

Output ends with words and minutes per chapter. That is information, not a target.

## Step 6 — Load it into ElevenReader

1. Open [elevenreader.io](https://elevenreader.io/) and sign in.
2. Upload `book.epub`. The library syncs to the phone app.
3. Pick a **multilingual** voice. A German-only voice mangles the English terms.
4. Listen to the first chapter before committing to the rest.

## Step 7 — Optional: GenFM

The GenFM button inside an opened document turns it into a two-host podcast dialogue.

- Accepts EPUB, PDF, TXT, HTML, or a URL.
- Useful for a second pass on material you already heard once.
- Source: [ElevenLabs on GenFM](https://help.elevenlabs.io/hc/en-us/articles/30727178607505-How-do-I-use-GenFM).

## Verify

```bash
# 1. No term is used before it is explained.
<handbook>/scripts/check-terms.sh audiobook/

# 2. Lint is clean and the EPUB builds.
STRICT=1 <handbook>/scripts/md-to-epub.sh audiobook/ book.epub

# 3. Nothing unspeakable survived: no code, no table markup, no URLs.
pandoc audiobook/[0-9][0-9]-*.md --from gfm --to plain \
  --lua-filter tools/strip-visuals.lua | less

# 4. The split worked: one xhtml file per chapter.
unzip -l book.epub | grep -c 'text/ch'
ls audiobook/[0-9][0-9]-*.md | wc -l          # must match
```

Expected: term check clean, lint clean, plain text reads as continuous prose, both
counts equal.

## Troubleshooting

```bash
# "pandoc 3.0 or newer required" → the distro package is 2.x.
# Install the release binary from github.com/jgm/pandoc/releases instead.

# "no NN-slug.md chapters" → chapters need a two-digit prefix, e.g. 01-storage.md.
# That prefix is also what keeps PLAN.md and sources.md out of the book.

# Chapters do not split → the file has no H1, or more than one.
grep -c '^# ' audiobook/[0-9][0-9]-*.md    # expect exactly 1 per file

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
- [.claude/skills/audiobook/review-rounds.md](../.claude/skills/audiobook/review-rounds.md) — the three review dimensions
- [templates/strip-visuals.lua](../templates/strip-visuals.lua) — pandoc filter
- [scripts/md-to-epub.sh](../scripts/md-to-epub.sh) — lint and render
- [scripts/check-terms.sh](../scripts/check-terms.sh) — use-before-explained check
