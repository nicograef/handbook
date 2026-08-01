# Research dossier: implement-plan skill rework

Captured from workflow run `wf_15d4b659-b32` so the findings survive the workflow, the
session, and context compaction. Working state and the checklist live in `plan.md` at the
repo root. **Delete this file together with `plan.md` when the rework lands.**

Four research agents completed; the three design agents that consumed this dossier died on a
session usage limit (reset 15:00 CEST 2026-08-01). The dossier below is the cached, replayable
input to the design phase.


---

## Handbook conventions

_skill format, plan-file anatomy, link targets, house style_

Now I have everything needed.

## 1. FRONTMATTER CONTRACT

Source: `.claude/rules/skills.md`.

- `name` — required; lowercase letters/numbers/hyphens; ≤ 64 chars; must match directory name.
- `description` — required; non-empty, ≤ 1024 chars; no XML tags; states the trigger in third person ("Works through…", "Use when…"), never a step-by-step summary. Written as a YAML folded block (`>-`) in every existing skill.
- `allowed-tools` — optional; tool allowlist (skill-only field; `tools:` is subagent-only, don't use in a skill).
- `disable-model-invocation` — optional; `true` for side-effect flows.
- `user-invocable` — optional; `false` hides from slash-command menu.
- `argument-hint` — optional; slash-command argument hint.
- Current `implement-plan/SKILL.md` frontmatter has only `name` + `description` — no extra fields, and none are needed for this rewrite unless behavior changes.

## 2. STRUCTURE CONTRACT

Source: `.claude/rules/skills.md`.

Required sections in every SKILL.md:
1. YAML frontmatter
2. **Workflow** — numbered steps
3. **Constraints** — guardrails/anti-patterns
4. **Quality** (only if the skill produces code/documents) — must be a relative link to `../quality.md`, not restated. `implement-plan` and `create-plan` both do exactly this: `run the shared [self-review checklist](../quality.md)`.

Reference files:
- Use relative links, never absolute paths.
- Descriptive names (e.g. `mocking.md`).
- Keep short/focused — push detail out of SKILL.md (progressive disclosure).
- Any reference file over 100 lines needs a bullet TOC of its `##` headings directly under the H1.

README obligation: after creating/renaming a skill, add/update its entry in `.claude/skills/README.md`'s "When to Use Which Skill" table — checked by `make check` → `scripts/check-repo.sh skills` (verifies `.claude/skills/README.md` indexes every SKILL.md directory and vice versa).

## 3. PLAN FILE SHAPE

`create-plan/SKILL.md`'s embedded template, and confirmed live in `docs/plans/plan-distill-handbook.md` (1005 lines, real, on disk):

```markdown
# Plan: <Title>

> Source PRD: <relative path to PRD file, or "n/a" if from task description>

## Goal
## Architectural decisions
## Inventory
## Resolved decisions
## Open questions / Risks

---

## Phase 1: <Title>

**User stories**: <list from PRD, or omit>

### Context
- `path/file.go — symbolName()` — <why relevant>

### What to build
<end-to-end vertical-slice description>

### Acceptance criteria
- [ ] Criterion 1
- [ ] Criterion 2
```

Verified in the real plan file: phase headings are `## Phase N: <title>` (e.g. `## Phase 1: Whole-file removals`, `## Phase 2: ...`), each phase has `### Context`, `### What to build`, `### Acceptance criteria`, and acceptance items are `- [ ] ...` checkbox lines (e.g. line 143: `- [ ] 5 files removed via \`git rm\`; total −307 lines.`). This is exactly the shape `implement-plan` must parse: find the phase with unmet `- [ ]`, flip to `- [x]` once verified.

## 4. LINK TARGETS

| Link (relative from `.claude/skills/implement-plan/`) | Covers |
|---|---|
| `../quality.md` | Shared verify-before-claiming-done checklist — already linked, keep as-is |
| `../create-plan/SKILL.md` | The plan-file format/template consumed by implement-plan — link instead of restating template shape |
| `../guided-implementation/SKILL.md` | Alternate mode: coached/human-writes-code execution of a plan phase — worth a "use this instead if…" pointer |
| `../systematic-debugging/SKILL.md` | Root-cause debugging when a phase's verification step fails repeatedly (implement-plan's own "when to stop" case) |
| `../finish-branch/SKILL.md` | What happens after all phases are done / branch is ready to integrate — natural next-skill link |
| `../using-git-worktrees/SKILL.md` | Isolating the plan execution in its own worktree/branch before starting — cited in that skill's own description ("before executing a multi-step plan") |

## 5. VERIFICATION COMMANDS

No single canonical command name exists repo-wide for arbitrary "target" projects (implement-plan operates on whatever repo/plan it's pointed at, not necessarily this handbook). Existing skills phrase it as a **fallback chain**, not a fixed command:

- `finish-branch/SKILL.md:18` — "Run the project's test command. Use `make test` if the repo has a Makefile, otherwise the language-appropriate default (`go test ./...`, `pnpm test`, `mvn test`)."
- `systematic-debugging/SKILL.md:74` — same pattern: `(\`make test\`, \`go test ./...\`, \`pnpm test\`, \`mvn test\`)`.
- Current `implement-plan/SKILL.md:20` just says "run the project's build, lint, and test suite" with no fallback chain — inconsistent with the other two skills; the rewrite should adopt the same explicit fallback phrasing for consistency.

Within *this* repo specifically, the concrete command is `make check` (runs `scripts/check-repo.sh all`: links, shellcheck, README index, language, skills index, compose config, plugin manifest) — but implement-plan is generic and must not hardcode that; it targets whatever project the plan belongs to.

## 6. HOUSE STYLE

Line counts (all `.claude/skills/*/SKILL.md`):

```
 17 research
 34 clarify
 40 implement-plan (current)
 57 dispatching-parallel-agents
 62 receiving-feedback
 79 ubiquitous-language
 82 using-git-worktrees
 89 ux-review
 90 finish-branch
 94 test-quality
 95 reflect
 98 tdd
 99 systematic-debugging
115 understand
119 prune
138 tutor
143 write-prd
147 cleanup
174 create-plan
175 guided-implementation
221 verify-docs
306 distill
```
Median is roughly 90–100 lines; `implement-plan` at 40 is among the shortest, alongside `research` (17) and `clarify` (34) — process-only skills stay very short.

Observations:
- **Imperative, numbered Workflow.** Every skill's core is a numbered list of imperative verb-first steps ("Read the plan…", "Run the project's test command…").
- **Bold lead phrase per step**, then plain-sentence elaboration: `1. **Read the plan** and find the next phase with unmet acceptance criteria (\`- [ ]\`)`.
- **Attribution line** right after the H1 for skills adapted from elsewhere: `_Adapted from the MIT-licensed [superpowers](https://github.com/obra/superpowers) plugin._` (seen in `systematic-debugging`, `using-git-worktrees`, `receiving-feedback`, `finish-branch`). No such line currently in `implement-plan` — fact, not required.
- **No prose paragraphs of explanation** — one or two sentence framing under the H1, then straight into Workflow/Constraints. No motivational or background text.
- **Sparse code blocks** — SKILL.md files mostly avoid fenced code except where literally copy-pasteable (commands, template skeletons like create-plan's). implement-plan currently has zero code blocks.
- **"When to stop / ask" pattern** appears as its own section in several skills (implement-plan already has "When to stop"; `receiving-feedback` and others use similar escalation sections) — a recurring structural idiom, not just Workflow/Constraints/Quality.
- **Description frontmatter always ends with an explicit "Use when…" trigger clause** — every skill follows `<what it does>. Use when <trigger>.` verbatim pattern.
- **Cross-links are terse markdown links inline in a sentence**, never a "See Also" bullet list section — e.g. `tdd/SKILL.md`: "See [anti-patterns.md](../test-quality/anti-patterns.md) for worked examples…".

---

## Git mechanics

_verified in scratch repos: detection, concurrency, integration, conflicts, recovery, hazards_

Scratch repos used: `/tmp/claude-1000/-home-nico-handbook/930eeaa6-87d6-44db-904d-1bbab0f15393/scratchpad/probeB` (main test bed), `.../probeA` (deliberately corrupted in the gc test), `.../probeSub` (submodule). git 2.47.3, Linux.

---

## A. DETECTION

**Repo root, linked-vs-main, submodule** — one probe, all fields (verified):

```bash
git rev-parse --show-toplevel                            # /…/probeB/wt-a
git rev-parse --path-format=absolute --git-dir           # /…/probeB/repo/.git/worktrees/wt-a
git rev-parse --path-format=absolute --git-common-dir    # /…/probeB/repo/.git
git rev-parse --show-superproject-working-tree           # empty, exit 0
```

From the main checkout `--git-dir` returned the *relative* `.git`, and `--git-common-dir` the absolute path — they compare unequal unless you force `--path-format=absolute`. (verified: the bare `git rev-parse --git-dir` printed `.git` in `probeB/repo`.)

```bash
[ "$(git rev-parse --path-format=absolute --git-dir)" \
= "$(git rev-parse --path-format=absolute --git-common-dir)" ] \
  && echo MAIN CHECKOUT || echo LINKED WORKTREE
```
(verified: `LINKED WORKTREE` in `wt-alpha`, `MAIN CHECKOUT` in `main-checkout`.)

**That test alone is wrong inside a submodule** (verified). In `probeB/repo/sub`:

```
--git-dir        = /…/probeB/repo/.git/modules/sub
--git-common-dir = /…/probeB/repo/.git/modules/sub     # EQUAL → test says "main checkout"
--show-superproject-working-tree = /…/probeB/repo      # non-empty → it's a submodule
```

So the order must be: submodule check **first**, then the git-dir comparison. Note this is the *opposite* failure mode from what `.claude/skills/using-git-worktrees/SKILL.md` step 2 claims ("The git-dir/git-common-dir mismatch is also true inside a submodule") — verified false at 2.47.3: inside a submodule they **match**. That skill's guard is documented backwards.

**Main checkout path.** Do not derive it as `dirname "$GIT_COMMON"` (what `.claude/skills/finish-branch/SKILL.md` step 5 does). Verified broken for a bare-hosted worktree: in `probeB/bare-wt`, common-dir is `/…/probeB/bare.git`, so dirname yields `/…/probeB` — a directory that is not a checkout at all. Correct primitive — the **first** record of `git worktree list --porcelain` is always the main worktree (verified: it was `…/main-checkout` even when the command ran from `wt-alpha`):

```bash
git worktree list --porcelain | awk 'NR==1{print $2}'
git worktree list --porcelain | sed -n '1,4p' | grep -q '^bare$' && echo "NO MAIN CHECKOUT (bare)"
```
(verified: printed `/…/probeB/bare.git` and `IS_BARE`.)

**Full worktree list.** `git worktree list --porcelain` record fields observed: `worktree <abs path>`, `HEAD <full oid>`, then exactly one of `branch refs/heads/<name>` / `detached` / `bare`, plus optional `locked [<reason>]` and `prunable <reason>`. Records are blank-line separated; `-z` uses NUL. (verified, all six field types produced.)

**Default branch** (verified, in order of reliability):

```bash
git symbolic-ref --short refs/remotes/origin/HEAD    # -> origin/main ; strip "origin/"
```
Exit 128 `fatal: ref refs/remotes/origin/HEAD is not a symbolic ref` on a fresh clone-less remote until you run `git remote set-head origin -a` (verified — it printed `origin/HEAD set to main`, after which the symbolic-ref succeeded). `git ls-remote --symref origin HEAD` also works and needs no local state (verified: `ref: refs/heads/main<TAB>HEAD`). With no remote at all there is no reliable answer — ask rather than guess (`init.defaultBranch` describes new repos, not this one).

**Dirty** (verified):

```bash
git status --porcelain=v2 --branch --untracked-files=all
```
Clean tree ⇒ only `# branch.*` header lines. Dirty ⇒ `1 .M …` / `? path` lines. `# branch.upstream` and `# branch.ab +N -M` appear **only when an upstream is configured** (verified: absent on `feat/alpha`, present on `main`). Exit code is always 0 — count the non-`#` lines, don't test `$?`. For tracked-only, `git diff --quiet` (exit 1 = dirty) and `git diff --cached --quiet` (verified: 1 and 0 respectively).

**Unmerged / unpushed** (verified):

```bash
git rev-list --left-right --count main...HEAD    # "1\t2"  = behind<TAB>ahead
git merge-base --is-ancestor HEAD main           # exit 1 = not yet merged into main
git log --oneline main..HEAD                     # the actual unmerged commits
git rev-list --count origin/main..main           # 1  = unpushed
git log --oneline --branches --not --remotes     # everything unpushed, all branches
git rev-parse --abbrev-ref --symbolic-full-name '@{upstream}'   # exit 128 if no upstream
```

---

## B. CONCURRENCY AWARENESS

**What git protects for you** (all verified, exact messages):

| command | result |
|---|---|
| `git checkout main` / `git switch main` from another worktree | exit 128 `fatal: 'main' is already used by worktree at '…/main-checkout'` |
| `git worktree add <dir> feat/beta` (already checked out) | exit 128 `fatal: 'feat/beta' is already used by worktree at '…/wt-beta'` |
| `git branch -d/-D feat/beta` (checked out elsewhere) | exit 1 `error: cannot delete branch 'feat/beta' used by worktree at …` |
| `git branch -f main HEAD` (main checked out elsewhere) | exit 128 `fatal: cannot force update the branch 'main' used by worktree at …` |
| `git push . HEAD:main` (fast-forward, main checked out) | exit 1 `remote rejected … (branch is currently checked out)` — `receive.denyCurrentBranch` default |

**What git does NOT protect — the silent corrupter** (verified):

```bash
git update-ref refs/heads/feat/beta "$(git rev-parse HEAD)"   # exit 0, NO warning
```
`wt-beta` afterwards reported four bogus **staged** changes (`1 M. … both-add.txt`, `1 D. … docs/README.md`, …) because its index still matched the old commit. `update-ref` bypasses every worktree guard above. **Never use `git update-ref` on a branch that might be checked out.** Its compare-and-swap form is safe *for the ref* but still desyncs the other worktree.

**`git rebase --update-refs` silently skips locked-out refs** (verified). Stack `st/mid` → `st/top`, with `st/mid` checked out in `wt-mid`:

```bash
git -C .../wt-st rebase --update-refs main
# stdout: (empty)   stderr: "Successfully rebased and updated refs/heads/st/top."   exit 0
# st/mid: still a430c5b (old base).  No "Updated the following refs" block, no warning.
```
With `st/mid` *not* checked out anywhere the same command printed `Updated the following refs with --update-refs:` and moved it. So `--update-refs` in a multi-worktree repo can leave a stack half-rebased with exit 0.

**index.lock is per-worktree** (verified):

```bash
git rev-parse --path-format=absolute --git-path index
# main-checkout/.git/index   vs   main-checkout/.git/worktrees/wt-alpha/index
```
`touch main-checkout/.git/index.lock` then committing in `wt-alpha` → exit 0. Committing in `main-checkout` → exit 128 `fatal: Unable to create '…/.git/index.lock': File exists.` The lock blocks only its own worktree. It is a 0-byte file with **no pid inside** (verified `wc -c` = 0), and `fuser` found no holder — so staleness can only be inferred from mtime age, never proven. (inference) Treat an index.lock as live and back off; never delete another worktree's lock.

**Worktree locks are advisory metadata, not mutexes** (verified):

```bash
git worktree lock --reason "agent-run-42 in progress" .../wt-a   # exit 0
git worktree list --porcelain   # → "locked agent-run-42 in progress"
git worktree remove .../wt-a    # exit 128 "cannot remove a locked working tree, lock reason: …"
```
It blocks `worktree remove`/`prune` only. It does not stop commits, rebases, or ref writes in that worktree.

**Safe concurrently** (verified by stress test):
- **Commits from separate worktrees on distinct branches** — 80+80 interleaved commits, **0 failures**.
- **Branch creation** — 100+100 concurrent `git branch x/…`, **0 errors**, 200 branches created.
- **Same-ref `update-ref` contention** — 6 workers × 150 writes to one ref, **0 errors**. Git's ref lockfile window is too small to observe; do not rely on collision as your safety net.
- `git fetch` and read-only commands (`log`, `status`, `merge-tree`, `rev-parse`).

**NOT safe concurrently — reproducible repository corruption** (verified):

```bash
( cd wt-beta;      for i in $(seq 1 40); do echo g$i >> f; git add -A; git commit -q -m g$i; done ) &
( cd main-checkout; git gc --prune=now --quiet ) &
wait
```
Observed: 22 × `fatal: could not parse HEAD` on the commit side; `error: cannot lock ref 'refs/heads/feat/beta': is at 3340c94 but expected fc1c59c` on the gc side, **gc exit 0**; then:

```
$ git fsck
error: refs/heads/feat/beta: invalid sha1 pointer 934d668…
error: worktrees/wt-beta/HEAD: invalid sha1 pointer 934d668…
```
The branch and the worktree HEAD point at pruned objects. Plain `git gc` (default 2-week grace) run against the same workload was clean: 0 commit errors, `gc_exit=0`, `fsck` errors = 0 (verified). It is `--prune=now` that kills it.

**Atomic cross-process mutex** (verified) — the only primitive here that actually serializes agents. `git update-ref <ref> <new> ""` means "create only if absent":

```bash
git update-ref refs/agent-lock/integrate "$(git rev-parse HEAD)" ""   # exit 0  = acquired
git update-ref refs/agent-lock/integrate "$(git rev-parse HEAD)" ""   # exit 128 "cannot lock ref …: reference already exists"
git update-ref -d refs/agent-lock/integrate                           # release
```
8 concurrent acquirers → exactly **1** winner (verified). Mismatch form for optimistic checks: `git update-ref <ref> <new> <expected-old>` → exit 128 `cannot lock ref 'refs/agent-lock/x': is at 5b03c01… but expected 5247322…`. `flock` (util-linux 2.41) is present at `/usr/bin/flock` as an alternative.

**Stash is repo-global, not per-worktree** (verified): `git rev-parse --git-path refs/stash` → `…/repo/.git/refs/stash` (common dir). A stash pushed in `wt-a` was listed by `git stash list` in `wt-b`. Two agents stashing concurrently can pop each other's work. Agents must never `git stash`.

---

## C. INTEGRATION

**Dry-run first — `git merge-tree` needs no working tree and no index** (verified; `git status --porcelain` was empty after both runs):

```bash
git merge-tree --write-tree --name-only main feat/a      # exit 0, prints tree oid only
git merge-tree --write-tree --messages  main feat/b      # exit 1
```
Conflicting output:
```
f03be97…                                    # merged tree oid (still written)
100644 91adb53… 2	addadd.txt              # stage 2/3 blobs per conflicted path
…
CONFLICT (add/add): Merge conflict in addadd.txt
CONFLICT (content): Merge conflict in shared.txt
CONFLICT (modify/delete): tobedeleted.txt deleted in feat/b and modified in main.
```
Caveat (verified): `git merge-tree --write-tree main no/such/branch` **also** exits 1 (`merge-tree: no/such/branch - not something we can merge`). Exit 1 alone does not mean "conflict" — require that stdout line 1 is a 40-hex tree oid.

**Landing without checking out main is not possible safely** (verified): `git push . HEAD:main` is rejected by `receive.denyCurrentBranch`, and `git update-ref` desyncs the main worktree (§B). The merge must run **in the main worktree**.

**Comparison of the four options:**

| approach | result |
|---|---|
| `git rebase main` in the branch worktree | verified working, clean linear result, `git merge-base --is-ancestor main HEAD` → exit 0 afterwards. Conflicts surface once per replayed commit. |
| `git merge main` in the branch worktree | verified working. Conflicts surface **once** total, not per commit. But it inverts the sides (below) and puts a merge commit inside the feature branch. |
| `git rebase --update-refs` | verified working for stacks — **but silently skips refs checked out elsewhere, exit 0** (§B). Do not use in a multi-worktree repo. |
| `git merge --no-ff <branch>` into main | verified working, and it **succeeds even when the branch is stale/diverged** (`no_ff_diverged_exit=0`, produced a real merge commit). It is therefore not a staleness detector. |

**Recommended sequence for an autonomous agent** (verified end-to-end, including a deliberate mid-run human commit to main):

```bash
MAIN=$(git worktree list --porcelain | awk 'NR==1{print $2}')
LOCK=refs/agent-lock/integrate

# 1. serialize against other agents
git update-ref "$LOCK" "$(git rev-parse HEAD)" "" || exit 1        # 128 = another agent holds it

# 2. pin main to an immutable sha; never pass the moving ref name to rebase
BEFORE=$(git -C "$MAIN" rev-parse refs/heads/main)

# 3. dry run — touches nothing
git -C "$MAIN" merge-tree --write-tree --messages "$BEFORE" "$BR"  # exit 1 => conflicts, go to D

# 4. resync the branch in ITS OWN worktree, onto the pinned sha
git -C "$WT" rebase --onto "$BEFORE" "$(git merge-base "$BEFORE" "$BR")" "$BR"

# 5. land from the main worktree; --ff-only is the race detector
git -C "$MAIN" merge --ff-only "$BR"        # or: --no-ff after asserting rev-parse main == $BEFORE
git update-ref -d "$LOCK"
```

Verified race behaviour: after a human committed to main between steps 2 and 5, `git merge --ff-only feat/c` failed **cleanly** — exit 128, `fatal: Not possible to fast-forward, aborting.`, working tree and refs untouched. Re-running step 4 against the new sha then made `--ff-only` succeed (exit 0). This is why `--ff-only` beats `--no-ff` for an agent: `--no-ff` would have silently produced a merge of an unverified combination.

Use `--no-ff` only if you want the branch grouped in history, and only after asserting `[ "$(git -C "$MAIN" rev-parse refs/heads/main)" = "$BEFORE" ]`.

**Mid-operation detection on a later run** (verified, worktree-correct):

```bash
GD=$(git rev-parse --path-format=absolute --git-dir)
[ -d "$GD/rebase-merge" ] || [ -d "$GD/rebase-apply" ]   # rebase in progress
[ -f "$GD/MERGE_HEAD" ]                                  # merge in progress
git rev-parse -q --verify REBASE_HEAD                    # exit 0 = mid-rebase
git rev-parse -q --verify MERGE_HEAD                     # exit 0 = mid-merge
```
During the rebase conflict, `git status --porcelain=v2 --branch` reported `# branch.head (detached)` — **the branch name is unavailable mid-rebase**; read `"$GD/rebase-merge/head-name"` instead (verified: `refs/heads/feat/b`). Mid-merge, `$GD` contained `AUTO_MERGE MERGE_HEAD MERGE_MODE MERGE_MSG MERGE_RR` (verified).

Abort must run in the owning worktree: from `probeB/repo`, `git rebase --abort` → exit 128 `fatal: no rebase in progress`; `git -C .../wt-b rebase --abort` → exit 0 (verified).

---

## D. CONFLICTS

**Enumerate** (verified):

```bash
git diff --name-only --diff-filter=U      # addadd.txt shared.txt tobedeleted.txt
git ls-files -u                           # stage 1/2/3 blob lines
git status --porcelain=v2 | grep '^u '
```

**Classify** — the porcelain v1 two-letter code is the cleanest signal (verified during a rebase of `feat/b` onto main):

```
AA addadd.txt        both added        (add/add)
UU shared.txt        both modified     (content)
UD tobedeleted.txt   deleted by them
```
`DU`/`UD`/`AU`/`UA`/`DD` are the remaining classes. `git merge-tree --messages` names the class in words (`CONFLICT (add/add)`, `CONFLICT (content)`, `CONFLICT (modify/delete)`) — verified.

**Sides flip between rebase and merge — this is the single easiest bug to write** (verified on the identical pair of commits):

| | stage 2 / `--ours` / `HEAD` | stage 3 / `--theirs` |
|---|---|---|
| `git rebase main` in `wt-b` | `MAIN-EDIT` (main) | `B-EDIT` (your branch) |
| `git merge main` in `wt-b` | `B-EDIT` (your branch) | `MAIN-EDIT` (main) |

The same file produced `UD tobedeleted.txt` under rebase and `DU tobedeleted.txt` under merge. Never hardcode "ours = my work".

**Inspect the three sides** (verified):

```bash
git show :1:shared.txt   # base   -> line1/line2/line3
git show :2:shared.txt   # ours
git show :3:shared.txt   # theirs
git show REBASE_HEAD:shared.txt        # the commit being replayed (rebase only)
git checkout -m --conflict=zdiff3 -- shared.txt   # rewrite markers with base section
```

**Complete / abort** (verified):

```bash
git checkout --ours -- <path> && git add <path>     # exit 0
git checkout --theirs -- <path> && git add <path>   # exit 0
git rm <path>          # resolve modify/delete by taking the deletion
git add <path>         # resolve modify/delete by keeping the file
git commit --no-edit   # finishes a merge      (exit 0)
git rebase --continue  # finishes a rebase step
git rebase --abort     # exit 0, HEAD back to 8dd6188, no residue in $GD
git merge  --abort
```
After the abort, `git reflog show feat/b` still had `8dd6188 feat/b@{0}: commit: feat: b1` — the reflog is the undo ledger.

**`rerere.enabled = true` is set in the user's global gitconfig** (verified: `git config --show-origin --get rerere.enabled` → `file:/home/nico/.gitconfig true`). This makes autonomous conflict handling **unsafe by default**. Verified demonstration: after one manual resolution was recorded, resetting and re-running the identical merge produced

```
Resolved 'addadd.txt' using previous resolution.
Resolved 'shared.txt' using previous resolution.
Automatic merge failed; fix conflicts and then commit the result.       exit 1
```
`shared.txt` on disk was `line1 / B-EDIT / line3` — fully resolved, **no conflict markers** — while `git status` still said `UU shared.txt`. An agent that decides "no markers ⇒ nothing to do" would `git add` a resolution no one reviewed this run. Running the same merge with `git -c rerere.enabled=false merge` restored real markers (verified). **Every integration command an agent runs must carry `-c rerere.enabled=false`**, or it must diff the working file against stages 2 and 3 before trusting it.

**Opinion — what an agent may auto-resolve:**

- **Auto-resolve, no human:** *nothing by content*. The only safe class is "no conflict at all", proven by `git merge-tree --write-tree` exit 0 with a tree oid on stdout.
- **Auto-resolve with a mechanical rule, allowed:** files where the repo has a declared merge driver (`.gitattributes merge=…`) — that is an explicit human decision already recorded. Also lockfiles/generated artifacts *only if* the resolution is "regenerate from source and verify", never "pick a side".
- **Stop for a human, always:** `UU`/content conflicts (both sides edited the same region — picking a side silently discards intent, exactly what `checkout --ours` did to `MAIN-EDIT` in my run), `AA`/add-add (two independent files claiming one path — no correct automatic answer), and every `UD`/`DU`/modify-delete (one side deleted what the other side changed; the delete may be a rename the other agent didn't know about). `DD` both-deleted is the one genuinely trivial case (`git rm` and move on) and is not worth a special path.

For this handbook specifically: prose files hit `UU` on nearly every real conflict, and prose has no mechanical merge. The honest agent rule is **any conflict ⇒ abort, report the paths and classes, hand back to the human**.

---

## E. FAILURE / CRASH RECOVERY

Scan every worktree from anywhere (verified — it correctly found `wt-b state: rebase dirty:3` while the others were clean):

```bash
git worktree list --porcelain | awk '/^worktree /{print $2}' | while read -r w; do
  [ -d "$w" ] || { echo "$w MISSING"; continue; }
  gd=$(git -C "$w" rev-parse --path-format=absolute --git-dir) || continue
  s=""
  [ -d "$gd/rebase-merge" ]     && s="$s rebase"
  [ -d "$gd/rebase-apply" ]     && s="$s rebase-apply"
  [ -f "$gd/MERGE_HEAD" ]       && s="$s merge"
  [ -f "$gd/CHERRY_PICK_HEAD" ] && s="$s cherry-pick"
  [ -f "$gd/REVERT_HEAD" ]      && s="$s revert"
  [ -f "$gd/BISECT_LOG" ]       && s="$s bisect"
  [ -f "$gd/index.lock" ]       && s="$s INDEX_LOCK"
  printf '%s\tstate:%s\tdirty:%s\n' "$w" "${s:-clean}" "$(git -C "$w" status --porcelain | wc -l)"
done
```

**Recover a crashed rebase's intent** before deciding — the state dir holds everything (verified contents of `…/worktrees/wt-b/rebase-merge/`):

```bash
cat "$GD/rebase-merge/head-name"   # refs/heads/feat/b   <- the branch, unavailable from HEAD
cat "$GD/rebase-merge/onto"        # dc4f27a…            <- the target it was pinned to
cat "$GD/rebase-merge/orig-head"   # 8dd6188…            <- pre-rebase branch tip, the undo point
cat "$GD/rebase-merge/msgnum" "$GD/rebase-merge/end"   # 1 of 1
```

**Stale / moved worktrees** (verified):

```bash
git worktree list                       # "…/wt-mid  a430c5b [st/mid] prunable"
git worktree list --porcelain           # "prunable gitdir file points to non-existent location"
git worktree prune --dry-run --verbose  # "Removing worktrees/wt-mid: gitdir file points to non-existent location"
git worktree prune --verbose            # exit 0
git worktree repair /new/path           # "repair: gitdir incorrect: …" exit 0; list now shows the new path
```
`repair` is the right call when the directory *moved*; `prune` when it's gone. Pruning does **not** delete the branch — `st/mid` survived at `a430c5b` (verified).

**Orphan branches left by pruned worktrees** (verified):

```bash
git branch --no-merged main --format='%(refname:short)'   # feat/b st/mid st/top stack/top
git for-each-ref refs/heads --format='%(refname:short) %(committerdate:relative)'
```

**Stale ref / object damage** — the only reliable detector:

```bash
git fsck --no-progress            # "error: refs/heads/feat/beta: invalid sha1 pointer 934d668…"
git fsck --no-progress --unreachable
git fsck --lost-found             # writes recoverable blobs/commits to .git/lost-found
```

**Stale locks**: `index.lock` carries no pid and `fuser` reports nothing (verified) — age is the only signal, and it is a guess, not proof. (inference) An agent should report a lock and stop, never remove one.

---

## F. HAZARDS — never run these

Never, unconditionally:

```bash
git push origin main            # never push main/master
git push --force / -f / --force-with-lease
git commit --no-verify / git push --no-verify
git gc --prune=now              # VERIFIED to corrupt the repo when any other worktree commits (§B)
git reflog expire --expire=now --all     # destroys the only undo ledger for §D/§E
git update-ref refs/heads/<branch> …     # VERIFIED to desync a checked-out worktree, exit 0, no warning
git rebase --update-refs                 # VERIFIED to silently skip refs checked out elsewhere, exit 0
git stash                                # VERIFIED repo-global; two agents pop each other's work
```

Silent destroyers, verified in `probeB/wt-a` (`M afile.txt`, `?? junk.txt`, `?? newdir/`):

```bash
git checkout -- .        # exit 0, silent. The tracked edit was never an object -> UNRECOVERABLE.
git restore .            # same
git clean -fd            # "Removing junk.txt / Removing newdir/" -> UNRECOVERABLE
git reset --hard         # discards index + worktree; only committed states survive via reflog
git branch -D <br>       # exit 0 "Deleted branch st/mid (was a430c5b)".
                         #   .git/logs/refs/heads/st/mid was ALSO deleted -> `git reflog show st/mid`
                         #   fails; recovery only via `git fsck --unreachable`, and only before gc.
git worktree remove --force <path>   # exit 0. Removed a worktree holding STAGED uncommitted work.
                                     #   The plain form correctly refused first:
                                     #   "fatal: … contains modified or untracked files, use --force"
```

Two more that are not destructive but are wrong-answer generators:

- `git merge --no-ff <branch>` as a landing step without first asserting `rev-parse main == $BEFORE` — verified to succeed (exit 0) on a diverged, unverified branch.
- Any merge/rebase without `-c rerere.enabled=false` — verified to hand back a pre-resolved working tree that still reports `UU`.

Safe substitutions the agent should use instead: `git worktree remove` (no `--force`), `git branch -d` (no `-D`, exit 1 + `error: the branch 'st/mid' is not fully merged` when unmerged — verified), `git gc` (no `--prune=now`), `git merge --ff-only`, and `git update-ref -d refs/agent-lock/…` only for locks it created.

---

## Failure modes & recovery levers

_usage limits, API incidents, durable state, resume semantics, scheduling_

# Findings: failure modes and recovery levers for long autonomous Claude Code runs

As-of date for all doc claims: **2026-08-01**. Local Claude Code version verified: **2.1.212** (`claude --version`). Several documented behaviours below carry min-versions above 2.1.212 and are therefore **not available in this environment** — flagged inline.

---

## 1. USAGE LIMITS

**Limit types** (FACT — https://code.claude.com/docs/en/errors.md, https://code.claude.com/docs/en/costs.md):

| Limit | Scope | Error string (verbatim) |
| --- | --- | --- |
| Session (rolling 5-hour) | shared across all models | `You've hit your session limit · resets 3:45pm` |
| Weekly (7-day) | shared across all models | `You've hit your weekly limit · resets Mon 12:00am` |
| Opus-specific | Opus requests only | `You've hit your Opus limit · resets 3:45pm` |
| Overage | usage credits, `/usage-credits` | not an error; keeps you working past the window |

- Session and weekly limits are **shared across all models — switching models does not restore access**. Only the Opus limit is escaped by `/model`.
- Usage counts against both windows simultaneously; a single burst can exhaust the weekly allowance before the 5-hour window resets.
- Team/Enterprise: per-seat allowance on a rolling 5-hour + weekly window, shared with Claude chat and Cowork.

**User-visible failure mid-run**: the run stops. For subagents specifically (FACT — errors.md, min-version 2.1.199, available here):
```
Agent terminated early due to an API error: <error detail>
```
The doc instructs matching `<error detail>` to the Usage-limits section, so the reset time is carried in the detail string (INFERENCE from the doc's instruction, not an explicit statement).

**Does a background task/workflow survive?** Mixed, and the docs conflict:
- FACT (https://code.claude.com/docs/en/workflows.md): "Resume works within the same Claude Code session. If you exit Claude Code while a workflow is running, the next session starts the workflow fresh."
- FACT (https://code.claude.com/docs/en/agent-view.md): when a *background session's* process stops/restarts, "Dynamic workflows (resume from where they left off)" carry over. Background sessions are run by a per-user supervisor daemon and survive terminal close and machine sleep; they show as failed after machine shutdown and "restart from saved state when you open agent view again".
- FACT (tool schema, given): a dead agent returns `null` from `agent()`; it does **not** throw. So a usage limit does not kill the workflow — it silently poisons individual results with `null`. A script without `.filter(Boolean)` propagates nulls into later stages.
- FACT (workflows.md): a `parallel`/`pipeline` stage that throws drops that item; `parallel()` never rejects. Combined with the above, a workflow can run to "completion" with most of its work missing.

**Documented programmatic wait-for-reset**: NO documented sleep-until-reset mechanism.
**Documented reset-time signal**: YES, one (FACT — https://code.claude.com/docs/en/statusline.md):
- `rate_limits.five_hour.used_percentage`, `rate_limits.seven_day.used_percentage` (0–100)
- `rate_limits.five_hour.resets_at`, `rate_limits.seven_day.resets_at` — **Unix epoch seconds**
- Present only for claude.ai subscribers (Pro/Max), only after the first API response in the session; each window can be independently absent. Delivered as JSON on stdin to the status-line command — i.e. readable by a shell script, **not** by the agent directly.
- `/usage` (interactive) and `/usage-credits` are the human-facing equivalents.

The user's config has `statusLine` set, so this signal is already reachable in this environment.

---

## 2. API INCIDENTS

**Error classes** (FACT — https://platform.claude.com/docs/en/api/errors):

| Status | Type | Retriable |
| --- | --- | --- |
| 400 | `invalid_request_error` | No |
| 401 / 402 / 403 / 404 / 409 / 413 | auth / billing / permission / not-found / conflict / too-large | No (409 after resolving conflict) |
| 429 | `rate_limit_error` | Yes |
| 500 | `api_error` | Yes — "Retry the request with exponential backoff" |
| 504 | `timeout_error` | Yes |
| 529 | `overloaded_error` | Yes |

**What the harness already does for you** (FACT — https://code.claude.com/docs/en/errors.md):
- Claude Code retries transient failures **up to 10 times with exponential backoff**: server errors, overloaded responses, request timeouts, dropped connections, and (as of v2.1.199) temporary 429 throttles for claude.ai subscriptions.
- `CLAUDE_CODE_MAX_RETRIES` default 10 (capped at 15 as of 2.1.186; as of 2.1.199 `CLAUDE_CODE_RETRY_WATCHDOG` removes the cap).
- `CLAUDE_CODE_RETRY_WATCHDOG=1` — "Set to `1` in unattended sessions (CI jobs) to retry 429 and 529 **capacity** errors indefinitely. As of v2.1.199 also raises default for other transient errors to 300 (~3 hours backoff)." Available on 2.1.212.
- `API_TIMEOUT_MS` default 600000 (10 min).
- Default request timeout 10 minutes; a stall triggers `Waiting for API response · will retry in … · check your network` after 20 s of no stream data.
- The Anthropic SDKs separately retry transient failures with exponential backoff, **twice by default**, honoring `retry-after`.

**What the harness does NOT retry** (FACT — errors.md):
- TLS certificate validation failures.
- **Any failure mid-response**, after Claude has completed a text block or tool call ("could run same tool calls twice"). It keeps the completed output and appends `API Error: Server error mid-response. The response above may be incomplete.` Recovery is a human/agent replying `continue`.
- Bedrock streaming with unexpected content-type (2.1.208+).

**Plan usage limits vs capacity 429s**: errors.md explicitly separates `API Error: Server is temporarily limiting requests (not your usage limit)` (auto-retried as of 2.1.199) from `You've hit your session limit`. **NOT VERIFIED** that `CLAUDE_CODE_RETRY_WATCHDOG` waits out a plan usage-limit window — the doc scopes it to "429 and 529 capacity errors". Do not write a skill that assumes it does.

**Verdict for a skill**: retry/backoff is the harness's job, not the skill's. The only thing left for a skill is what to do **after retries are exhausted** — which is exactly what `StopFailure` marks (see §3).

---

## 3. DURABLE STATE — what survives a crash, kill, or compaction

| Mechanism | Survives | Does NOT survive / carry |
| --- | --- | --- |
| **Git commits** | Everything. Independent of Claude Code entirely. | Uncommitted working tree in a deleted background worktree (worktrees with unpushed commits are kept; `claude rm <id>` keeps a worktree with uncommitted changes). |
| **Files on disk** | Everything, incl. a plan file's `- [x]` marks. Only durable channel readable by both a fresh session and a human. | Nothing — but nothing tells a new session *where* to look unless the file path is conventional. |
| **Workflow journal** (`<transcriptDir>/journal.jsonl`) | Verified on disk at `~/.claude/projects/<project>/<session-id>/subagents/workflows/wf_<id>/journal.jsonl`. Records `{type:"started"\|"result", key:"v2:<hex>", agentId, result}` — one `started` and one `result` per completed `agent()` call, with the **full return value inlined**. Per-agent full transcripts sit alongside as `agent-<id>.jsonl`. | Agents that were still running are never written (`result` absent). |
| **Workflow run state** | Verified: `~/.claude/projects/<project>/<session-id>/workflows/wf_<id>.json` with keys `runId, timestamp, taskId, script, scriptPath, result, agentCount, logs, durationMs, summary, workflowName, status, startTime, phases, defaultModel, workflowProgress, totalTokens, totalToolCalls`. The **whole script text is embedded**, and also written to `workflows/scripts/<name>-<runId>.js`. | — |
| **`resumeFromRunId`** | See §4. | Docs say resume is same-session only; local evidence disagrees (see §4). |
| **Session resume** (`claude --resume` / `--continue` / `--resume <id>`) | Conversation history incl. tool calls and results; model; `--agent`; permission mode; active `/goal`; unexpired scheduled tasks. Transcripts at `~/.claude/projects/<project>/<session-id>.jsonl`, 30-day retention (`cleanupPeriodDays`). | `plan` and `bypassPermissions` modes; `--mcp-config`, `--settings`, `--plugin-dir`, `--fallback-model`, `--add-dir`; **background Bash and monitor tasks are never restored**. |
| **Background sessions** (supervisor daemon) | Survive closing agent view, closing the terminal, machine sleep, supervisor restarts and auto-updates. State in `~/.claude/jobs/<id>/state.json`, roster in `~/Claude/daemon/roster.json`. Carried over on process restart: background shell commands, **dynamic workflows**, background subagents, `/loop` tasks. | Machine shutdown → shown as failed (restart from saved state on reattach). Not carried: shell commands a subagent started, running monitors, work inside the process. Idle unattached sessions stop after ~1 h. |
| **Checkpoints / `/rewind`** | Saved with the conversation, survive resume; 100 most recent per session; deleted with sessions after 30 days. | **Bash-made file changes are not tracked. Subagent edits are not restored** (explicitly incl. background forked skills) — "Use git to revert those edits." External/concurrent-session edits not captured. Symlinked and hard-linked paths not restored. |
| **Task list** (`TaskCreate` / `TaskGet` / `TaskList` / `TaskUpdate`) | Lives in the session; restored with the session transcript on `--resume` (INFERENCE — the tools-reference calls it "the task list"; no explicit persistence statement). | **NOT VERIFIED** that task state is readable by a *different* session or by a human without the session. Do not treat it as a handoff artifact. |
| **Scheduled tasks** (`CronCreate`/`CronList`/`CronDelete`) | Session-scoped; restored on `--resume`/`--continue` if unexpired. Stored in the project's `.claude` directory. | Cleared by a fresh conversation. 7-day expiry. Never fire while Claude Code isn't running. |
| **Notifications** | `Notification` hook types `agent_needs_input`, `agent_completed`; terminal notification channel. | Not state — a signal only, and only to a human at a terminal. |
| **`StopFailure` hook** | Fires **after retries are exhausted**, when a turn ends on an API error. Input: `session_id, prompt_id, transcript_path, cwd, hook_event_name, error_type, error_message`. Matcher on `error_type` ∈ `rate_limit, overloaded, authentication_failed, oauth_org_not_allowed, billing_error, invalid_request, model_not_found, server_error, max_output_tokens, unknown`. | **Cannot block** — output and exit code are ignored. Useful only for logging/side effects. This is the single documented programmatic hook for "the run just died on a limit or incident". |

The user already has `hooks` configured in settings — `StopFailure` is an available lever, but it belongs in settings.json (the `/update-config` skill), **not** in a skill's prose.

---

## 4. RESUME SEMANTICS

**Documented rule** (FACT — workflows.md, "Resume after a pause"):
> "An agent that was still running when you stopped isn't saved, so it starts over on resume. Replay follows the order agents started. Cached results stop at the first agent that didn't finish, and every agent that started after that one runs again, even if it completed."

Worked example from the doc: agents A, B, C, D start in that order; stop while B runs. On resume A is cached; **B, C and D all re-run**, even though C and D completed.

Consequence stated by the doc: "A workflow that fans work out across many small agents therefore preserves more progress than one long agent."

**Cache key is content-derived, not positional** (FACT — verified locally across 1488 journal keys in `~/.claude/projects/*/subagents/workflows/*/journal.jsonl`): keys have the form `v2:<64-hex>`, and 5 keys are shared between two *different* run ids (`wf_14d67c73-77c` and `wf_1e0c8df6-132`) in the same session — i.e. identical `agent()` calls in different runs hash to the same key. The key is **not** a plain SHA-256 of the prompt text alone (tested and refuted), so it also covers opts.

**Practical consequence for a script whose prompts embed changing data**: an `agent()` prompt that interpolates the current contents or state of a plan file changes its hash the moment the plan file is edited. Every re-run therefore misses the cache for that call **and every call after it**. Concretely: a script that reads `plan.md` and embeds phase text into prompts will re-run the entire tail of the workflow after the first phase ticks a box. To keep resume cheap, embed **stable identifiers** (phase number, file path, acceptance-criterion id) and make the agent read the mutable file itself.

**Contradiction to flag**: workflows.md says "If you exit Claude Code while a workflow is running, the next session starts the workflow fresh." But locally, 4 workflow run ids appear under **two different session directories** each, and `diff -rq` shows the two `wf_f4e960c4-271` journal directories are byte-identical. INFERENCE: the journal is copied/carried when a session is forked, branched or resumed under a new session id, and agent-view.md's "Dynamic workflows (resume from where they left off)" covers the background-session case. Do not write a skill that promises cross-session workflow resume; the docs do not.

**Also relevant**: `Date.now()`, `Math.random()` and argless `new Date()` throw inside a workflow script, and the script has no filesystem or shell access. A workflow script therefore **cannot** implement a wall-clock wait-until-reset loop. Whether a plain `setTimeout`/sleep is usable is **NOT VERIFIED** (not in the documented hook set).

---

## 5. SCHEDULING LEVERS

| Lever | Runs on | Needs open session | Needs machine on | Local files | Min interval | Can a skill trigger it? |
| --- | --- | --- | --- | --- | --- | --- |
| **`/loop` + `CronCreate`** | your machine | **Yes** | Yes | Yes | 1 min | **Yes.** A skill's instructions can tell Claude to call `CronCreate` — the docs' own guidance is "ask Claude in natural language"; `CronCreate` requires no permission. |
| **`ScheduleWakeup`** | your machine | Yes | Yes | Yes | 1 min–1 h | **No, not directly.** Docs: "Claude calls this at the end of each iteration… you don't call it directly." It only reschedules the next iteration of a *self-paced* `/loop`. `stop: true` ends the loop. Not available on Bedrock / Google Cloud Agent Platform / Microsoft Foundry. |
| **Routines** (cloud) | Anthropic cloud | No | **No** | **No** (fresh clone of a GitHub repo) | **1 hour** | Partly. `/schedule` is a slash command; a skill can instruct the agent to run it, but it requires a claude.ai subscription login (fails on Console API key or cloud providers), and CLI creation is **scheduled routines only** — API/GitHub triggers are web-only. Runs autonomously with no permission prompts. Research preview. |
| **Desktop scheduled tasks** | your machine | No | Yes | Yes | 1 min | NOT VERIFIED that a skill can create one; the docs describe UI creation only. |

Key constraints that kill the "pause and retry later" idea for in-session scheduling (FACT — scheduled-tasks.md):
- "Tasks only fire while Claude Code is running **and idle**. Closing the terminal or letting the session exit stops them firing."
- "**No catch-up for missed fires.** If a task's scheduled time passes while Claude is busy on a long-running request, it fires once when Claude becomes idle."
- Recurring tasks expire after 7 days; jitter adds up to 30 min to recurring fires.
- Backgrounding the session (agent view) carries `/loop` tasks over to a background session, which keeps running without a terminal — **this is the only in-session path to unattended retry**, and it needs the machine on.
- A scheduled fire runs only skills Claude is allowed to invoke on its own; `disable-model-invocation: true` skills reach Claude as plain text (2.1.196+).

Routines' own limit handling (FACT — routines.md): "When a routine hits the daily cap or your subscription usage limit, organizations with usage credits turned on can keep running routines on metered overage. **Without usage credits, additional runs are rejected until the window resets.**" No retry, no backoff.

---

## 6. HONEST VERDICT — 5 bullets

- **Achievable: checkpoint density, not self-repair.** Every genuine recovery lever is a durable artifact — a git commit, a `- [x]` tick in the plan file, a small `agent()` call whose journal `result` is cached. A skill can raise recovery odds only by instructing the agent to commit and tick **after each acceptance criterion**, not once per phase. This is also what makes workflow resume cheap, since replay stops at the first unfinished agent.
- **Achievable: correct diagnosis and a clean stop.** The skill can name the exact failure strings (`You've hit your session limit · resets …`, `Agent terminated early due to an API error: …`, `529 Overloaded`, `Server error mid-response`), tell the agent to distinguish a plan usage limit (wait for the printed reset time; `/model` only helps for the Opus limit) from a capacity incident (check https://status.claude.com — verified live JSON at `/api/v2/status.json` and `/api/v2/summary.json`, plus `history.rss`/`history.atom`), and stop with a written handoff instead of thrashing.
- **Achievable: null-safety in any workflow the skill launches.** `agent()` returns `null` on terminal API error or user skip, `parallel()` never rejects, a throwing pipeline stage silently drops its item. A skill that tells the agent to `.filter(Boolean)` and to report the dropped count is preventing a real, documented silent-data-loss failure. Same for setting `model` explicitly in **every** `agent()` opts — verified locally that omission inherits the session model (a real run's persisted `defaultModel` was a session-inherited value, not a per-stage choice).
- **Wishful thinking: retrying limits and incidents from skill prose.** Retry and exponential backoff already belong to the harness (10 attempts by default, `CLAUDE_CODE_RETRY_WATCHDOG=1` for unattended runs). By the time the agent can observe a failure, retries are already exhausted — that is literally when `StopFailure` fires, and `StopFailure` cannot block. Mid-response failures are deliberately never retried. Any instruction telling the agent to "retry the request" duplicates the harness or asks for the one thing it refuses to do.
- **Wishful thinking: pausing until the limit resets.** There is no documented sleep-until-reset. The reset timestamp exists (`rate_limits.*.resets_at`, epoch seconds) but only in the status-line JSON — a shell script's input, not something the agent can read mid-turn. `/loop` and `CronCreate` fire only while the session is running *and idle*, with no catch-up for missed fires; workflow scripts cannot call `Date.now()` at all. Replace this requirement with: **write the resume handle** (branch name, plan file path, next unmet criterion, workflow `scriptPath` + `runId`) so a human or a `claude --resume` costs one prompt instead of a re-derivation.

---

## Files read locally

- `/home/nico/handbook/.claude/skills/implement-plan/SKILL.md` (current skill, 1612 bytes — links `../quality.md`)
- `/home/nico/handbook/.claude/skills/distill/parallelism.md` — **already holds** the repo's model-routing table, worker-contract, workflow-mode and worktree guidance. Under the single-source-of-truth rule the rewritten `implement-plan/SKILL.md` must **link** to `../distill/parallelism.md` and `../dispatching-parallel-agents/SKILL.md` rather than restate any of it.
- `/home/nico/handbook/.claude/skills/quality.md` (756 bytes, shared self-review contract — already linked)
- `/home/nico/handbook/.claude/rules/skills.md` — governs frontmatter fields, the required Workflow/Constraints/Quality sections, and the `.claude/skills/README.md` index update.

## Sources

- https://code.claude.com/docs/en/errors.md
- https://code.claude.com/docs/en/costs.md
- https://code.claude.com/docs/en/workflows.md
- https://code.claude.com/docs/en/scheduled-tasks.md
- https://code.claude.com/docs/en/routines.md
- https://code.claude.com/docs/en/sessions.md
- https://code.claude.com/docs/en/agent-view.md
- https://code.claude.com/docs/en/checkpointing.md
- https://code.claude.com/docs/en/tools-reference.md
- https://code.claude.com/docs/en/statusline.md
- https://code.claude.com/docs/en/hooks.md
- https://code.claude.com/docs/en/headless.md
- https://platform.claude.com/docs/en/api/errors
- https://status.claude.com/ and https://status.claude.com/api/v2/status.json

---

## Duplication / overlap / contradictions

_what already exists in the repo, gaps, stale refs, rule conflicts_

## 1. OVERLAP TABLE

| Topic | file:line | What it says | Relative link from `.claude/skills/implement-plan/` |
|---|---|---|---|
| Parallel subagent dispatch contract (scope, self-contained context, file ownership, return format, collision check) | `.claude/skills/dispatching-parallel-agents/SKILL.md:22-56` | Full workflow for splitting independent work across parallel agents, incl. constraints on isolation and resuming vs. redispatching | `../dispatching-parallel-agents/SKILL.md` |
| Model routing for subagents (sonnet vs opus) | `claude/CLAUDE.md:88-92` | Sonnet for mechanical/well-specified work, Opus for judgment/implementation/verification; Fable banned; exact mechanics for `Agent` tool and Workflow `agent()` calls | `../../claude/CLAUDE.md` (or wherever this ships — verify it's the repo's distributed file, not `~/.claude/CLAUDE.md`) |
| Model routing worked example (execution-mode tiers, per-stage model choice) | `.claude/skills/distill/parallelism.md:18-41` | Inline vs parallel-agents vs Workflow tiers by file count; which stage gets sonnet vs opus | `../distill/parallelism.md#execution-modes`, `#model-routing` |
| Creating/reusing a git worktree | `.claude/skills/using-git-worktrees/SKILL.md:17-73` | Full workflow: detect existing isolation, guard against submodules, confirm before creating, `.worktrees/` convention, clean-baseline check, removal | `../using-git-worktrees/SKILL.md` |
| Worktree isolation as an option for parallel agents | `.claude/skills/dispatching-parallel-agents/SKILL.md:52-54` | "Isolate writes... give each a disjoint file-ownership partition, or run them in separate worktrees (`isolation: worktree`)" | `../dispatching-parallel-agents/SKILL.md` |
| When worktree isolation is the *wrong* tool (disjoint-file case) | `.claude/skills/distill/parallelism.md:120-122` | Worktree isolation not needed when actions are already disjoint by file | `../distill/parallelism.md#apply-stage-partitioning` |
| Branch integration decision (merge/PR/keep/discard) | `.claude/skills/finish-branch/SKILL.md:9-133` (whole file) | Full workflow: run tests first, detect base branch, detect worktree, present exactly four options, execute chosen one, never force-push/delete without confirmation | `../finish-branch/SKILL.md` |
| Removing a worktree once branch is settled | `.claude/skills/using-git-worktrees/SKILL.md:67-73` | Defers the merge/PR/keep/discard decision to finish-branch, then shows `git worktree remove` | `../using-git-worktrees/SKILL.md` |
| Verification/quality gate shared by all producing skills | `.claude/skills/quality.md:1-16` | Scope guard + "verify before claiming done" — audit each claim against a fresh tool result this session; name exact test/build/lint command | `../quality.md` |
| Verify-then-fix / lane / evidence-rule machinery for fact-checking after a big autonomous pass | `.claude/skills/verify-docs/SKILL.md` (whole file) | Independent-session verification pattern, evidence rule, triage table, tripwire on over-correction | `../verify-docs/SKILL.md` (topic-adjacent, not directly reusable, but shows repo's established pattern for gating an autonomous multi-file pass before commit) |
| Plan-phase execution loop (read plan → phase → context → implement → checkbox → verify → stop) | `.claude/skills/implement-plan/SKILL.md:11-40` | This is the file being rewritten — current one-phase-at-a-time loop, checkbox flip, build/lint/test, explicit stop | n/a (this file itself) |
| Plan file structure / phases / acceptance-criteria checkbox format | `.claude/skills/create-plan/SKILL.md:119-171` (template) | Defines the exact `- [ ]` acceptance-criteria format, phase headings, Context block — this is the canonical plan-file schema | `../create-plan/SKILL.md` |
| Commit-every-completed-task rule, Conventional Commits, no `--force`/`--no-verify` | `AGENTS.md` (Git section, end of file) and `CLAUDE.md:` Non-negotiables | Governs when/how implement-plan (or its rewrite) commits | `../../AGENTS.md`, `../../CLAUDE.md` |
| Skill file format requirements (frontmatter, Workflow/Constraints/Quality sections) | `.claude/rules/skills.md:19-51` | Structural contract every SKILL.md (including the rewrite) must follow | `../../.claude/rules/skills.md` |

## 2. GAPS

Nothing in the repo currently covers:

- **Multi-phase autonomous looping.** Every existing skill (`implement-plan`, `dispatching-parallel-agents`) explicitly stops after one unit of work (one phase, or one dispatch-and-collect round). There is no pattern anywhere for "keep going across N phases without a human turn in between," nor any stated criteria for when such looping should halt (e.g. on a failed phase, on ambiguity, on scope drift across phases).
- **Assigning whole plan phases to separate subagents in parallel.** `dispatching-parallel-agents` covers independent *investigation/fix* targets sharing no state; it never addresses splitting a single plan's phases (which by `create-plan`'s own "tracer bullet" design are meant to be sequential/incremental, not independent) across agents. No file reconciles "phases are sequential slices" with "run several agents at once."
- **Integrating multiple subagents' branches into one.** `finish-branch` handles exactly one branch, and its worktree removal steps assume one worktree; nothing describes reconciling N worktrees/branches from N parallel implementers into a single result (order of merges, conflict resolution across agents' branches, re-running tests after each merge vs. once at the end).
- **Autonomous decision-making that overrides `finish-branch`'s human-choice gate.** No file describes a "pick the integration path yourself" mode — see Contradictions below.
- **Per-phase quality gate composed with cross-phase gate.** `quality.md` and `implement-plan`'s current step 6 verify one change; nothing says whether/how to re-verify after merging several agents' phase branches together (the "integrate and verify as a whole" line in `dispatching-parallel-agents:46-48` is the closest, but it's about independent bug fixes, not plan phases).
- **Plan-file update contention.** If multiple agents work different phases of the same plan file concurrently, nothing says who owns writing the `- [x]` checkboxes back to the single plan file (a shared-file, not disjoint-file, situation — the opposite of the partitioning rule in `distill/parallelism.md:108-115`).

## 3. STALE REFERENCES

`grep -rn "implement-plan"`:
- `.claude/skills/README.md:29` — index row: `"Executing an existing plan step by step | [Implement Plan](implement-plan/)"`. Update the description text if the rewrite changes what the skill does (e.g. no longer strictly "step by step" if it becomes multi-phase/parallel).
- `.claude/skills/implement-plan/SKILL.md:2,6` — the file itself (frontmatter `name` and `description`).

`grep -rn "one phase at a time"`:
- `.claude/skills/implement-plan/SKILL.md:6` (frontmatter description) — "Use when the user wants to execute an existing implementation plan one phase at a time." This line is the literal contradiction target if the rewrite adds multi-phase/parallel execution: it must be reworded, not left stale.
- Body line 11: `"Read the referenced plan and work through **one phase** at a time."` — same.

No other file describes implement-plan's behavior in prose (guides/, docs/, README.md top-level don't mention it by name).

## 4. CONTRADICTIONS

- **`finish-branch/SKILL.md:13-14`**: *"Once work on a branch is done, decide how to integrate it. Verify tests first, then present exactly four options and execute the one chosen."* And **line 45**: *"Present exactly these four options — no open-ended 'what next?'"* And **Constraints, line 82**: *"Never merge, push, or delete anything the user didn't explicitly pick from the four options."* — If the reworked implement-plan is meant to autonomously merge/integrate multiple worktree branches without a human picking one of the four options each time, that directly violates this gate. Any autonomy here needs either (a) implement-plan never touching branch integration and always handing off to finish-branch per branch, or (b) an explicit, separately-stated exception that the user must approve.

- **`using-git-worktrees/SKILL.md:41-43`**: *"In a normal checkout, confirm before creating. Ask whether an isolated worktree is wanted for this work. If the answer is no, work in place and skip to step 4."* — If the rewritten skill auto-creates worktrees per subagent without asking, this conflicts. Needs either an explicit override (stated as such, since AGENTS.md's "ask instead of assuming" is a repo-wide default) or routing every worktree creation through this existing confirm step.

- **AGENTS.md** (Working rules): *"Ask before deleting or renaming a file (check for references first)."* — Combined with `finish-branch`'s discard option requiring "explicit confirmation" (line 73-74) and worktree removal being part of branch teardown: if the new skill autonomously discards a subagent's losing/superseded worktree or branch as part of integration, it must not silently delete — this rule and finish-branch's confirmation requirement both block silent cleanup.

- **AGENTS.md** (Plan-first workflow, step 2): *"Plan — create `plan.md`... Do not make changes yet."* — Not a direct conflict but a scope boundary: the plan file itself is created by a *different* process (`create-plan` or this manual step); implement-plan (rewritten or not) must not be the thing that authors new plan phases mid-flight — it only executes and checks off existing ones. Worth stating explicitly in the rewrite so orchestrating-many-subagents doesn't drift into re-planning.

- No direct textual contradiction found regarding "ask before starting work" beyond the above — `implement-plan`'s current step 3 ("Raise concerns with the user first; if there are none, proceed") is itself already a narrow human-gate that a fully autonomous multi-agent rewrite would need to either preserve per-phase or explicitly narrow with justification.
