# WEB01 hardening (Exercise 3.4)

Applied on 12/11/2026 on WEB01 (Ubuntu 24.04.5, 10.10.20.20). Scripts: [harden.sh](harden.sh) (steps 2-4), [cleanup.sh](cleanup.sh) (step 5), [lynis-fixes.sh](lynis-fixes.sh) (step 6). Evidence: [evidence/](evidence/).

## Lynis results

| Audit | When | Hardening index | Warnings | Suggestions | Report |
|-------|------|-----------------|----------|-------------|--------|
| Before | fresh WEB01 after Exercise 3.1-3.3 | **63** | 1 | 47 | [lynis-before.txt](evidence/lynis-before.txt) |
| After | after firewall, unattended upgrades, sysctl, service cleanup | **65** | 0 | 48 | [lynis-after.txt](evidence/lynis-after.txt) |
| Final | after the two Lynis suggestions below | **71** | 0 | 38 | [lynis-final.txt](evidence/lynis-final.txt) |

**The hardening index went from 63 to 71 (+8).**

- **Before → after (63 → 65):** the warning FIRE-4512 ("iptables module loaded, but no rules active") disappeared. The suggestion count went up by one because, with a firewall, Lynis now adds FIRE-4513 ("check which iptables rules are not used").
- **After → final (65 → 71):** 10 suggestions closed:
  - SSH-7408: 7 of its 8 points (only `Port` remains, kept on purpose);
  - BANN-7126 and BANN-7130 (legal banner);
  - NAME-4404 (`/etc/hosts`).

## What was changed

| Step | Change | Check |
|------|--------|-------|
| 2. Firewall | ufw: deny incoming, allow outgoing; allow 22/tcp from 10.10.20.0/24 only; allow 80/tcp | `ufw status verbose`; SSH from the laptop still works (it arrives from 10.10.20.1) |
| 3. Security updates | unattended-upgrades enabled (`APT::Periodic::Update-Package-Lists "1"`, `Unattended-Upgrade "1"`) | `/etc/apt/apt.conf.d/20auto-upgrades` |
| 4. Kernel network | `/etc/sysctl.d/99-bh.conf`: no ICMP redirects accepted or sent, log martian packets, SYN cookies on | `sysctl` shows 0 / 0 / 1 / 1 |
| 5. Services | 9 units disabled (below); 83 → 74 enabled unit files | `systemctl list-unit-files --state=enabled` |
| 6a. SSH (Lynis SSH-7408) | `/etc/ssh/sshd_config.d/20-lynis.conf`: no TCP or agent forwarding, no X11, `LogLevel VERBOSE`, `MaxSessions 2`, `ClientAliveCountMax 2`, `TCPKeepAlive no` | `sshd -T` |
| 6b. Banner (Lynis BANN-7126, BANN-7130) | legal warning in `/etc/issue` and `/etc/issue.net` | `cat /etc/issue` |
| Also | `/etc/hosts` was **empty**: standard content restored with `127.0.1.1 web01.blueharbor.internal web01` (Lynis NAME-4404) | `getent hosts web01` |

SSH hardening from Exercise 3.1 (`10-hardening.conf`: keys only, no root, 3 tries, group sudo) was already in place before the first audit.

## Listening ports

`sudo ss -tulpn` before and after the cleanup ([services-before.txt](evidence/services-before.txt)):

| Port | Process | Bound to | Why it stays |
|------|---------|----------|--------------|
| 22/tcp | sshd (socket-activated by systemd) | all addresses, IPv4 and IPv6 | Administration. Keys only, no root, `AllowGroups sudo`; ufw only lets in 10.10.20.0/24. |
| 80/tcp | nginx | all addresses, IPv4 and IPv6 | The TrackIt status page, the service WEB01 exists for. |
| 53/tcp and 53/udp | systemd-resolved | 127.0.0.53 and 127.0.0.54 only | Local DNS cache for WEB01 itself; not reachable from the network. |

No other port listens. HTTPS (443) is not open yet: there is no certificate (Lynis HTTP-6710, see the risks below).

## Services disabled

| Unit | Why it is not needed on WEB01 |
|------|-------------------------------|
| ModemManager.service | No modem in a VM |
| open-vm-tools.service, vgauth.service | Guest tools for VMware; WEB01 runs on VirtualBox |
| thermald.service | CPU thermal control; the host handles it, not the VM |
| udisks2.service | Desktop disk management |
| lxd-installer.socket | Installs LXD on demand; no containers on WEB01 |
| snapd.service, snapd.socket, snapd.seeded.service | No snap is installed or used (the server was installed without snaps) |
| cloud-init (via `/etc/cloud/cloud-init.disabled`) | No cloud datasource in VirtualBox; it could also rewrite the network config |

Kept on purpose: open-iscsi, iscsid and multipathd (Lab 04 connects WEB01 to iSCSI storage on STOR01), lynis.timer (daily audit), sysstat (performance history), apport (crash reports).

## Lynis suggestions not applied

| Suggestion | Reason |
|------------|--------|
| SSH-7408 `Port` (move SSH off 22) | Hides the service without protecting it; the firewall rule (22 from 10.10.20.0/24 only) and key-only login do the real work. |
| HTTP-6710 HTTPS on nginx | Needs a certificate; planned with the reverse proxy / PKI work in a later lab. Until then the status page has no sensitive data. |
| BOOT-5122 GRUB password | Console access already means VirtualBox access on the laptop; a GRUB password would block unattended reboots. |
| FILE-6310 separate /home, /tmp, /var | Requires re-partitioning; the 80 % disk alert in bh-health.sh covers the "full disk" risk for now. |
| AUTH-9230 / AUTH-9286 / AUTH-9262 password ageing and quality | SSH accepts keys only, so local passwords are only used for sudo and the console. To do with central identity (AD) later. |
| DEB-0880 fail2ban | Password login is off and SSH is limited to the lab network; fail2ban adds little today. Useful once SSH is exposed more widely. |
| ACCT-9628 auditd, FINT-4350 file integrity (AIDE), HRDN-7230 malware scanner, LOGG-2154 remote logging | Worth doing, but each needs storage and a review routine; planned with central logging (later lab). |
| KRNL-6000 other sysctl values, NETW-3200 unused protocols (dccp, sctp, rds, tipc), USB-1000 USB storage | Low risk on a VM with no USB devices; can be added to `99-bh.conf` and a modprobe blacklist in a next pass. |
