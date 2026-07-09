# Plan: Plug-and-Play — Distribute the Handbook Everywhere

> Source PRD: [docs/prds/prd-plug-and-play.md](../prds/prd-plug-and-play.md)

## Goal

Distribution becomes two documented tiers from one source of truth: the symlink
tier stays untouched on the dev machine, and a public Claude Code plugin —
served from this repo as its own marketplace — becomes the remote tier for
every other machine, Codespace, and Claude web session. Project repos commit
plugin enablement so cloud sessions load the skills with zero manual steps.
Definition of done: a Claude web session on a project repo has the full skill
set with zero manual steps, and every consumption path in the matrix has been
exercised once with the result recorded.

## Architectural decisions

Durable decisions that apply across all phases:

- **Baseline**: this plan executes on the post-fix-and-prune repo state
  (`docs/plans/plan-fix-and-prune.md` completed): six self-check stages,
  corrected consumption matrix, `research/`, `theory/`, and
  `.github/instructions/` deleted. If that plan drifted, re-verify affected
  references before each phase.
- **Frozen names** (permanent — project repos reference them in committed
  settings): marketplace **`nicograef`**, plugin **`handbook`**, enablement key
  **`handbook@nicograef`**, GitHub source **`nicograef/handbook`** (public,
  verified 2026-07-09). Plugin skills invoke as `/handbook:<skill>`, the agent
  as `handbook:web-researcher`.
- **Manifest layout** (verified against code.claude.com/docs plugins-reference
  and plugin-marketplaces, 2026-07-09; re-verify exact keys at implementation
  time per the research rule): the repo root is marketplace and plugin at once.
  `.claude-plugin/marketplace.json` (fields `name`, `owner`, `plugins`) lists
  one plugin `handbook` with `source: "./"`. `.claude-plugin/plugin.json`
  declares `"skills": "./.claude/skills/"` and
  `"agents": ["./.claude/agents/web-researcher.md"]` so both tiers expose the
  same directories — no content is duplicated or moved. No `version` field in
  either manifest: the git commit SHA is the version, so every pushed commit is
  an update (the marketplace's default update behavior, per the PRD's
  out-of-scope on release ceremony).
- **Personal config stays out**: the plugin declares no hooks, no MCP servers,
  no settings, no statusline. `claude/`, `.claude/settings.json`, and
  `claude/statusline.sh` are never referenced by a manifest.
- **Project adoption snippet** (committed to jotti, lexiban, website; carried
  by the new template):

  ```json
  {
    "extraKnownMarketplaces": {
      "nicograef": {
        "source": { "source": "github", "repo": "nicograef/handbook" }
      }
    },
    "enabledPlugins": { "handbook@nicograef": true }
  }
  ```

- **Dev-machine opt-out**: on symlink-tier machines, each adopted repo gets a
  gitignored `.claude/settings.local.json` with
  `"enabledPlugins": { "handbook@nicograef": false }` (local scope overrides
  project scope), so skills never load twice locally while cloud sessions are
  unaffected.
- **New files**: `LICENSE` (MIT), `.claude-plugin/plugin.json`,
  `.claude-plugin/marketplace.json`, `guides/claude-plugin.md`,
  `templates/claude-settings.json`, `.devcontainer/devcontainer.json`.
- **New self-check stage**: `plugin` in `scripts/check-repo.sh` (and
  `make plugin`), running the official validator `claude plugin validate .`
  (exists in CLI v2.1.197, verified 2026-07-09). Plain mode, not `--strict`:
  warnings must not hard-fail the Stop hook. A missing `claude` binary is
  logged as a failure exactly like missing `shellcheck` in `check_shell()`.
- **Devcontainer**: `.devcontainer/devcontainer.json` is derived from
  `templates/devcontainer.json` and carries the check toolchain: docker-in-docker
  feature (compose stage), the Claude Code devcontainer feature
  (`ghcr.io/anthropics/devcontainer-features/claude-code` — verify exact
  version tag at implementation time), and `make` + `shellcheck` via
  `postCreateCommand`. Every deliberate divergence from the template is
  commented in place.
- **Phases = commits**: one conventional commit per phase, full `make check`
  green at every commit, no commit or push without explicit approval. Phases 4
  and 6 additionally require pushes / external-repo commits — each proposed
  and approved separately.

## Inventory

- `.claude/skills/` — 18 skill directories plus shared `quality.md` and
  `README.md`; the single skills source both tiers expose. Skill reference
  files (e.g. `clarify/question-rules.md`) resolve relatively within this
  directory, so they travel with the plugin's cache copy unchanged.
- `.claude/skills/README.md — Skill Consumption Matrix` — the matrix to rewrite
  around two tiers; its intro currently says skills are exposed "through
  symlinks" only.
- `.claude/agents/web-researcher.md` — the agent the plugin bundles.
- `scripts/check-repo.sh — check_shell(), STAGE dispatch, header stage list` —
  prior art for the new `plugin` stage (missing-tool handling, silent-on-success
  style, stage wiring).
- `Makefile — check target, help comments` — gains the `plugin` target.
- `scripts/install-dotfiles.sh — CLAUDE_LINKS, manual-run header` — the symlink
  tier installer; its documented manual-run path is the VPS one-paste command.
- `install.sh` — repo-root wrapper Codespaces and the VPS one-liner call.
- `templates/devcontainer.json` — derivation source for the root devcontainer;
  gains a "proven by" note.
- `guides/dotfiles-codespaces.md — Setup, Verify` — records smoke test 1.
- `guides/provision-server.md — After provisioning` — gains the VPS one-paste
  dotfiles install.
- `guides/copilot-agent-setup.md` — post-PRD-1 home of the verified Copilot
  loading facts; the rewritten matrix must not contradict it.
- `README.md — Guides, Templates, Scripts, Agent Setup sections` — index rows
  for every new file; Agent Setup gains the plugin as a first-class entry.
- `AGENTS.md — Structure` — gains `.claude-plugin/` and `.devcontainer/` lines.
- `.claude/settings.json — Stop hook` — handbook-repo personal config; stays
  out of the plugin.
- External: `~/r/jotti`, `~/r/lexiban`, `~/r/website` — each repo's shared
  `.claude/settings.json` (create or merge) receives the adoption snippet under
  that repo's own commit conventions.

## Resolved decisions

- Naming frozen as marketplace `nicograef` / plugin `handbook` / key
  `handbook@nicograef`. (User-confirmed.)
- Dev-machine double-loading handled via the local opt-out in
  `.claude/settings.local.json`, documented in the adoption runbook.
  (User-confirmed.)
- License: MIT — `LICENSE` file plus `"license": "MIT"` in `plugin.json`;
  consistent with the five skills ported from the MIT-licensed superpowers
  plugin. (User-confirmed.)
- Smoke test 2 environment: temporary clean `HOME` on the dev machine
  (`HOME=$(mktemp -d) claude`), one-time auth, deleted afterwards.
  (User-confirmed.)
- Validator runs without `--strict`: unrecognized-field warnings (e.g.
  cross-tool frontmatter) must not break the Stop hook; errors still exit
  nonzero.
- The adoption runbook is a new runbook-style guide `guides/claude-plugin.md`
  (install, project adoption, opt-out, update behavior, smoke-test records).
- The enablement snippet template is a new file `templates/claude-settings.json`
  (copy to a project's `.claude/settings.json`), functional as-is per template
  conventions.
- Smoke-test records live in the document each test verifies: test 1 in
  `guides/dotfiles-codespaces.md`, tests 2 and 3 in `guides/claude-plugin.md`;
  the rewritten matrix cites all three with dates.
- The whole repo is copied into the plugin cache on install (plugin root =
  repo root). Accepted: only skills and agents contribute session context;
  guides/templates are inert disk content of a few hundred kilobytes.

## Open questions / Risks

- **Claude web behavior is the test, not a given**: whether a cloud session
  auto-installs a project-declared marketplace with zero prompts is exactly
  what smoke test 3 verifies. If a trust or auth step blocks it, the matrix row
  records the honest result and the follow-up is a separate decision.
- The `plugin` stage makes the `claude` CLI a dependency of `make check` (and
  the Stop hook), the same way `shellcheck` and `docker` already are. Present
  on the maintainer's machines and in the devcontainer via the Claude Code
  feature; logged as a failure elsewhere.
- Marketplace names register once per user; `nicograef` is not on the reserved
  list (checked 2026-07-09). If the local test in Phase 1 registers it from a
  path source, remove it before Phase 4 re-adds it from GitHub.
- Commit-SHA versioning means consumers update on every push to `main` —
  including doc-only commits. Harmless (idempotent re-copy), noted in the
  guide's update-behavior section.

---

## Phase 1: The plugin installs locally

**User stories**: 2 (one-command install), 3 (symlink tier untouched), 8 (clean, attributed reuse)

### Context

- `.claude/skills/` and `.claude/agents/web-researcher.md` — the content both
  manifests point at; nothing in them changes.
- `README.md — Agent Setup section` — the license line lands at the README's
  end.
- `AGENTS.md — Structure` — new `.claude-plugin/` entry.

### What to build

The repo becomes a marketplace serving itself as one plugin, installable and
demoable entirely locally. Create `LICENSE` (MIT, Nico Graef),
`.claude-plugin/marketplace.json` (marketplace `nicograef`, owner Nico, one
plugin entry `handbook` with `source: "./"` and a one-line description), and
`.claude-plugin/plugin.json` (name `handbook`, description, author, repository
URL, `"license": "MIT"`, `"skills": "./.claude/skills/"`,
`"agents": ["./.claude/agents/web-researcher.md"]`, no `version` field). Add
the `.claude-plugin/` line to the AGENTS.md Structure list and a short license
note at the end of `README.md`. Validate with `claude plugin validate .`, then
prove the loop end-to-end on this machine: add the marketplace from the local
path, install `handbook@nicograef`, confirm the component inventory
(`claude plugin details handbook` — one skill per directory under
`.claude/skills/` (18 at plan time), 1 agent, 0 hooks, 0 MCP servers), invoke
one namespaced skill in a session, then uninstall and remove
the local marketplace so the symlink tier remains the only local consumer.

### Acceptance criteria

- [ ] `claude plugin validate .` passes on the repo root.
- [ ] `.claude-plugin/plugin.json` has no `version` field, declares MIT, and
      points only at `.claude/skills/` and the web-researcher agent — no
      hooks, MCP servers, or settings keys.
- [ ] Local install demo: after adding the repo as a path marketplace,
      `claude plugin details handbook` lists one skill per directory under
      `.claude/skills/` (18 at plan time) and the `web-researcher` agent with
      zero hooks and zero MCP servers, and a
      namespaced skill (e.g. `/handbook:commit`) is invocable in a session.
- [ ] A skill that loads reference files (e.g. `create-plan`, which reads
      `clarify/question-rules.md` and `quality.md`) works from the plugin's
      cache copy — the shared checklist and reference files travel.
- [ ] The local test marketplace and plugin are removed afterwards;
      `claude plugin list` shows no `handbook` on this machine.
- [ ] `LICENSE` exists; `README.md` states the MIT license; `AGENTS.md`
      Structure lists `.claude-plugin/`.
- [ ] `make check` passes.

---

## Phase 2: Self-check guards the manifests

**User stories**: 8 (a stranger can trust the manifests stay valid)

### Context

- `scripts/check-repo.sh — check_shell(), STAGE dispatch, header comment` —
  missing-tool handling and stage wiring to copy.
- `Makefile — check target, help comments` — new `plugin` target.
- `README.md — Scripts table` — the `check-repo.sh` row enumerates the stages.

### What to build

A `plugin` stage in `scripts/check-repo.sh`, same silent-on-success /
focused-error style as the existing stages: run `claude plugin validate .` and
log its output as a failure when it exits nonzero; a missing `claude` binary is
logged as a failure exactly like missing `shellcheck` in `check_shell()`. Wire
the stage into the `all` dispatch, add the `make plugin` target, and update
every place that enumerates the stages (script header, Makefile help comments,
README Scripts-table row). Prove the stage once: temporarily corrupt
`.claude-plugin/marketplace.json` — observe the failure — revert.

### Acceptance criteria

- [ ] `scripts/check-repo.sh plugin` passes on the real repo and fails on a
      corrupted manifest (intentional-break test performed and reverted,
      failure output captured in the phase's verification notes).
- [ ] With the `claude` binary absent from `PATH`, the stage logs a failure
      instead of silently passing.
- [ ] `make check` runs all seven stages; `make plugin` runs the stage alone;
      `make help`, the script header, and the README Scripts row all list
      seven stages.
- [ ] `scripts/check-repo.sh` passes shellcheck; `make check` passes.

---

## Phase 3: Distribution docs — guide and template

**User stories**: 2 (fresh-machine install documented), 4 (adoption procedure for future repos)

### Context

- `guides/provision-server.md`, `guides/dotfiles-codespaces.md` — runbook style
  to match (prerequisites, numbered steps, Verify section).
- `templates/vscode-settings.json` — closest existing JSON-template prior art.
- `README.md — Guides (runbooks) and Templates tables` — two new index rows.
- `.claude/rules/guides.md` and `.claude/rules/templates.md` — the conventions
  both new files must follow.

### What to build

The adoption runbook and the reusable snippet. `guides/claude-plugin.md` is a
runbook-style guide covering: what the plugin contains (all skills + the
web-researcher agent; personal config excluded), the two-command install for
any machine (`claude plugin marketplace add nicograef/handbook`,
`claude plugin install handbook@nicograef`), project adoption (paste
`templates/claude-settings.json` as the repo's `.claude/settings.json`, or
merge the two keys into an existing one), the dev-machine opt-out
(`.claude/settings.local.json` with `"handbook@nicograef": false` on
symlink-tier machines, and that the file must be gitignored), update behavior
(commit-SHA versioning — every push to `main` is an update;
`/plugin marketplace update nicograef` refreshes), and a Verify section whose
smoke-test records Phases 4 and 6 will date and fill.
`templates/claude-settings.json` carries exactly the project adoption snippet
from the header, functional as-is. Both files are indexed in `README.md`.

### Acceptance criteria

- [ ] `guides/claude-plugin.md` exists, follows the runbook shape, and covers
      install, project adoption, opt-out, and update behavior with
      copy-paste-ready commands; its Verify section names smoke tests 2 and 3
      as pending with their exact commands.
- [ ] `templates/claude-settings.json` contains the adoption snippet verbatim
      (both keys, `handbook@nicograef`) and validates as JSON.
- [ ] Both files are indexed in the correct `README.md` tables; the guide
      links the template instead of inlining it a second time.
- [ ] `make check` passes.

---

## Phase 4: Smoke test 2 — clean remote install

**User stories**: 2, 8

### Context

- `guides/claude-plugin.md — Verify` — where the result is recorded.
- Phases 1–3 must be committed and pushed to `main` first (needs approval) —
  the marketplace add pulls from GitHub.

### What to build

Prove the remote tier on an environment without symlinks. In a scratch
directory with `HOME=$(mktemp -d)`, authenticate `claude` once, run
`claude plugin marketplace add nicograef/handbook` and
`claude plugin install handbook@nicograef`, then verify inside a session that
the namespaced skills and the `handbook:web-researcher` agent are available
and that one skill executes with its reference files. Record date,
environment, and result in the Verify section of `guides/claude-plugin.md`,
and delete the temporary `HOME`.

### Acceptance criteria

- [ ] From the temp `HOME`, one marketplace-add plus one install yields
      `claude plugin details handbook` showing the full skill set (one per
      `.claude/skills/` directory) and the `web-researcher` agent, with no
      handbook symlinks present anywhere in that `HOME`.
- [ ] A namespaced skill invocation works in a live session from the clean
      environment.
- [ ] `guides/claude-plugin.md` Verify records smoke test 2 with date,
      environment, and result; the temp `HOME` is deleted.
- [ ] `make check` passes.

---

## Phase 5: The handbook proves its own devcontainer (smoke test 1)

**User stories**: 5

### Context

- `templates/devcontainer.json` — derivation source; gains the "proven by"
  note.
- `guides/dotfiles-codespaces.md — Setup, Verify` — the dotfiles flow the
  Codespace exercises; records smoke test 1.
- `scripts/check-repo.sh` — all seven stages must go green inside the
  container (compose needs docker, plugin needs the claude CLI).
- `README.md — Agent Setup table` and `AGENTS.md — Structure` — index the new
  directory.

### What to build

A root `.devcontainer/devcontainer.json` derived from the template: Ubuntu
base image, docker-in-docker feature uncommented (compose stage), the Claude
Code devcontainer feature added (claude CLI for the plugin stage and the
skills check), `postCreateCommand` installing `make` and `shellcheck` instead
of the template's `setup-dev-tools.sh` call, and the EditorConfig extension
kept. Every divergence from the template carries an in-place comment naming
why, so the template stays the generic source and this file its proven
specialization; the template gains a one-line note pointing at the root
devcontainer as its tested instance. Then run smoke test 1 in a fresh
Codespace on `nicograef/handbook`: the account-level dotfiles install runs
automatically, the `guides/dotfiles-codespaces.md` Verify commands pass
(symlinks live), skills load in a Claude Code session, and `make check` is
green with all seven stages. Record date, environment, and result in
`guides/dotfiles-codespaces.md`.

### Acceptance criteria

- [ ] `.devcontainer/devcontainer.json` exists, parses, and comments every
      deliberate divergence from `templates/devcontainer.json` in place.
- [ ] Fresh-Codespace run: dotfiles installed automatically (Verify commands
      of the dotfiles guide pass), a Claude Code session loads the symlinked
      skills, and `make check` exits green — all seven stages, none skipped.
- [ ] Smoke test 1 recorded (date, environment, result) in
      `guides/dotfiles-codespaces.md`; `templates/devcontainer.json` notes the
      root devcontainer as its proven instance.
- [ ] `README.md` Agent Setup indexes the devcontainer; `AGENTS.md` Structure
      lists `.devcontainer/`.
- [ ] `make check` passes.

---

## Phase 6: Project repos adopt the plugin (smoke test 3)

**User stories**: 1, 4

### Context

- `~/r/jotti`, `~/r/lexiban`, `~/r/website` — each repo's shared
  `.claude/settings.json` (merge the two keys into existing content, or create
  the file); each commit follows that repo's own conventions and is proposed
  and approved separately — these are final, separately-approved steps per the
  PRD.
- `guides/claude-plugin.md — Verify` — records smoke test 3.
- `templates/claude-settings.json` — the snippet being committed, kept
  identical.

### What to build

Permanent opt-in for the three project repos, then the cloud proof. In each of
jotti, lexiban, and website: merge `extraKnownMarketplaces.nicograef` and
`enabledPlugins."handbook@nicograef": true` into the shared
`.claude/settings.json`, propose the commit message per that repo's
conventions, and commit only on approval (pushes likewise). On the dev
machine, add the local opt-out to each repo's `.claude/settings.local.json`
and confirm the file is gitignored there. Once one adopted repo's change is on
its default branch, run smoke test 3: start a Claude web session on that repo
and verify the namespaced skills and the web-researcher agent are available
with zero manual steps. Record date, repo, and result in
`guides/claude-plugin.md`.

### Acceptance criteria

- [ ] All three repos carry the adoption snippet in their shared
      `.claude/settings.json`, committed with individually approved messages;
      the keys match `templates/claude-settings.json` exactly.
- [ ] Each repo on the dev machine has the gitignored local opt-out; a local
      session there shows no duplicate skill listings (only the symlink-tier
      skills).
- [ ] Smoke test 3: a Claude web session on an adopted repo lists the
      `/handbook:` skills and the `handbook:web-researcher` agent with zero
      manual steps — or the honest blocker is recorded instead.
- [ ] Smoke test 3 recorded (date, repo, result) in
      `guides/claude-plugin.md`.
- [ ] Handbook `make check` passes (no handbook files change in this phase
      beyond the guide's record).

---

## Phase 7: VPS one-paste dotfiles install

**User stories**: 6

### Context

- `guides/provision-server.md — After provisioning` — where the one-liner
  lands.
- `scripts/install-dotfiles.sh — manual-run header` and `install.sh` — the
  existing manual-run path the command uses; no new script.

### What to build

One paste-able block in the After-provisioning section of
`guides/provision-server.md`:
`git clone https://github.com/nicograef/handbook.git ~/handbook && ~/handbook/install.sh`
— with a one-line explanation (shell aliases, git defaults, gh CLI; idempotent
to re-run; the Claude config symlinks it also creates are inert on servers
without Claude Code) and a cross-link to `guides/dotfiles-codespaces.md` for
what the installer does in detail.

### Acceptance criteria

- [ ] The provision guide's After-provisioning section contains the one-paste
      clone-and-install command using the existing `install.sh` path, plus the
      idempotency note and the dotfiles-guide link.
- [ ] No new script was added; `scripts/install-dotfiles.sh` is unchanged.
- [ ] `make check` passes.

---

## Phase 8: Consumption matrix rewritten around two tiers

**User stories**: 7

### Context

- `.claude/skills/README.md — intro paragraph, Skill Consumption Matrix` — the
  rewrite target; intro currently names symlinks as the only exposure.
- `guides/claude-plugin.md` and `guides/dotfiles-codespaces.md` — the dated
  smoke-test records the matrix cites.
- `guides/copilot-agent-setup.md` — Copilot loading facts the matrix must not
  contradict.
- `README.md — Agent Setup table` — the plugin becomes a first-class entry.

### What to build

The distribution story in one trustworthy place. Rewrite the
`.claude/skills/README.md` intro and matrix around the two tiers: a local
symlink tier (Claude Code CLI/IDE, VS Code Copilot via `~/.claude/skills`,
Copilot CLI via `~/.agents/skills`) and a remote plugin tier (any Claude Code
via `handbook@nicograef`, Claude web sessions on adopted repos). Every "yes"
row carries the date and pointer of the smoke test that proved it (tests 1–3);
rows that cannot be verified — Copilot cloud / server-side review — stay
explicitly "not verified" with the documented-unknown note that Copilot's
cloud story would require vendoring skills into project repos. Note the
namespacing difference between tiers (`/commit` vs `/handbook:commit`) and
link `guides/claude-plugin.md` for the remote tier. In `README.md`, add the
plugin (manifests + guide) as a first-class Agent Setup entry.

### Acceptance criteria

- [ ] The matrix presents both tiers; no row claims "yes" without a dated
      smoke test behind it, and unverifiable rows keep an explicit
      "not verified" label.
- [ ] No matrix claim contradicts `guides/claude-plugin.md`,
      `guides/copilot-agent-setup.md`, or `scripts/install-dotfiles.sh`.
- [ ] The skills-README intro no longer describes symlinks as the only
      exposure; it names both tiers and the namespacing difference.
- [ ] `README.md` Agent Setup lists the plugin manifests and
      `guides/claude-plugin.md` as first-class entries.
- [ ] `make check` passes.
