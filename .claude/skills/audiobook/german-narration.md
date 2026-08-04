# German Narration with English Terms

- [The rule](#the-rule)
- [The gloss](#the-gloss)
- [Keep or translate](#keep-or-translate)
- [Grammar around English nouns](#grammar-around-english-nouns)
- [Acronyms](#acronyms)
- [Voice and pronunciation](#voice-and-pronunciation)

Narration language is German. Technical terms stay English. Every term gets a
short German explanation the first time a chapter uses it.

Rationale: the listener reads English docs and English code. Translating the
terms would break the link to everything they search for later.

## The rule

- Prose, connectives, and argument: German.
- Technical term, identifier, product name: English, unchanged.
- First use per chapter: term, then a comma, then one German clause.
- Later uses in the same chapter: bare term, no repeat gloss.

Gloss per chapter, not per book. A listener may start in the middle.

## The gloss

One clause. It names what the thing *is*, not what it is good for.

| Term | Gloss on first use |
| --- | --- |
| index | Ein Index, also eine Datenstruktur, die Suchen beschleunigt |
| query planner | Der Query Planner, die Komponente, die den Ausführungsweg einer Abfrage wählt |
| connection pool | Ein Connection Pool, ein Vorrat offener Datenbankverbindungen |
| chunking | Chunking, das Zerlegen eines Textes in kleine Abschnitte |
| embedding | Ein Embedding, ein Vektor, der die Bedeutung eines Textstücks abbildet |
| retrieval | Retrieval, das Nachschlagen passender Textstücke vor der Antwort |

Anti-pattern: a gloss that restates the English word in German and stops there.
"Chunking, also das Chunken" explains nothing.

## Keep or translate

| Category | Handling | Example |
| --- | --- | --- |
| Established technical term | Keep English | index, cache, replication lag |
| Identifier from the codebase | Keep, spoken form | `user_id` wird zu "user id" |
| Product or tool name | Keep | PostgreSQL, Docker, pandoc |
| Everyday word with a German equivalent | Translate | "Abfrage" statt "query" im Fließtext |
| Verb built on an English term | Use a German verb | "einen Index anlegen", nicht "indexen" |

The last row matters most. English nouns survive in German sentences; English
verbs do not. Build the sentence around a German verb.

## Grammar around English nouns

- Pick the gender of the closest German noun, then stay consistent in the book.
- Der Index, der Pool, das Embedding, das Chunking, die Query.
- Plural stays English: "die Embeddings", "die Chunks", nicht "die Embeddinge".
- Keep a term list in the project so later chapters match earlier ones.

## Acronyms

Write the expansion once, then the acronym.

- "Retrieval Augmented Generation, kurz RAG" — danach nur noch RAG.
- Decide once whether an acronym is spoken as a word or as letters.
- Write it the same way every time so the voice stays consistent.

## Voice and pronunciation

- Pick a multilingual voice in ElevenReader. A German-only voice mangles the
  English terms.
- Check one chapter by ear before rendering the rest of the book.
- Last resort for a stubborn term: spell it phonetically in the text.
- That damages the on-screen text, so use it only where the audio is unusable.
