# Central logging with rsyslog (Exercise 7.5)

Done on 17/11/2026.

- **Collector:** WEB01 (10.10.20.20).
- **Sender:** WEB02 (10.10.20.21).
- **Deployment:** with Ansible, not by hand: [ansible/logging.yml](../ansible/logging.yml) installs [10-receive.conf](../ansible/files/rsyslog/10-receive.conf) on WEB01 and [90-forward.conf](../ansible/files/rsyslog/90-forward.conf) on WEB02.
- **Evidence:** [evidence/7.5/](evidence/7.5/).

## Flow

```
WEB02: every program -> journald -> rsyslog --TCP 514--> WEB01: rsyslog (imtcp)
                                   (queue if WEB01 down)        -> /var/log/remote/<host>/<program>.log
```

| Setting | Where | Effect |
|---------|-------|--------|
| `module(load="imtcp")`, `input(type="imtcp" port="514")` | WEB01 | Listen on TCP 514 (`ss -tlnp`: `rsyslogd` on 0.0.0.0:514 and [::]:514) |
| `template PerHost` = `/var/log/remote/%HOSTNAME%/%PROGRAMNAME%.log` | WEB01 | One directory per sending host, one file per program |
| `if $inputname == "imtcp" then { ... stop }` | WEB01 | Remote messages go only to `/var/log/remote`, never into WEB01's own `syslog` |
| ufw `allow from 10.10.20.0/24 to any port 514 proto tcp` | WEB01 | Only the server network can send logs |
| `*.* action(type="omfwd" target="10.10.20.20" port="514" protocol="tcp" ...)` | WEB02 | Every message is forwarded, over TCP rather than UDP so that a lost message is retried |
| `queue.type="LinkedList" action.resumeRetryCount="-1"` | WEB02 | While WEB01 is unreachable, messages wait in an in-memory queue and the forward is retried forever |

## Deployment run

`ansible-playbook logging.yml -K` (`playbook-run.txt`):

| Host | Result | Changes |
|------|--------|---------|
| web01 | ok=6, **changed=4**, failed=0 | directory, receive config, ufw rule, rsyslog restart (handler) |
| web02 | ok=4, **changed=2**, failed=0 | forward config, rsyslog restart |

**First attempt failed, on purpose kept in the notes.** The copy used `validate: rsyslogd -N1 -f %s`, and it failed with `Permission denied`:

- AppArmor confines `rsyslogd`, so it may not read Ansible's temporary file under `/home/opsadmin/.ansible/tmp`;
- the playbook stopped before changing anything.

The fix:

1. Copy the file.
2. Run `rsyslogd -N1` on the whole configuration (`changed_when: false`).
3. Restart rsyslog only through the handler.

Handlers run at the end of the play, and only if the play has not failed. So rsyslog is never restarted on a configuration that fails the check.

## Tests

| UTC | Step | Result |
|-----|------|--------|
| 13:06:25 | `ss -tlnp \| grep :514` on WEB01 | `rsyslogd` listening |
| 13:06:26 | WEB02: `logger -t bhtest "hello from web02"` | `/var/log/remote/web02/bhtest.log`: `2026-11-17T13:06:26+00:00 web02 bhtest: hello from web02`. The directory already holds `kernel.log`, `sshd.log`, `sudo.log`, `systemd.log`, `systemd-logind.log`, `rsyslogd.log` |
| 13:06:29 | WEB01: `systemctl stop syslog.socket rsyslog.service` (collector down) | both `inactive` |
| 13:06:29 / 13:06:49 / 13:07:10 | WEB02: three `logger -t bhtest "queued message N, ..."` | nothing new in `bhtest.log` while the collector is stopped |
| 13:06:29 → 13:07:29 | WEB02 `rsyslogd.log` | `cannot connect to 10.10.20.20:514: Connection refused`, retried every 30 s |
| 13:07:30 | WEB01: `systemctl start rsyslog.service` | `active` |
| 13:07:59 | WEB02 `rsyslogd.log` | `action 'action-8-builtin:omfwd' resumed` |
| 13:08:39 | WEB01: `sudo cat /var/log/remote/web02/bhtest.log` | **all 3 queued messages present**, with their original times (13:06:29, 13:06:49, 13:07:10) |

**Checkpoint:** WEB02's logs appear under `/var/log/remote/web02/`, including the three messages sent while the collector was stopped.

- **Delay.** They arrived at the next retry, 29 s after the restart. A check 25 s after the restart did not show them yet. Forwarding resumes on the sender's retry interval, not instantly.
- **Socket activation.** `systemctl stop rsyslog` alone is not enough to stop the collector on Ubuntu. `syslog.socket` restarts the service as soon as a local message arrives (the first try showed `Stopping 'rsyslog.service', but its triggering units are still active: syslog.socket`).

## Three useful searches

The remote files belong to `syslog` (directory mode 0700), so reading them needs `sudo` on WEB01.

### 1. Failed SSH logins, on every host

```bash
# Central: every host that forwards its logs
sudo grep -hE "Invalid user|Failed password|authentication failure" /var/log/remote/*/sshd.log
# Who is trying, most active source first
sudo grep -hoE "(Invalid user \S+|Failed password for \S+) from [0-9.]+" /var/log/remote/*/sshd.log | awk '{print $NF}' | sort | uniq -c | sort -rn
# Local: the collector itself
sudo journalctl -u ssh --since today --no-pager | grep -E "Invalid user|Failed password"
```

Result in the test (three invalid users tried from WEB01 against WEB02):

```
2026-11-17T13:07:55+00:00 web02 sshd[12642]: Invalid user admin from 10.10.20.20 port 58252
2026-11-17T13:07:55+00:00 web02 sshd[12644]: Invalid user test from 10.10.20.20 port 58258
2026-11-17T13:07:55+00:00 web02 sshd[12646]: Invalid user oracle from 10.10.20.20 port 58262
```

**Use:** the same brute force spread over several servers stays under the threshold of each server's fail2ban (4 failures in 10 min). It only shows when all hosts are searched together. The Lab 05 incident drill would have been read here in one command.

### 2. bh-health warnings

```bash
sudo grep -h "WARN" /var/log/remote/*/bh-health.log     # central
journalctl -t bh-health --since today --no-pager         # local
```

Result: **no entries**, which is expected: disk and memory were below 80 % / 90 % on both servers. `bh-health.sh` (Lab 03) only calls `logger -t bh-health` when its status is `WARN`, so any line here is worth reading. The file `bh-health.log` only appears under `/var/log/remote/web02/` after WEB02's first warning.

### 3. sudo usage

```bash
sudo grep -h "COMMAND=" /var/log/remote/*/sudo.log                          # central
sudo journalctl _COMM=sudo --since today --no-pager | grep "COMMAND="        # local
# Only privileged commands run by people (not by Ansible's become)
sudo grep -h "COMMAND=" /var/log/remote/*/sudo.log | grep -v "BECOME-SUCCESS"
```

Result on WEB01 (local), the test script running `ssh` as opsadmin:

```
Nov 17 13:07:55 web01 sudo[28532]: root : TTY=pts/0 ; PWD=/home/haytam ; USER=opsadmin ; COMMAND=/usr/bin/ssh ... admin@10.10.20.21 true
```

Each line says **who** (`haytam` through `root`), **as whom** (`USER=opsadmin`), **where** (`TTY`, `PWD`) and **what** (`COMMAND=`). That is the audit trail of the "named admin + sudo" rule from Lab 03.

WEB02's own `sudo.log` existed but contained no `COMMAND=` line during the test. The only `sudo` run on WEB02 was Ansible's `become` during the playbook, before rsyslog restarted with forwarding enabled.

## Limits and next steps

- **Memory queue only.** A reboot of WEB02 while WEB01 is down loses the waiting messages. Fix: `queue.filename="fwd"` plus `queue.saveOnShutdown="on"` for a disk-assisted queue.
- **Plain TCP.** The logs travel unencrypted and the collector accepts any sender in 10.10.20.0/24. A compromised server could also inject fake lines. Fix: TLS (gtls) with certificates, or RELP for acknowledged delivery.
- **No rotation for `/var/log/remote` yet.** Fix: a logrotate rule (daily, 30 days, compress), or the disk of the collector fills up. bh-health's 80 % alert would catch it, which is how the problem would show up.
- **WEB01 is collector, monitor and web server at once.** If it fails, logs, metrics and the website go together. In production, logging gets its own host.
- **Search is grep.** Fine for two servers. With more hosts or volume, a log platform (Loki with Grafana, or Elastic) indexes the same files and adds dashboards and alerts on log content.
