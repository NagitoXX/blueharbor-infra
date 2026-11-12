# Capacity plan - VirtualBox host (Exercise 4.1)

Inventory taken on 12/11/2026 with `VBoxManage list hostinfo`, `list vms`, `list runningvms` and `showvminfo <vm> --machinereadable | findstr /i "cpus memory"`. Raw output: [evidence/inventory.txt](evidence/inventory.txt).

## Host

| Item | Value |
|------|-------|
| Machine | MSI Cyborg 15 A13VF, Windows 11 |
| CPU | Intel Core i7-13620H: 10 cores (6 performance with Hyper-Threading + 4 efficiency) = **16 threads** |
| RAM | **16 087 MB** (15.7 GB) |
| RAM used by Windows and apps, no VM running | 10.6 GB (5.5 GB available); Opera alone uses about 7 GB |
| Hardware virtualisation | VT-x, nested paging: yes |
| VM storage | D: = external USB hard drive (131.7 GB free); C: = internal SSD (44.5 GB free) |

## Virtual machines

| VM | Role | vCPU | RAM | Disk (virtual size) | Disk on host | Notes |
|----|------|------|-----|---------------------|--------------|-------|
| DC01 | Domain controller, DNS (Windows Server 2025) | 2 | 4 096 MB | 61 GB, dynamic | 23.8 GB | snapshot `dc01-clean` |
| WEB01 | Web server (Ubuntu 24.04) | 2 | 2 048 MB | 25 GB, dynamic | 8.1 GB | snapshots up to `base-hardened`, `before-break` |
| WEB02 | Second web server, linked clone of WEB01 | 1 | 1 024 MB | 25 GB, linked clone | < 0.1 GB | shares WEB01's base disk |
| STOR01 | Storage server, linked clone of WEB01 | 1 | 1 024 MB | 25 GB, linked clone | < 0.1 GB | its 2 × 10 GB data disks are not created yet |
| **Total** | | **6** | **8 192 MB** | **136 GB** (+ 20 GB planned for STOR01) | **32 GB** | |

All VMs are on the NAT network BH-SRV (10.10.20.0/24), with no CPU cap (100 %). None was running during the inventory.

## Ratios

| Ratio | Formula | Result |
|-------|---------|--------|
| **vCPU overcommit** | sum of vCPU / host threads = 6 / 16 | **0.38 : 1** (no overcommit) |
| **RAM commitment** | (sum of VM RAM + 4 GB for the host OS) / host RAM = (8 + 4) / 15.7 GB | **0.76** (76 %) |
| RAM commitment with the host as measured | (8 + 10.6) / 15.7 GB | **1.18** (118 %): overcommitted |
| Disk | 136 GB of virtual disks / 131.7 GB free on D: | thin provisioning; 32 GB really used |

Reading:

- **CPU:** a 0.38 ratio leaves a large margin. Even with all four VMs busy, each vCPU has a host thread of its own.
- **RAM:** on paper (host OS = 4 GB), all four VMs fit with 3.7 GB to spare. In reality the host uses 10.6 GB on its own, and adding the 8 GB of VMs goes past physical RAM. This was seen in Lab 03: with only DC01 and WEB01 running, the host fell to about 500 MB free and VirtualBox's NAT service crashed.

## Which VMs can run together without swapping?

| Combination | VM RAM | With the host at 4 GB (formula) | With the host as measured (10.6 GB) |
|-------------|--------|--------------------------------|-------------------------------------|
| DC01 + WEB01 | 6 GB | 10 GB / 15.7 → yes | 16.6 GB / 15.7 → **no**, the host swaps |
| WEB01 + WEB02 + STOR01 (Linux lab, DC01 off) | 4 GB | 8 GB → yes | 14.6 GB → yes, about 1 GB left |
| All four | 8 GB | 12 GB → yes | 18.6 GB → **no** |

**Answer:**

- **As the laptop is used today** (browser open), only the three Linux VMs (WEB01, WEB02, STOR01: 4 GB) run together without swapping. DC01 + WEB01 together already push the host into swap.
- **After closing the heavy apps** (back to about 4 GB for Windows), all four VMs run together: 12 GB of 15.7 GB.

DC01 is the DNS server and forwarder for the Linux VMs, so the practical rule during the labs is: close the browser (or keep only a few tabs) before starting DC01 with the Linux servers.

## What to buy first

**More RAM first: go from 16 GB to 32 GB.** RAM is the only resource already overcommitted (118 % as measured), while the CPU sits at 0.38 : 1. With 32 GB, all four VMs (8 GB), the host (4 to 11 GB) and a margin for the next labs (more clones, the STOR01 data disks, containers) fit without swapping.

**Second: a fast internal SSD (NVMe) for the VMs.** The Lab 03 USE report showed the disk saturating first (`%util` 88-99 %, writes waiting up to 1 s), because the VM files are on an external USB hard drive. C: has only 44.5 GB free, so a second internal SSD of 1 TB is needed to move the VMs.

No CPU upgrade is needed.
