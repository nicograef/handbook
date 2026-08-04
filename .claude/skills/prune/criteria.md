# Prune Criteria

What makes a memory, rule, or repo leftover prunable, and which layer may act
without asking.

- [Memory review](#memory-review)
- [Instructions-surface review](#instructions-surface-review)
- [Repo-leftover review](#repo-leftover-review)

## Memory review

- **Target** — the harness memory directories `~/.claude/projects/<slug>/memory/`.
- **Format** — per [../reflect/targets.md](../reflect/targets.md).
- **Default scope** — the current project's memory only.
- **`all` scope** — widens to every slug.

### Mechanical checks — no repo access needed

Run for every reviewed memory directory, including slugs without a local repo:

1. **Orphaned index line** — a `MEMORY.md` line whose linked file is missing.
2. **Unindexed file** — a memory file with no `MEMORY.md` index line.
3. **Near-duplicates** — two memories covering the same fact; compare names, descriptions, and
   body claims. Propose merging into one and deleting the other.
4. **Dead references** — `[[name]]` links to memories that do not exist. Same for file paths
   cited in a memory body that no longer exist on disk.

### Semantic verification — repo required

Checks each memory's factual claims against the project it describes. Runs
only where the project's repo exists locally:

- **Repo resolution** — reverse the directory slug: replace the dashes of
  `-home-nico-r-handbook` with `/` → `/home/nico/r/handbook`.
- **Ambiguity** — a slug dash may be a path separator or part of a directory name, e.g.
  `msh-sportpferde`.
- **Fallback** — when the naive reversal does not exist, list the plausible parent directory.
- **Match** — the remaining slug tail against its entries.
- **No unambiguous match** — treat the repo as absent.
- **A slug without a local repo** gets **mechanical checks only**.
- Never guess about a codebase that is not there to verify against.
- **Stale claim** — the repo contradicts it: the referenced file, command, flag, or convention
  is gone or changed.
- **Superseded** — or git history shows the described state was superseded.
- Cite the contradicting evidence.
- **Partially stale memories become update proposals, never deletions** —
  propose the corrected text, keep the file.

### Finding contract

Every memory finding — inline or from a subagent — carries exactly these fields:

| Field | Value |
| --- | --- |
| **target** | the memory file (and its `MEMORY.md` index line) |
| **class** | orphaned-index \| unindexed \| duplicate \| dead-reference \| stale-claim |
| **evidence** | the concrete citation: contradicting file/commit, missing path, or the duplicate's name |
| **action** | delete, or update with the proposed new text |

### `all` scope fan-out

- **Current project** — reviewed inline.
- **Every other slug with a local repo** — one subagent each.
- **Tier** — the default worker tier, `opus` per the model-routing rules.
- **Returns** — findings in the contract above.
- **Slugs without a local repo** — the mechanical checks only.
- **Subagents only report** — nothing they find is applied without the gate.

## Instructions-surface review

- **Scope** — always current-repo-only, in every scope including `all`.
- **Why** — cross-repo rule edits from a session not in that repo are error-prone.
- **Surfaces in the handbook** — `AGENTS.md` (canonical instructions) and
  `.claude/rules/*.md` (path-scoped rules).
- **Surfaces elsewhere** — discovered per the generic-repo procedure in
  [../reflect/targets.md](../reflect/targets.md).
- Never assume handbook paths outside the handbook.

Flag a rule when:

- current repo state **contradicts** it (the convention it encodes is no
  longer what the code does)
- it references **deleted files or tools**
- it is **duplicated across surfaces** — a single-source-of-truth violation;
  propose keeping the canonical copy and deleting the rest
- it pins a **stale version** — cross-check the version the repo actually
  uses (lockfiles, manifests, CI config) before flagging

Proposals:

- updates or deletions of individual rules, each citing the contradicting evidence
- never a rewrite of a whole surface

## Repo-leftover review

- **Scope** — always current-repo-only, in every scope.
- **Deletions** — land in the working tree, committed once the user has picked them.

Propose:

- **Completed plan files** — plan documents (`docs/plans/*.md`) with every
  checklist item ticked; one unticked box disqualifies the file.
- **Merged worktrees** — `git worktree list` entries that are clean (no
  uncommitted changes) **and** whose branch is merged into the default
  branch.
- **Merged branches** — local branches merged into the default branch
  (`git branch --merged`), excluding the default and current branches.
- **Stale scratch artifacts** — throwaway files past the run's age
  threshold (the only semantic criterion the threshold governs).

Guards:

- **Never propose uncommitted work for deletion.**
- **Anything ambiguous** — presented as a finding with the ambiguity named, never auto-deleted.
- **Ambiguous examples** — a plan that might still be referenced, a branch whose merge state is
  unclear.
- **Dry-run** — findings are reported; the apply step is skipped entirely.
