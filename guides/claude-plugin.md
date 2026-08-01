# Install the Handbook as a Claude Code Plugin

The handbook ships as a public Claude Code plugin served from this repo (which
is its own marketplace). This is the remote tier: it works on any fresh
machine, Codespace, or Claude web session without the dotfile symlinks. For the
local symlink tier, see [dotfiles-codespaces.md](dotfiles-codespaces.md).

## What the plugin contains

- **Every skill** under `.claude/skills/` — the same source the symlink tier
  exposes.
- **The `web-researcher` agent** (`.claude/agents/web-researcher.md`), exposed
  through the root `agents` symlink — the manifest `agents` field validated but
  did not load agents in Claude Code v2.1.197 (not re-verified since), so the
  plugin relies on the default `agents/` directory scan instead.

Personal config is deliberately **excluded**: no hooks, no `settings.json`, no
statusline, no MCP servers. Those stay on the dev machine only.

Because the plugin namespaces its components, skills invoke as
`/handbook:<skill>` (e.g. `/handbook:distill`, not `/distill`) and the agent is
`handbook:web-researcher`.

## Prerequisites

- Claude Code CLI installed and authenticated (`claude`).
- Network access to `github.com/nicograef/handbook` (public repo).

## Install on a fresh machine

Two commands — add the marketplace, then install the plugin:

```bash
claude plugin marketplace add nicograef/handbook
claude plugin install handbook@nicograef
```

Then invoke a namespaced skill in any session, e.g. `/handbook:distill`.

## Adopt the plugin in a project

So Claude web sessions on a project repo load the skills with zero manual
steps, commit the enablement to the repo. Copy
[`templates/claude-settings.json`](../templates/claude-settings.json) to the
project as `.claude/settings.json` — or, if the file already exists, merge its
two keys (`extraKnownMarketplaces.nicograef` and
`enabledPlugins."handbook@nicograef"`) into the existing content.

## Dev-machine opt-out

On machines that already load the skills through the symlink tier, the plugin
would load them a second time. In each adopted repo, add a **gitignored**
`.claude/settings.local.json`:

```json
{ "enabledPlugins": { "handbook@nicograef": false } }
```

Local scope overrides project scope, so skills never load twice on the dev
machine while cloud sessions on the same repo stay enabled. Keep
`.claude/settings.local.json` out of version control.

In **Codespaces** this file is created automatically:
[`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh) scans
`/workspaces` for adopted repos and writes the opt-out wherever it is missing
(the symlink tier is always present there, since the dotfiles install runs in
every Codespace). Manual creation is only needed on machines that don't use
the dotfiles install.

## Update behavior

There is no `version` field in the manifests — the git commit SHA is the
version, so every push to `main` is an update (including doc-only commits;
re-copy is idempotent and harmless).

Updating an installed plugin takes **two commands and a restart**:

```bash
claude plugin marketplace update nicograef    # git-pull the marketplace clone
claude plugin update handbook@nicograef       # repoint the install at the new SHA
```

Neither alone is enough. `marketplace update` advances the clone under
`~/.claude/plugins/marketplaces/nicograef` and stages a new SHA-named copy in
`~/.claude/plugins/cache/nicograef/handbook/`, but leaves the install pinned —
`installed_plugins.json` keeps the old `installPath` and `gitCommitSha`.
`plugin update` moves the pin and prints `Restart to apply changes`; a running
session keeps the old copy.

Verify with `claude plugin list`, which prints the installed SHA.

**`claude plugin details handbook` does not verify an update.** It reports what
the marketplace currently offers, not what is installed — after `marketplace
update` alone it lists a newly pushed skill while the installed copy still lacks
it.

## Verify

```bash
claude plugin details handbook   # one skill per .claude/skills/ dir, 1 agent, 0 hooks, 0 MCP servers
```

---

See also:
- [templates/claude-settings.json](../templates/claude-settings.json) — project adoption snippet
- [guides/dotfiles-codespaces.md](dotfiles-codespaces.md) — local symlink tier
- [.claude/skills/README.md](../.claude/skills/README.md) — skills index and consumption matrix
