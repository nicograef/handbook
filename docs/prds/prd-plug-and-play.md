# PRD: Plug-and-Play — Distribute the Handbook Everywhere

Third of three PRDs for the handbook rework (PRD 1: fix & prune; PRD 2: ops
lifecycle; this one: plug-and-play distribution). Executes after PRD 1;
independent of PRD 2.

## Problem Statement

The handbook's agent setup is excellent — on exactly the machines where its
symlinks exist. Everywhere else it degrades or vanishes:

- **Claude web/cloud sessions have none of it.** A cloud session on jotti or
  lexiban runs without the 19 skills, the web-researcher agent, or any of the
  workflow discipline they encode — the home-directory symlinks simply don't
  exist there.
- **A fresh machine starts from zero.** Skills arrive only after manually
  cloning the handbook and running the installer; there is no
  install-in-one-command path.
- **The devcontainer template is an untested reference.** The handbook ships a
  devcontainer template but doesn't use one itself; the repo's own Codespace
  lacks the check toolchain, and the dotfiles flow has never been verified
  end-to-end in a fresh Codespace.
- **Shell comfort doesn't travel to servers.** SSHing into a provisioned VPS
  means no aliases, no git defaults — the dotfiles installer supports manual
  runs but no runbook mentions it.
- **The distribution story is undocumented and partly wrong.** The consumption
  matrix covers only the symlink tier, states one row incorrectly, and marks
  others "not verified."

## Solution

Distribution becomes two documented tiers from one source of truth:

- **The symlink tier stays** — unchanged, zero-lag skill editing on the dev
  machine.
- **A public plugin becomes the remote tier:** the handbook itself becomes a
  Claude Code plugin marketplace exposing all skills plus the web-researcher
  agent. Any machine or web session gets everything in one command; personal
  config (settings, hooks, statusline) deliberately stays out.
- **Project repos opt in permanently:** plugin enablement is committed into
  jotti, lexiban, and website's shared settings — done within this PRD — so
  every future session on those repos, local or cloud, loads the skills
  automatically. The handbook's templates carry the same snippet so new
  projects get it for free, and a short adoption runbook covers the next repo.
- **The handbook proves its own devcontainer:** a root devcontainer with the
  check toolchain, doubling as the tested validation of the devcontainer
  template.
- **A one-paste dotfiles install for VPSes** lands in the provision guide.
- **Every path is smoke-tested once** — fresh Codespace, clean plugin install,
  Claude web session on an adopted repo — and the consumption matrix is
  rewritten around the two tiers, with its "not verified" rows resolved by
  those very tests.

**Definition of done:** a Claude web session on a project repo has the full
skill set with zero manual steps, and every consumption path in the matrix has
been exercised once with the result recorded.

## User Stories

1. As the maintainer in a Claude web session on a project repo, I want my
   skills and web-researcher agent loaded automatically, so that cloud
   sessions are as capable as my local ones.
2. As the maintainer on a fresh machine, I want the full skill set installable
   in one command without cloning the handbook, so that new-environment setup
   cost is near zero.
3. As the maintainer on my dev machine, I want the symlink tier untouched, so
   that skill edits keep applying instantly without a publish cycle.
4. As the owner of the project repos, I want plugin enablement committed in
   each, so that any future session — mine, cloud, or collaborator — gets the
   same skills without setup.
5. As the maintainer editing the handbook in a Codespace, I want a
   devcontainer with the check toolchain, so that the repo self-check runs
   there and the shipped template is proven by real use.
6. As an operator on a VPS, I want a documented one-paste dotfiles install, so
   that my shell setup travels to any server I SSH into.
7. As the maintainer, I want the consumption matrix to document both tiers
   with verified rows, so that the distribution story lives in one trustworthy
   place.
8. As a stranger discovering this public repo, I want the plugin cleanly
   installable and properly attributed, so that reuse is safe and licensing is
   honest.

## Implementation Decisions

- **Architecture:** two tiers, one source of truth. Symlinks (installed by the
  dotfiles installer) remain the local tier; the plugin is the remote tier.
  Neither duplicates content — both expose the same skills directory.
- **Plugin packaging:** the handbook repo itself becomes the marketplace (no
  separate repo, per the review's split analysis). The plugin bundles all
  skills and the web-researcher agent; personal configuration — settings,
  hooks, statusline, permissions — is deliberately excluded. Skills must
  behave identically when consumed as a plugin, including the shared quality
  checklist and each skill's reference files; the exact manifest layout
  follows the official plugin docs at plan time.
- **Naming stability:** marketplace and plugin names are chosen once at plan
  time and treated as frozen — project-repo settings will reference them
  permanently.
- **Project adoption:** plugin enablement is committed into the shared Claude
  settings of the three project repos as part of this PRD, following each
  repo's own commit conventions (propose message, explicit approval — no
  auto-commit). The handbook's project templates gain the same snippet, and a
  short adoption runbook documents the procedure for future repos.
- **Devcontainer:** the handbook's root devcontainer is derived from the
  shipped template and carries the check toolchain (make, shellcheck, compose
  for the validation stage). Deliberate divergences from the template are
  commented in place, so the template remains the generic single source and
  the root config its proven specialization.
- **VPS one-liner:** a documented clone-and-install command in the provision
  guide, using the installer's existing manual-run path — no new script.
- **Docs:** the consumption matrix is rewritten around the two tiers; the
  incorrect Copilot row is corrected and formerly unverified rows carry the
  date and result of their smoke test. The agent-setup section of the index
  gains the plugin as a first-class entry.
- **Self-check:** the plugin manifest gets a validation stage in the repo
  self-check — the official validator if one exists (verified at plan time),
  otherwise structural JSON validation.
- **Sequencing:** after PRD 1 (the plugin publishes the skills surface more
  visibly, so the attribution note and index fixes land first). Independent of
  PRD 2 — the two can proceed in either order.

## Testing Decisions

- Three one-time smoke tests are the acceptance tests, each recorded (date,
  environment, result) in the document it verifies:
  1. **Fresh Codespace** — dotfiles install runs automatically, symlinks live,
     skills load in Claude Code, the devcontainer provides a green repo
     self-check.
  2. **Clean plugin install** — on an environment without symlinks, one
     marketplace-add plus install yields working skills and the web-researcher
     agent.
  3. **Claude web session** — on an adopted project repo, a cloud session
     loads the skills with zero manual steps.
- The consumption matrix is the test record: no row may claim "yes" without a
  dated smoke test behind it; rows that cannot be verified stay explicitly
  marked unverified.
- The repo self-check stays green throughout; the new manifest-validation
  stage is proven by breaking it once intentionally, like the stages added in
  PRD 1.
- No unit-test infrastructure — observable behavior only.

## Out of Scope

- Migrating local consumption to the plugin — the symlink tier is explicitly
  kept.
- Submitting the plugin to the official or community marketplaces; it is
  served from this repo only.
- Copilot cloud/server-side skill loading — the plugin is a Claude Code
  mechanism; Copilot's cloud story would require vendoring skills into project
  repos and stays a documented unknown.
- Bundling MCP servers, hooks, or settings into the plugin.
- Release ceremony (semver tags, changelogs) beyond the marketplace's default
  update behavior.
- Any change to skill content — packaging and distribution only.
- Cloud-init and VPS provisioning delivery — PRD 2 owns those.

## Further Notes

- This PRD's plan touches three external repos (jotti, lexiban, website) for
  the adoption commits — each under its own repo rules; the handbook plan
  should treat those as final, separately-approved steps.
- The plugin mechanics (marketplace file layout, project-settings enablement
  keys, validator availability) were verified against official docs during
  the 2026-07-09 review research; the plan should re-verify the exact keys at
  implementation time per the research rule.
- The smoke tests double as documentation upgrades: every "presumably" or
  "not verified" in today's consumption matrix either becomes a dated fact or
  stays honestly labeled.
