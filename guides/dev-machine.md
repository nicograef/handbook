# New Dev Machine

Take a fresh Ubuntu laptop to a working toolchain with [scripts/setup-dev-machine.sh](../scripts/setup-dev-machine.sh).
Its header lists every item it checks and fixes, in apply order.

## Prerequisites

An Ubuntu desktop with a `sudo` user. Cloning needs `git`; the script stops without `jq`:

```bash
sudo apt install -y git jq
```

Have your git name and email ready, and a browser logged in to GitHub.

## Set up

1. **Clone the handbook** — over HTTPS, since no key exists yet. The script switches `origin` to SSH later.
   `~/r/handbook` then holds the clone:

   ```bash
   mkdir -p ~/r && git clone https://github.com/nicograef/handbook.git ~/r/handbook
   ```

   The Claude config enables the `nico` plugin from `/home/nico/r/handbook/plugin`.
   Another clone path edits `extraKnownMarketplaces` in [claude/settings.json](../claude/settings.json).

2. **Run the script** — it prints one line per item, then asks `[Y/n/q]` before each fix.
   It ends with `Done – open a new terminal`; a skipped item ends it with `Still differs`:

   ```bash
   sudo ~/r/handbook/scripts/setup-dev-machine.sh
   ```

   These prompts need you, in this order:

   | Prompt | Answer |
   | --- | --- |
   | `git user.name:` / `git user.email:` | Your git identity |
   | `Enter passphrase` | A passphrase for `~/.ssh/id_ed25519`, or empty |
   | `gh auth login` | Log in with a web browser |
   | `Key title on GitHub` | This machine's name; Enter takes the hostname |
   | `gh auth refresh`, only for an older login | Approve the key scopes in the browser |

3. **New login** — log out and back in. The session then has the `docker` group and the new `PATH`.

## Update

Rerun the script whenever you like. It updates the tools it installs and leaves everything else alone.
Unattended upgrades update the rest of the system. `--yes` applies every fix without asking:

```bash
sudo ~/r/handbook/scripts/setup-dev-machine.sh --yes
```

## Verify

`--check` needs no root and changes nothing:

```bash
~/r/handbook/scripts/setup-dev-machine.sh --check   # → 18 lines starting with ok, then "Everything matches the handbook"
docker run --rm hello-world | grep Hello             # → Hello from Docker!
```

## Troubleshooting

| Symptom | Cause | Fix |
| --- | --- | --- |
| `docker run` needs sudo | The session started before the group change | Log out and back in |
| `GitHub keys` stays `MISSING` | The browser approval for the key scopes was skipped | Rerun the script and approve it |
| `snaps` shows `WRONG` for node | The snap tracks another major | Rerun the script; it switches to `NODE_CHANNEL` |
