# USE report - WEB01 (Exercise 3.3)

WEB01: Ubuntu 24.04, 2 vCPU, 1.9 GiB RAM, **no swap**, one 25 GB disk (`sda2` on `/`). The disk file sits on the laptop's external USB drive (D:). Measured on 12/11/2026 between 09:33 and 09:38 UTC, from an SSH session as opsadmin. Raw outputs: [evidence/use/](evidence/use/).

| Phase | Command | Files |
|-------|---------|-------|
| Baseline (1 min, idle) | `vmstat 2 30`, `mpstat -P ALL 2 5`, `iostat -xz 2 5`, `free -h`, `sar -n DEV,EDEV 2 5` | `base-*.txt` |
| CPU load | `stress-ng --cpu 2 --timeout 60s --metrics-brief` | `cpu-*.txt` |
| Memory pressure | `stress-ng --vm 1 --vm-bytes 90% --timeout 60s` | `mem-*.txt` |
| Disk load | `stress-ng --hdd 1 --timeout 60s` | `disk-*.txt` |
| Network and errors | `ip -s link`, `sar -n DEV,EDEV`, `ss -s`, `journalctl -k -p warning -b` | `net-*.txt`, `errors.txt` |

## USE table

| Resource | Utilisation (value, tool) | Saturation (value, tool) | Errors (where you looked) |
|----------|---------------------------|--------------------------|---------------------------|
| **CPU** | Baseline: 94.7 % idle, 0 % user (`mpstat`). Load: **0 % idle**, user 75-100 % (`vmstat` us/id); each stress-ng worker at 83 % (`top`). | Baseline: run queue `r` = 0. Load: **`r` = 2 to 9** for 2 vCPU (`vmstat`), so up to 4 tasks wait per CPU; load average rising (0.95 after 30 s, `top`). | None. `journalctl -k -p warning`: no CPU errors; `%steal` = 0 (`mpstat`). |
| **Memory** | Baseline: 410 MiB used of 1.9 GiB, 1.5 GiB available (`free -h`). Load: **912 MiB used, 65 MiB free**, 1.0 GiB available (`free -h` at 20 s); `free` down to 64 MB (`vmstat`). | `si`/`so` = 0 all along (`vmstat`), because **there is no swap** (`swapon --show` empty). The kernel reclaimed page cache instead: cache 1.21 GB → 1.14 GB (`vmstat`). | No OOM kill and no allocation failure (`journalctl -k -b`, grep oom). |
| **Disk** | Baseline: `%util` 0.3-2.8 %, writes 0.1-0.6 MB/s (`iostat -xz`). Load: **`%util` 88-99 %**, writes 12-54 MB/s (`iostat -xz`). | Baseline: `aqu-sz` 0.02-0.21, `w_await` 0.7-6.4 ms. Load: **`aqu-sz` 7-22, `w_await` 120-1070 ms** (`iostat -xz`); `wa` (I/O wait) 38-95 % and 1-4 processes blocked (`b`) (`vmstat`). | No I/O error (`journalctl -k`, grep i/o error / reset). Kernel warnings `blk_mq_run_work_fn hogged CPU` show slow block I/O in the VM, not a fault. |
| **Network** | `enp0s3`: 3 packets/s, 0.7 kB/s, `%ifutil` 0.00 (`sar -n DEV`). Not loaded in this exercise. | No drops: `rxdrop/s` = `txdrop/s` = 0 (`sar -n EDEV`); 1 established TCP connection (`ss -s`). | 0 errors, 0 dropped on RX and TX (`ip -s link`), 0 `rxerr/s`/`txerr/s` (`sar -n EDEV`). |

Note: `mpstat` inside VirtualBox shows odd values under load (`%soft` 7-50 %, a misleading average because samples stretched); `vmstat` and `top` give the consistent picture.

## Conclusion

**The disk saturates first.** A single writer (`stress-ng --hdd 1`) is enough to keep the disk at 88-99 % busy, with a queue of 7 to 22 requests and writes waiting 0.1 to 1 s. The CPU then spends up to 95 % of its time waiting for I/O. The cause is mostly the platform: the VM's disk file is on an external USB hard drive. For a web server that writes logs and serves files, that is the bottleneck users would feel first.

The CPU only saturated because two CPU-bound workers were started on purpose for two vCPUs; at idle it is 95 % free. Memory held 90 % pressure without failing, but only by dropping cache: with no swap, a real peak would end in an OOM kill instead of a slowdown.

What I would change:

1. **Disk:** move WEB01's disk file from the USB drive to the laptop's internal SSD, and turn on host I/O caching for the controller (`VBoxManage storagectl WEB01 --name SATA --hostiocache on`). In production: SSD storage, logs on a separate volume, and an `await`/`%util` alert.
2. **Memory:** add a 1 GB swap file with a low `vm.swappiness` (10), so a peak slows the server down instead of killing nginx.
3. **Monitoring:** extend `bh-health.sh` with an I/O-wait check (field `wa` from `vmstat 1 2`) so disk saturation shows up in the log and the journal, not only disk space.
4. **CPU:** no change; 2 vCPU are enough for this load.
