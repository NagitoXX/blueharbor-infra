# Effect of resource allocation (Exercise 4.3)

Measured on 12/11/2026 on WEB02 (Ubuntu 24.04, linked clone of WEB01, 1 024 MB), VirtualBox 7.2.2 on an i7-13620H (16 threads). Each CPU test: `stress-ng --cpu 2 --timeout 30s --metrics-brief`, run over SSH 20 s after the VM was up. Raw outputs: [evidence/](evidence/) (`cpu-*.txt`, `mem-*.txt`, `disk-web01-vdi.txt`, `paravirt.txt`).

## CPU

| # | Setting (VM powered off between changes) | `nproc` | bogo ops/s (real time) | user time | system time | vs 1 vCPU |
|---|---------------------------------------------|---------|------------------------|-----------|-------------|-----------|
| 1 | 1 vCPU, cap 100 % | 1 | **178** | 3.8 s | 23.9 s | 1.0 × |
| 2 | 2 vCPU, cap 100 % (`modifyvm --cpus 2`) | 2 | **800** | 44.7 s | 13.3 s | 4.5 × |
| 3 | 2 vCPU, cap 50 % (`modifyvm --cpuexecutioncap 50`) | 2 | **698** | 31.6 s | 24.2 s | 3.9 × |
| 4 | 2 vCPU, cap back to 100 %, paravirt KVM | 2 | **817** | 36.7 s | 22.7 s | 4.6 × |
| 1b | 1 vCPU again, after a cold boot (check) | 1 | **176** | 3.9 s | 24.5 s | 1.0 × |

Observations:

- **1 → 2 vCPU: × 4.5, not × 2.** With one vCPU, the two CPU-bound workers share a single processor: 82 % of their time goes to the kernel (switching between them and handling the virtualised timer) and only 18 % to real work. With two vCPUs, each worker gets its own and user time dominates. Test 1b repeats test 1 after a cold boot and gives the same result, so it is not a measurement accident.
- **Tests 2 and 4 agree (800 vs 817, 2 % apart):** the measurement is repeatable.
- **The 50 % cap only took 13 % off (800 → 698).** VirtualBox applies the cap by pausing the vCPU threads on the host for part of each time slice. The guest does not see fewer processors, and its work comes back in bursts. The cap is therefore a coarse limit to protect the host or other VMs, not a precise way to halve a VM's power. Its side effect is visible: system time almost doubles (13 → 24 s).
- **Paravirtualisation:** `showvminfo WEB02 | findstr /i paravirt` showed `Paravirt. Provider: Default`, `Effective Paravirt. Prov.: KVM`. Default already picks KVM for a Linux guest. It is now set explicitly (`--paravirtprovider kvm`). The guest knows it is virtualised: it has the `hypervisor` flag in `/proc/cpuinfo`, and `systemd-detect-virt` answers `oracle`. Because nothing really changed, test 4 equals test 2.

WEB02 is back to its spec at the end: 1 vCPU, 1 024 MB, cap 100 %, paravirt KVM.

## Memory

`stress-ng --vm 1 --vm-bytes 1200M --timeout 30s` with `vmstat 2` running in a second SSH session ([mem-stress.txt](evidence/mem-stress.txt), [mem-vmstat.txt](evidence/mem-vmstat.txt)):

| Value | Observed |
|-------|----------|
| RAM seen by the guest | 961 MB total, 664 MB available |
| Swap | **none** (`swapon --show` empty) |
| `si` / `so` (swap in / out) | **0 / 0** during the whole run |
| stress-ng | `vm: gave up trying to mmap, no available memory, skipping stressor`; the run stopped after 12 s, with no work done |

Asking for 1 200 MB on a VM with 961 MB of RAM and no swap cannot be satisfied: the kernel refuses the allocation up front instead of swapping, because there is nowhere to swap to. With a swap file, `si`/`so` would rise and everything would slow down. Without one, a real application in the same situation fails, or the OOM killer stops a process. Either way, giving a VM less RAM than its working set does not make it slower: it makes it fail.

## Disk

`VBoxManage showmediuminfo disk "D:\windows 2025 server\UIR-2024\WEB01\WEB01.vdi"` ([disk-web01-vdi.txt](evidence/disk-web01-vdi.txt)):

| Value | WEB01.vdi |
|-------|-----------|
| Storage format | VDI |
| Format variant | **dynamic** default |
| Capacity (what the guest sees) | **25 600 MB** |
| Size on disk (what the host stores) | **4 075 MB** |
| Space used inside the guest (`df -h /` on WEB02) | 3.1 GB of 25 GB |

Whole chain on the host:

| File | Size | Role |
|------|------|------|
| `WEB01.vdi` | 4 075 MB | base disk (after the Ubuntu install) |
| `{74a10825…}.vdi` | 2 MB | WEB01 snapshot (old linked-clone base) |
| `{515fd7aa…}.vdi` | 3 880 MB | WEB01 changes up to `base-hardened`: updates, nginx, Lab 03 |
| `{63db8a15…}.vdi` | 100 MB | changes up to `before-break` |
| `{ed879ca1…}.vdi` | 41 MB | WEB01 current state |
| WEB02 `{0e3c4b05…}.vdi` and `{1f039c83…}.vdi` | 87 + 134 MB | WEB02's own changes, up to `web02-clean` and after |

**Dynamic format:** the VDI file starts almost empty and grows by 1 MB blocks the first time the guest writes to them, up to the capacity. It never shrinks on its own: deleting files in the guest leaves the blocks allocated. Reclaiming them needs zeroing the free space in the guest, then `VBoxManage modifymedium --compact`.

- **Advantage:** 136 GB of virtual disks (Lab 04 capacity plan) take only about 32 GB on the host. The 18.5 GB file of the Lab 03 challenge never inflated the disk, because `fallocate` reserves blocks in the guest without writing any data.
- **Cost:** the host can be overcommitted, since the sum of capacities exceeds the free space on D:. Every first write also pays for growing the file, on a USB drive that is already the bottleneck.
- **Fixed format** (`--variant Fixed`): allocates everything at creation. That is safer and a little faster, but uses the full size from day one.

## Conclusion

**Adding vCPUs helps when the workload can use them in parallel and the host has free threads.** Here, 2 CPU-bound workers went 4.5 times faster with 2 vCPUs, because each got its own processor and stopped wasting time switching. The host has 16 threads for 6 vCPUs in total, so there was no contention.

**It does not help:**

- for single-threaded work (one process uses one vCPU at a time);
- when the bottleneck is elsewhere: on this laptop that is the disk (Lab 03: `%util` 88-99 %), and for WEB02's memory, the missing swap;
- when the host itself runs out of threads: past about 1 vCPU per host thread, vCPUs wait for each other, and SMP guests can even get slower.

A CPU cap is no substitute for sizing: at 50 % it only removed 13 % here, and it added system overhead.

Changing vCPU or RAM on one VM is **vertical scaling** (Foundations, step 6):

- it needs a reboot;
- it stops at the size of the host;
- it does not add redundancy.

For TrackIt, the next step after giving WEB01 the right size is **horizontal scaling**: WEB01 + WEB02 behind a load balancer. That is why WEB02 exists.
