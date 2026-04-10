# Readability — German Prose

German-specific patterns that affect how quickly a reader can understand
documentation, comments, commit messages, and README files. Supplements
[readability.md](readability.md) for German-language content.

The Code Readability section in [readability.md](readability.md) is
language-neutral and applies to all code regardless of prose language. This
file covers only the Prose and Documentation Slop section.

**Scope:** Apply this file when the prose is in German. For English text, use
the prose section in [readability.md](readability.md). For mixed-language
content, apply both to the respective sections.

---

## Prose and Documentation Slop — German

### KI-Vokabular

Certain words are statistically overrepresented in German LLM output. One in
isolation may be coincidental; clusters are a signal.

| Remove or replace | Typically means |
|---|---|
| `grundlegend` / `grundsätzlich` | "wichtig" or often nothing |
| `maßgeblich` | "wichtig", "wesentlich", or remove |
| `gewährleisten` / `sicherstellen` | "sorgen für" or simplify the sentence |
| `umfassend` | "vollständig" or often nothing |
| `ganzheitlich` | remove — almost always filler |
| `nahtlos` | remove — calque of "seamless" |
| `vielfältig` | remove or use a concrete term |
| `wegweisend` / `bahnbrechend` | "neu" or remove |
| `innovativ` | remove or be specific about what is new |
| `optimieren` | "verbessern" or be specific |
| `essenziell` | "wichtig" or "nötig" |
| `bemerkenswert` | remove — usually introduces filler |
| `bedeutsam` | "wichtig" or remove |
| `nachhaltig` (outside ecology) | remove or use the actual meaning |
| `aufweisen` | "haben" or "zeigen" |
| `hinsichtlich` | "bei", "für", or restructure |
| `diesbezüglich` | remove or restructure |
| `im Rahmen von` | "bei", "in", or remove |

Not every occurrence is slop. "Grundlegend" in a sentence about foundations is
literal. "Grundlegend" in "spielt eine grundlegende Rolle" is slop.

### Overused Conjunctions

LLMs use formal connectors mechanically and too often, creating a stiff,
formulaic rhythm.

**Flag excessive use of:**

- "darüber hinaus"
- "außerdem" / "ferner" / "zudem"
- "des Weiteren" / "überdies"
- "zusätzlich"
- "andererseits"
- "dementsprechend"

Natural German prose varies sentence openings. LLM prose chains these
connectors paragraph after paragraph. Remove or replace with simpler
alternatives ("auch", "und") when the sentence flows without the connector.

### Puffery and Significance Claims

Sentences that assert importance without evidence.

**Flag sentences containing:**

- "steht als / dient als Zeugnis"
- "spielt eine wichtige/bedeutende/entscheidende/zentrale Rolle"
- "unterstreicht seine/ihre Bedeutung"
- "fasziniert weiterhin"
- "hinterlässt (einen) bleibenden Eindruck"
- "Wendepunkt" / "Schlüsselmoment" (without evidence)
- "tief verwurzelt"
- "unerschütterliche Hingabe"
- "festigt seinen/ihren Platz"
- "prägt die [Landschaft/Zukunft/Entwicklung]"

**Suggest:** Delete the sentence. If the fact it asserts is important, state it
concretely with evidence.

### Superficial Analysis

German LLMs attach shallow analysis via Partizip-I constructions (present
participle). These are more marked in German than English "-ing" forms and
sound stilted or bureaucratic.

**Flag trailing participial phrases like:**

- "...gewährleistend, dass..."
- "...hervorhebend, wie wichtig..."
- "...betonend, dass..."
- "...widerspiegelnd..."
- "...unterstreichend seine Bedeutung"
- "...sicherstellend, dass..."
- "...verdeutlichend..."

**Suggest:** Delete the trailing phrase. The sentence before it usually stands
on its own.

### Promotional Tone

Marketing language in technical documentation.

**Flag:**

- "reiches kulturelles Erbe" / "reiche Geschichte"
- "atemberaubend"
- "beeindruckende natürliche Schönheit"
- "bleibendes Vermächtnis"
- "eingebettet in" / "im Herzen von"
- "lebendige [Szene/Kultur/Gemeinschaft]"
- "Engagement für Exzellenz"
- "renommiert"
- "kuratiert"

**Suggest:** Replace with neutral, specific language.

### Copula Avoidance

Inflated alternatives to "ist/sind" or "hat/haben."

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

### Collaborative Residue

Traces of the AI conversation left in German output. Often direct translations
of English ChatGPT phrases that sound unnatural in German.

**Flag:**

- "Wie gewünscht, hier ist..."
- "Ich hoffe, das hilft"
- "Natürlich!" / "Sicherlich!" / "Gerne!" / "Gerne doch!"
- "Möchten Sie, dass ich..."
- "Gibt es noch etwas..."
- "Lassen Sie mich wissen, ob..."
- "Hier ist eine detailliertere Aufschlüsselung..."
- Any sentence addressing "Sie/du" when the document should not

**Suggest:** Delete the sentence entirely.

### Generic Filler

Sentences that say nothing. Test: delete the sentence — if the paragraph's
meaning is unchanged, it was filler.

**Common patterns:**

- "Es ist wichtig zu bemerken/bedenken/beachten, dass..."
- "Es ist bemerkenswert, dass..."
- "Es sei darauf hingewiesen, dass..."
- "An dieser Stelle sei erwähnt..."
- "In diesem Abschnitt werden wir..."
- "Im Folgenden wird erläutert..."
- "Es lässt sich festhalten, dass..."

### Section Summaries and "Fazit"

LLMs summarize sections with formulaic closings — a pattern common in academic
writing but inappropriate in most technical documentation.

**Flag:**

- "Zusammenfassend lässt sich sagen..."
- "Abschließend..."
- "Insgesamt..."
- "Alles in allem..."
- Sections titled "Fazit" that merely restate what was already said

**Suggest:** Delete. The preceding content should stand on its own.

### Negative Parallelisms

Contrastive constructions that create an argumentative tone inappropriate for
neutral prose.

**Flag:**

- "nicht nur... sondern auch" — often the second part is obvious
- "es geht nicht nur um... sondern" — rhetorical without substance
- "es geht nicht darum... sondern vielmehr um" — false depth

**Suggest:** State the point directly without the contrastive setup.

### Elegant Variation

Same as in English: cycling through synonyms for the same concept.
"Das System", "die Plattform", "die Lösung", "das Werkzeug" — all meaning the
same thing.

**Suggest:** Pick one term and use it consistently.

### Compulsive Triples

German LLMs group items in threes, often using "sowohl... als auch... und" or
three coordinated adjectives.

- "innovativ, nachhaltig und zukunftsorientiert"
- "sowohl kulturell als auch wirtschaftlich und sozial"
- "Fachleute, Experten und Stakeholder"

**Suggest:** Keep only terms that carry distinct meaning. Often one or two
suffice.

### Vague Attributions

Claims attributed to unnamed authorities.

**Flag:**

- "Experten zufolge"
- "Branchenberichte deuten darauf hin"
- "Studien zeigen" (without citing any)
- "Kritiker argumentieren"
- "laut verschiedenen Quellen"
- "nach Einschätzung von Fachleuten"

**Suggest:** Cite a specific source or remove the attribution.

### Formatting Tells

Weak signals on their own but strengthen the case alongside content patterns.

**Flag (in combination with other indicators):**

- Key phrases bolded for emphasis — natural German technical prose uses bold
  sparingly
- Frequent anglicistic em dashes (—) — German prose prefers commas,
  parentheses, or colons
- Emojis before headings or list items
- Non-standard list markers (•, -, –) instead of native markup syntax
