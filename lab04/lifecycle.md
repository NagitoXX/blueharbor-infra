# VM lifecycle: snapshot, linked clone, restore (Exercise 4.2)

Done on 12/11/2026 on the laptop's VirtualBox 7.2.2. Identity script used on WEB02: [web02-identity.sh](web02-identity.sh).

## What was done

| Step | Command / action | Result |
|------|------------------|--------|
| 1. Clone | `VBoxManage clonevm WEB01 --snapshot "base-hardened" --options link --name WEB02 --register` (+ `--basefolder` and `--groups` to keep it next to the other VMs), then `modifyvm WEB02 --cpus 1 --memory 1024` | WEB02 created in a few seconds; its disk is a differencing image of a few MB |
| | First boot, before any change | WEB02 answered on port 2220 as `web01`, with WEB01's IP, machine-id and SSH host key. The laptop could not tell the two apart. |
| 2. Identity | On the WEB02 console: hostname `web02` (also in `/etc/hosts`); `10.10.20.20` → `10.10.20.21` in the netplan file (renamed `01-web02.yaml`); new `/etc/machine-id`; new SSH host keys; reboot | See the table below |
| 3. Both running | `ssh -p 2220` and `ssh -p 2221` (shortcuts `ssh web01` / `ssh web02`) | Both answer; WEB02 pings WEB01 |
| 4. Rollback | `snapshot WEB02 take "web02-clean"` → `sudo rm -rf /srv/trackit` (folder gone) → `controlvm WEB02 acpipowerbutton` → `snapshot WEB02 restore "web02-clean"` → `startvm WEB02 --type headless` | `/srv/trackit` is back (`drwxrwsr-x root webteam`) |

| | WEB01 | WEB02 after step 2 |
|---|---|---|
| Hostname | web01 | web02 |
| IP | 10.10.20.20 | 10.10.20.21 |
| machine-id | 332ff2db… | 0a5c9ed1… |
| SSH host key (ED25519) | SHA256:Nuu+du1k… | SHA256:/eSe+KP5… |

Why each identity item matters on a clone:

- **IP:** two machines with the same IP conflict on the network.
- **machine-id:** used for DHCP client IDs, the systemd journal, and monitoring agents; duplicates make two servers look like one.
- **SSH host keys:** with shared keys, a copy of one server's private host key can impersonate the other, and a key change can no longer reveal a swapped machine.

Because `web02-clean` was taken while WEB02 was running, it also holds the RAM. After the restore, the VM was in the `saved` state and resumed exactly where it was when the snapshot was taken.

## Why a snapshot is not a backup

1. **Same disk, same machine.** The snapshot files sit next to the VM (`D:\...\WEB01\Snapshots\`), on the same external USB drive and the same laptop. If that drive fails, is lost or is encrypted by ransomware, the VM and all its snapshots disappear together. A backup is a separate copy, ideally off-site (3-2-1 rule: 3 copies, 2 media, 1 off-site).
2. **A chain, not a copy.** A snapshot does not copy the disk; it freezes it and writes the next changes into a new differencing file. Each state needs all the files before it. WEB02's chain: its own differencing file → WEB02 `web02-clean` → WEB01 `base-hardened` (`{515fd7aa…}.vdi`) → `{74a10825…}.vdi` → `WEB01.vdi`. One damaged or missing file breaks every state after it.
3. **All or nothing.** A restore brings back the whole VM. In the test, everything written after `web02-clean` was lost along with the mistake, including logs and any useful data. A backup can restore one file or one folder.
4. **Not application-consistent.** A live snapshot catches a database or a file in the middle of a write; it is a "crash-consistent" state, like pulling the power plug.
5. **It costs while it lives.** Every write goes to a growing differencing file, and long chains slow the disk down (already the bottleneck on this laptop, see the Lab 03 USE report). Snapshots are meant to be short-lived: before a change, then deleted or merged.

A snapshot is a quick **undo** before a risky change. A backup is an independent copy, kept elsewhere and tested by restoring it.

## What happens to WEB02 if someone deletes `base-hardened` on WEB01

WEB02 is a **linked clone**: it has no full disk of its own. Its disk only stores the differences from WEB01's disk as it was at `base-hardened`. `VBoxManage showmediuminfo` shows that the frozen disk of `base-hardened` (`{515fd7aa…}.vdi`) now has **two children**:

- `ed879ca1…`: the rest of WEB01;
- `0e3c4b05…`: WEB02.

- **Through VirtualBox:** deleting a snapshot means merging its frozen disk into its child. With two children, that merge is impossible, so VirtualBox should refuse the deletion as long as WEB02 exists. This was not tried on purpose: if it worked, it would destroy the template.
- **By hand, or by removing WEB01 with "delete all files":** if `{515fd7aa…}.vdi` or anything above it in the chain (`{74a10825…}.vdi`, `WEB01.vdi`) disappears, WEB02 can no longer start (parent medium not found). Its own file only holds the differences and is useless alone. WEB02 is lost, unless there is a backup.

Safeguards in place or planned:

- **Description:** `base-hardened`'s description now says "Parent of the WEB02 linked clone: do not delete."
- **No WEB01 deletion while clones exist:** never delete WEB01 or move its files while WEB02 exists.
- **Independent template copy:** keep one outside the chain, either as a full clone (`clonevm WEB01 --snapshot base-hardened --mode machine --name TPL-UBUNTU` without `--options link`) or an export to another disk (`VBoxManage export WEB01 -o <other disk>\web01-base.ova`).
- **When WEB02 must outlive WEB01:** turn it into a full clone.
- **Real backups:** backups of the servers themselves (Lab 08), independent of snapshots.
