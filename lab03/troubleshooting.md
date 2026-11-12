# Troubleshooting challenge: broken WEB01 (Exercise 3.5)

12/11/2026, WEB01. Safety snapshot `before-break` taken first (VM powered off, so it was quick). The fault-injection script was decoded on the laptop and read before it ran, as a safety rule (never run unread code as root). The diagnosis below still followed the method, and each fault was found by its own command.

Scripts: [diagnose.sh](diagnose.sh) (read-only, in the order of the method) and [repair.sh](repair.sh). Evidence: [evidence/diag-before.txt](evidence/diag-before.txt) and [evidence/diag-after.txt](evidence/diag-after.txt).

**Reported symptom:** the TrackIt status page is down. `curl -I http://localhost` → `Failed to connect to localhost port 80`.

## Method

| Step | Command | What it showed |
|------|---------|----------------|
| 1. Service state | `systemctl status nginx`, `systemctl list-units --failed` | nginx **masked** and inactive; no failed unit (a masked service is not "failed") |
| 2. Logs | `journalctl -p warning -b` | Nothing about the faults: they were admin actions, not errors |
| 3. Resources | `df -h /`, `du -xh / --max-depth=2 \| sort -h \| tail` | `/` at **88 %**; `/var/tmp` holds 18 GB |
| 4. Permissions | `ls -l /var/www/html` | page in mode **000** |
| 5. Scheduled jobs | `systemctl list-timers`, `systemctl is-enabled bh-health.timer` | `bh-health.timer` **disabled and inactive** |

Repair order: disk first (services need space to start and write logs), then the page, then nginx, then the timer.

## Faults

### Fault 1: nginx stopped and masked

| | |
|---|---|
| **Symptom** | Port 80 refuses connections; the status page is down. |
| **Evidence** | `systemctl status nginx` → `Loaded: masked`, `Active: inactive (dead) since 10:02:45`; `/etc/systemd/system/nginx.service -> /dev/null`. `list-units --failed` shows nothing. |
| **Cause** | `systemctl stop nginx` then `systemctl mask nginx`: masking links the unit to `/dev/null`, so it cannot be started, even by hand or at boot. |
| **Fix** | `systemctl unmask nginx && systemctl enable --now nginx` → `enabled`, `active (running)`. |
| **Detect earlier** | Check the service from outside, not only on the host: an HTTP probe (curl expecting 200) from DC01 or a monitoring tool. Add `systemctl is-active nginx` and `curl -fsI http://localhost` to `bh-health.sh`. `journalctl -p warning` misses a clean stop, so `journalctl -u nginx` is the log to read. |

### Fault 2: disk filled by a hidden file

| | |
|---|---|
| **Symptom** | `/` at 88 % (3 GB free of 25 GB), against 13 % normally. |
| **Evidence** | `df -h /` → `21G used, 88%`. `du -xh / --max-depth=2` → `/var/tmp 18G`. `ls -la /var/tmp` → `.bh-cache.bin`, 18 555 017 626 bytes, created at 10:02. |
| **Cause** | An 18.5 GB file pre-allocated with `fallocate`, sized to leave exactly 12 % free, and hidden by its leading dot. |
| **Fix** | Checked that no process used it (`fuser`), then `rm /var/tmp/.bh-cache.bin` → `df -h /` = 13 %. |
| **Detect earlier** | `bh-health.sh` already raises WARN at 80 %, but its timer had been disabled (fault 4), so nobody was warned. Alerting must not depend on a single local timer. Also: `/var` and `/var/tmp` on their own partition (Lynis FILE-6310), and `du` sorted by size as the first reflex. |

### Fault 3: web page unreadable

| | |
|---|---|
| **Symptom** | Once nginx runs again, the page would return 403 Forbidden. |
| **Evidence** | `ls -l /var/www/html/` → `---------- 1 root root 615 index.nginx-debian.html` (mode 000). nginx runs as `www-data` and cannot read it. |
| **Cause** | `chmod 000` on the site files. |
| **Fix** | `chmod 644 /var/www/html/index.nginx-debian.html` → `-rw-r--r--`; `curl -I http://localhost` → `200 OK`. |
| **Detect earlier** | The HTTP probe from fault 1 (it would see 403 instead of 200). nginx's `error.log` shows `Permission denied`. File-integrity monitoring (AIDE, Lynis FINT-4350) flags permission changes on web content. |

### Fault 4: health-check timer disabled

| | |
|---|---|
| **Symptom** | `/var/log/bh-health.log` stopped growing: the last line is 10:00:12, then nothing, although the disk filled at 10:02. |
| **Evidence** | `systemctl list-timers` no longer shows `bh-health.timer`; `systemctl is-enabled` → `disabled`, `is-active` → `inactive`. |
| **Cause** | `systemctl disable --now bh-health.timer`. This is what hid fault 2. |
| **Fix** | `systemctl enable --now bh-health.timer` and one manual run (`systemctl start bh-health.service`) → new line at 10:04:18 `disk=13% status=OK`; next run 10:10. |
| **Detect earlier** | Watch for the absence of the signal (a "heartbeat" or "dead man's switch"): alert when the last line of `bh-health.log` is older than 10 minutes, from another machine. Check the timer state in configuration management (Ansible, Lab 05) so drift is corrected automatically. |

## Result

| Check | Before | After |
|-------|--------|-------|
| `curl -I http://localhost` | Failed to connect | `HTTP/1.1 200 OK` |
| `df -h /` | 88 % | 13 % |
| `bh-health.timer` | disabled, inactive | enabled, active, runs every 5 min |
| `/var/www/html/index.nginx-debian.html` | `----------` | `-rw-r--r--` |

## Lesson

The four faults reinforced each other: the disabled timer hid the full disk, and the masked service hid the broken permissions. A health check that runs on the server it watches can be switched off with that server. The most useful improvement is an outside check: an HTTP probe plus a heartbeat on the health log.
