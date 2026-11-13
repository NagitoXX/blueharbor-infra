# Attack surface of the servers (Exercise 5.3)

Audit done on 13/11/2026 from **WEB02** (10.10.20.21, nmap 7.94SVN), inside the server network. Only lab addresses were scanned.

**Two views of each server:**

- **From outside:** what nmap reaches through the network and the host firewall.
- **From inside:** what is really listening: `sudo ss -tulpn` on WEB01, `Get-NetTCPConnection -State Listen` on DC01.

A port that listens but is filtered is **not exposed**. A port that nmap sees open must have a reason to be.

Raw outputs:

| File | Content |
|------|---------|
| [nmap/1-discovery.txt](evidence/nmap/1-discovery.txt) | Host discovery |
| [nmap/2-services.txt](evidence/nmap/2-services.txt) | Service scan of DC01 and WEB01 |
| [nmap/3-web01-allports.txt](evidence/nmap/3-web01-allports.txt) | All 65 535 ports of WEB01 |
| [nmap/4-dc01-high-before.txt](evidence/nmap/4-dc01-high-before.txt) | DC01 high ports, before the fix |
| [nmap/5-dc01-high-after.txt](evidence/nmap/5-dc01-high-after.txt) | DC01 high ports, after the fix |
| [web01-ss-tulpn.txt](evidence/web01-ss-tulpn.txt) | WEB01 listeners with processes |
| [dc01-listeners.txt](evidence/dc01-listeners.txt) | DC01 listeners with processes |

## 1. Scans

| Command (on WEB02) | Result |
|--------------------|--------|
| `nmap -sn 10.10.20.0/24` | 4 hosts up: 10.10.20.1 (VirtualBox NAT gateway), DC01 .10, WEB01 .20, WEB02 .21 (the scanner). No unknown machine. |
| `sudo nmap -sS -sV -T4 10.10.20.10,20` (top 1000 ports) | DC01: 11 open ports, 989 filtered. WEB01: 2 open ports, 998 filtered. |
| `sudo nmap -p- --min-rate 1000 10.10.20.20` | WEB01: **22 and 80 only**. 65 533 ports filtered (no answer at all: ufw drops instead of rejecting). 226 s. |
| `sudo nmap -sS -sV -p 5985,9389,47001,49664-49800 10.10.20.10` | DC01 ports above 1000, which the top-1000 scan does not cover: WinRM, ADWS and the dynamic RPC ports. |

## 2. WEB01 (Ubuntu 24.04, ufw default deny)

| Port | Service (process) | nmap from WEB02 | Expected? | Who should reach it | Action |
|------|-------------------|-----------------|-----------|---------------------|--------|
| 22/tcp | SSH, OpenSSH 9.6p1 (`sshd`, socket-activated by `systemd`) | open | Yes: administration | Admins only: the laptop through 10.10.20.1 today, VLAN 10 later | **Filter.** ufw allows the whole server network 10.10.20.0/24, so WEB02 and DC01 can reach it too, and servers never need SSH to each other. Restrict to the admin source (`ufw allow from 10.10.10.0/24` + 10.10.20.1, then delete rule [1]). Key-only login and `AllowGroups sudo` limit the risk meanwhile. |
| 80/tcp | HTTP, nginx 1.24.0 (`nginx` master + 2 workers) | open | Yes: TrackIt status page, the reason WEB01 exists | Users, Admins, Warehouse | **Keep.** Add HTTPS (443) with a certificate, then redirect 80 → 443. Hide the version (`server_tokens off`): nmap read `nginx 1.24.0 (Ubuntu)` from the banner. |
| 53/tcp and 53/udp | DNS stub (`systemd-resolved`) on 127.0.0.53 and 127.0.0.54 | not visible | Yes: local name cache for WEB01 itself | WEB01 only | **Keep.** Bound to loopback, so it cannot be reached from the network. |
| `[::]:22`, `[::]:80` | Same services on IPv6 | not tested (no IPv6 on BH-SRV) | - | - | **Keep.** ufw has a v6 rule for 80 only, so SSH over IPv6 is already denied. |

**Result: `ss` and nmap agree.** WEB01 has 2 network listeners, and nmap sees exactly those 2. Nothing listens that should not.

## 3. DC01 (Windows Server 2025, AD DS + DNS, Defender Firewall on)

| Port | Service (process) | nmap from WEB02 | Expected? | Who should reach it | Action |
|------|-------------------|-----------------|-----------|---------------------|--------|
| 53/tcp | DNS (`dns`) | open | Yes | All internal zones (clients and servers resolve through DC01) | **Keep.** Never from the Internet. |
| 88/tcp | Kerberos (`lsass`) | open | Yes: domain logon | All domain members | **Keep.** |
| 464/tcp | Kerberos password change (`lsass`) | open | Yes | All domain members | **Keep.** |
| 135/tcp | RPC endpoint mapper (`svchost`) | open | Yes: AD management, GPO, replication | Domain members | **Keep,** internal zones only. |
| 593/tcp | RPC over HTTP endpoint mapper (`svchost`) | open | Yes, installed with AD DS | Domain members | **Keep,** internal only. |
| 49664, 49667, 49668, 49677, 49700/tcp | Dynamic RPC for AD: LSA, Netlogon, replication (`lsass`) | open | Yes | Domain members | **Keep.** These ports are chosen at boot; the firewall rules follow the service, not the port number. |
| 49698/tcp | Dynamic RPC for DNS management (`dns`) | open | Yes | Admins | **Filter** to Admins (DNS console, `dnscmd`). |
| 49774/tcp | DFS Replication of SYSVOL (`dfsrs`) | open | Yes: replicates GPO files between DCs | Other domain controllers | **Keep** (only one DC today). |
| 389/tcp | LDAP (`lsass`) | open | Yes: directory queries | Domain members | **Keep.** Plan LDAP signing and channel binding, so credentials do not travel unsigned. |
| 636/tcp | LDAPS (`lsass`) | open, `tcpwrapped` | Yes in principle | Domain members | **Keep.** It answers without a certificate today (no AD CS). Install a certificate, then require LDAPS. |
| 3268, 3269/tcp | Global Catalog, LDAP and LDAPS (`lsass`) | open | Yes: forest-wide searches | Domain members | **Keep.** |
| 445/tcp | SMB (`System`): Finance share, SYSVOL and NETLOGON (GPO) | open | Yes | Users and Admins | **Keep.** Require SMB signing; SMBv1 is off by default on Server 2025. |
| 139/tcp | NetBIOS session service (`System`) | open | **No:** legacy, SMB runs directly on 445 | Nobody | **Close later:** disable NetBIOS over TCP/IP on the network adapter (also closes UDP 137/138). Left for now because it needs a change on the NIC and a test of the share access. |
| 5985/tcp | WinRM over HTTP (`System`, HTTP.sys) | open | Yes: PowerShell remoting | **Admins only** | **Filter:** today any host of the server network reaches it. Limit the "Windows Remote Management (HTTP-In)" rule to the admin subnet (`Set-NetFirewallRule -RemoteAddress 10.10.10.0/24`). |
| 9389/tcp | Active Directory Web Services (`Microsoft.ActiveDirectory.WebServices`) | open | Yes: AD PowerShell module, Admin Center | Admins | **Filter** to Admins, like WinRM. |
| **49675/tcp** | **Print Spooler RPC (`spoolsv`)** | **open** | **No.** No printer is shared from DC01. A running spooler on a DC is the PrintNightmare (CVE-2021-34527) and coerced-authentication target; Microsoft recommends disabling it on domain controllers | Nobody | **Closed** (see section 4). |
| 47001/tcp | WinRM local listener (`System`) | filtered | Yes, local use | DC01 itself | **Keep.** Listening but blocked by the firewall: not exposed. |
| 49665 (`wininit`), 49674 and 49676 (`svchost`), 49715 (`services`) | System RPC endpoints | filtered | Yes, local system services | DC01 itself | **Keep.** Listening, not reachable from the network. |

**Result: `Get-NetTCPConnection` lists 26 listeners on DC01; before the fix, nmap reached 21 of them** (11 in the top 1000 + 10 above). The Windows firewall already hides the 5 others. Of the 21 reachable ports, 19 are normal for a domain controller. **2 had no business being open: the Print Spooler and NetBIOS 139.**

## 4. Fix and proof: Print Spooler disabled on DC01

```powershell
Stop-Service Spooler -Force
Set-Service Spooler -StartupType Disabled
Get-Service Spooler                  # Stopped, Disabled
Get-NetTCPConnection -State Listen -LocalPort 49675   # nothing
```

Rescan from WEB02, same command before and after:

| | Before (08:25) | After (08:27) |
|---|---|---|
| `49675/tcp` | `open msrpc Microsoft Windows RPC` | **gone** |
| Open ports in 5985, 9389, 47001, 49664-49800 | 10 | 9 |
| Everything else | unchanged | unchanged |

**The fix closes the port and does not break AD.** The 9 other ports are the same before and after. `StartupType Disabled` keeps the spooler off after a reboot. In production, the same setting goes in a GPO linked to the Domain Controllers OU, so a new DC gets it automatically.

## 5. What the audit teaches

- **Listening is not the same as exposed.** DC01 had 26 listeners, but only 21 were reachable. The difference is the host firewall, so it must stay on.
- **A default install exposes more than it needs.** The spooler, NetBIOS and WinRM open to the whole server network all came from defaults, not from a decision. An audit after every install catches them.
- **Banners help attackers.** `-sV` read exact versions: OpenSSH 9.6p1 Ubuntu 3ubuntu13.20, nginx 1.24.0, Windows Kerberos. An attacker matches them against known CVEs. Patching (unattended-upgrades on WEB01, Windows Update on DC01) matters more than hiding them, but `server_tokens off` costs nothing.
- **The server network is flat.** WEB02 could scan and reach every DC01 port. A compromised web server is one hop from the domain controller. This is the DMZ point of the [risk register](risk-register.md).

## 6. Actions

| # | Action | Status |
|---|--------|--------|
| 1 | Disable the Print Spooler on DC01 | **Done**, rescan proves it |
| 2 | Limit WinRM 5985, ADWS 9389 and DNS RPC management on DC01 to the admin subnet | To do |
| 3 | Limit SSH on WEB01 (and WEB02) to the admin sources instead of the whole server network | To do |
| 4 | Disable NetBIOS over TCP/IP on DC01 (closes 139) | To do |
| 5 | HTTPS on nginx, `server_tokens off` | Planned (certificate needed) |
| 6 | Certificate on DC01 for LDAPS 636/3269, LDAP signing | Planned (AD CS) |
| 7 | Rescan after each change, and monthly | Routine |
