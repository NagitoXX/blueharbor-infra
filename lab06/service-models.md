# Lab 06 - BlueHarbor workloads by service model

Shared responsibility reminder: the further we move from IaaS to SaaS, the less the provider leaves to us. Identity, access, data and configuration always stay BlueHarbor's job.

| Workload | Model (provider) | Why | Still BlueHarbor's job | Risk |
|---|---|---|---|---|
| Mail and office tools | SaaS (Microsoft 365) | Commodity service, no value in running Exchange ourselves, always up to date | User accounts and licences; MFA and conditional access; retention and mailbox backup | Phishing / account takeover exposes mail and files |
| TrackIt web application | PaaS (Vercel) | Small web app, no OS or web server to manage, deploys from Git | Code; environment variables and secrets; access to the Vercel team; domain and DNS | Free-plan limits, vendor lock-in |
| TrackIt database | DBaaS (Supabase, PostgreSQL, EU region) | Managed PostgreSQL: patching, HA and engine upgrades done by the provider | Schema and data; Row Level Security and API keys; export backups and test restores | Free plan: no point-in-time recovery, project paused after inactivity |
| Active Directory | IaaS (2 domain controller VMs, Azure EU region) | AD DS needs full OS control (GPO, LDAP/Kerberos for legacy apps), not offered as SaaS | OS patching and hardening; privileged accounts and admin tiering; system-state backups | A DC exposed by a bad firewall rule means full domain compromise |
| File shares | SaaS (SharePoint / OneDrive, Microsoft 365) | Replaces the file server, sync and versioning included, access from anywhere | Folder permissions and external sharing policy; data classification; retention rules | Oversharing through "anyone with the link" links |
| Finance accounting software | IaaS (VM with the OS version the vendor requires) | Needs a specific OS version, so we must control the OS: only IaaS allows it | OS and application patching; access (VPN/Bastion, no public RDP); VM backups | That OS version reaches end of support and can no longer be patched |
| Backups | SaaS (Backup-as-a-Service, e.g. Azure Backup / Veeam Data Cloud) | Off-site, immutable copies without running our own backup servers | Scope, RPO and RTO; regular restore tests; MFA on the backup console | Backups reachable with the same admin account as production: ransomware deletes both |
| Monitoring | SaaS (Grafana Cloud free tier + UptimeRobot) | Monitoring must live outside what it watches; free tier is enough for a small company | What to monitor and alert thresholds; who receives alerts; protect agent tokens | Monitoring provider outage leaves us blind; logs with personal data stored outside the EU |

## Who operates what

| Layer | IaaS | PaaS / DBaaS | SaaS |
|---|---|---|---|
| Data, identities, access | BlueHarbor | BlueHarbor | BlueHarbor |
| Application / configuration | BlueHarbor | BlueHarbor | BlueHarbor (configuration only) |
| Runtime, middleware, database engine | BlueHarbor | Provider | Provider |
| Operating system | BlueHarbor | Provider | Provider |
| Virtualisation, hardware, datacenter | Provider | Provider | Provider |
