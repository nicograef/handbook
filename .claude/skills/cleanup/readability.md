# Readability

- [Code Readability](#code-readability)
- [Prose and Documentation Slop](#prose-and-documentation-slop)

Patterns that affect how quickly a reader can understand code, documentation,
and config files.

---

## Code Readability

### Naming

**Ask:** Does the name describe what this represents, not how it is
implemented?

**Flag when:**

- A function name describes the mechanism (`processData`, `handleStuff`)
  instead of the intent (`calculateDiscount`, `sendWelcomeEmail`)
- Abbreviations are used that are not universally understood in the project
  (`ctx` is fine, `cBldFctry` is not)
- A boolean is named without a clear true/false reading (`flag`, `status` vs
  `isActive`, `hasPermission`)
- Inconsistent naming: same concept is called `user`, `account`, `customer` in
  different places without distinct meaning

**Suggest:** Rename to describe the domain concept. Good names eliminate the
need for comments.

### Clever Code

**Ask:** Would a team member understand this without the author explaining it?

**Flag when:**

- Bitwise operations carry non-bitwise logic
- Short-circuit evaluation is used for control flow (`condition && doThing()`)
- Operator overloading or implicit conversions create surprising behavior
- A language trick requires looking up documentation

**Suggest:** Replace with the obvious version. Only justify cleverness with a
measured performance requirement and a comment explaining why.

### Deep Nesting

**Ask:** Can early returns, guard clauses, or condition inversion flatten this?

**Flag when:**

- The "happy path" is nested inside multiple conditions
- An else branch is as long as or longer than the if branch
- Nested callbacks create a pyramid shape

**Suggest:** Invert conditions and return early. Put the exceptional case first
(`if invalid, return error`) so the happy path runs at the top level.

---

## Prose and Documentation Slop

Patterns that make documentation, comments, commit messages, and README files
feel AI-generated rather than human-written.

### AI Vocabulary

Certain words are statistically overrepresented in LLM output. One in isolation
may be coincidental; clusters are a signal.

| Remove or replace | Typically means |
|---|---|
| `additionally` (sentence-initial) | "also", or just start the sentence |
| `crucial` / `vital` / `pivotal` / `significant` / `key` (adj.) | "important", or often nothing |
| `delve` / `delve into` | "explore", "examine", or nothing |
| `enhance` / `enhancing` | "improve", or rewrite without it |
| `foster` / `fostering` | "encourage", "support", or nothing |
| `garner` | "get", "receive" |
| `highlight` / `underscore` (as verb) | "show", or remove the sentence |
| `intricate` / `intricacies` | "complex", or often nothing |
| `landscape` (abstract) | remove or use a concrete term |
| `leverage` (verb) | "use" |
| `meticulous` / `meticulously` | "careful", or remove |
| `moreover` | often deletable |
| `navigate` (abstract) | "handle", "manage", or nothing |
| `robust` | "strong", "reliable", or nothing |
| `seamless` / `seamlessly` | remove — almost always filler |
| `showcase` | "show", "demonstrate" |
| `streamline` | "simplify" |
| `tapestry` (figurative) | remove — always filler |
| `testament` | remove the whole phrase |

Not every occurrence is slop.

- "Crucial" in a sentence about load-bearing structures is fine.
- "Crucial" in "plays a crucial role in the ecosystem" is slop.

### Puffery and Significance Claims

Sentences that assert importance without evidence.

**Flag sentences containing:**

- "stands as / serves as a testament to"
- "underscores/highlights its importance/significance"
- "reflects broader trends"
- "setting the stage for"
- "marking/shaping the"
- "evolving landscape"
- "symbolizing its ongoing/enduring/lasting"
- "represents/marks a shift"
- "key turning point"
- "indelible mark"
- "deeply rooted"

**Also watch for** hedging that precedes puffery — the hedge does not excuse it:

- "While relatively unknown, [subject] plays a crucial role..."

**Suggest:** Delete the sentence. If the fact it asserts is important, state it
concretely with evidence.

### Superficial Analysis

Trailing participial phrases tacked onto sentence ends that add no information.

**Flag:**

- "...highlighting the importance of X"
- "...underscoring its significance in the broader context"
- "...reflecting a commitment to Y"
- "...ensuring that Z"
- "...contributing to the overall success of"
- "...emphasizing the need for"

**Suggest:** Delete the trailing phrase. The sentence before it usually stands
on its own.

### Promotional Tone

Marketing language in technical documentation.

**Flag:**

- "boasts a" (means "has")
- "rich" (not about money)
- "vibrant" (not about color)
- "commitment to excellence"
- "groundbreaking"
- "renowned"
- "elevate" (not literal)
- "curated"
- "diverse array"
- "nestled in" / "in the heart of"
- "featuring" (as a generic introduction)
- "natural beauty"

**Suggest:** Replace with neutral, specific language.

### Copula Avoidance

Inflated alternatives to "is" or "has."

| AI version | Human version |
|---|---|
| "serves as" | "is" |
| "stands as" | "is" |
| "represents" | "is" |
| "functions as" | "is" |
| "features" (meaning "has") | "has" |
| "offers" (meaning "has") | "has" |
| "boasts" (meaning "has") | "has" |

### Collaborative Residue

Traces of the AI conversation left in the output.

**Flag:**

- "As requested, here is..."
- "Let me know if you'd like..."
- "I've structured this as..."
- "Here's an overview of..."
- "Feel free to adjust..."
- Any sentence addressing "you" when the document should not

**Suggest:** Delete the sentence entirely.

### Generic Filler

Sentences that say nothing. Test: delete the sentence — if the paragraph's
meaning is unchanged, it was filler.

**Common patterns:**

- "In this section, we will explore..."
- "It is worth noting that..."
- "It is important to mention that..."
- Sentences that only introduce what the next sentence already says
- Sentences that restate the heading in prose form

### Elegant Variation

Cycling through synonyms for the same thing: "the system", "the platform",
"the solution", "the tool" — all referring to one concept.

**Suggest:** Pick one term and use it consistently. Repetition is fine;
confusing synonym chains are not.

### Compulsive Triples

LLMs group things in threes: "professionals, experts, and stakeholders" /
"innovative, sustainable, and scalable" / "keynote sessions, panel
discussions, and networking opportunities."

**Suggest:** Keep only the terms that carry distinct meaning. Often one or two
suffice.

### Negative Parallelisms

Explanations framed as if correcting a misconception nobody holds.

**Flag:**

- "Not just X, but also Y" — often Y is obvious
- "It's not about X — it's about Y" — rhetorical without substance
- "No X, no Y, just Z" — false drama

**Suggest:** State Y directly without the setup. Keep a simpler version only if
the contrast is genuinely informative.

### Outline-Like Conclusions

Sections that end with a formulaic "Challenges and Future Prospects": "Despite
its [positive], [subject] faces challenges..." followed by vague optimism.

**Suggest:** Remove entirely if the challenges are generic or the prospects
speculative. Replace with specific, sourced information if available.

### Vague Attributions

Claims attributed to unnamed authorities.

**Flag:**

- "experts argue"
- "industry reports suggest"
- "observers have noted"
- "researchers have found" (without citing any)
- "according to several sources"
- "some critics argue"

**Suggest:** Cite a specific source or remove the attribution. If you cannot
name the authority, the claim probably does not belong.
