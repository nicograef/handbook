# Resource Usage

Monthly thresholds and fixes: [maintenance.md](../guides/maintenance.md#verify).

```bash
sudo apt install btop ncdu sysstat   # add-ons for the live view, ncdu and iostat; the rest ships with Ubuntu
```

## What is it doing now

| Resource          | Command                        | Read                        | Act when                          |
| ----------------- | ------------------------------ | --------------------------- | --------------------------------- |
| CPU               | `uptime`                       | load average (1, 5, 15 min) | above `nproc` for 15 min          |
| RAM               | `free -h`                      | `available` column only     | swap `used` keeps growing         |
| Disk space        | `df -h`                        | `Use%`                      | ≥ 80 %                            |
| What fills a disk | `sudo ncdu -x /`               | largest folders first       | one folder grows unexpectedly     |
| Disk I/O          | `iostat -xz 2`                 | `%util`                     | near 100 for minutes              |
| Top processes     | `ps aux --sort=-%cpu \| head`  | `%CPU`, `RSS`               | one process pins a core for hours |
| Everything live   | `btop`                         | one panel per resource      |                                   |

`free` looks low because Linux fills spare RAM with file cache. The kernel frees it on demand.
