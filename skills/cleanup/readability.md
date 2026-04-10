# Readability

Patterns that affect how quickly a reader can understand code, documentation,
and config files. Split into two sections: code readability and prose/doc slop.

---

## Code Readability

### Naming

**Ask:** Does the name describe what this represents, not how it is
implemented?

**Flag when:**

- A variable is named after its type (`strName`, `userList`, `resultMap`)
  instead of its role (`email`, `activeUsers`, `pricesByProduct`)
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

- Bitwise operations are used for non-bitwise logic
- Regex one-liners replace readable string processing
- Short-circuit evaluation is used for control flow (`condition && doThing()`)
- Reduce is used where a loop with clear variable names would be more readable
- Operator overloading or implicit conversions create surprising behavior
- A function uses language tricks that require looking up documentation

**Suggest:** Replace with the obvious version. Clever code optimises for
writing speed; clear code optimises for reading speed. Only justify cleverness
with a measured performance requirement and a comment explaining why.

### Deep Nesting

**Ask:** Can early returns, guard clauses, or condition inversion flatten this?

**Flag when:**

- A function has 4+ levels of indentation
- The "happy path" is nested inside multiple conditions
- An else branch is as long as or longer than the if branch
- Nested callbacks create a pyramid shape

**Suggest:** Invert conditions and return early. Put the exceptional case first
(`if invalid, return error`) so the happy path runs at the top level.

### Long Functions

**Ask:** Is this function doing more than one thing? Can a reader hold the
entire function in their head?

**Flag when:**

- A function exceeds the point where you lose track of what it does while
  reading (typically 40–60 lines, context-dependent)
- Blank lines are used to separate "phases" within a function — each phase is
  a candidate for extraction
- Local variables from the first half are not used in the second half

**Do NOT flag when:**

- A long function is a straightforward sequence of steps with no branching
  (e.g. a build/configuration function)
- Splitting would create shallow fragments with interfaces as complex as the
  implementation

**Suggest:** Extract only if the pieces are genuinely independent. The goal is
deep modules, not maximum fragmentation.

### Consistent Style

**Ask:** Does this code match the conventions established in the rest of the
file and project?

**Flag when:**

- Indentation, brace style, or spacing differs from the surrounding code
- Import grouping or ordering breaks the file's pattern
- Error handling follows a different convention than the rest of the codebase
- String formatting mixes styles (template literals and concatenation in the
  same file)

**Suggest:** Match the existing style. Do not impose a new one.

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
| `crucial` / `vital` / `pivotal` | "important", or often nothing |
| `delve` / `delve into` | "explore", "examine", or nothing |
| `enhance` / `enhancing` | "improve", or rewrite without it |
| `foster` / `fostering` | "encourage", "support", or nothing |
| `garner` | "get", "receive" |
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
| `vibrant` | remove or use a concrete adjective |

Not every occurrence is slop. "Crucial" in a sentence about load-bearing
structures is fine. "Crucial" in "plays a crucial role in the ecosystem" is
slop.

### Puffery and Significance Claims

Sentences that assert importance without evidence.

**Flag sentences containing:**

- "stands as / serves as a testament to"
- "plays a vital/significant/crucial/pivotal role"
- "underscores/highlights its importance/significance"
- "reflects broader trends"
- "setting the stage for"
- "marking/shaping the"
- "evolving landscape"

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

### Elegant Variation

Cycling through synonyms for the same thing: "the system", "the platform",
"the solution", "the tool" — all referring to one concept.

**Suggest:** Pick one term and use it consistently. Repetition is fine;
confusing synonym chains are not.

### Compulsive Triples

LLMs group things in threes: "professionals, experts, and stakeholders" /
"innovative, sustainable, and scalable."

**Suggest:** Keep only the terms that carry distinct meaning. Often one or two
suffice.
