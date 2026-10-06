# Host History with sysstat

Record a server's CPU, memory, load, disk, network and filesystem fill every minute, kept 28 days on the host.
`sar` reads the record back; `sadf -j` prints it as JSON for a script.

Debian 13's sysstat package (12.7.5) ships with collection off, and its defaults keep a coarse record.
A data file keeps the activities it was created with, so the settings go in before the first file.

| Setting | Debian default | This guide | Why |
| --- | --- | --- | --- |
| debconf `sysstat/enable` | `false`: the units stay disabled | `true` | Nothing collects until the answer is `true` |
| Collect timer | `OnCalendar=*:00/10` | `OnCalendar=*:*:00` | A ten-minute mean hides a one-minute spike |
| `HISTORY` | `7` days | `28` | Four weeks to compare; above 28, sadc names files `saYYYYMMDD` instead of `saDD` |
| `COMPRESSAFTER` | `10` days, then xz | `31` | `sadf` cannot read an xz file; past `HISTORY`, none is ever compressed |
| `SADC_OPTIONS` | `-S DISK` | `-S XDISK` | Adds partition and filesystem statistics, which `sar -F` reads |

## Prerequisites

- A Debian 13 server provisioned per [provision-server.md](provision-server.md), with SSH as `<user>` and `sudo`.
- Room on `/var/log/sysstat` for 28 daily files; [Verify](#verify) reads the size of the first full day.

## Record every minute

1. **Write the settings** before the install, so the first data file already collects filesystem statistics.
   The last four lines are Debian's own values.

   ```bash
   sudo install -d -m 755 /etc/sysstat
   sudo tee /etc/sysstat/sysstat >/dev/null <<'EOF'
   HISTORY=28
   COMPRESSAFTER=31
   SADC_OPTIONS="-S XDISK"
   SA_DIR=/var/log/sysstat
   ZIP="xz"
   DELAY_RANGE=0
   UMASK=0022
   EOF
   ```

   Expected: `cat /etc/sysstat/sysstat` prints the seven lines.

2. **Collect every minute.** The empty `OnCalendar=` clears the shipped schedule; without it, both schedules fire.

   ```bash
   sudo install -d -m 755 /etc/systemd/system/sysstat-collect.timer.d
   printf '[Timer]\nOnCalendar=\nOnCalendar=*:*:00\n' | sudo tee /etc/systemd/system/sysstat-collect.timer.d/50-every-minute.conf >/dev/null
   ```

   Expected: `cat /etc/systemd/system/sysstat-collect.timer.d/50-every-minute.conf` prints the three lines.

3. **Answer debconf's question, then install.** `--force-confold` keeps the settings file from the first step.

   ```bash
   echo 'sysstat sysstat/enable boolean true' | sudo debconf-set-selections
   sudo apt-get update
   sudo apt-get install -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold sysstat
   ```

   Expected: `systemctl is-enabled sysstat` prints `enabled`, and `/etc/sysstat/sysstat` still holds `HISTORY=28`.
   On a host with sysstat installed already, follow [Enable an installed sysstat](#enable-an-installed-sysstat) instead.

4. **Start collecting.** The install enables the units but leaves them stopped until the next boot.
   `sysstat.service` pulls in the collect, summary and rotate timers.

   ```bash
   sudo systemctl daemon-reload
   sudo systemctl start sysstat.service
   ```

   Expected: `systemctl list-timers sysstat-collect.timer` shows `NEXT` within the coming minute.

## Verify

After a few minutes of collection, as `<user>`:

```bash
systemctl list-timers sysstat-collect.timer   # NEXT within the coming minute
sar -u                                        # CPU: %user, %system, %iowait, %steal
sar -r                                        # memory: kbavail, %memused
sar -q                                        # load: ldavg-1, ldavg-5, ldavg-15
sar -F MOUNT                                  # filesystems by mount point: %ufsused, %Iused
sadf -j -- -F | head -n 1                     # the same record as JSON
```

Expected: each `sar` prints one row per minute since the start, then an `Average:` or `Summary:` row.
`sadf` prints `{"sysstat": {`.
After a full day, `ls -lh /var/log/sysstat` shows that day's `saDD` file; 28 of them must fit the disk.

`sar` reads today's file; `sar -r -f /var/log/sysstat/saDD` reads day `DD`.
[linux-services.md](../reference/linux-services.md#resource-usage) says when a reading needs action.

## Troubleshooting

### Enable an installed sysstat

Once `/etc/default/sysstat` exists, the package's config script copies its `ENABLED` into the debconf answer.
It does so on every configure, so a preseeded answer is overwritten.
Write the first two steps' files, then set `ENABLED` and reconfigure:

```bash
sudo sed -i 's/^ENABLED=.*/ENABLED="true"/' /etc/default/sysstat
sudo dpkg-reconfigure -f noninteractive sysstat
```

Expected: `systemctl is-enabled sysstat` prints `enabled`. Then start collecting as the last step does.

### `sar -F` finds no requested activities

The day's data file was created before `-S XDISK`, and it keeps the activities it was created with.
The next day's file holds them, so `sar -F` reads them from midnight on.

Sources: [sysstat](https://sysstat.github.io/), [sadc(8)](https://manpages.debian.org/trixie/sysstat/sadc.8.en.html), [sar(1)](https://manpages.debian.org/trixie/sysstat/sar.sysstat.1.en.html), [sadf(1)](https://manpages.debian.org/trixie/sysstat/sadf.1.en.html), [systemd.timer](https://www.freedesktop.org/software/systemd/man/latest/systemd.timer.html).
