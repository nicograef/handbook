# tmux

Prefix is `Ctrl-b` (press and release, then the key). Config:
[templates/.tmux.conf](../templates/.tmux.conf).

## Sessions — survive ssh disconnects

Run long-lived work (Claude Code, builds, migrations) inside a named session.
A dropped ssh connection only detaches; the work keeps running.

```bash
tmux new -A -s myproject          # create session, or re-attach if it exists
tmux ls                           # list sessions
tmux attach -t myproject          # re-attach explicitly
tmux kill-session -t myproject    # terminate session and everything in it
```

### Surviving logout needs lingering

A detach survives on its own; a logout does not. Without lingering, systemd stops
`user@$UID.service` once the last session ends. **Every** tmux server in that
slice dies with it — not just yours. Enable it once:

```bash
sudo loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger    # expect Linger=yes
```

Lingering also bounds an out-of-memory kill. The kill lands on the user manager;
a lingering one stays up instead of taking its slice down. Diagnosing one:
[maintenance.md](../guides/maintenance.md#after-an-oom-kill).

## Scrollback / copy mode

Mouse wheel scrolls directly (`mouse on` in the config). Keyboard:

| Key                | Action                                  |
| ------------------ | --------------------------------------- |
| Prefix + `[`       | Enter copy mode (then arrows/PgUp)      |
| `Space` … `Enter`  | Start selection … copy it               |
| Prefix + `]`       | Paste                                   |
| `q`                | Leave copy mode                         |

## Config reload

```bash
tmux source-file ~/.tmux.conf     # apply config changes to the running server
```
