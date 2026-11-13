# BlueHarbor risk register (Exercise 5.1)

Written on 13/11/2026 from what Labs 01 to 04 built. The risk table is sorted by risk, highest first: protect those first.

## Scales

| Scale | 1 | 2 | 3 | 4 |
|-------|---|---|---|---|
| **C, I, A** (need) | low | medium | high | - |
| **Likelihood (L)** | rare: needs a skilled, targeted attacker | possible: needs a mistake or a known flaw | likely: common attack, weak or missing control | expected: automated attacks do this every day |
| **Impact** | minor, one person, hours | one service down or limited data exposed | business stopped for a day or sensitive data exposed | whole company stopped, or domain/cloud taken over, legal (GDPR) consequences |

**Risk = L × Impact** (1 to 16): 12 and above = treat now, 6 to 11 = plan, 5 and below = accept and monitor.

## 1. Assets and CIA needs

| Asset | What it is | C | I | A | Why |
|-------|-----------|---|---|---|-----|
| **DC01** | Windows Server 2025: AD DS `blueharbor.internal`, DNS, hosts the Finance share | 3 | 3 | 3 | Holds every account and password hash (NTDS.dit). A change gives control of every machine. Without it there are no logins and no name resolution for the servers. |
| **VirtualBox host (admin laptop)** | Runs every VM and snapshot; holds the admin SSH key, Git working copy and browser sessions | 3 | 3 | 3 | Whoever controls it controls all the VMs and their disks. It is also a single point of failure: one laptop, one USB drive. |
| **Finance share** `\\DC01\Finance` | Accounting files, Modify for `DL_FinanceShare_RW` (AGDLP) | 3 | 3 | 2 | Confidential financial data; tampering means wrong accounts. A day without it is painful, not fatal. |
| **Cloud tokens** | Vercel, Supabase and GitHub access tokens and API keys (TrackIt website and shipment data) | 3 | 3 | 2 | A token gives the same rights as its owner: deploy, read or delete customer data (GDPR). |
| **Switches and routers** | R-HQ, R-WH1, SW-DIST, SW-ACC1, SW-ACC2, SW-WH1 (Lab 01) | 2 | 3 | 3 | Every flow crosses them. A changed VLAN or route cuts HQ or the warehouse off, or sends traffic to an attacker. Their configs reveal the network map. |
| **Git repository** `blueharbor-infra` | Scripts, unit files, configs, dossier, evidence | 2 | 3 | 2 | Scripts run as root and as Domain Admin: a modified script compromises the servers. It describes the whole infrastructure, so it helps an attacker plan. |
| **WEB01** | Ubuntu 24.04, nginx, TrackIt status page; template of the Linux clones (`base-hardened`) | 1 | 3 | 2 | The page is public by design. Defacement or a backdoor in the template would spread to every clone. |
| **WEB02** | Linked clone of WEB01, second web node | 1 | 3 | 2 | Same role as WEB01. Two nodes make availability less critical, once a load balancer is in place. |

## 2. Threats on the five most important assets (sorted by risk)

| Asset | C | I | A | Threat (who, how) | L | Impact | Risk | Existing control | Control to add |
|-------|---|---|---|-------------------|---|--------|------|------------------|----------------|
| **DC01** | 3 | 3 | 3 | **Password spraying on domain accounts.** An outsider who got one foothold (phishing on a PC), or an insider, tries one common password on every account. The Lab 02 audit found that every staff account still uses the **same initial password**, and 7 accounts were never used. One guess opens many accounts. | 4 | 4 | **16** | Lockout after 5 attempts for 15 min; 12 characters with complexity; PSO-Admins (16 characters, lockout after 3) for Domain Admins; change at next logon | Unique initial password per user; disable accounts unused after 14 days; MFA for admins; alert on many failed logons (event 4625, 4771) across accounts; named admin accounts instead of the shared Administrator |
| **VirtualBox host (admin laptop)** | 3 | 3 | 3 | **Malware or theft of the admin laptop.** A malicious download, game launcher or browser extension (the laptop is also a personal machine) or a stolen laptop gives the attacker the SSH private key. The key has **no passphrase**, so it opens WEB01/WEB02 with sudo. The attacker also gets the VM disks on an unencrypted USB drive, including NTDS.dit inside DC01's disk. | 3 | 4 | **12** | SSH private key readable only by the user (ACL fixed in Lab 03); VMs not reachable from the LAN (NAT Network, port forwards on 127.0.0.1 only); Windows Defender | Passphrase on the SSH key + ssh-agent; BitLocker on the internal disk and the USB drive; separate admin profile without games or personal browsing; keep the host patched; offline backup of the VMs (Lab 08) |
| **Finance share** | 3 | 3 | 2 | **Ransomware through phishing.** A Finance employee opens a malicious attachment; the malware runs with their rights and encrypts everything they can modify on `\\DC01\Finance`, then threatens to publish it (double extortion). | 3 | 4 | **12** | AGDLP: only `GG_Finance` (through `DL_FinanceShare_RW`) can modify; read-only group for others; `BUILTIN\Users` removed, inheritance off; file access audit planned | Backups with an offline copy (3-2-1, Lab 08) and a tested restore; Volume Shadow Copies on the share; antivirus/EDR on PCs; block macros from the Internet (GPO); alert on mass file renames |
| **Switches and routers** | 2 | 3 | 3 | **An employee or a compromised PC in VLAN 30 (Users) reaches the management VLAN 99.** Inter-VLAN routing on R-HQ allows everything, so the attacker can reach the switches' SSH and try to guess the password. There is **no `enable secret`**, so whoever logs in is one step from full control. From there, they can change a VLAN, shut a trunk or mirror traffic. | 3 | 3 | **9** | Management in its own VLAN 99 (not VLAN 1, not VLAN 10); vty lines with SSH v2 only and a local user (`login local`, `transport input ssh`, checked on SW-ACC1 in Exercise 5.2); OSPF passive interfaces on every LAN (no fake neighbour); SW-DIST forced as spanning-tree root | ACL on R-HQ: VLAN 30 → VLAN 99 denied, SSH to the switches only from VLAN 10 (done in Exercise 5.2); `enable secret`, console password and `service password-encryption`; port security and BPDU guard on access ports; config backups |
| **Cloud tokens** | 3 | 3 | 2 | **Token leaked in the Git repository.** An admin commits a `.env`, a Terraform state or a script with a Vercel/Supabase/GitHub token in it. Bots scan public GitHub within minutes and use the token to read or delete shipment data, or deploy a malicious site. | 2 | 4 | **8** | `.gitignore` excludes `.env`, `*.tfvars`, `*.tfstate`; workbook rule: secrets written as `<redacted>`; Supabase in the EU region with row level security | Secret scanning before each commit (gitleaks pre-commit hook) and GitHub push protection; tokens scoped to one project, read-only where possible, with an expiry date; secrets kept in a manager (KeePass, CI secrets), never in files; revoke and rotate at once if one leaks |

## 3. Reading the register

- **Treat now (12 and above):**
  1. The **directory** comes first: one shared initial password plus unused accounts make password spraying both easy and powerful. The fix costs little: unique passwords and disabling unused accounts. It is already listed in the dossier as an open risk.
  2. Then the **admin laptop**, the weakest link today: everything, the SSH key included, sits on a personal machine without disk encryption.
  3. Then the **Finance share**: there is **no backup at all yet**, so ransomware would be final.
- **Plan (6 to 11):**
  - the **network devices** are fixed by the ACLs and device hardening of the next exercise;
  - the **cloud tokens** risk is lower today because few tokens exist, but it grows with every lab that adds automation (Labs 06 and 09).
- **Watch list (assets outside the top five):**
  - **WEB01/WEB02:** the main threat is an exploited vulnerability in nginx or the future TrackIt app, followed by a pivot to DC01. The web servers sit in the **same subnet as DC01** (10.10.20.0/24). Existing controls are already the best of the lab: ufw default deny, SSH keys only from 10.10.20.0/24, unattended-upgrades, Lynis index 71. To add: HTTPS, Suricata and fail2ban (this lab), and a separate DMZ subnet for the web tier.
  - **Git repository:** commit and branch protection, review before merge, and signed commits once the CI pipeline runs these scripts automatically (Lab 09).

The register is reviewed after each lab and after any incident. Each "control to add" moves to "existing control" when it is in place and tested.
