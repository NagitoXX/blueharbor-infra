# Virtual networks: server network and storage network (Exercise 4.4)

Done on 12/11/2026 on the laptop's VirtualBox 7.2.2. Raw outputs: [evidence/net-web01.txt](evidence/net-web01.txt), [net-web02.txt](evidence/net-web02.txt), [net-web01-dns.txt](evidence/net-web01-dns.txt), [net-host.txt](evidence/net-host.txt).

## VirtualBox network modes

| Mode | VM → Internet | VM ↔ VM | Host → VM | Typical use |
|------|---------------|---------|-----------|-------------|
| NAT | Yes | No (each VM has its own private NAT) | Port forwarding only | One isolated VM that only needs to download |
| **NAT Network** (`BH-SRV`) | Yes | Yes, on the same NAT network | Port forwarding only | Server LAN: servers talk to each other and reach the Internet |
| Bridged | Yes, as a real machine on the host's LAN | Yes | Yes | VM must be seen by the physical network |
| Host-only | No | Yes | Yes (host has an adapter, here `192.168.56.1`) | Lab admin network between the host and the VMs |
| **Internal** (`BH-STORAGE`) | No | Yes, on the same internal network | **No** | Private back-end segment: storage, replication, cluster heartbeat |

## What was configured

| VM | NIC 1: NAT Network `BH-SRV` (`enp0s3`) | NIC 2: Internal `BH-STORAGE` (`enp0s8`) |
|----|------------------------------------------|---------------------------------------------|
| WEB01 | 10.10.20.20/24, gateway 10.10.20.1 | **172.16.30.20/24**, no gateway |
| WEB02 | 10.10.20.21/24, gateway 10.10.20.1 | **172.16.30.21/24**, no gateway |

- **Host side**, with each VM powered off: `VBoxManage modifyvm WEB0x --nic2 intnet --intnet2 BH-STORAGE`. `VBoxManage list intnets` now shows `BH-STORAGE`.
- **Inside each VM**, as root on the console: a copy of the netplan file was saved to `/root/`. Then this block was appended under `ethernets:` in `/etc/netplan/01-web0x.yaml`, followed by `netplan generate && netplan apply`:

```yaml
    enp0s8:
      addresses: [172.16.30.21/24]   # .20 on WEB01
```

`ip route` on WEB01 after the change:

```
default via 10.10.20.1 dev enp0s3 proto static
10.10.20.0/24 dev enp0s3 proto kernel scope link src 10.10.20.20
172.16.30.0/24 dev enp0s8 proto kernel scope link src 172.16.30.20
```

There is no gateway on `enp0s8` on purpose. Only the 172.16.30.0/24 subnet goes through it. Everything else, Internet included, still leaves through `enp0s3` (`ip route get 1.1.1.1` → `dev enp0s3`).

## Test results

| Test | NAT Network `BH-SRV` (10.10.20.0/24) | Internal network `BH-STORAGE` (172.16.30.0/24) |
|------|----------------------------------------|---------------------------------------------------|
| **VM → Internet** | **Yes.** `ping -I enp0s3 1.1.1.1`: 3/3, about 13 ms. HTTP 200 from `archive.ubuntu.com` (185.125.190.82). | **No.** `ping -I enp0s8 1.1.1.1`: 0/3, 100 % loss. The neighbour entry for 1.1.1.1 is `FAILED`: nobody on the segment answers, because the segment has no router. |
| **VM → VM** | **Yes.** WEB01 ↔ WEB02 on 10.10.20.20/.21: 3/3 both ways. | **Yes.** WEB01 → 172.16.30.21 and WEB02 → 172.16.30.20: 3/3 both ways, 2-7 ms. Each VM learned the other's MAC on `enp0s8` (`REACHABLE`). |
| **Host (laptop) → VM** | **Not directly.** Ping and TCP/22 to 10.10.20.20 and .21 fail: the laptop has no adapter on that network. **Only through the port forwards**: `127.0.0.1:2220` → WEB01:22 and `127.0.0.1:2221` → WEB02:22 both answer. | **No, not at all.** Ping and TCP/22 to 172.16.30.20 and .21 fail. The laptop has no adapter on this network, and an internal network cannot have port forwards. |

A side effect of the host tests: the laptop has no route to either network, so Windows sends those packets to its Wi-Fi gateway (10.159.128.1, `Find-NetRoute`). They leave the laptop and are lost on the physical network. They never reach VirtualBox.

### DNS on the current Wi-Fi

`curl http://archive.ubuntu.com` first failed with "Could not resolve host". This did not come from the network modes:

- the VMs use 10.10.20.10 (DC01, powered off during the test), then 1.1.1.1;
- the Wi-Fi the laptop was on blocks outside DNS servers. `Resolve-DnsName -Server 1.1.1.1` also times out on the laptop itself. Only the network's own DNS servers answer (10.96.23.50/51);
- through the NAT Network, `dig @10.96.23.50 archive.ubuntu.com` works, and the HTTP request then returns 200.

The NAT Network path is fine. Name resolution depends on DC01 being up: DC01 already forwards to 10.96.23.50/51 ([dossier](../dossier/README.md)). The Linux servers' only fallback, 1.1.1.1, is blocked on this Wi-Fi. When DC01 is off, the servers have no working DNS server.

## Why storage traffic should not share the server network

1. **Performance.** Storage traffic is heavy and arrives in bursts: NFS/iSCSI/SMB, backups, replication, VM disk moves. On the server network it competes with user traffic to TrackIt and adds latency to every request. A separate network gives it its own NIC, its own queues and its own bandwidth. It can also get settings the server network should not have, such as jumbo frames (MTU 9000).
2. **Security.** Storage protocols are often weakly authenticated and unencrypted (NFS trusts client IPs, iSCSI often runs without CHAP). On `BH-STORAGE`, there is no gateway and no port forwarding. The laptop and the Internet cannot reach it, as the tests show. Only machines with a NIC on this segment can talk to the storage. A compromised user workstation cannot even see the storage server.
3. **Fault isolation.** A saturated link, a broadcast storm or a wrong IP on one network does not take the other down. If the server network is under a DDoS or a bad change, the servers can still reach their data, and the reverse is also true.
4. **Simpler rules and monitoring.** Each network has one job: server network for clients and administration, storage network only for data. Firewall rules stay short. Unusual traffic is easy to spot, for example anything other than NFS/iSCSI on 172.16.30.0/24.

In a real datacenter, the same idea uses a dedicated VLAN or physical switches and NICs for storage. In this lab, VirtualBox keeps the internal network entirely in the host's memory, so it never touches the physical network.

## Incident during the exercise

On the first boot after adding the NIC, WEB01 hit a kernel panic: `Fatal exception in interrupt`, `exc_page_fault`, at 37 s. The laptop had only about 3.4 GB of RAM free with both VMs and the browser running. After `controlvm WEB01 poweroff` and a new boot, WEB01 started normally and has had no further problems. This is consistent with the host memory pressure noted in [capacity.md](capacity.md). If it happens again, check `journalctl -k -b -1` on WEB01 and the VirtualBox `VBox.log`.
