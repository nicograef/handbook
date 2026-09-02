# tmux

Prefix is `Ctrl-b` (press and release, then the key). Config:
[templates/.tmux.conf](../templates/.tmux.conf).

```bash
tmux source-file ~/.tmux.conf     # apply config changes to the running server
```

## Sessions — survive ssh disconnects

Run long-lived work (Claude Code, builds, migrations) inside a named session.
A dropped ssh connection only detaches; the work keeps running.

### Surviving logout needs lingering

A detach survives on its own; a logout does not. Without lingering, systemd stops
`user@$UID.service` after the last logout. Whether tmux servers in that scope die is
`KillUserProcesses=` in logind.conf (Debian default `no` keeps them). Enable it once:

```bash
sudo loginctl enable-linger "$USER"
loginctl show-user "$USER" -p Linger    # expect Linger=yes
```

Lingering also bounds an out-of-memory kill. The kill lands on the user manager;
a lingering one stays up instead of taking its slice down. Diagnosing one:
[maintenance.md](../guides/maintenance.md#after-an-oom-kill).

## Scrollback / copy mode

| Key                | Action                                  |
| ------------------ | --------------------------------------- |
| Prefix + `[`       | Enter copy mode (then arrows/PgUp)      |
| `Space` … `Enter` (vi) / `C-Space` … `M-w` (emacs) | Start selection … copy it |
| Prefix + `]`       | Paste                                   |
| `q`                | Leave copy mode                         |
