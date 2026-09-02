# Install the Handbook as a Claude Code Plugin

The handbook ships as a public Claude Code plugin served from this repo, which is its own
marketplace.

- **Local symlinks** — see [dotfiles-codespaces.md](dotfiles-codespaces.md).

## What the plugin contains

- **The manifest `agents` field** validated but did not load agents in Claude Code v2.1.197.
  - Not re-verified since, so the plugin relies on the default `agents/` directory scan.
- **Personal config is deliberately excluded** — no hooks, no `settings.json`, no statusline,
  no MCP servers; those stay on the dev machine only.
- **Namespaced components** — skills invoke as `/handbook:<skill>`, e.g. `/handbook:distill`,
  not `/distill`.

## Prerequisites

- Claude Code CLI installed and authenticated (`claude`).
- Network access to `github.com/nicograef/handbook` (public repo).

## Install on a fresh machine

Two commands — add the marketplace, then install the plugin:

```bash
claude plugin marketplace add nicograef/handbook
claude plugin install handbook@nicograef
```

- **Then invoke** a namespaced skill in any session, e.g. `/handbook:distill`.

## Adopt the plugin in a project

Commit the enablement so Claude web sessions on the project repo load skills with zero manual
steps (not verified).

- **New file** — copy [`templates/claude-settings.json`](../templates/claude-settings.json)
  to the project as `.claude/settings.json`.
- **Existing file** — merge its three keys into the existing content.
- **The three keys** — `includeCoAuthoredBy`, `extraKnownMarketplaces.nicograef`, and
  `enabledPlugins."handbook@nicograef"`.

## Dev-machine opt-out

On machines already loading the skills through the symlink tier, the plugin would load them a
second time.
In each adopted repo, add a **gitignored** `.claude/settings.local.json`:

```json
{ "enabledPlugins": { "handbook@nicograef": false } }
```

- **Local scope overrides project scope** — skills never load twice on the dev machine.
- **Cloud sessions** on the same repo stay enabled.
- **Keep `.claude/settings.local.json`** out of version control.
- **Codespaces** — created by [`scripts/install-dotfiles.sh`](../scripts/install-dotfiles.sh).
- **Manual creation** is only needed on machines that don't use the dotfiles install.

## Update behavior

- **No `version` field** in the manifests — the git commit SHA is the version.
- **Every push to `main` is an update**, doc-only commits included.
- **Re-copy** is idempotent and harmless.

Updating an installed plugin takes **two commands and a restart**:

```bash
claude plugin marketplace update nicograef    # git-pull the marketplace clone
claude plugin update handbook@nicograef       # repoint the install at the new SHA
```

- **Neither alone is enough.**
- **`marketplace update`** advances the clone under `~/.claude/plugins/marketplaces/nicograef`.
- **It also stages** a new SHA-named copy in `~/.claude/plugins/cache/nicograef/handbook/`.
- **It leaves the install pinned** — `installed_plugins.json` keeps the old `installPath` and
  `gitCommitSha`.
- **`plugin update`** moves the pin and prints `Restart to apply changes`.
- **A running session** keeps the old copy.
- **Verify with `claude plugin list`**, which prints the installed SHA.
- **`claude plugin details handbook` does not verify an update.**
- **It reports** what the marketplace currently offers, not what is installed.
- **After `marketplace update` alone** it lists a newly pushed skill while the installed copy
  still lacks it.

## Verify

```bash
# first install
claude plugin details handbook   # one skill per .claude/skills/ dir, 1 agent, 0 hooks, 0 MCP servers

# after an update
claude plugin list               # installed SHA matches the pushed commit
```

---

See also:
- [templates/claude-settings.json](../templates/claude-settings.json) — project adoption snippet
- [guides/dotfiles-codespaces.md](dotfiles-codespaces.md) — local symlink tier
- [.claude/skills/README.md](../.claude/skills/README.md) — skills index and consumption matrix
