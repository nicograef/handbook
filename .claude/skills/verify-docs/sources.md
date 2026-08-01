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

A verdict is worth exactly as much as the artifact behind it. Every one carries
one of three things, produced **in this session**:

- a file excerpt with `path:line`,
- the actual stdout of a command run here, or
- a fetched URL with an as-of date.

Training data is not a source. "nginx does X" from recollection is not a verdict,
and neither is "this looks right". The failure mode this rule exists to stop is
not missing a wrong line — it is confidently correcting a right one.

A corpus that comes back with zero findings still needs every evidence field
filled in. An all-TRUE report with empty evidence fields means the checks did
not happen, not that the docs are perfect — re-read before reporting.

## Lane 1 — the repo

The nearest and cheapest lane, and the one most claims belong to.

**Covers:** paths, filenames, make targets, script names and flags, compose
services, env var names, config keys and their defaults, function and type names,
internal relative links.

**How:** open the file and read the definition. A grep hit on a heading proves the
word appears, not that the thing exists — `make check` in a doc and `check:` in
the Makefile are different facts.

**Precedence:** the file wins over any prose describing it, without exception.

**Gotcha — templates.** A claim about a template file is checked against the
template, not against the repo's own instance of it. The two drift, and the
instance is usually the one that moved.

## Lane 2 — read-only command output

**Covers:** installed tool versions, which flags actually exist, real defaults,
whether a command is present at all.

**Allowed:** `--help`, `--version`, `-n` / `--dry-run`, `git log|show|ls-files`,
`ls`, `stat`, `shellcheck`, `make -n`, and validators or parsers that do not
write.

**Forbidden, without exception:** anything that installs, starts, stops, writes,
deletes, reaches a production host, or sends traffic that changes remote state.
If settling a claim requires really running it, the claim is UNREACHED. Say so —
an infrastructure handbook documents commands that are meant to be destructive,
and "verifying" them is the worst thing this skill could do.

**The dev machine is not the target.** A version from the local box says nothing
about a Debian server, a CI runner, or a container image. Record which machine
produced the output, and downgrade the verdict to UNREACHED when the claim is
about a host you cannot read.

## Lane 3 — official upstream sources

**Covers:** third-party tool behaviour, deprecated flags, current stable
versions, security guidance, anything about a tool not installed locally.

**How:** delegate to the `web-researcher` agent, or `WebFetch` a known official
URL. Official means the vendor's docs, the project's own repository or release
notes, or an RFC. A blog post, a forum answer, and a model's recollection are
none of these.

**Every external verdict carries an as-of date and the URL.** "Current" is a
moving target; a version verified today is a dated observation, not a permanent
fact, and the report says so.

**Do not "correct" a deliberate pin.** A repo pinning an older version is stating
a decision. Check the lockfile, manifest, or CI config before treating an
upstream release as evidence the doc is stale — the doc may be describing the pin
accurately.

## Which lane wins

- For a claim about **this repo**: repo > command output > upstream.
- For a claim about **a third-party tool's behaviour**: upstream > command output
  > repo.
- A doc never verifies a doc, in either direction.

When two lanes genuinely disagree — the Makefile says one thing, `make -n` does
another — that is a finding about the repo, not a doc fix. Report it.

## Claims with no lane

Some statements cannot be false in any checkable way:

- Conventions and preferences ("2-space indent", "no frameworks")
- Rationale for a past decision
- Tribal knowledge — where credentials live, who owns the upstream service, which
  registrar holds the domain

These take lane `none` and get no verdict at all — a verdict implies a source
that could have refuted them, and there is none. Do not fix them, do not delete
them, and never list them individually in the report; a findings list padded with
unfalsifiable conventions buries the real errors. Count them in one line instead.

They remain in scope for exactly one check: two of them contradicting each other
is a genuine finding, because at least one is misleading a reader today.

This is a different thing from UNREACHED, which means a claim *does* have a lane
and the source could not be reached this session. Those are listed one by one —
they are unfinished work, not unfalsifiable statements.

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
