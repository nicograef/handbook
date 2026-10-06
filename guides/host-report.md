# Read-only Host Report over SSH

Give your laptop a key that can only ask a server for a report.
For that key the server runs one fixed command, never a shell, and the command answers exact requests only.

## Prerequisites

- A server provisioned per [provision-server.md](provision-server.md), with SSH as `<user>` and `sudo`.
- report-health at `/usr/local/bin/report-health`, as provisioning installs it, for the `checks` request.
- The sysstat record of [host-history.md](host-history.md), for the `history` request.
- Your own login key behind a passphrase; [Why each client option](#why-each-client-option) says why.

## Set up the report key

1. **Write the report command** on the server. It reads the request from `SSH_ORIGINAL_COMMAND` and matches it whole.

   ```bash
   sudo tee /usr/local/bin/<command> >/dev/null <<'EOF'
   #!/usr/bin/env bash
   set -euo pipefail
   case "${SSH_ORIGINAL_COMMAND:-}" in
     checks)  exec sudo -n /usr/local/bin/report-health --check-only ;;
     history) exec sadf -j -- -u -r -q -F ;;
     *)       echo "unknown request" >&2; exit 2 ;;
   esac
   EOF
   sudo chmod 755 /usr/local/bin/<command>
   ```

   Expected: `SSH_ORIGINAL_COMMAND='checks; id' /usr/local/bin/<command>` prints `unknown request` and exits 2.
   Never pass the request to `eval`, `sh -c` or an unquoted expansion: each turns it into a shell command.

2. **Allow the one root command** the report needs. With `sudo -n`, a missing rule fails at once instead of prompting.

   ```bash
   echo '<user> ALL=(root) NOPASSWD: /usr/local/bin/report-health --check-only' > /tmp/<command>.sudoers
   sudo visudo -cf /tmp/<command>.sudoers
   sudo install -m 440 -o root -g root /tmp/<command>.sudoers /etc/sudoers.d/<command>
   rm /tmp/<command>.sudoers
   ```

   Expected: `visudo` prints `parsed OK`, and `sudo -n -l` lists the command with its argument.
   A rule that names arguments allows that exact argument list only.
   The last matching rule wins, and Debian reads `/etc/sudoers.d` after the `sudo` group's rule.
   sudo skips a file in `/etc/sudoers.d` whose name holds a dot.

3. **Make the key** on your laptop, without a passphrase: the client turns the agent off, so nothing could unlock one.

   ```bash
   ssh-keygen -t ed25519 -N '' -C <key> -f ~/.ssh/<key>
   ```

   Expected: `~/.ssh/<key>` and `~/.ssh/<key>.pub` exist.

4. **Authorize the key for the command only.** `restrict` turns off forwarding, the PTY and `~/.ssh/rc`.
   `command=` runs in place of whatever the client asks for.

   ```bash
   printf 'restrict,command="/usr/local/bin/<command>" %s\n' "$(cat ~/.ssh/<key>.pub)" | ssh <host> 'cat >> ~/.ssh/authorized_keys'
   ```

   Expected: the server's `~/.ssh/authorized_keys` ends in `restrict,command="/usr/local/bin/<command>" ssh-ed25519 … <key>`.

## Read a report

```bash
ssh -i ~/.ssh/<key> -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes \
  -o ControlPath=~/.ssh/cm-<key>-%C -o ConnectTimeout=8 <host> checks
```

Expected: one tab-separated line per check, as [Add a health check](monitoring.md#add-a-health-check) defines it.
Parse the lines, not the exit status: a failing check and a refused `sudo` both exit 1.

### Why each client option

| Option | Why |
| --- | --- |
| `-i ~/.ssh/<key>`, `IdentitiesOnly=yes` | ssh offers the report key, and no key that only the agent holds |
| `IdentityAgent=none` | ssh cannot fall back to your login key in the agent; that login would run the request as a shell command |
| `BatchMode=yes` | ssh never prompts; a login key named by `IdentityFile` is skipped while it carries a passphrase |
| `ControlPath=~/.ssh/cm-<key>-%C` | A shared control path would carry the request over your open login, or leave a report-key master for later logins |
| `ConnectTimeout=8` | An unreachable host fails within 8 s instead of hanging the reader |

[templates/ssh_config](../templates/ssh_config) multiplexes a host over `~/.ssh/cm-%C`.
The report key's own path keeps the two apart and still reuses one connection across reads.
Command-line options do not reach a `ProxyJump` hop: the hop logs in with your client config and only forwards.

## Verify

From your laptop:

```bash
report() { ssh -i ~/.ssh/<key> -o IdentitiesOnly=yes -o IdentityAgent=none -o BatchMode=yes -o ControlPath=~/.ssh/cm-<key>-%C -o ConnectTimeout=8 <host> "$@"; }
report checks; echo "exit $?"
report 'checks; id'; echo "exit $?"
report; echo "exit $?"
report history | head -c 13; echo
```

Expected: the check lines and `exit 0`, or `exit 1` beside a `fail` line.
The next two print `unknown request` and `exit 2`; the bare one may first print `PTY allocation request failed`.
`history` prints `{"sysstat": {`.

Sources: [sshd(8)](https://man.openbsd.org/sshd.8), [ssh_config(5)](https://man.openbsd.org/ssh_config.5), [sudoers(5)](https://www.sudo.ws/docs/man/sudoers.man/), [sadf(1)](https://manpages.debian.org/trixie/sysstat/sadf.1.en.html).
