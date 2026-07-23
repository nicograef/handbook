# tmux

Prefix is `Ctrl-b` (press and release, then the key). Config:
[templates/.tmux.conf](../templates/.tmux.conf).

## Sessions — survive ssh disconnects

Run long-lived work (Claude Code, builds, migrations) inside a named session:
a dropped ssh connection only detaches, everything keeps running.

```bash
tmux new -A -s myproject          # create session, or re-attach if it exists
tmux ls                           # list sessions
tmux attach -t myproject          # re-attach explicitly
tmux kill-session -t myproject    # terminate session and everything in it
```

| Prefix + key | Action                              |
| ------------ | ----------------------------------- |
| `d`          | Detach (session keeps running)      |
| `$`          | Rename session                      |
| `s`          | Pick session interactively          |

## Windows

| Prefix + key | Action                     |
| ------------ | -------------------------- |
| `c`          | New window                 |
| `1`…`9`      | Jump to window             |
| `n` / `p`    | Next / previous window     |
| `,`          | Rename window              |
| `&`          | Kill window (confirms)     |

## Panes

| Prefix + key | Action                                |
| ------------ | ------------------------------------- |
| `%`          | Split left/right                      |
| `"`          | Split top/bottom                      |
| arrow keys   | Move between panes                    |
| `z`          | Zoom pane to full window (toggle)     |
| `x`          | Kill pane (confirms)                  |

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
