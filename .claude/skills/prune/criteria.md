# Prune Criteria

What makes a memory, rule, or repo leftover prunable, and which layer may act
without asking.

- [Memory review](#memory-review)
- [Instructions-surface review](#instructions-surface-review)
- [Repo-leftover review](#repo-leftover-review)
- [Gating rules](#gating-rules)

## Memory review

Reviews the harness memory directories (`~/.claude/projects/<slug>/memory/`,
format per [../reflect/targets.md](../reflect/targets.md)). Default scope: the
current project's memory only; `all` scope widens to every slug.

### Mechanical checks — no repo access needed

Run for every reviewed memory directory, including slugs without a local repo:

1. **Orphaned index line** — a `MEMORY.md` line whose linked file is missing.
2. **Unindexed file** — a memory file with no `MEMORY.md` index line.
3. **Near-duplicates** — two memories covering the same fact (compare names,
   descriptions, and body claims); propose merging into one and deleting the
   other.
4. **Dead references** — `[[name]]` links to memories that do not exist, or
   file paths cited in a memory body that no longer exist on disk.

### Semantic verification — repo required

Checks each memory's factual claims against the project it describes. Runs
only where the project's repo exists locally:

- **Repo resolution** — reverse the directory slug: replace the dashes of
  `-home-nico-r-handbook` with `/` → `/home/nico/r/handbook`. Dashes are
  ambiguous (a slug dash may be a path separator or part of a directory
  name, e.g. `msh-sportpferde`): when the naive reversal does not exist,
  list the plausible parent directory and match the remaining slug tail
  against its entries. No unambiguous match → treat the repo as absent.
- A slug without a local repo gets **mechanical checks only** — never guess
  about a codebase that is not there to verify against.
- A claim is stale when the repo contradicts it: the referenced file,
  command, flag, or convention is gone or changed, or git history shows the
  described state was superseded. Cite the contradicting evidence.
- **Partially stale memories become update proposals, never deletions** —
  propose the corrected text, keep the file.

### Finding contract

Every memory finding — inline or from a subagent — carries exactly:

- **target** — the memory file (and its `MEMORY.md` index line)
- **class** — orphaned-index | unindexed | duplicate | dead-reference | stale-claim
- **evidence** — the concrete citation: contradicting file/commit, missing
  path, or the duplicate's name
- **action** — delete, or update with the proposed new text

Applying a deletion removes the file **and** its `MEMORY.md` index line
together; an update edits the file in place and keeps the index line
consistent.

### `all` scope fan-out

The current project is reviewed inline. Every other slug with a local repo
gets one subagent on the default worker tier (`opus` per the model-routing
rules) that returns findings in the contract above; slugs without a local
repo get the mechanical checks only. Subagents only report — nothing they
find is applied without the gate.

## Instructions-surface review

Always current-repo-only, in every scope including `all` — cross-repo rule
edits from a session not in that repo are error-prone.

- **Surfaces in the handbook** — `AGENTS.md` (canonical instructions) and
  `.claude/rules/*.md` (path-scoped rules).
- **Surfaces elsewhere** — discovered per the generic-repo procedure in
  [../reflect/targets.md](../reflect/targets.md); never assume handbook
  paths outside the handbook.

Flag a rule when:

- current repo state **contradicts** it (the convention it encodes is no
  longer what the code does)
- it references **deleted files or tools**
- it is **duplicated across surfaces** — a single-source-of-truth violation;
  propose keeping the canonical copy and deleting the rest
- it pins a **stale version** — cross-check the version the repo actually
  uses (lockfiles, manifests, CI config) before flagging

Proposals are updates or deletions of individual rules, each citing the
contradicting evidence. Never propose rewriting a whole surface.

## Repo-leftover review

Always current-repo-only, in every scope. Deletions land in the working tree and
are committed once the user has picked them.

Propose:

- **Completed plan files** — plan documents (e.g. `plan.md`,
  `docs/plans/*.md`) with every checklist item ticked; one unticked box
  disqualifies the file.
- **Merged worktrees** — `git worktree list` entries that are clean (no
  uncommitted changes) **and** whose branch is merged into the default
  branch.
- **Merged branches** — local branches merged into the default branch
  (`git branch --merged`), excluding the default and current branches.
- **Stale scratch artifacts** — throwaway files past the run's age
  threshold (the only semantic criterion the threshold governs).

Never propose uncommitted work for deletion. Anything ambiguous — a plan
that might still be referenced, a branch whose merge state is unclear — is
presented as a finding with the ambiguity named, never auto-deleted.

## Gating rules

- **Ungated** — only the mechanical classes in
  [state-map.md](state-map.md), and only via the bundled script.
- **Always gated** — every semantic finding (memory, rule, leftover): one
  evidence-citing multi-select; only picked items are applied; selecting
  nothing changes nothing. In dry-run the findings are reported and the
  apply step is skipped entirely.
- **Never proposed** — uncommitted work, memory files as mechanical
  deletions, configuration or credentials, anything outside the three
  review classes above.
- **Age threshold** — governs the mechanical classes and the stale-scratch
  criterion only; memory, rule, and other leftover findings are judged by
  evidence, not mtime.
