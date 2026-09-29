# tmux

Config: [dotfiles/.tmux.conf](../dotfiles/.tmux.conf).

```bash
tmux new -A -s <project>          # attach to the named session, or create it
tmux source-file ~/.tmux.conf     # apply config changes to the running server
```

## Sessions — survive ssh disconnects

Run long-lived work (Claude Code, builds, migrations) inside a named session.
A dropped ssh connection only detaches; the work keeps running.

### Surviving logout needs lingering

A detach survives on its own. The last logout stops the user manager unless lingering is on.
Enable it: [provision-server.md](../guides/provision-server.md#turn-on-lingering). Why: [maintenance.md](../guides/maintenance.md#after-an-oom-kill).
