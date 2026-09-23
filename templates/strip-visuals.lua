-- strip-visuals.lua - Pandoc filter that removes what a narrator cannot speak.
--
-- Consumed by scripts/md-to-epub.sh; see guides/audiobook-pipeline.md.
-- Copy this file into a project to render audiobook chapters there.
--
-- It is a safety net, not a converter: it deletes unspeakable elements rather
-- than describing them. The prose has to carry the meaning already.
-- Every deletion or unwrap writes one line to stderr; STRIP_VISUALS_QUIET=1
-- silences them.

local quiet = os.getenv("STRIP_VISUALS_QUIET") == "1"

-- io.stderr, not pandoc.log: the log module needs pandoc 3.2.
local function report(message)
  if not quiet then
    io.stderr:write(message, "\n")
  end
end

-- ── Code ──────────────────────────────────────────────────────────────────
-- Code blocks are dropped whole. Inline code is spoken, so separators become
-- spaces: `user_id` reads as "user id", not "user underscore id".

function CodeBlock(_)
  report("code block dropped - say what it does instead")
  return {}
end

function Code(el)
  local spoken = el.text:gsub("[_%-%./]+", " "):gsub("%s+", " ")
  spoken = spoken:gsub("^%s+", ""):gsub("%s+$", "")
  return pandoc.Str(spoken)
end

-- ── Tables ────────────────────────────────────────────────────────────────
-- A read-aloud table is a wall of disconnected cells. Linearise it in prose
-- instead.

function Table(_)
  report("table dropped - linearise it in prose")
  return {}
end

-- Optional: keep tables in the EPUB anyway (they are then read cell by cell).
-- Delete the Table function above and this comment to enable.

-- ── Alerts ────────────────────────────────────────────────────────────────
-- GitHub alerts (> [!WARNING]) carry prose, so the box goes and the text
-- stays. The generated title ("Warning") is read as a lead-in.

local alerts = { "note", "tip", "important", "warning", "caution" }

function Div(el)
  for _, kind in ipairs(alerts) do
    if el.classes:includes(kind) then
      report(kind .. " alert unwrapped - check it reads as prose")
      return el.content
    end
  end
  return el
end

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

function RawBlock(el)
  report("raw " .. el.format .. " block dropped - write it as prose")
  return {}
end

function RawInline(el)
  report("raw " .. el.format .. " inline dropped - write it as prose")
  return {}
end

function Math(_)
  report("math dropped - write the formula in words")
  return {}
end

-- ── Footnotes ─────────────────────────────────────────────────────────────
-- A footnote interrupts the sentence it hangs off. Fold the content into the
-- main text instead; anything left here is dropped.

function Note(_)
  report("footnote dropped - fold it into the sentence")
  return {}
end

-- ── Bare URLs ─────────────────────────────────────────────────────────────
-- Autolinks survive as plain strings after the Link filter; strip them too.

function Str(el)
  if el.text:match("^https?://") or el.text:match("^www%.") then
    report("bare URL dropped - drop it or name the source")
    return {}
  end
  return el
end
