# Ground Truth

What may be used to settle a claim, in what order, and what cannot be settled at
all.

- [The evidence rule](#the-evidence-rule)
- [Lane 1 — the repo](#lane-1--the-repo)
- [Lane 2 — read-only command output](#lane-2--read-only-command-output)
- [Lane 3 — official upstream sources](#lane-3--official-upstream-sources)
- [Which lane wins](#which-lane-wins)
- [Claims with no lane](#claims-with-no-lane)
- [Routing table](#routing-table)

## The evidence rule

A verdict is worth exactly as much as the artifact behind it. Every verdict carries one of
three artifacts, produced **in this session**:

| Artifact | Form |
| --- | --- |
| File excerpt | with `path:line` |
| Command output | the actual stdout of a command run here |
| Fetched URL | the URL, with an as-of date |

- **Training data is not a source.** "nginx does X" from recollection is not a verdict.
- Neither is "this looks right".
- The failure mode this rule stops is not missing a wrong line — it is confidently correcting
  a right one.
- A corpus that comes back with zero findings still needs every evidence field filled in.
- An all-TRUE report with empty evidence fields means the checks did not happen, not that the
  docs are perfect.
- Re-read before reporting.

## Lane 1 — the repo

The nearest and cheapest lane, and the one most claims belong to.

- **Covers** — paths, filenames, make targets, script names and flags, compose services.
- Also env var names, config keys and their defaults, function and type names.
- Also internal relative links.
- **How** — open the file and read the definition.
- A grep hit on a heading proves the word appears, not that the thing exists.
- `make check` in a doc and `check:` in the Makefile are different facts.
- **Precedence** — the file wins over any prose describing it, without exception.
- **Gotcha, templates** — check a claim about a template file against the template.
- Never against the repo's own instance of it.
- The two drift, and the instance is usually the one that moved.

## Lane 2 — read-only command output

- **Covers** — installed tool versions, which flags actually exist, real defaults.
- Also whether a command is present at all.
- **Allowed** — `--help`, `--version`, `-n` / `--dry-run`, `git log|show|ls-files`, `ls`,
  `stat`.
- Also `shellcheck`, `make -n`, and validators or parsers that do not write.
- **Forbidden, without exception** — anything that installs, starts, stops, writes, or
  deletes.
- Also anything that reaches a production host, or sends traffic that changes remote state.
- If settling a claim requires really running it, the claim is UNREACHED. Say so.
- An infrastructure handbook documents commands that are meant to be destructive.
- "Verifying" them is the worst thing this skill could do.
- **The dev machine is not the target.** A version from the local box says nothing about a
  Debian server.
- Nor about a CI runner, nor a container image.
- Record which machine produced the output.
- Downgrade the verdict to UNREACHED when the claim is about a host you cannot read.

## Lane 3 — official upstream sources

- **Covers** — third-party tool behaviour, deprecated flags, current stable versions.
- Also security guidance, and anything about a tool not installed locally.
- **How** — delegate to the `web-researcher` agent, or `WebFetch` a known official URL.
- **Official** means the vendor's docs, the project's own repository or release notes, or an
  RFC.
- A blog post, a forum answer, and a model's recollection are none of these.
- **Every external verdict carries an as-of date and the URL.**
- "Current" is a moving target; a version verified today is a dated observation.
- It is not a permanent fact, and the report says so.
- **Do not "correct" a deliberate pin.** A repo pinning an older version is stating a
  decision.
- Check the lockfile, manifest, or CI config before treating an upstream release as staleness
  evidence.
- The doc may be describing the pin accurately.

## Which lane wins

| Claim about | Precedence |
| --- | --- |
| **This repo** | repo > command output > upstream |
| **A third-party tool's behaviour** | upstream > command output > repo |
| **Any doc** | a doc never verifies a doc, in either direction |

- Two lanes can genuinely disagree — the Makefile says one thing, `make -n` does another.
- That is a finding about the repo, not a doc fix. Report it.

## Claims with no lane

Some statements cannot be false in any checkable way:

- Conventions and preferences ("2-space indent", "no frameworks")
- Rationale for a past decision
- Tribal knowledge — where credentials live, who owns the upstream service, which registrar
  holds the domain

Handling:

- These take lane `none` and get no verdict at all.
- A verdict implies a source that could have refuted them, and there is none.
- Do not fix them, and do not delete them.
- Never list them individually in the report.
- A findings list padded with unfalsifiable conventions buries the real errors.
- Count them in one line instead.
- They stay in scope for exactly one check: two of them contradicting each other.
- That is a genuine finding, because at least one is misleading a reader today.
- **Not the same as UNREACHED** — that means a claim *does* have a lane the session could not
  reach.
- UNREACHED claims are listed one by one: unfinished work, not unfalsifiable statements.

## Routing table

| Claim | Lane | Settled by |
| --- | --- | --- |
| `make check` runs the repo self-check | repo | the `Makefile` target |
| A script accepts `--dry-run` | repo | the source; `--help` corroborates |
| A relative link resolves | repo | the file on disk, plus the anchor |
| An env var name | repo | `.env.example`, compose file, or the code reading it |
| Node 24 / Go 1.26 is the version used | repo | lockfile, `go.mod`, CI matrix, Dockerfile |
| Docker Compose v2 dropped `version:` | upstream | Compose docs, with an as-of date |
| A certbot flag still exists | upstream | certbot docs; local `--help` only if installed |
| A UFW rule ordering claim | command | `ufw --dry-run`, never `ufw enable` |
| "Restore takes about 20 minutes" | none | operational experience — leave it |
| "We deploy from `main` only" | none | policy; check only against other policy statements |
| "The staging box is reachable at …" | none | tribal knowledge — the doc *is* the source |
