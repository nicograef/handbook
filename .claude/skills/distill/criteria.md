# Distillation Criteria

- [The bar](#the-bar)
- [What dies](#what-dies)
- [What survives](#what-survives)
- [Judgment calls](#judgment-calls)
- [Code and config comments](#code-and-config-comments)

## The bar

A line survives when you can name **a reader who needs it** and **what breaks if
they never see it**. Both halves are required.

- **"Someone might want context"** names no reader and no breakage — delete.
- **Two tests do most of the work** — derivability and consequence.
- **The 30-second test (derivability)** — can a competent reader get this fact in under 30 seconds?
- **From the source of truth** — reading the config, running `--help`, opening the type, checking `git log`.
- **If yes** — the doc is a stale mirror. Delete it and point at the source.
- **Derivability is measured in *reader cost***, not in principle.
- **Not derivable** — a fact recoverable only by reading eight files and running the code.
- **It belongs in the docs.**
- **The breakage test (consequence)** — delete it in your head and ask who gets hurt.
- **No answer means no reader.**
- **"They would run the wrong command against production"** means keep, whatever it looks like.

## What dies

### Historic residue

Text about how things *used to be*, aimed at a reader who no longer exists.
**Delete** — git holds the history and holds it better.

- Prose changelogs and release notes duplicating `git log` or `CHANGELOG.md`
- "Previously we used X", "as of v2 we switched to", "the old approach was"
- Migration guides for migrations that are complete
- Deprecation notices for things already removed
- Dated status tables: "smoke test 3 pending", "verified 2025-04-11", "TODO:
  revisit after Q3"
- Rationale for a decision nobody will revisit

**Keep** only the rare historic note that is still *operative*. Operative means a
compatibility constraint the current system must honour. Or a documented reason an
obvious-looking change is forbidden.

### Derivable content

Text that restates a machine-readable source. **Delete and link** to the source
of truth.

- Directory listings that duplicate `ls` or the file tree
- Command inventories that duplicate a `Makefile`, `package.json` scripts, or
  `--help`
- API tables regenerable from signatures or an OpenAPI spec
- Config-option lists copied from the config file, with its own defaults
- Prose walking through steps that the numbered list below already gives

**A mirrored list is worse than no list** — it silently drifts and readers trust it anyway.

### Common knowledge

Text explaining things the named audience already knows. **Delete.**

- What Docker / Git / REST / a container is
- "Install dependencies with `npm install`", "clone the repo"
- Generic best-practice essays: why tests matter, why code review matters
- Tool tutorials available upstream in better form

**The bar moves with the audience**, which step 5 settles. An external-user README
may need the install line; a private knowledge base never does. Until then, mark
the verdict `audience-sensitive` rather than assuming.

### Aspirational content

Documentation for things that do not exist. **Delete.**

- Roadmaps, "future work", "planned features"
- Docs for unimplemented or half-built functionality
- TODO essays describing what someone intended to build
- Empty sections kept as placeholders

**Plans belong in an issue tracker**, where they can be closed. Docs describing a
non-existent system actively mislead — a reader cannot tell which paragraphs are real.

### Duplicated content

The same claim in more than one place. Handled by the cross-file pass, not by
per-file review.

- **Delete all but the canonical home.**
- **Canonical** — the file whose stated purpose the claim belongs to, nearest to the thing it describes.
- **Replace with a relative link** only where the reader would otherwise be stuck.
- **Conflicting duplicates are never merged by you** — report both locations to the user.

### Ceremonial scaffolding

Structure that exists because documents are supposed to have structure.
**Delete.** Headings are the navigation.

- Table of contents on a file that fits on one screen
- "Introduction", "Overview", "Background", "Conclusion", "Summary" sections that
  restate their own document
- A first sentence that restates the heading
- Badge walls, decorative separators, emoji section markers
- `CONTRIBUTING`/`CODE_OF_CONDUCT` boilerplate with nothing project-specific
- "This document describes…", "In this section we will…"

**Sentence-level patterns** — see the slop catalogue in
[../cleanup/readability.md](../cleanup/readability.md). Those patterns: puffery,
compulsive triples, negative parallelisms, vague attributions.

### Narrative padding

Prose that surrounds real content without adding any. **Delete.** Instructions
should start at step 1.

- A paragraph introducing a code block that the code block already says
- "As you can see", "it is worth noting that", "simply", "just"
- Motivational framing before instructions
- Restating the previous section before continuing

## What survives

Delete-by-default has one failure mode that matters: cutting the only copy of
something. These categories survive even when they look like noise.

- **Non-derivable why** — the reason behind a surprising choice, especially where the obvious alternative fails.
- **Example** — `// batch size 500 — 1000 hits the provider's undocumented payload cap`; it cannot be recovered.
- **This is the single most valuable prose** in most repos, and the easiest to mistake for a stray comment.
- **Facts that exist nowhere else** — where credentials live, which registrar holds the domain.
- **Also** — which colleague owns the upstream service, why the staging host is named oddly, a dashboard URL.
- **Tribal knowledge has no source of truth** to link to; the doc *is* the source.
- **Sharp edges** — gotchas, ordering dependencies, known-bad paths, "this looks idempotent and is not".
- **Each one is somebody's lost afternoon**, already paid for.
- **Irreversible operations** — exact command sequences for deploys, restores, migrations, key rotation, incident response.
- **Precision beats brevity absolutely here** — never compress a runbook into a summary.
- **Constraints and prohibitions** — "never force-push", "do not run this against prod".
- **They read as common sense and are load-bearing**, particularly for agents. Keep them in the instruction surfaces.
- **Legal and compliance text** — licences, third-party notices, attribution requirements, security policies. Not your call.
- **Entry points** — one file that tells a new reader or agent where to start. Keep it, and keep it short.

## Judgment calls

- **Examples** — one worked example often replaces three paragraphs of explanation.
- **Keep the example**, delete the explanation.
- **Delete additional examples** that vary nothing meaningful.
- **Long onboarding docs** — usually a mix: the environment-specific facts survive, the tool tutorials go.
- **Split** rather than delete wholesale.
- **Docs the user wrote by hand recently** — still subject to the bar.
- **Say so explicitly in the report** rather than quietly cutting them.
- **Comments in template files** — commented-out optional blocks are the interface, not dead code.
- **See *Template Pollution*** in [../cleanup/code-smells.md](../cleanup/code-smells.md). Keep.
- **A doc that is wrong** — wrong is worse than absent.
- **Delete it or FLAG it**; never rewrite it into something you have not verified.

## Code and config comments

Per-comment rules already exist in [../cleanup/code-smells.md](../cleanup/code-smells.md) —
*Unnecessary Comments*, *Narrating Comments*, *Promotional Comments in Configs*, *Dead Code*.
Apply them; do not restate them. What this skill adds at corpus scale:

- **Block-level, not line-level** — look for whole comment headers, banner blocks, and
  file-preamble essays that repeat the module's docs. Delete the block.
- **Docstrings mirroring the signature** — `@param userId The user ID` on a typed parameter is derivable.
- **Delete the parameter list**, keep any sentence stating a contract the type cannot express.
- **Contracts** — units, ownership, nullability semantics, side effects.
- **Comments duplicating a doc file** — the comment wins when both explain the same mechanism.
- **Why** — it is nearest the code and rots slower.
- **Delete the doc section**, not the comment.
