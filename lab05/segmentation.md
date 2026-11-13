# Network segmentation and host firewalls (Exercise 5.2)

Done on 13/11/2026.

- Network part: [bh-hq-secured.pkt](bh-hq-secured.pkt), a copy of `lab01/bh-hq.pkt` with the ACLs below.
- Raw outputs: [evidence/acl-tests.txt](evidence/acl-tests.txt).

## 1. Zones

| Zone | Network | Contains |
|------|---------|----------|
| Users | VLAN 30, 10.10.30.0/24 | Employees' PCs (PC-U1, PC-U2) |
| Admins | VLAN 10, 10.10.10.0/24 | IT administrators' workstations (PC-A1) |
| Servers | VLAN 20, 10.10.20.0/24 (BH-SRV in VirtualBox) | DC01, WEB01, WEB02, STOR01 |
| Management | VLAN 99, 10.10.99.0/24 | Switch management interfaces (SW-DIST .11, SW-ACC1 .12, SW-ACC2 .13) |
| Warehouse | WH1 LAN, 10.20.40.0/24 | Warehouse devices (PC-WH1), behind R-WH1 and the WAN link |
| Storage | BH-STORAGE, 172.16.30.0/24, no gateway | Server storage NICs only (NFS, iSCSI) |
| Internet | outside | Updates, cloud services (Vercel, Supabase, GitHub) |

## 2. Flow matrix

Rows are sources, columns are destinations. Each cell lists what is **allowed**; everything else is denied.

| From ↓ / To → | Users | Admins | Servers | Management | Storage | Internet |
|---|---|---|---|---|---|---|
| **Users** | - (same VLAN) | **denied** | DNS 53 to DC01; AD logon: Kerberos 88, LDAP 389, SMB 445 (shares, GPO), RPC 135 + 49152-65535, NTP 123; HTTP 80 to WEB01/WEB02 | **denied** | denied (not routed) | HTTP/HTTPS 80/443 |
| **Admins** | RDP 3389 and ICMP for support | - | Everything Users have, plus SSH 22 to the Linux servers, RDP 3389 and WinRM 5985 to DC01, ICMP | **SSH 22 only** | denied (not routed) | HTTP/HTTPS 80/443 |
| **Servers** | - (answers only) | - (answers only) | AD and DNS between servers (DC01 ↔ Linux); HTTP between web nodes | - (answers only) | via their own storage NIC only | DNS 53 from DC01 to the forwarders; HTTP/HTTPS for updates (apt, Windows Update) |
| **Management** | - | - | Syslog 514 and NTP 123 to the servers | - | denied | denied |
| **Warehouse** | denied | denied | Same as Users | denied | denied | HTTP/HTTPS 80/443 |
| **Storage** | denied | denied | NFS 2049 / iSCSI 3260 between the servers and STOR01 only | denied | - | denied (no gateway) |
| **Internet** | denied | denied | Nothing today (TrackIt is on Vercel); later only HTTPS 443 to a reverse proxy | denied | denied | - |

"Answers only" means return traffic of a connection opened from the other side. A stateful firewall allows it automatically. A plain router ACL does not track connections, so a reply must not be blocked by a rule written for new traffic.

## 3. Where each rule is enforced

| Flow | Control | State on 13/11/2026 | Evidence |
|------|---------|---------------------|----------|
| Users → Admins, Users → Management | R-HQ, extended ACL `USERS-IN` inbound on `g0/0.30` (rules 10 and 20) | **Enforced.** PC-U1 → PC-A1 and → SW-ACC1: "Destination host unreachable" from 10.10.30.1. Counters: 4 matches on rule 10, 4 on rule 20 | `acl-tests.txt` |
| Users → Servers | R-HQ `USERS-IN` rule 30 `permit ip any any` | **Too open.** Every port is allowed, not only the services in the matrix. PC-U1 → SRV-DC works (3/4, 4 matches on rule 30) | `acl-tests.txt` |
| Admins → Management (SSH only) | SW-ACC1, standard ACL 10 with `access-class 10 in` on `vty 0 4`; vty already SSH v2 only with a local user | **Enforced on SW-ACC1.** SSH from SRV-DC (VLAN 20) is closed by the switch; SSH from PC-A1 (VLAN 10) reaches the password prompt; 2 matches on ACL 10 | `acl-tests.txt` |
| Storage isolated | VirtualBox internal network `BH-STORAGE`, no gateway, no host adapter | **Enforced** by design (Exercise 4.4: unreachable from the laptop and from the Internet) | `lab04/networks.md` |
| Servers: host firewalls | ufw on WEB01, Windows Defender Firewall on DC01 | **Enforced.** WEB01: default deny, 22 from 10.10.20.0/24, 80 open, logging on; DC01 → WEB01:3306 refused and logged. DC01: all three profiles on | `host-firewalls.txt` |
| Warehouse → Admins/Management | nothing yet | **Not enforced.** Traffic from R-WH1 enters R-HQ on `g0/1`, where no ACL is applied | - |

### Two ACL types, two placements

- **Extended ACL close to the source** (`USERS-IN`, inbound on the Users sub-interface). It matches source and destination, so it can stop Users → Admins without touching Users → Servers. Placed inbound, it drops the packet before the router spends work routing it.
- **Standard ACL on the vty lines** (`access-class 10 in`). It only checks the source address, which is all that is needed to say who may open a management session. It protects the switch itself, whatever path the packet took, including from inside VLAN 99.

The two layers overlap on purpose. The router ACL stops Users from even reaching VLAN 99. The vty ACL still blocks a server or a misplaced device that the router lets through (SRV-DC in the test).

## 4. Host firewalls

Raw outputs: [evidence/host-firewalls.txt](evidence/host-firewalls.txt).

### WEB01: ufw

`sudo ufw logging on` → `Logging enabled`. `sudo ufw status verbose`:

```
Status: active
Logging: on (low)
Default: deny (incoming), allow (outgoing), disabled (routed)
```

| # (`ufw status numbered`) | Rule | Matches the matrix? |
|---|------|---------------------|
| [1] | 22/tcp ALLOW IN from 10.10.20.0/24 | Partly. SSH is limited to the server network, but the Admins zone (10.10.10.0/24) is missing (gap 4 below) |
| [2] | 80/tcp ALLOW IN from Anywhere | Yes: HTTP for Users, Admins and Warehouse |
| [3] | 80/tcp (v6) ALLOW IN from Anywhere (v6) | Same rule for IPv6 |
| default | deny incoming, allow outgoing | Yes: everything not listed is refused |

**Logging test.** From DC01: `Test-NetConnection 10.10.20.20 -Port 80` → `True`, and `-Port 3306` → `False`. WEB01 logged each refused SYN in the kernel journal:

```
[UFW BLOCK] IN=enp0s3 SRC=10.10.20.10 DST=10.10.20.20 PROTO=TCP SPT=49945 DPT=3306 SYN
```

There are 3 lines, at 08:13:17, :21 and :30: Windows retried the SYN, waiting longer each time.

- The `low` level logs blocked packets, plus allowed packets that do not match any rule.
- The lines go to the kernel journal (`journalctl -k | grep "UFW BLOCK"`). rsyslog also copies them to `/var/log/ufw.log` and `/var/log/syslog`. `ufw.log` only appears with the first blocked packet after logging is enabled.
- These lines are what an IDS or fail2ban can read in the next exercises.

### DC01: Windows Defender Firewall

`Get-NetFirewallProfile | Select Name, Enabled`:

| Profile | Enabled | Default inbound / outbound | Log blocked |
|---------|---------|----------------------------|-------------|
| Domain | True | NotConfigured (Windows default: block inbound unless a rule allows, allow outbound) | False |
| Private | True | NotConfigured | False |
| Public | True | NotConfigured | False |

All three profiles are on.

- **Active profile:** DC01 uses the Domain profile on the BH-SRV network (`Get-NetConnectionProfile` → `DomainAuthenticated`).
- **Inbound rules:** the AD DS and DNS roles added 22 enabled inbound rules (groups Active Directory Domain Services, DNS Service, Kerberos Key Distribution Center). They match the "Users → Servers" cell of the matrix. Dropped packets are not logged (`LogBlocked False`). To match WEB01, turn it on:

```powershell
Set-NetFirewallProfile -Profile Domain,Private,Public -LogBlocked True
```

The log goes to `%windir%\system32\LogFiles\Firewall\pfirewall.log`.

### Why filter on the hosts too

- **R-HQ only filters traffic between VLANs.** DC01 and WEB01 are in the same VLAN 20, so their traffic never crosses the router. Only the host firewalls can stop DC01 → WEB01:3306, as the test shows.
- **The host firewall travels with the server.** It still applies if the server is moved, cloned (WEB02 inherited WEB01's ufw rules) or reached from a new network.
- **Defense in depth.** If someone loosens the router ACL by mistake, the host rules still hold, and the reverse is also true.

## 5. Gaps and next steps

1. **Replace `permit ip any any` in `USERS-IN`** by the services of the matrix (DNS, Kerberos, LDAP, SMB, RPC, NTP to DC01; HTTP to the web servers; HTTP/HTTPS to the Internet), then `deny ip any any log`. Today a compromised user PC can still reach every port of every server.
2. **Apply `access-class 10 in` on all switches** (SW-DIST, SW-ACC2, SW-WH1), not only SW-ACC1. Add an `enable secret` on all of them (none today).
3. **Filter the warehouse** with an inbound ACL on R-HQ `g0/1` (WH1 LAN → Admins and Management denied), or on R-WH1.
4. **Allow admin SSH to the Linux servers from VLAN 10.** ufw on WEB01 only accepts SSH from 10.10.20.0/24, so admins can only connect through the VirtualBox gateway today.
5. **Log dropped packets on DC01** (`Set-NetFirewallProfile -LogBlocked True`), like ufw on WEB01, so both hosts leave evidence.
6. **Move the web servers to their own DMZ subnet**, away from DC01, as listed in the [risk register](risk-register.md).
