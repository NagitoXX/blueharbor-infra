# Incident report: reconnaissance and SSH brute force against WEB01 (Exercise 5.5)

| | |
|---|---|
| **Incident ID** | INC-2026-11-13-01 (drill) |
| **Date** | 13/11/2026, 09:24 to 09:30 UTC |
| **Reported by** | Suricata alert, fail2ban ban |
| **Handled by** | IT, Linux administration |
| **Severity** | Low: no access gained, no service impact |
| **Status** | Closed |

All times are UTC. The clocks of WEB01 and WEB02 were synchronised by NTP (`System clock synchronized: yes`), so the attacker's notes and the server logs can be compared to the second.

Evidence: [evidence/incident/](evidence/incident/).

## 1. Summary

Between 09:24 and 09:28, the server **WEB02 (10.10.20.21)** attacked **WEB01 (10.10.20.20)** from inside the server network:

- a TCP SYN port scan;
- an HTTP request carrying the output of a root `id` command;
- five SSH logins with invalid user names.

The attacker was played by IT for the drill.

- **Detection.** The HTTP payload was detected by Suricata in the same second it was sent.
- **Containment.** fail2ban banned the source from SSH 10 seconds after the first login attempt.
- **Impact.** The attacker learned that WEB01 exposes SSH and HTTP, nothing more. No account was accessed, no data left the server, and the website stayed up the whole time.
- **Gap.** The port scan itself **raised no alert**: it is only visible in rate-limited firewall logs.

## 2. Timeline

| # | Time (UTC) | Source | Event | Evidence |
|---|-----------|--------|-------|----------|
| 1 | 09:24:28 | WEB02 (attacker notes) | Drill starts on WEB02 | [attacker-notes.txt](evidence/incident/attacker-notes.txt) |
| 2 | 09:24:33.567 | WEB01 ufw (kernel) | First `[UFW BLOCK]` from 10.10.20.21: SYN to port 113. Then 21, 23, 25, 199, 256, 3306, 3389 and 8080 within 25 ms | [ufw-syslog-tail.txt](evidence/incident/ufw-syslog-tail.txt), [ufw-kernel.txt](evidence/incident/ufw-kernel.txt) |
| 3 | 09:24:33 → 09:24:38 | WEB02 nmap | `nmap -sS -T4 10.10.20.20`: 1 000 ports in 5.33 s. Result: 22/tcp and 80/tcp open, 998 filtered | [attacker-nmap.txt](evidence/incident/attacker-nmap.txt) |
| 4 | 09:24:34.684 | WEB01 ufw (kernel) | Last logged block (SYN to 3306). Only **10 lines** are logged for about 998 blocked probes (rate limit of ufw `low` logging) | [ufw-kernel.txt](evidence/incident/ufw-kernel.txt) |
| 5 | 09:26:06 | WEB01 nginx | `GET /?q=uid=0(root)` from 10.10.20.21, `curl/8.5.0`, answer 200 | [nginx-access.txt](evidence/incident/nginx-access.txt) |
| 6 | 09:26:06.928 | WEB01 Suricata | **Alert** `[1:2100498:7] GPL ATTACK_RESPONSE id check returned root`, Priority 2, 10.10.20.21:49264 → 10.10.20.20:80 | [fast.log](evidence/incident/fast.log), [eve-alerts.json](evidence/incident/eve-alerts.json) |
| 7 | 09:27:20 → 09:27:21 | WEB01 sshd | `Invalid user admin`, `test`, `oracle`, `ubuntu`, `deploy` from 10.10.20.21; each one `Connection closed ... [preauth]` | [journal-ssh.txt](evidence/incident/journal-ssh.txt) |
| 8 | 09:27:30.180 → .233 | WEB01 fail2ban | 5 × `[sshd] Found 10.10.20.21` (the journal is read about 10 s after the attempts) | [fail2ban-log.txt](evidence/incident/fail2ban-log.txt) |
| 9 | 09:27:30.822 | WEB01 fail2ban | **`[sshd] Ban 10.10.20.21`** (nftables set `addr-set-sshd`, port 22 rejected for 15 min) | [fail2ban-log.txt](evidence/incident/fail2ban-log.txt), [fail2ban-status.txt](evidence/incident/fail2ban-status.txt) |
| 10 | 09:28:31 | WEB02 (attacker notes) | Attacker retries. SSH → `Connection refused`; HTTP → `succeeded` (the ban only covers SSH) | [attacker-notes.txt](evidence/incident/attacker-notes.txt) |
| 11 | ~09:29 | WEB01 (responder) | Evidence collected as root: fast.log, eve.json, fail2ban status and log, sshd journal, ufw/syslog lines, nginx log | this folder |
| 12 | 09:30:31 | WEB01 (responder) | Recovery: `fail2ban-client set sshd unbanip 10.10.20.21` → banned 0. `curl -I localhost` → `200 OK`. suricata, fail2ban, nginx and ssh all `active` | [recovery.txt](evidence/incident/recovery.txt) |

Attacker side as written down by WEB02 (`attacker-notes.txt`):

```
2026-11-13T09:24:28Z 0 drill start on web02
2026-11-13T09:24:33Z 1 SYN scan nmap -sS -T4 10.10.20.20
2026-11-13T09:24:38Z 1 scan finished
2026-11-13T09:26:06Z 2 HTTP request carrying uid=0(root)
2026-11-13T09:27:14Z 3 SSH attempts with invalid users
2026-11-13T09:27:21Z 3 SSH attempts finished
2026-11-13T09:28:31Z 4 retry SSH and HTTP
2026-11-13T09:28:31Z 5 drill end
```

The workbook's Suricata test URL (`testmynids.org`) now returns a parked "domain for sale" page and no longer triggers the signature (see [ids.md](ids.md)). Phase 2 therefore sent the same string (`uid=0(root)`) to WEB01 in the URL of a normal HTTP request. That string is what the signature looks for.

## 3. Impact

| Area | Impact |
|------|--------|
| **Confidentiality** | No data accessed. The attacker learned that 22 (SSH) and 80 (HTTP) are open. A `-sV` scan, not run here, would also have given the versions (see [exposure.md](exposure.md)). |
| **Integrity** | None. Every SSH attempt failed before authentication (`[preauth]`): the user names do not exist, and SSH accepts keys only. No file changed on WEB01. |
| **Availability** | None. The website answered 200 throughout, including to the banned host. Suricata and fail2ban ran without restarts. |
| **Business** | None for TrackIt users. About 30 minutes of IT time for the response and this report. |

## 4. Detection

| Attack step | What saw it | Raised an alert? | Delay |
|-------------|-------------|------------------|-------|
| SYN scan (09:24:33) | ufw logging only: 10 `[UFW BLOCK]` lines out of about 1 000 probes | **No.** No Suricata signature fired, and nothing was sent to anyone | - (visible only to someone reading the log) |
| HTTP `uid=0(root)` (09:26:06) | Suricata sid 2100498 | **Yes,** Priority 2, in `fast.log` and `eve.json` | **< 1 s** (09:26:06.928) |
| SSH invalid users (09:27:20) | sshd journal → fail2ban | **Yes,** `Found` then `Ban` in `fail2ban.log` | Ban **10.8 s** after the first attempt (journal read at 09:27:30) |

**What worked:**

- **Signature detection is immediate.** Suricata matched the payload in the same packet.
- **Blocking is automatic.** No human had to act: the source was contained in about 10 seconds.
- **All logs agree.** The same events appear in nginx, Suricata, the sshd journal, fail2ban and the attacker's notes, at matching times. The timeline above can be proven line by line.

**What did not work:**

- **The scan, the first step of every attack, went unnoticed.** None of the 53 428 enabled ET Open rules fired for a plain SYN scan of the common ports.
- **ufw logging hides most of the scan.** The `low` level is rate-limited, so 10 logged lines represent about 1 000 probes.
- **Nobody was told.** Every alert stayed in a file on WEB01. Without someone reading `fast.log` and `fail2ban.log`, detection would have happened only on paper.

## 5. Response

| Phase | What was done | Time |
|-------|---------------|------|
| **Containment** | Automatic: fail2ban banned 10.10.20.21 on port 22 for 15 minutes (nftables `reject`). HTTP was left open: the web requests were harmless, and blocking a server's IP entirely could break TrackIt between WEB01 and WEB02. | 09:27:30 |
| **Analysis** | Evidence collected on WEB01 as root, then copied to the repository. The source was confirmed to be WEB02, an internal server, and the activity was confirmed to match the planned drill (attacker notes). | ~09:29 |
| **Eradication** | Drill: nothing to remove on WEB01, since no access was gained. The tools stay on WEB02 (`nmap`, installed in Exercise 5.3). In a real incident, an internal server attacking another one is **treated as compromised**: see the procedure below. | - |
| **Recovery** | Ban lifted by hand once the source was explained. Service check: HTTP 200; suricata, fail2ban, nginx and ssh active. | 09:30:31 |

What would change if this were real (WEB02 not under our control):

- **Isolate WEB02:** VirtualBox `setlinkstate1 off`, or a firewall rule. Do not just ban it on WEB01.
- **Keep evidence:** take a snapshot of WEB02 before touching it.
- **Look for the entry point** on WEB02: `last`, `/var/log/auth.log`, new users, `authorized_keys`, cron jobs and timers, recently changed files under `/etc` and `/usr/local`.
- **Rebuild:** recreate WEB02 from the `base-hardened` template rather than cleaning it.
- **Rotate secrets:** SSH host keys and any credential stored on WEB02.

## 6. Lessons learnt

1. **Detect the reconnaissance, not just the exploit.** A scan comes minutes or days before the real attack. That is the best moment to react, and today it is invisible. Add a local Suricata threshold rule, for example "more than 20 SYN to different ports from one source in 10 s". Raise ufw logging to `medium` on servers that face users.
2. **An alert nobody reads is not detection.** `fast.log`, `eve.json`, `fail2ban.log` and `ufw.log` are local, readable only by root, and push nothing. They need to reach a central place with a notification (Lab 07: central logging and monitoring).
3. **Automatic containment works, but only where it was set up.** fail2ban protected SSH on WEB01 only. The same brute force against WEB02 or DC01 would not have been stopped.
4. **The server network trusts itself too much.** WEB02 could scan WEB01 and open SSH sessions to it. Servers do not need SSH to each other: the [exposure table](exposure.md) (action 3) and the [risk register](risk-register.md) (DMZ) already say so.
5. **Synchronised clocks and UTC everywhere made the timeline easy.** Keep NTP on every host, and DC01 as the time source for the domain.
6. **Test tools age.** The workbook's test URL is dead. Keep our own test cases (local rule sid 9000001, the `uid=0(root)` request) to prove the IDS still works after each update.

## 7. Actions

| # | Action | Owner | Due | Status |
|---|--------|-------|-----|--------|
| 1 | Local Suricata rule to detect SYN scans (threshold on distinct ports per source) and test it with `nmap -sS` | Linux administrator | Lab 05 follow-up | Open |
| 2 | Ship `eve.json`, `fail2ban.log`, `auth.log` and `ufw.log` to a central log server; alert on Suricata priority ≤ 2 and on every fail2ban `Ban` | SysOps lead | Lab 07 | Open |
| 3 | Same fail2ban and ufw logging setup on WEB02 (and STOR01 when created), through Ansible (Lab 09) instead of by hand | Linux administrator | Lab 09 | Open |
| 4 | SSH on the Linux servers only from the admin sources, not from the whole server network | Linux administrator | Next change window | Open |
| 5 | Add `suricata-update` to a daily timer, followed by `suricatasc -c reload-rules` | Linux administrator | Lab 05 follow-up | Open |
| 6 | Write the incident response procedure and contacts into the dossier | Security officer (IT lead) | 13/11/2026 | **Done** (dossier, Operations) |
| 7 | Repeat the drill every quarter, varying the source (a user PC, the Internet once the web tier is exposed) | Security officer | Quarterly | Planned |
