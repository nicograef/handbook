# Writing for the ear

Prose is heard once, in order, with no way to scroll back. Read each sentence aloud; rewrite what you would not say to a colleague on a walk.

## Visual elements

| Element | Rule |
| --- | --- |
| Table | One sentence per row, column names as sentence parts |
| Bullet list | Ordinal prose with connective sentences |
| Diagram | Narrate the flow; never the source |
| Screenshot, chart | State the fact it shows |
| Code block | Cut it; say what the code does and why in two or three sentences |
| Identifier | Spoken form: `user_id` becomes "user id" |
| Path, flag, env var | In words, or leave it out |
| URL, citation, footnote | Drop it; name the source in the sentence if it matters |
| Formula | In words, or keep only the consequence |
| Heading | One H1 per chapter, H2 for sections, nothing deeper |

## Ear rules

- Repeat the core claim at the start and end of a chapter; a listener drifts.
- Signpost transitions in words ("more on that shortly"); there is no visual structure.
- Full sentences of 25 to 35 words read naturally; telegram style sounds rushed.
- Active voice, concrete subjects. Name a thing before you use it; the listener cannot jump to a definition.
- Spell out numbers that matter ("version 17"), skip the rest ("v2.1.197").
- Open a chapter with the question it answers; close with what the listener can now decide or do. One concept per chapter.
- Anti-patterns: reading the existing doc aloud, theory with no anchor in the project, a project tour with no theory. Also API reference as narration, and a bare back-reference instead of restating the point in one clause.

## German narration, English terms

Prose, connectives and argument are German. Technical terms, identifiers and product names stay English, unchanged. The listener reads English docs and code and will search for those words. First use per chapter: the term, a comma, one German clause explaining it. Example: "der Aggregate Root, das Objekt, über das alle Änderungen an einem Zustand laufen". Later uses in the chapter: the bare term. Established loanwords need no gloss (Server, Code, Commit). The article follows the gender in common German use (der Commit, das Repository). Acronyms are spelled out on first use, then spoken letter by letter (E-P-U-B).

## Review rounds

Three rounds, one dimension each. A round that edits outside its dimension is a defect.

| Round | Runs | May change | Must not change |
| --- | --- | --- | --- |
| A, correctness | Per chapter, parallel | Wrong statements; claims without a `sources.md` entry (source them or delete them); code references that drifted | Chapter order, coverage, rhythm, register |
| B, structure and terms | Once, whole book | Chapter order and numbering when dependencies broke; where a term is first explained (move it, never add a second gloss); `terms.yml` | Wording within chapters |
| C, language and flow | Per chapter, parallel | Sentence structure, rhythm, connectives, passives, transitions | Any claim, any term or gloss, order, scope, length |

Round A reads the code as well as `sources.md`; sources cover theory, not this repo. Round B fixes every `check-terms.sh` hit by moving the explanation earlier or moving the chapter, then re-runs the check after renumbering. Round C never cuts for length; repetition that serves the listener stays.

Step 12 diffs each chapter against its Round B state. It verifies only the changed sentences that carry a claim; a broken claim reverts to the Round B wording. Drift guards: a term explained twice means B added instead of moving; delete the later gloss. Chapters shrinking each round means reviewers compressing by habit; revert.
