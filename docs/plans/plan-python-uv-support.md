# Plan: Python/uv support and gyva's general patterns

> Source PRD: n/a

## Goal

A Python/uv project follows the handbook end to end: stack row, conventions, templates, CI, Docker, permissions. The CI, Docker, Makefile help and docs patterns gyva proved become handbook defaults for every stack.

## Architectural decisions

- **Worktree location**: `../<repo>-wt/<branch>`, a sibling of the repository. Linters and type checkers that walk `.` never see a lane.
- **Python toolchain**: uv, ruff, ty, pytest. `src/<package>/` layout as `uv init --package` writes it, build backend included. No mypy, no pip, no poetry.
- **CI actions**: every `uses:` pinned to a full commit SHA with the tag in a trailing comment. Dependabot's `github-actions` group bumps both.
- **Makefile help**: target classes are `CLASS_*` lists rendered by `scripts/make-help.awk`. The template ships `developer` and `production`.
- **Scope**: Must and Should tiers of the review. Out: `lint-pins`, `lock-check`, `.NOTPARALLEL`, `make worktree` lanes, the no-counts ratchet, `lint-docrefs`.

## Inventory

- `claude/CLAUDE.md` — Working rules, worktree line — the rule that changes
- `claude/settings.json` — `permissions.allow`, `autoMode.environment` — uv entries and the worktree path
- `.claude/skills/implement-plan/SKILL.md`, `.claude/skills/implement-plan/git.md` — name `.worktrees/`
- `guides/new-project.md` — Inputs, step 2, step 3 matrix, step 5 — the Python row lands here
- `guides/stack-conventions.md` — Go, Java, React sections — the Python section joins them
- `guides/docker-multi-stage-builds.md` — Java and Node examples — the Python example joins them
- `templates/ci.yml` — mutable tags, push on `main` only, no timeout, Go and Node jobs
- `templates/dependabot.yml` — `gomod` and `npm` entries, docker-compose only as a comment
- `templates/.gitignore`, `templates/vscode-settings.json`, `templates/devcontainer.json`, `templates/setup-dev-tools.sh` — no Python
- `templates/Makefile` — `help` target, flat grep — replaced by classes
- `templates/.env.example` — header states the copy-to-`.env` half only
- `README.md` — index rows for every guide, template and script
- `scripts/check-repo.sh` — `make check`, the gate for every phase
- gyva sources: `~/r/gyva/pyproject.toml`, `Dockerfile`, `.dockerignore`, `.github/workflows/ci.yml`, `.github/dependabot.yml`, `Makefile — help`, `scripts/make_help.awk`, `.env.example`

## Resolved decisions

- Worktrees move to the sibling directory; the global rule, the autoMode environment and the implement-plan skill change with it. `.git/info/exclude` is no longer needed.
- The Python row needs its VS Code formatter, devcontainer feature and `setup-dev-tools.sh` block to be functional as copied. Those three Could items ship with the row.
- The Python CI job spells its steps like the Go job does. `make check` stays the project's own gate.
- The Docker guide keeps its name and gains a note that one stage suffices when the base image carries the toolchain.
- `templates/.dockerignore` is a real template, copied by every shape with a Dockerfile.
- `Bash(uv run mypy:*)` leaves the allow-list; no handbook stack uses mypy.
- Nothing gyva-specific crosses over: ontology, vocabulary and manifest lints, ParadeDB tuning, service logins, the evaluation harness.

## Open questions / Risks

- SHA pins must come from `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` at implementation time, never from memory.
- `actionlint` is not installed; the CI template is verified by `gh api` resolution and a YAML parse only.
- The handbook's `make check` enforces the prose caps on every guide; every new sentence stays under twenty words.

## Phase 1: Worktrees live beside the repository

**Depends on**: none

### Context

- `claude/CLAUDE.md` — Working rules — the `.worktrees/<branch>` line
- `claude/settings.json` — `autoMode.environment` — two entries name `.worktrees/`
- `.claude/skills/implement-plan/SKILL.md` — step 6 creates `.worktrees/plan-<slug>`
- `.claude/skills/implement-plan/git.md` — gate rule 6 excludes `.worktrees/` from scans

### What to build

The global rule states `../<repo>-wt/<branch>` via `git worktree add` and the reason in one clause. The autoMode environment trusts `~/r` and every `*-wt` directory beside a repository. The implement-plan skill creates `../<repo>-wt/plan-<slug>` and drops the scan-exclusion clause, which the location makes unnecessary.

### Acceptance criteria

- [x] `grep -rn '\.worktrees' claude .claude guides templates` returns nothing
- [x] `claude/CLAUDE.md` names the sibling path and the linter reason in one bullet
- [x] `claude/settings.json` parses with `jq` and its environment names the sibling path
- [x] `make check` is green

## Phase 2: uv permissions

**Depends on**: 1

### Context

- `claude/settings.json` — `permissions.allow` — `Bash(uv run:*)` and three `uv run` variants exist

### What to build

The allow-list gains `Bash(uv sync:*)`, `Bash(uv lock:*)`, `Bash(uv audit:*)`, `Bash(uv add:*)`, `Bash(uv tool:*)` and `Bash(uv --version)`. `Bash(uv run mypy:*)` is removed. Entries sit with the other `uv` lines.

### Acceptance criteria

- [x] `jq '.permissions.allow[]' claude/settings.json | grep uv` lists the six new entries and no mypy
- [x] `make check` is green

## Phase 3: Python section in the stack conventions

**Depends on**: none

### Context

- `guides/stack-conventions.md` — Go, Java, React — the heading style and rule-plus-rationale form
- `README.md` — Stack conventions row — lists the covered stacks
- `~/r/gyva/pyproject.toml` — `[tool.ruff]`, `[tool.ruff.lint]`, `[tool.pytest.ini_options]`, `[tool.ty.src]` — the source shapes

### What to build

A `## Python` section in the same form as the others. Rules with one line of rationale each: uv with `pyproject.toml` and `uv.lock`; the `src/<package>/` layout `uv init --package` writes; `requires-python` and `.python-version` agree; ruff with `line-length = 100`, `target-version`, and `extend-select` extending the default set; ty for types with `exclude = []`; pytest `testpaths` and registered markers, opt-in markers deselected through `addopts`; `uv sync --frozen` in CI and images; `uv lock --check` as the drift gate; `uv audit` as the last, online step. The README row names Python among the covered stacks.

### Acceptance criteria

- [x] `guides/stack-conventions.md` has a `## Python` heading with every rule above and one rationale line each
- [x] The section names no gyva marker, waiver or module
- [x] `README.md` lists Python in the stack-conventions row
- [x] `make check` is green

## Phase 4: Python entries in the base templates

**Depends on**: none

### Context

- `templates/.gitignore` — Node and Go blocks — the block style
- `templates/vscode-settings.json` — per-language formatter entries
- `templates/devcontainer.json` — commented feature and extension blocks
- `templates/setup-dev-tools.sh` — Go and Node sections and the summary block
- `templates/.env.example` — header comment
- `~/r/gyva/.gitignore`, `~/r/gyva/.vscode/settings.json`, `~/r/gyva/.env.example`, `~/r/gyva/tests/test_env_example.py`

### What to build

`.gitignore` gains a Python block: `.venv/`, `__pycache__/`, `*.py[cod]`, `.pytest_cache/`, `.ruff_cache/`. VS Code settings gain `[python]` with ruff as formatter. The devcontainer gains a commented Python feature block and `charliermarsh.ruff` in the commented extensions. `setup-dev-tools.sh` gains a Python section that ensures `uv` and runs `uv sync`, plus its summary line. `.env.example` states both directions of the invariant: every variable the tree reads stands here, and a documented variable no code reads is a lie a test refuses.

### Acceptance criteria

- [x] Each of the five templates carries its Python or invariant addition in the file's own style
- [x] `shellcheck templates/setup-dev-tools.sh` passes
- [x] `jq . templates/vscode-settings.json` parses
- [x] `make check` is green

## Phase 5: Python row in the new-project guide

**Depends on**: 3, 4

### Context

- `guides/new-project.md` — Inputs table, step 2, step 3 matrix, step 5, Verify
- `~/r/gyva/.python-version` — the pinned interpreter

### What to build

The Inputs table gains `<project-python-version>`. The matrix gains "Python service (uv)": compose plus `.env.example` (`db`), Python plus Docker-in-Docker features, one Dockerfile, the stack guide link to `#python`. Step 3 runs `uv init --package --python <project-python-version>`, which writes `.python-version` and the `src/` layout, then adds the ruff, ty and pytest tables from the conventions. Step 5 tells a new project to create `docs/README.md` as a one-row-per-page table whose column is the question the page answers. Verify gains `uv lock --check` for Python shapes.

### Acceptance criteria

- [x] The matrix row, the input and the `.python-version` step exist and link to `stack-conventions.md#python`
- [x] Step 5 states the `docs/README.md` rule in at most two sentences
- [x] `make check` is green

## Phase 6: Dependabot covers uv and Compose

**Depends on**: none

### Context

- `templates/dependabot.yml` — `gomod`, `npm`, commented `docker`
- `~/r/gyva/.github/dependabot.yml` — `uv` and `docker-compose` entries

### What to build

A `uv` ecosystem entry at `/`, monthly, grouped, in the same shape as `gomod`. An active `docker-compose` entry at `/`, since the `docker` ecosystem parses Dockerfiles only. The `docker` block stays commented with its enabling condition.

### Acceptance criteria

- [x] The template has active `github-actions`, `gomod`, `npm`, `uv` and `docker-compose` entries
- [x] `python3 -c 'import yaml,sys; yaml.safe_load(open("templates/dependabot.yml"))'` succeeds
- [x] `make check` is green

## Phase 7: CI template defaults

**Depends on**: none

### Context

- `templates/ci.yml` — `on`, `changes`, `backend-ci`, `backend-golangci`, `frontend-ci`, later jobs
- `~/r/gyva/.github/workflows/ci.yml` — SHA pins, timeout, all-branch push, `fetch-depth` comment, uv steps

### What to build

Every `uses:` is pinned to the full commit SHA of its current release, with the tag in a trailing comment and one comment block explaining why. Push triggers on every branch. Every job carries `timeout-minutes` with a placeholder and the note to read the real figure off `gh run view`. The checkout step carries a commented `fetch-depth: 0` with the diff-scoped-lint reason. A `backend-python-ci` job gated on the `backend` filter runs `astral-sh/setup-uv`, `uv sync --frozen`, `ruff check`, `ruff format --check`, `ty check`, `pytest`, `uv lock --check` and `uv audit` last. The `setup-uv` comment states that upstream publishes no floating tag.

### Acceptance criteria

- [x] `grep -n 'uses:' templates/ci.yml` shows only `@<40-hex-sha> # v<tag>` forms
- [x] Every SHA resolves through `gh api repos/<owner>/<repo>/git/ref/tags/<tag>` to the commented tag
- [x] `on.push.branches` is `['**']` and every job has `timeout-minutes`
- [x] The Python job exists with the steps above, `uv audit` last
- [x] `make check` is green

## Phase 8: Python image and `.dockerignore`

**Depends on**: 5

### Context

- `guides/docker-multi-stage-builds.md` — Java and Node sections, the `.dockerignore` bullet
- `guides/new-project.md` — step 3 Dockerfiles bullet
- `README.md` — Templates table
- `~/r/gyva/Dockerfile`, `~/r/gyva/.dockerignore`

### What to build

A `## Python (uv, single stage)` section: the `ghcr.io/astral-sh/uv:<uv>-python<py>-bookworm-slim` base with both versions literal, `UV_COMPILE_BYTECODE=1` and `UV_LINK_MODE=copy`, a dependency-only `uv sync --frozen --no-dev --no-install-project` layer before `COPY src`, the project sync, a non-root user created after the sync, `EXPOSE` and the uvicorn `CMD`. One line says why one stage suffices here. `templates/.dockerignore` carries `.git/`, `.github/`, `.env`, `.env.*`, `node_modules/`, `.venv/`, `__pycache__/`, `*.pyc`, `.pytest_cache/`, `.ruff_cache/`, `tests/`, `docs/`, with one comment on the build context. The guide's `.dockerignore` bullet links the template; step 3 copies it for shapes with a Dockerfile; the README indexes it.

### Acceptance criteria

- [ ] The Python section exists with the listed elements and no gyva directory names
- [ ] `templates/.dockerignore` exists, is indexed in `README.md` and copied in step 3
- [ ] `make check` is green

## Phase 9: Grouped `make help`

**Depends on**: 8

### Context

- `templates/Makefile` — `help` target, `.DEFAULT_GOAL`, section comments
- `~/r/gyva/Makefile — help`, `~/r/gyva/scripts/make_help.awk` — the classes, the renderer, the wrap
- `guides/new-project.md` — step 2 base files
- `README.md` — Templates table

### What to build

`templates/make-help.awk` renders `CLASS_*` lists as titled sections, wraps at `HELP_WIDTH`, and prints an `UNCLASSIFIED` section for targets in no list. The Makefile template declares `CLASS_developer` and `CLASS_production`, assigns every documented target to exactly one, and `help` pipes the documented targets through the script with `$(firstword $(MAKEFILE_LIST))`. Step 2 copies the script to `scripts/make-help.awk`; the README indexes it.

### Acceptance criteria

- [ ] Copying `templates/Makefile` and `templates/make-help.awk` into a scratch directory and running `make help` prints two titled sections and no `UNCLASSIFIED` entry
- [ ] Adding an undocumented-class target to the scratch copy prints it under `UNCLASSIFIED`
- [ ] `README.md` and step 2 name the script
- [ ] `make check` is green
