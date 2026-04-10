# Text Slop Patterns

Patterns to identify and remove in AI-generated prose — documentation, READMEs,
guides, commit messages, PR descriptions, and any written content.

Based on patterns documented by Wikipedia editors and academic research on LLM
writing tells.

## AI Vocabulary — Overused Words

LLMs statistically over-represent certain words. One or two in isolation may be
coincidental; clusters of them are a strong signal.

**High-frequency AI words:**

| Remove or replace | Typically means |
|---|---|
| `additionally` (sentence-initial) | "also" or just start the sentence |
| `crucial` / `vital` / `pivotal` / `key` (adj.) | "important" or often nothing |
| `delve` / `delve into` | "explore", "examine", or nothing |
| `enhance` / `enhancing` | "improve" or rewrite without it |
| `foster` / `fostering` | "encourage", "support", or nothing |
| `garner` | "get", "receive", "attract" |
| `highlight` / `underscore` (as verb) | "show" or remove the sentence |
| `intricate` / `intricacies` | "complex" or often nothing |
| `landscape` (abstract noun) | remove or use a concrete term |
| `leverage` (verb) | "use" |
| `meticulous` / `meticulously` | "careful" or remove |
| `moreover` | often deletable |
| `navigate` (abstract) | "handle", "manage", or nothing |
| `pivotal` | "important" or remove |
| `robust` | "strong", "reliable", or nothing |
| `seamless` / `seamlessly` | remove — almost always filler |
| `showcase` / `showcasing` | "show", "demonstrate" |
| `streamline` | "simplify" |
| `tapestry` (figurative) | remove — always filler |
| `testament` | remove the whole phrase |
| `vibrant` | remove or use a concrete adjective |

**Not every occurrence is slop.** "Crucial" in a sentence about load-bearing
walls is fine. "Crucial" in "plays a crucial role in the ecosystem" is slop.

## Puffery and Significance Claims

LLMs inflate the importance of everything they write about. Sentences that
assert significance without evidence are the clearest sign.

**Remove sentences containing:**

- "stands as / serves as a testament to"
- "plays a vital/significant/crucial/pivotal role"
- "underscores/highlights its importance/significance"
- "reflects broader trends"
- "symbolizing its ongoing/enduring/lasting"
- "setting the stage for"
- "marking/shaping the"
- "represents/marks a shift"
- "key turning point"
- "evolving landscape"
- "indelible mark"
- "deeply rooted"

**Also watch for** hedging that precedes puffery: "While relatively unknown,
[subject] plays a crucial role..." — the hedge does not make the puffery okay.

## Superficial Analysis

LLMs attach shallow commentary to facts, often using present-participle
("-ing") phrases tacked onto sentence ends.

**Remove trailing participial phrases like:**

- "...highlighting the importance of X"
- "...underscoring its significance in the broader context"
- "...reflecting a commitment to Y"
- "...ensuring that Z"
- "...contributing to the overall success of"
- "...fostering a sense of community"
- "...emphasizing the need for"

The sentence before the participle usually stands fine on its own.

## Promotional and Ad-Like Tone

LLMs default to marketing language even when describing mundane subjects.

**Slop words in this category:**

- "boasts a" (meaning "has")
- "rich" (not about money)
- "vibrant" (not about color)
- "nestled in" / "in the heart of"
- "commitment to excellence"
- "diverse array"
- "groundbreaking"
- "renowned"
- "featuring" (as a generic introduction)
- "natural beauty"
- "elevate" (not literal)
- "curated"

**Fix:** Replace with neutral, specific language. "The city boasts a vibrant
cultural scene" → "The city has several theaters and an annual film festival"
(if that's what the source actually says).

## Negative Parallelisms

LLMs structure explanations as if correcting misconceptions that nobody holds.

**Patterns:**

- "Not just X, but also Y" — often Y is obvious
- "It's not about X — it's about Y" — rhetorical without substance
- "No X, no Y, just Z" — false drama

**Fix:** State Y directly without the setup. If the contrast is genuinely
informative, keep a simpler version.

## Rule of Three

LLMs compulsively group things in triples.

- "professionals, experts, and stakeholders"
- "innovative, sustainable, and scalable"
- "keynote sessions, panel discussions, and networking opportunities"

**Fix:** Keep only the terms that carry distinct meaning. Often one or two
suffice.

## Outline-Like Conclusions

LLMs end sections with "Challenges and Future Prospects" that follow a rigid
formula: "Despite its [positive], [subject] faces challenges..." followed by
vague optimism.

**Remove entirely** if the challenges are generic or the future prospects are
speculative. Replace with specific, sourced information if available.

## Vague Attributions

LLMs attribute claims to unnamed authorities.

**Slop phrases:**

- "experts argue"
- "industry reports suggest"
- "observers have noted"
- "researchers have found" (without citing any)
- "according to several sources"
- "some critics argue"

**Fix:** Either cite a specific source or remove the attribution. If you can't
name the expert, the claim probably doesn't need to be there.

## Elegant Variation

LLMs avoid repeating words by cycling through synonyms: "the system", "the
platform", "the solution", "the tool" — all referring to the same thing.

**Fix:** Pick one term and use it consistently. Repetition is fine; confusing
synonym chains are not.

## Copula Avoidance

LLMs avoid simple "is/are" constructions in favor of inflated alternatives.

| AI version | Human version |
|---|---|
| "serves as" | "is" |
| "stands as" | "is" |
| "represents" | "is" |
| "functions as" | "is" |
| "features" (meaning "has") | "has" |
| "offers" (meaning "has") | "has" |
| "boasts" (meaning "has") | "has" |

## Collaborative Residue

LLMs sometimes leave traces of their conversational nature in the output.

**Remove:**

- "As requested, here is..."
- "Let me know if you'd like..."
- "I've structured this as..."
- "Here's an overview of..."
- "Feel free to adjust..."
- Any sentence addressing "you" when the document shouldn't

## Generic Filler Sentences

LLMs pad content with sentences that say nothing.

**Test:** Delete the sentence. If the paragraph's meaning is unchanged, the
sentence was filler.

**Common filler patterns:**

- Sentences that only introduce sections: "In this section, we will explore..."
- Sentences that summarize what was just said
- Sentences that restate the heading in prose form
- "It is worth noting that..." (followed by the actual content — keep the
  content, remove the prefix)
- "It is important to understand that..."
