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

## Operations

## Risks
