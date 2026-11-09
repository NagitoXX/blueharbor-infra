# Lab 01 - Troubleshooting challenge (Exercise 1.5)

Broken file: `lab01/bh-broken.pkt`, a copy of `bh-hq-reference.pkt` with three faults injected (no partner available, no trainer file). The file is now repaired and saved under the same name.
Method: bottom up - physical (link lights), data link (`show vlan brief`, `show interfaces trunk`), network (`show ip interface brief`, `show ip route`, `show ip ospf neighbor`, `show ip protocols`, pings).

## Starting point

- **Physical:** all links up (green on the switch side). Not a cabling problem.
- **Pings before repair:** PC-U1 reaches its gateway 10.10.30.1 but not SRV-DC (0/4); PC-U2 gets 10.10.10.21 from DHCP instead of a 10.10.30.x address; PC-WH1 reaches neither SRV-DC nor 10.10.30.1 on R-HQ.
- Note: just after opening the file, PC-U1 had 169.254.67.45. That is not a fault: the DHCP request left before spanning tree had finished converging. `ipconfig /renew` gave it 10.10.30.21.

## Fault 1 - wrong VLAN on an access port

- **Symptom:** PC-U2 (a Users PC) receives 10.10.10.21 / gateway 10.10.10.1, an ADMIN address, after `ipconfig /renew`.
- **Command that revealed it:** `show vlan brief` on SW-ACC1: Fa0/2 is listed under VLAN 10 ADMIN, while Fa0/1 and Fa0/3-10 are in VLAN 30 USERS.
- **Cause:** `switchport access vlan 10` on SW-ACC1 Fa0/2. The PC is in the wrong broadcast domain, so the DHCP request is answered by the ADMIN pool.
- **Fix:** on SW-ACC1
  ```
  interface fa0/2
   switchport access vlan 30
  ```
  then `write memory`, and `ipconfig /release` + `ipconfig /renew` on PC-U2, which got 10.10.30.22 again.

## Fault 2 - VLAN missing from a trunk

- **Symptom:** PC-U1 pings its gateway (4/4) but not SRV-DC 10.10.20.10 (0/4). Routing works, so the problem is between R-HQ and the server.
- **Command that revealed it:** `show interfaces trunk` on SW-DIST: "Vlans allowed on trunk" shows `10,30,99` on Fa0/24 (link to SW-ACC2) instead of `10,20,30,99`.
- **Cause:** `switchport trunk allowed vlan 10,30,99` on SW-DIST Fa0/24. Frames tagged VLAN 20 (SERVERS) are dropped on the trunk, so SRV-DC is cut from its gateway.
- **Fix:** on SW-DIST
  ```
  interface fa0/24
   switchport trunk allowed vlan 10,20,30,99
  ```
  then `write memory`. `show interfaces trunk` shows `10,20,30,99` again (forwarding after STP convergence).

## Fault 3 - wrong OSPF network statement

- **Symptom:** PC-WH1 (10.20.40.21) cannot reach SRV-DC nor even 10.10.30.1 on R-HQ.
- **Command that revealed it:** on R-HQ, `show ip ospf neighbor` still shows 2.2.2.2 FULL, but `show ip route` has no `O 10.20.40.0/24` route anymore. On R-WH1, `show ip protocols` lists "Routing for Networks: 10.255.0.0 0.0.0.3 area 0 / 10.20.4.0 0.0.0.255 area 0".
- **Cause:** typo in the R-WH1 OSPF configuration: `network 10.20.4.0 0.0.0.255 area 0` instead of `10.20.40.0`. G0/0 (10.20.40.1) matches no network statement, so the warehouse LAN is not advertised. The adjacency stays up because the WAN statement is correct, which is why the neighbour table alone does not show the problem. HQ has no route back to 10.20.40.0/24.
- **Fix:** on R-WH1
  ```
  router ospf 1
   no network 10.20.4.0 0.0.0.255 area 0
   network 10.20.40.0 0.0.0.255 area 0
  ```
  then `write memory`. R-HQ learns `O 10.20.40.0/24 [110/2] via 10.255.0.2` again.

## Final check (pings of Exercise 1.4)

| From | To | Result |
|------|----|--------|
| PC-U1 10.10.30.21 | gateway 10.10.30.1 | 4/4 |
| PC-U1 | SRV-DC 10.10.20.10 | 3/4 (first lost to ARP) |
| PC-U1 | PC-A1 10.10.10.22 | 3/4 (first lost to ARP) |
| PC-WH1 10.20.40.21 | SRV-DC 10.10.20.10 | 4/4, TTL 126 |

Side effect: PC-A1 now has 10.10.10.22 instead of 10.10.10.21, because the wrong lease given to PC-U2 during fault 1 still holds .21 in the R-HQ DHCP table (Packet Tracer does not support `clear ip dhcp binding`). On a real router: `clear ip dhcp binding 10.10.10.21`.

## Lessons

- Work bottom up: two of the three faults were at layer 2 even though the symptom was a failed ping.
- A FULL OSPF neighbour does not prove that every network is advertised: check the routing table and `show ip protocols`.
- A PC with an address from the wrong subnet points straight to the access port VLAN.
