# BlueHarbor Logistics - Infrastructure dossier

## Architecture

### Target deployment model (v1, from Foundations step 5)

| Workload | Model | Reason |
|----------|-------|--------|
| Active Directory | On-premises (private) | Local logins and GPOs at HQ and WH1, available even without Internet |
| Finance application | On-premises (private) | Sensitive data, needs a specific OS version |
| TrackIt website | Public cloud (PaaS, Vercel) | Internet-facing, variable traffic, needs elasticity |
| TrackIt shipment data | Public cloud (DBaaS, Supabase, EU region) | Managed database close to the app, GDPR (EU region) |
| Off-site backups | Public cloud (object storage, EU region) | Off-site copy of the 3-2-1 rule |

The result is a **hybrid** model: on-premises and public cloud connected by encrypted links (VPN or HTTPS APIs) and a common identity.

### HQ and warehouse network (Lab 01, Packet Tracer model)

![Packet Tracer topology of HQ and warehouse WH1](img/lab01-topology.jpg)

- **HQ:** R-HQ does inter-VLAN routing (router-on-a-stick on G0/0) and DHCP. SW-DIST is the distribution switch and spanning-tree root; SW-ACC1 (users) and SW-ACC2 (admins, servers) are access switches. Trunks are 802.1Q, native VLAN 99, allowed 10,20,30,99.
- **Warehouse WH1:** R-WH1 with one flat LAN (SW-WH1, PC-WH1), DHCP on R-WH1.
- **WAN:** R-HQ G0/1 to R-WH1 G0/1, /30, OSPF area 0 with passive-interface on every LAN.
- Model file: [lab01/bh-hq.pkt](../lab01/bh-hq.pkt); full per-interface table: [lab01/addressing.md](../lab01/addressing.md).

| Network | Subnet | Gateway | Used for |
|---------|--------|---------|----------|
| VLAN 10 ADMIN | 10.10.10.0/24 | 10.10.10.1 | IT administrators' workstations (DHCP from .21) |
| VLAN 20 SERVERS | 10.10.20.0/24 | 10.10.20.1 | Servers, static (DC01 = 10.10.20.10) |
| VLAN 30 USERS | 10.10.30.0/24 | 10.10.30.1 | Employees' PCs (DHCP from .21) |
| VLAN 99 MGMT | 10.10.99.0/24 | 10.10.99.1 | Switch management (SW-DIST .11, SW-ACC1 .12, SW-ACC2 .13) |
| WAN HQ-WH1 | 10.255.0.0/30 | - | R-HQ .1, R-WH1 .2 |
| WH1 LAN | 10.20.40.0/24 | 10.20.40.1 | Warehouse devices (DHCP from .21) |
| BH-STORAGE | 172.16.30.0/24 | none | VirtualBox internal network for NFS and iSCSI |

### Active Directory (Lab 02)

Domain **blueharbor.internal** (NetBIOS `BLUEHARBOR`), one forest. DC01 (10.10.20.10) is the domain controller and the DNS server.

```
blueharbor.internal
└── BlueHarbor
    ├── Users
    │   ├── Finance      elaurent, mpetit, lmartin
    │   ├── Operations   hbernard, irobert, trichard
    │   └── IT           sdurand, nmoreau, lsimon
    ├── Groups           GG_Finance, GG_Helpdesk, DL_FinanceShare_RW, DL_FinanceShare_R
    ├── Servers
    ├── Computers
    └── Admins
```

- **Access model: AGDLP.** Accounts go into global groups (GG_*), global groups go into domain local groups (DL_*), and only DL groups appear in share and NTFS permissions. Example: GG_Finance → DL_FinanceShare_RW → Modify on `\\DC01\Finance` ([lab02/agdlp.md](../lab02/agdlp.md)).
- **Delegation:** GG_Helpdesk can reset passwords and force a change at next logon on `OU=Users`, without being Domain Admins.
- **Policies:**
  - Default domain policy: 12 characters minimum, complexity on, lockout after 5 attempts for 15 minutes.
  - PSO-Admins applies to Domain Admins: 16 characters, lockout after 3 attempts for 30 minutes, password changed every 90 days.
  - GPO BH-Users-Baseline is linked to `OU=Users` and locks idle sessions after 10 minutes.

| DNS zone | Type | Content |
|----------|------|---------|
| blueharbor.internal | Primary, AD-integrated | DC01 records, `web01` → 10.10.20.20 |
| 20.10.10.in-addr.arpa | Reverse, AD-integrated (domain) | PTR for 10.10.20.0/24 (web01) |
| _msdcs.blueharbor.internal | Primary, AD-integrated (forest) | Domain controller locator records |

Forwarders for names outside the domain: 10.96.23.50, 10.96.23.51 (school network resolvers, because public DNS is blocked there), then 1.1.1.1.

## Operations

### Create a user

Run on DC01 as an administrator. Put the user in the OU of their department, then add them to the global group of that department.

```powershell
New-ADUser -Name "First Last" -GivenName First -Surname Last -SamAccountName flast `
  -UserPrincipalName flast@blueharbor.internal -Department Finance -Title Accountant `
  -Path "OU=Finance,OU=Users,OU=BlueHarbor,DC=blueharbor,DC=internal" `
  -AccountPassword (Read-Host -AsSecureString "Initial password") -ChangePasswordAtLogon $true -Enabled $true
Add-ADGroupMember -Identity GG_Finance -Members flast
```

The initial password must have at least 12 characters, with complexity. Give it to the user through a separate channel, and use a different one for each user. Several users at once: [lab02/02-users.ps1](../lab02/02-users.ps1) with a CSV file.

### Grant access to a share

Never put a user directly into a share or NTFS permission. Change group membership only:

1. The user's global group (for example GG_Finance) is added to the DL group of the share and access level: `DL_<Share>_RW` for modify, `DL_<Share>_R` for read only.
2. For a new share, create the two DL groups first. Then grant them on the share (Change / Read) and in NTFS (Modify / Read & execute), with inheritance disabled and `BUILTIN\Users` removed.
3. Check with Effective Access on the folder (Properties > Security > Advanced). The user must sign out and back in to receive the new group.

Temporary access (for example an auditor): put the account in a global group nested in `DL_<Share>_R` and set an account expiry date ([lab02/agdlp.md](../lab02/agdlp.md)).

## Risks

First entries, from the directory audit of Lab 02 ([lab02/audit.md](../lab02/audit.md)):

| Risk | Impact | Action | Status |
|------|--------|--------|--------|
| A single, shared, built-in admin account (Administrator) is used for all administration | No trace of who did what; one leaked password gives the whole domain | Named admin accounts in `OU=Admins`; built-in Administrator kept as break-glass in KeePass | Open |
| The Administrator password predates the 12- and 16-character policies; the DC clock was wrong during the install | Weak password on the most powerful account; Kerberos failures if the clock drifts | Change the password now (16+ characters); set a reliable NTP source on DC01 | Open |
| 7 enabled accounts never used, all staff share the same initial password | Anyone who knows it can take over a colleague's account | Unique initial passwords; disable unused accounts after 14 days; monthly audit | Open |
| PSO-Admins was created with reversible encryption on (cmdlet default) | Admin passwords stored in a decryptable form | Turned off; always pass `-ReversibleEncryptionEnabled $false` | Fixed |
