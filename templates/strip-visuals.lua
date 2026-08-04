-- strip-visuals.lua - Pandoc filter that removes what a narrator cannot speak.
--
-- Consumed by scripts/md-to-epub.sh; see guides/audiobook-pipeline.md.
-- Copy this file into a project to render audiobook chapters there.
--
-- It is a safety net, not a converter: it deletes unspeakable elements rather
-- than describing them. The prose has to carry the meaning already.

-- ── Code ──────────────────────────────────────────────────────────────────
-- Code blocks are dropped whole. Inline code is spoken, so separators become
-- spaces: `user_id` reads as "user id", not "user underscore id".

function CodeBlock(_)
  return {}
end

function Code(el)
  local spoken = el.text:gsub("[_%-%./]+", " "):gsub("%s+", " ")
  spoken = spoken:gsub("^%s+", ""):gsub("%s+$", "")
  return pandoc.Str(spoken)
end

-- ── Tables ────────────────────────────────────────────────────────────────
-- A read-aloud table is a wall of disconnected cells. Linearise it in prose
-- instead; the lint in md-to-epub.sh reports every table it finds.

function Table(_)
  return {}
end

-- Optional: keep tables in the EPUB anyway (they are then read cell by cell).
-- Delete the Table function above and this comment to enable.

-- ── Images ────────────────────────────────────────────────────────────────
-- The picture stays visible in the reader, but its alt text and caption are
-- cleared so nothing spurious gets narrated.

function Image(el)
  el.caption = {}
  el.title = ""
  return el
end

-- ── Links and raw markup ──────────────────────────────────────────────────
-- Link text is prose and stays; the URL is dropped. Raw HTML and LaTeX have
-- no spoken form.

function Link(el)
  return el.content
end

function RawBlock(_)
  return {}
end

function RawInline(_)
  return {}
end

function Math(_)
  return {}
end

-- ── Footnotes ─────────────────────────────────────────────────────────────
-- A footnote interrupts the sentence it hangs off. Fold the content into the
-- main text instead; anything left here is dropped.

function Note(_)
  return {}
end

-- ── Bare URLs ─────────────────────────────────────────────────────────────
-- Autolinks survive as plain strings after the Link filter; strip them too.

function Str(el)
  if el.text:match("^https?://") or el.text:match("^www%.") then
    return {}
  end
  return el
end
