# System Info and Resource Usage

Monthly thresholds and fixes: [maintenance.md](../guides/maintenance.md#verify).

```bash
sudo apt install fastfetch btop ncdu nvtop sysstat   # friendlier add-ons; the rest ships with Ubuntu
```

## What is this machine

| Question                       | Command                              |
| ------------------------------ | ------------------------------------ |
| OS, kernel, VM or bare metal   | `hostnamectl`                        |
| CPU model and core count       | `lscpu`, short `nproc`               |
| RAM total                      | `free -h`                            |
| Disks and partitions           | `lsblk`                              |
| GPU                            | `lspci \| grep -iE 'vga\|display'`   |
| All of the above on one screen | `fastfetch`                          |

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
| GPU live          | `nvtop`                        | engine and memory use       |                                   |

`free` looks low because Linux fills spare RAM with file cache. The kernel frees it on demand.

## Reading htop

| Element               | Meaning                                                                   |
| --------------------- | ------------------------------------------------------------------------- |
| `0[` … `N[` bars      | one bar per core                                                          |
| `Mem` bar colours     | green programs, blue buffers, yellow file cache; the number counts programs only |
| `Load average`        | processes running or waiting on CPU or disk; compare to the core count    |
| `CPU%`                | 100 is one full core; the maximum is 100 × cores                          |
| `RES`                 | RAM the process really uses; ignore `VIRT`, which counts reservations      |
| `S`                   | `R` running, `S` sleeping, `D` waiting on disk                            |
| Green process rows    | threads of the process above, not separate processes                      |

| Key       | Action                          |
| --------- | ------------------------------- |
| `H`       | hide threads, the biggest declutter |
| `F5`      | tree view                       |
| `P` / `M` | sort by CPU / memory            |
| `F3`      | search                          |
| `F9`      | send a signal, e.g. kill        |
| `q`       | quit                            |
