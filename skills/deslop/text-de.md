# German Text Slop Patterns

German-specific patterns to identify and remove in AI-generated prose —
documentation, READMEs, guides, articles, and any German-language written
content. Supplements [text.md](text.md) with patterns unique to German or
patterns where the German surface form differs significantly from the English
equivalent.

Source: patterns documented by German Wikipedia editors
([Wikipedia:Anzeichen für KI-generierte Inhalte](https://de.wikipedia.org/wiki/Wikipedia:Anzeichen_f%C3%BCr_KI-generierte_Inhalte))
and observed in German LLM output.

**Scope:** Apply this file when the text is in German. For English text, use
[text.md](text.md). For mixed-language content, apply both files to the
respective sections.

---

## KI-Vokabular — Overused Words

German LLMs over-represent certain words and constructions. Clusters are a
strong signal; isolated occurrences may be coincidental.

| Remove or replace | Typically means |
|---|---|
| `grundlegend` / `grundsätzlich` | "wichtig" or often nothing |
| `maßgeblich` | "wichtig", "wesentlich", or remove |
| `gewährleisten` / `sicherstellen` | "sorgen für" or simplify the sentence |
| `umfassend` | "vollständig" or often nothing |
| `ganzheitlich` | remove — almost always filler |
| `nahtlos` | remove — direct calque of "seamless" |
| `vielfältig` | remove or use a concrete term |
| `wegweisend` / `bahnbrechend` | "neu" or remove |
| `innovativ` | remove or be specific about what is new |
| `optimieren` | "verbessern" or be specific |
| `essenziell` | "wichtig" or "nötig" |
| `bemerkenswert` | remove — usually introduces filler |
| `bedeutsam` | "wichtig" or remove |
| `nachhaltig` (outside ecology) | remove or use the actual meaning |
| `ermöglichen` (overused) | "erlauben", "lassen", or restructure |
| `aufweisen` | "haben" or "zeigen" |
| `bewerkstelligen` | "schaffen", "machen" |
| `hinsichtlich` | "bei", "für", or restructure |
| `diesbezüglich` | remove or restructure |
| `dementsprechend` | "daher", "deshalb" |
| `im Rahmen von` | "bei", "in", or remove |

**Not every occurrence is slop.** "Grundlegend" in a sentence about
foundations is literal. "Grundlegend" in "spielt eine grundlegende Rolle" is
slop.

## Overused Conjunctions

LLMs use formal connectors mechanically and too often, creating a stiff,
formulaic rhythm that stands out in natural German prose.

**Flag excessive use of:**

- "darüber hinaus"
- "außerdem"
- "ferner"
- "zusätzlich"
- "andererseits"
- "zudem"
- "des Weiteren"
- "überdies"

**Fix:** Remove the connector if the sentence flows without it. Replace with
simpler alternatives ("auch", "und") or restructure. Natural German prose
varies its sentence openings; LLM prose chains these connectors paragraph after
paragraph.

## Puffery and Significance Claims

German LLMs inflate importance with a small repertoire of phrases. These are
direct equivalents to the English patterns but sound even more unnatural in
German-language technical or encyclopedic writing.

**Remove sentences containing:**

- "steht als / dient als Zeugnis"
- "spielt eine wichtige/bedeutende/entscheidende/zentrale Rolle"
- "unterstreicht seine/ihre Bedeutung"
- "fasziniert weiterhin"
- "hinterlässt (einen) bleibenden Eindruck"
- "Wendepunkt" / "Schlüsselmoment" (without concrete evidence)
- "tief verwurzelt"
- "tiefes Erbe"
- "unerschütterliche Hingabe"
- "festigt seinen/ihren Platz"
- "symbolisiert" (without concrete referent)
- "prägt die [Landschaft/Zukunft/Entwicklung]"

## Superficial Analysis

German LLMs attach shallow analysis via Partizip-I constructions (present
participle). These are more marked in German than English "-ing" forms because
natural German prose uses them sparingly. They often sound stilted or
bureaucratic.

**Remove trailing participial phrases like:**

- "...gewährleistend, dass..."
- "...hervorhebend, wie wichtig..."
- "...betonend, dass..."
- "...widerspiegelnd..."
- "...unterstreichend seine Bedeutung"
- "...sicherstellend, dass..."
- "...verdeutlichend..."
- "...aufzeigend..."

The sentence before the participle usually stands on its own.

## Promotional Tone

Marketing language in German LLM output. Particularly common when writing
about places, culture, or organizations.

**Slop words and phrases:**

- "reiches kulturelles Erbe"
- "reiche Geschichte"
- "atemberaubend"
- "unbedingt besuchen" / "unbedingt sehen"
- "beeindruckende natürliche Schönheit"
- "bleibendes Vermächtnis"
- "reicher kultureller Teppich"
- "eingebettet in" / "im Herzen von"
- "lebendige [Szene/Kultur/Gemeinschaft]"
- "Engagement für Exzellenz"
- "renommiert"
- "kuratiert"

**Fix:** Replace with neutral, specific language. "Die Stadt verfügt über ein
reiches kulturelles Erbe" → "Die Stadt hat drei Theater und ein jährliches
Filmfestival" (if the source actually says that).

## Editorial Comments and Filler

German LLMs insert meta-commentary that addresses the reader directly. These
are inappropriate in technical documentation, encyclopedic writing, and most
formal German prose.

**Remove sentences containing:**

- "es ist wichtig zu bemerken/bedenken/beachten"
- "es ist bemerkenswert, dass"
- "es sei darauf hingewiesen, dass"
- "an dieser Stelle sei erwähnt"
- "keine Diskussion wäre vollständig ohne"
- "in diesem Abschnitt werden wir..."
- "im Folgenden wird erläutert..."
- "wie bereits erwähnt" (when it restates the heading)
- "es lässt sich festhalten, dass"

**Test:** Delete the sentence. If the paragraph's meaning is unchanged, the
sentence was filler.

## Section Summaries and "Fazit"

LLMs end paragraphs or sections by summarizing the core idea — a pattern
common in academic writing but inappropriate in most technical documentation
and German encyclopedic style.

**Flag:**

- "Zusammenfassend lässt sich sagen..."
- "Abschließend..."
- "Insgesamt..."
- "Alles in allem..."
- Entire sections titled "Fazit" at the end of a document

**Fix:** Remove the summary sentence. The preceding content should stand on
its own. Delete "Fazit" sections that merely restate what was already said.

## Outline-Like Conclusions

German LLMs produce formulaic challenge-and-outlook endings.

**Pattern:** "Trotz seiner/ihrer [positive adjective] steht [subject] vor
mehreren Herausforderungen..." followed by vague optimism about future
initiatives.

**Also flag:**

- "Vermächtnis"
- "Zukunftsaussichten"
- "bleibt abzuwarten"
- "es wird sich zeigen"
- "laufende Initiativen" (without naming any)

**Remove entirely** if the challenges are generic or the future prospects are
speculative.

## Negative Parallelisms

German LLMs use contrastive constructions that create an argumentative tone
inappropriate for neutral prose.

**Patterns:**

- "nicht nur... sondern auch" — often the second part is obvious
- "es geht nicht nur um... sondern" — rhetorical without substance
- "es geht nicht darum... sondern vielmehr um" — false depth

**Fix:** State the point directly without the contrastive setup.

## Trikolon (Rule of Three)

German LLMs group items in threes, often using "sowohl... als auch... und" or
three coordinated adjectives/phrases.

- "innovativ, nachhaltig und zukunftsorientiert"
- "sowohl kulturell als auch wirtschaftlich und sozial"
- "Fachleute, Experten und Stakeholder"

**Fix:** Keep only terms that carry distinct meaning. Often one or two suffice.

## Vague Attributions

German LLMs attribute claims to unnamed authorities — a pattern known as
"Weasel Wording."

**Slop phrases:**

- "Experten zufolge"
- "Branchenberichte deuten darauf hin"
- "Beobachter haben festgestellt"
- "Studien zeigen" (without citing any)
- "Kritiker argumentieren"
- "laut verschiedenen Quellen"
- "nach Einschätzung von Fachleuten"

**Fix:** Either cite a specific source or remove the attribution.

## False Extension

German LLMs use "von... bis" constructions to enumerate examples, creating a
non-neutral, promotional impression.

**Example:** "von traditioneller Volksmusik bis hin zu moderner
Gegenwartskunst"

**Fix:** List the specific examples or remove the enumeration if it adds no
information.

## Copula Avoidance

German LLMs avoid simple "ist/sind/hat" in favour of inflated alternatives.

| AI version | Human version |
|---|---|
| "dient als" | "ist" |
| "steht als" | "ist" |
| "stellt ... dar" | "ist" |
| "fungiert als" | "ist" |
| "bietet" (meaning "hat") | "hat" |
| "verfügt über" (meaning "hat") | "hat" |
| "zeichnet sich aus durch" | "hat" / "ist" |
| "weist ... auf" | "hat" / "zeigt" |

## Elegant Variation

Same pattern as English: cycling through synonyms for the same concept.
"Das System", "die Plattform", "die Lösung", "das Werkzeug" — all meaning the
same thing.

**Fix:** Pick one term and use it consistently.

## Collaborative Residue

Traces of the AI conversation left in German output. These are often direct
translations of English ChatGPT phrases and sound unnatural in German.

**Remove:**

- "Wie gewünscht, hier ist..."
- "Ich hoffe, das hilft"
- "Natürlich!" / "Sicherlich!" / "Gerne!" / "Gerne doch!"
- "Möchten Sie, dass ich..."
- "Gibt es noch etwas..."
- "Lassen Sie mich wissen, ob..."
- "Hier ist eine detailliertere Aufschlüsselung..."
- Any sentence addressing "Sie/du" when the document should not

## Knowledge Cutoff Hints

Traces of the LLM's training data limitations left in the output.

**Remove:**

- "Stand [Datum]"
- "Bis zu meinem letzten Update..."
- "Stand meines letzten Wissensupdates..."
- "Obwohl spezifische Details begrenzt/rar sind..."
- "nicht allgemein verfügbar/dokumentiert/offengelegt"
- "in den bereitgestellten/verfügbaren Quellen..."
- "basierend auf verfügbaren Informationen..."

These are definitive proof of unedited LLM output.

## Formatting Tells

Formatting patterns that signal German LLM output. Less about content, more
about visual structure.

**Flag:**

- **Excessive bold:** key phrases bolded for emphasis ("wichtige
  Erkenntnisse" style). Natural German technical prose uses bold sparingly.
- **Anglicistic em dashes:** frequent use of "—" in German text. German prose
  prefers commas, parentheses, or colons. Isolated use is fine; systematic use
  alongside other indicators is a signal.
- **Emojis before headings or list items.** Unnatural in German technical or
  encyclopedic writing.
- **Non-standard list markers:** bullet characters (•), dashes (-), or em
  dashes (–) instead of the markup format's native list syntax.

These are weak signals on their own. Flag only in combination with other
indicators.

## Style Shifts

Abrupt changes in register or quality within a single document.

**Flag:**

- Sudden switch from colloquial to highly formal German
- Anglicistic constructions mixed into otherwise natural German prose
  (e.g. "in 2024" instead of "im Jahr 2024", passive voice calques)
- Error-free sections surrounded by text with typical non-native speaker
  mistakes

These do not prove AI use alone but strengthen the case alongside content
patterns.
