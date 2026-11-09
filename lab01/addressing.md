# Lab 01 - BlueHarbor addressing plan

## Networks

| Network | Subnet | Gateway | Used for |
|---------|--------|---------|----------|
| VLAN 10 ADMIN | 10.10.10.0/24 | 10.10.10.1 | IT administrators' workstations |
| VLAN 20 SERVERS | 10.10.20.0/24 | 10.10.20.1 | Servers; mirrored by VirtualBox NAT network BH-SRV |
| VLAN 30 USERS | 10.10.30.0/24 | 10.10.30.1 | Employees' PCs, addresses from DHCP |
| VLAN 99 MGMT | 10.10.99.0/24 | 10.10.99.1 | Switch management interfaces |
| WAN HQ-WH1 | 10.255.0.0/30 | - | Point-to-point link R-HQ (.1) to R-WH1 (.2) |
| WH1 LAN | 10.20.40.0/24 | 10.20.40.1 | Warehouse devices |
| BH-STORAGE | 172.16.30.0/24 | none | VirtualBox internal network for NFS and iSCSI |

DHCP: the first 20 addresses of VLAN 10 and VLAN 30 are excluded for static use, so clients start at .21.

## Interfaces (Packet Tracer model)

| Device | Interface | VLAN | IP address | Mask | Gateway |
|--------|-----------|------|------------|------|---------|
| R-HQ | G0/0 | trunk to SW-DIST | - (sub-interfaces only) | - | - |
| R-HQ | G0/0.10 | 10 | 10.10.10.1 | 255.255.255.0 | - |
| R-HQ | G0/0.20 | 20 | 10.10.20.1 | 255.255.255.0 | - |
| R-HQ | G0/0.30 | 30 | 10.10.30.1 | 255.255.255.0 | - |
| R-HQ | G0/0.99 | 99 (native) | 10.10.99.1 | 255.255.255.0 | - |
| R-HQ | G0/1 | WAN | 10.255.0.1 | 255.255.255.252 | - |
| R-WH1 | G0/1 | WAN | 10.255.0.2 | 255.255.255.252 | - |
| R-WH1 | G0/0 | WH1 LAN | 10.20.40.1 | 255.255.255.0 | - |
| SW-DIST | VLAN 99 (SVI) | 99 | 10.10.99.11 | 255.255.255.0 | 10.10.99.1 |
| SW-ACC1 | VLAN 99 (SVI) | 99 | 10.10.99.12 | 255.255.255.0 | 10.10.99.1 |
| SW-ACC2 | VLAN 99 (SVI) | 99 | 10.10.99.13 | 255.255.255.0 | 10.10.99.1 |
| SW-WH1 | VLAN 1 (SVI) | WH1 LAN | 10.20.40.2 | 255.255.255.0 | 10.20.40.1 |
| PC-U1 | Fa0 | 30 | 10.10.30.21 (DHCP, expected lease) | 255.255.255.0 | 10.10.30.1 |
| PC-U2 | Fa0 | 30 | 10.10.30.22 (DHCP, expected lease) | 255.255.255.0 | 10.10.30.1 |
| PC-A1 | Fa0 | 10 | 10.10.10.21 (DHCP, expected lease) | 255.255.255.0 | 10.10.10.1 |
| SRV-DC | Fa0 | 20 | 10.10.20.10 (static) | 255.255.255.0 | 10.10.20.1 |
| PC-WH1 | Fa0 | WH1 LAN | 10.20.40.21 (DHCP, expected lease) | 255.255.255.0 | 10.20.40.1 |

DNS server for DHCP clients at HQ: 10.10.20.10 (SRV-DC / DC01), domain `blueharbor.internal`.

DHCP leases are the first addresses after the excluded range (.1 to .20), handed out in the order the PCs ask; the exact address can differ if a PC requests first. The WH1 pool uses the same exclusion so that .1 (R-WH1) and .2 (SW-WH1) stay static. The warehouse LAN has no VLANs, so SW-WH1 is managed on its default VLAN 1.

## Switch ports

| Switch | Ports | Mode | VLAN |
|--------|-------|------|------|
| SW-DIST | Gi0/1 (R-HQ), Fa0/23 (SW-ACC1), Fa0/24 (SW-ACC2) | trunk, native 99 | allowed 10,20,30,99 |
| SW-ACC1 | Gi0/1 (SW-DIST) | trunk, native 99 | allowed 10,20,30,99 |
| SW-ACC1 | Fa0/1-10 (PC-U1, PC-U2) | access | 30 |
| SW-ACC2 | Gi0/1 (SW-DIST) | trunk, native 99 | allowed 10,20,30,99 |
| SW-ACC2 | Fa0/11-15 (PC-A1) | access | 10 |
| SW-ACC2 | Fa0/21-24 (SRV-DC) | access | 20 |
| SW-WH1 | Gi0/1 (R-WH1), Fa0/1 (PC-WH1) | access | 1 (default, WH1 LAN) |

## Servers in VirtualBox (VLAN 20 mirrored by BH-SRV)

| VM | BH-SRV address | Storage address | Host SSH port |
|----|----------------|-----------------|---------------|
| DC01 | 10.10.20.10 | 172.16.30.10 | console |
| WEB01 | 10.10.20.20 | 172.16.30.20 | 2220 |
| WEB02 | 10.10.20.21 | 172.16.30.21 | 2221 |
| STOR01 | 10.10.20.30 | 172.16.30.30 | 2230 |

## Why is switch management in a dedicated VLAN 99 rather than in VLAN 10?

- **Separation of the management plane.** VLAN 10 holds the administrators' everyday workstations: they browse the web, read e-mail and can be infected (phishing). If management lived in VLAN 10, any compromised admin PC would sit directly in the same broadcast domain as every switch management interface. In VLAN 99, only the router decides who may reach the switches.
- **Filtering becomes possible.** Because traffic from VLAN 10 to VLAN 99 has to cross R-HQ, it can be controlled with ACLs (Lab 05: SSH to the switches only from VLAN 10, Users blocked from VLAN 99). Inside a single VLAN, nothing can be filtered.
- **Stability.** A broadcast storm, a loop or a scan in the admin VLAN does not affect the management of the network, so the switches stay reachable to repair the problem.
- **Clear role.** VLAN 99 only contains infrastructure addresses (switches), which makes the addressing plan, the monitoring and the audit simpler. It also avoids using the default VLAN 1.

## What does passive-interface change? (Exercise 1.4)

- **What it does.** On a passive interface, OSPF stops sending and receiving Hello packets, so no neighbour can ever form there. The network of that interface is still advertised to the other routers: R-WH1 still learns 10.10.10.0/24, 10.10.20.0/24, 10.10.30.0/24 and 10.10.99.0/24 even though G0/0.10 to G0/0.99 are passive on R-HQ. Only G0/1 (the WAN) stays active, and that is where the FULL adjacency 1.1.1.1 / 2.2.2.2 is formed.
- **Security.** The LAN segments contain PCs and servers, not routers. If Hellos were sent there, any machine on the LAN could answer them, become an OSPF neighbour and inject false routes (for example a fake default route to capture traffic). Passive interfaces close that door; OSPF authentication on the WAN would be the next step.
- **Less useless traffic and load.** No Hello every 10 seconds on every VLAN, no DR/BDR election on segments where there will never be a second router, and nothing extra for the hosts to process.
- **Good practice.** A common pattern is to make every interface passive (`passive-interface default`) and re-enable only the links that really lead to other routers (`no passive-interface g0/1`). A new LAN interface is then safe by default.

## Why should SW-DIST be the spanning-tree root? (Exercise 1.4 challenge)

`spanning-tree vlan 10,20,30,99 root primary` set the SW-DIST priority to 24576 (+ VLAN ID), lower than the default 32768 of the other switches, so it is elected root for every VLAN (`show spanning-tree vlan 30`: "This bridge is the root").

- **Predictable paths.** Without configuration, the root is the switch with the lowest MAC address, which can be any access switch. Traffic would then be forced to cross that access switch and its uplinks, which are not sized for it.
- **It is the centre of the topology.** SW-DIST connects both access switches and the router (R-HQ G0/0). With the root at the centre, every access switch reaches it in one hop, and all its ports are designated and forwarding.
- **Stability.** Adding or rebooting an access switch does not change the root, so there is no full spanning-tree recalculation. In a redundant design, a second distribution switch would get `root secondary`.
