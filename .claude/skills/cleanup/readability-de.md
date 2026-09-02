# Readability — German Prose

German-specific patterns for documentation, comments, commit messages, and
README files — supplements [readability.md](readability.md) for
German-language content.
Use it for German prose, readability.md for English, and both for
mixed-language content.

## KI-Vokabular

| Remove or replace                 | Typically means                         |
| --------------------------------- | --------------------------------------- |
| `grundlegend` / `grundsätzlich`   | "wichtig" or often nothing              |
| `maßgeblich`                      | "wichtig", "wesentlich", or remove      |
| `gewährleisten` / `sicherstellen` | "sorgen für" or simplify the sentence   |
| `umfassend`                       | "vollständig" or often nothing          |
| `ganzheitlich`                    | remove — almost always filler           |
| `nahtlos`                         | remove — calque of "seamless"           |
| `vielfältig`                      | remove or use a concrete term           |
| `wegweisend` / `bahnbrechend`     | "neu" or remove                         |
| `innovativ`                       | remove or be specific about what is new |
| `optimieren`                      | "verbessern" or be specific             |
| `essenziell`                      | "wichtig" or "nötig"                    |
| `bemerkenswert`                   | remove — usually introduces filler      |
| `bedeutsam`                       | "wichtig" or remove                     |
| `nachhaltig` (outside ecology)    | remove or use the actual meaning        |
| `ermöglichen` (overused)          | "erlauben", "lassen", or restructure    |
| `aufweisen`                       | "haben" or "zeigen"                     |
| `bewerkstelligen`                 | "schaffen", "machen"                    |
| `hinsichtlich`                    | "bei", "für", or restructure            |
| `diesbezüglich`                   | remove or restructure                   |
| `im Rahmen von`                   | "bei", "in", or remove                  |

Not every occurrence is slop.

- "Grundlegend" in a sentence about foundations is literal.
- "Grundlegend" in "spielt eine grundlegende Rolle" is slop.

## Overused Conjunctions

LLMs use formal connectors mechanically and too often, creating a stiff,
formulaic rhythm.

**Flag excessive use of:**

- "darüber hinaus"
- "außerdem" / "ferner" / "zudem"
- "des Weiteren" / "überdies"
- "zusätzlich"
- "andererseits"
- "dementsprechend"

- Natural German prose varies sentence openings.
- LLM prose chains these connectors paragraph after paragraph.
- Remove or replace with simpler alternatives ("auch", "und") when the sentence
  flows without the connector.

## Puffery and Significance Claims

**Flag sentences containing:**

- "steht als / dient als Zeugnis"
- "spielt eine wichtige/bedeutende/entscheidende/zentrale Rolle"
- "unterstreicht seine/ihre Bedeutung"
- "fasziniert weiterhin"
- "hinterlässt (einen) bleibenden Eindruck"
- "Wendepunkt" / "Schlüsselmoment" (without evidence)
- "tief verwurzelt"
- "tiefes Erbe"
- "unerschütterliche Hingabe"
- "festigt seinen/ihren Platz"
- "symbolisiert" (without concrete referent)
- "prägt die [Landschaft/Zukunft/Entwicklung]"

## Superficial Analysis

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

## Promotional Tone

**Flag:**

- "reiches kulturelles Erbe" / "reiche Geschichte"
- "atemberaubend"
- "beeindruckende natürliche Schönheit"
- "bleibendes Vermächtnis"
- "eingebettet in" / "im Herzen von"
- "lebendige [Szene/Kultur/Gemeinschaft]"
- "Engagement für Exzellenz"
- "unbedingt besuchen" / "unbedingt sehen"
- "reicher kultureller Teppich"
- "renommiert"
- "kuratiert"

## Copula Avoidance

Inflated alternatives to "ist/sind" or "hat/haben."

| AI version                     | Human version   |
| ------------------------------ | --------------- |
| "dient als"                    | "ist"           |
| "steht als"                    | "ist"           |
| "stellt ... dar"               | "ist"           |
| "fungiert als"                 | "ist"           |
| "bietet" (meaning "hat")       | "hat"           |
| "verfügt über" (meaning "hat") | "hat"           |
| "zeichnet sich aus durch"      | "hat" / "ist"   |
| "weist ... auf"                | "hat" / "zeigt" |

## Collaborative Residue

**Flag:**

- "Wie gewünscht, hier ist..."
- "Ich hoffe, das hilft"
- "Natürlich!" / "Sicherlich!" / "Gerne!" / "Gerne doch!"
- "Möchten Sie, dass ich..."
- "Gibt es noch etwas..."
- "Lassen Sie mich wissen, ob..."
- "Hier ist eine detailliertere Aufschlüsselung..."
- Any sentence addressing "Sie/du" when the document should not

## Generic Filler

**Common patterns:**

- "Es ist wichtig zu bemerken/bedenken/beachten, dass..."
- "Es ist bemerkenswert, dass..."
- "Es sei darauf hingewiesen, dass..."
- "An dieser Stelle sei erwähnt..."
- "In diesem Abschnitt werden wir..."
- "Im Folgenden wird erläutert..."
- "Es lässt sich festhalten, dass..."

## Section Summaries and "Fazit"

LLMs summarize sections with formulaic closings — a pattern common in academic
writing but inappropriate in most technical documentation.

**Flag:**

- "Zusammenfassend lässt sich sagen..."
- "Abschließend..."
- "Insgesamt..."
- "Alles in allem..."
- Sections titled "Fazit" that merely restate what was already said

**Suggest:** Delete. The preceding content should stand on its own.

## Negative Parallelisms

Contrastive constructions that create an argumentative tone inappropriate for
neutral prose.

**Flag:**

- "nicht nur... sondern auch" — often the second part is obvious
- "es geht nicht nur um... sondern" — rhetorical without substance
- "es geht nicht darum... sondern vielmehr um" — false depth

**Suggest:** State the point directly without the contrastive setup.

## Elegant Variation

"Das System", "die Plattform", "die Lösung", "das Werkzeug" — all meaning the
same thing.

## Knowledge Cutoff Hints

Traces of the model's training-data cutoff that remain visible in the output.

**Flag:**

- "Stand [Datum]"
- "Bis zu meinem letzten Update..."
- "Stand meines letzten Wissensupdates..."
- "Obwohl spezifische Details begrenzt/rar sind..."
- "nicht allgemein verfügbar/dokumentiert/offengelegt"
- "in den bereitgestellten/verfügbaren Quellen..."
- "basierend auf verfügbaren Informationen..."

**Suggest:** Delete the sentence. These are definitive proof of unedited LLM output.

## Compulsive Triples

German LLMs group items in threes, often using "sowohl... als auch... und" or
three coordinated adjectives.

- "innovativ, nachhaltig und zukunftsorientiert"
- "sowohl kulturell als auch wirtschaftlich und sozial"
- "Fachleute, Experten und Stakeholder"

## False Extension

"Von... bis" constructions that enumerate examples without conveying information.

**Flag:**

- "von traditioneller Volksmusik bis hin zu moderner Gegenwartskunst"
- "von klassischen Methoden bis hin zu innovativen Ansätzen"

**Suggest:** List the specific examples or remove the enumeration if it adds no information.

## Vague Attributions

**Flag:**

- "Experten zufolge"
- "Branchenberichte deuten darauf hin"
- "Studien zeigen" (without citing any)
- "Kritiker argumentieren"
- "laut verschiedenen Quellen"
- "nach Einschätzung von Fachleuten"

## Formatting Tells

Weak signals on their own but strengthen the case alongside content patterns.

**Flag (in combination with other indicators):**

- Key phrases bolded for emphasis — natural German technical prose uses bold
  sparingly
- Frequent anglicistic em dashes (—) — German prose prefers commas,
  parentheses, or colons
- Emojis before headings or list items
- Non-standard list markers (•, -, –) instead of native markup syntax
