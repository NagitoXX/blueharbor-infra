# Intrusion detection and automated blocking (Exercise 5.4)

Done on 13/11/2026 on **WEB01** (10.10.20.20). WEB02 (10.10.20.21) played the attacker.

- Commands were typed as root on the WEB01 console.
- Outputs: [evidence/ids/](evidence/ids/).
- Configuration files kept in the repository:

| File | Installed on WEB01 as |
|------|-----------------------|
| [config/local.rules](config/local.rules) | `/etc/suricata/rules/local.rules` |
| [config/sshd.local](config/sshd.local) | `/etc/fail2ban/jail.d/sshd.local` |

## 1. Suricata (IDS)

### Install and rules

| Step | Command | Result | Evidence |
|------|---------|--------|----------|
| Install | `apt -y install suricata jq` | Suricata 7.0.3, with AF_PACKET support | `1-install.txt` |
| Rules | `suricata-update` | Emerging Threats Open: **69 398 rules**, 53 428 enabled. Written to `/var/lib/suricata/rules/suricata.rules` (46 MB) | `1-install.txt` |
| Config | `/etc/suricata/suricata.yaml` (original saved in `/root/suricata.yaml.orig`) | see the diff below | `2-yaml-*.txt` |
| Test | `suricata -T -c /etc/suricata/suricata.yaml -v` | `53428 rules successfully loaded, 0 rules failed`. `Configuration provided was successfully loaded`, exit 0 | `3-test.txt` |
| Service | `systemctl restart suricata` | `active (running)`, enabled at boot | `3-test.txt` |

```diff
18c18
<     HOME_NET: "[192.168.0.0/16,10.0.0.0/8,172.16.0.0/12]"
>     HOME_NET: "[10.10.20.0/24,172.16.30.0/24]"
615c615
<   - interface: eth0
>   - interface: enp0s3
 rule-files:
   - suricata.rules
+  - /etc/suricata/rules/local.rules
```

`default-rule-path` was already `/var/lib/suricata/rules`.

- **`HOME_NET`** tells the rules which addresses are "ours". Many signatures only fire for traffic going to or from `$HOME_NET`. The default (every private range) would also count the school Wi-Fi (10.159.x.x) as home.
- **`interface: eth0`** does not exist on WEB01. With it, Suricata would capture nothing.

Startup takes about **2 minutes**: Suricata compiles 53 000 signatures before the engine starts (`Engine started` in `suricata.log`). Running, it uses about **530 MB** of WEB01's 2 GB (`MemoryCurrent=553529344`). That counts in the sizing of a server that also runs nginx.

### Test signature: GPL ATTACK_RESPONSE id check returned root (sid 2100498)

The workbook command `curl http://testmynids.org/uid/index.html` **no longer triggers anything**: the domain has expired and now returns a parked "This domain may be for sale" page (`4-testsig.txt`), without the expected answer.

The rule matches any IP packet that contains the output of `id` run as root:

```
alert ip any any -> any any (msg:"GPL ATTACK_RESPONSE id check returned root"; content:"uid=0|28|root|29|"; ... sid:2100498; rev:7; ...)
```

So the same answer was served from inside the lab:

1. On WEB02, nginx served a page at `/uid/index.html` containing `uid=0(root) gid=0(root) groups=0(root)`.
2. WEB01 ran `curl http://10.10.20.21/uid/index.html`.
3. The response crossed `enp0s3`, where Suricata listens.

The page was deleted from WEB02 afterwards.

```
$ sudo tail -n 5 /var/log/suricata/fast.log
11/13/2026-08:43:44.661993  [**] [1:2100498:7] GPL ATTACK_RESPONSE id check returned root [**] [Classification: Potentially Bad Traffic] [Priority: 2] {TCP} 10.10.20.21:80 -> 10.10.20.20:33124

$ sudo jq -r 'select(.event_type=="alert") | .alert.signature' /var/log/suricata/eve.json | tail -5
GPL ATTACK_RESPONSE id check returned root
```

- **Why it matters.** This pattern is what an attacker sees after a successful exploit: they run `id` to check they are root. Seeing it in traffic means a command ran as root somewhere and its output crossed the network.
- **Two output formats.** `fast.log` is one readable line per alert, for a human. `eve.json` holds the same alert with all its fields (flow, HTTP, payload metadata), for a SIEM or `jq`.

### Our own rule (sid 9000001)

```
alert icmp any any -> $HOME_NET any (msg:"BH LAB ICMP echo to a server"; itype:8; sid:9000001; rev:1;)
```

| Part | Meaning |
|------|---------|
| `alert icmp any any -> $HOME_NET any` | Any ICMP packet going to our networks |
| `itype:8` | Echo request only (a ping), not the replies |
| `sid:9000001` | Local signature ID. The 9 000 000+ range avoids collisions with ET rules |
| `rev:1` | First version of the rule |

`ping -c 3 10.10.20.20` from WEB02 → 3 alerts, one per echo request (`5-localrule.txt`, `9-fastlog.txt`):

```
11/13/2026-08:52:30.876200  [**] [1:9000001:1] BH LAB ICMP echo to a server [**] [Classification: (null)] [Priority: 3] {ICMP} 10.10.20.21:8 -> 10.10.20.20:0
11/13/2026-08:52:31.875058  [**] [1:9000001:1] BH LAB ICMP echo to a server [**] ... {ICMP} 10.10.20.21:8 -> 10.10.20.20:0
11/13/2026-08:52:32.880789  [**] [1:9000001:1] BH LAB ICMP echo to a server [**] ... {ICMP} 10.10.20.21:8 -> 10.10.20.20:0
```

The rule has no `classtype`, hence `Classification: (null)` and the default priority 3. In real use a ping is not an attack, and such a rule would flood the logs. It is useful as a canary: it proves the whole chain works, from capture through rules to logs. It also shows the format of a local rule.

### Limits of this setup

- **Detection only.** Suricata runs as an IDS (`--af-packet`), so it alerts and does not block. Blocking inline (IPS, `nfqueue`) would stop a false positive from breaking production traffic. That is a deliberate choice to make later, after tuning.
- **One sensor, on one host.** It only sees WEB01's own traffic. Traffic between DC01 and the users never reaches it. A network IDS belongs on a SPAN/mirror port of SW-DIST or at the R-HQ uplink.
- **Rules go stale.** `suricata-update` must run daily (cron or systemd timer, then `suricatasc -c reload-rules`). Otherwise new threats are not detected.
- **Alerts must be read.** `fast.log` on the server is evidence, not monitoring. The next step is shipping `eve.json` to a central log/SIEM (Lab 07).

## 2. fail2ban (automated blocking)

### Jail

`/etc/fail2ban/jail.d/sshd.local`:

```ini
[sshd]
enabled = true
maxretry = 4
findtime = 10m
bantime = 15m
ignoreip = 127.0.0.1/8 ::1 10.10.20.1
```

| Setting | Meaning |
|---------|---------|
| `maxretry = 4`, `findtime = 10m` | Ban after 4 failures from the same IP within 10 minutes |
| `bantime = 15m` | Ban for 15 minutes, then automatic unban |
| `ignoreip` | Never ban 10.10.20.1. All SSH from the laptop arrives through that NAT gateway, so banning it would lock every admin out at once |

Ubuntu's `defaults-debian.conf` already sets `backend = systemd` and `banaction = nftables`.

- **Backend.** fail2ban reads the systemd journal directly and matches `_COMM=sshd`, instead of parsing `/var/log/auth.log`.
- **Ban action.** Bans go into an nftables set.
- **Version.** Fail2Ban v1.0.2 started without the Python 3.12 problem mentioned in the workbook.

### Test: WEB02 tries `ssh wronguser@10.10.20.20` five times

Each attempt was refused: `Permission denied (publickey)`, because SSH accepts keys only. WEB01 logged `Invalid user wronguser from 10.10.20.21`.

fail2ban (`7-ban.txt`):

```
[sshd] Found 10.10.20.21 - 2026-11-13 08:59:13
[sshd] Found 10.10.20.21 - 2026-11-13 08:59:14
[sshd] Found 10.10.20.21 - 2026-11-13 08:59:14
[sshd] Found 10.10.20.21 - 2026-11-13 08:59:15
[sshd] Ban 10.10.20.21
```

The ban came after the 4th failure, as `maxretry = 4` sets.

```
$ sudo fail2ban-client status sshd
|- Filter
|  |- Currently failed: 1
|  |- Total failed:     5
`- Actions
   |- Currently banned: 1
   |- Total banned:     1
   `- Banned IP list:   10.10.20.21
```

The ban is a rule in its own nftables table, applied before ufw (`priority filter - 1`):

```
table inet f2b-table {
    set addr-set-sshd { type ipv4_addr; elements = { 10.10.20.21 } }
    chain f2b-chain {
        type filter hook input priority filter - 1; policy accept;
        tcp dport 22 ip saddr @addr-set-sshd reject with icmp port-unreachable
    }
}
```

**Effect seen from WEB02 while banned:**

| Port | Result | Meaning |
|------|--------|---------|
| 22 | `nc -zv 10.10.20.20 22` → `Connection refused` | Only SSH is blocked |
| 80 | `nc -zv 10.10.20.20 80` → `succeeded` | The web service stays available to that address |

**Unban:** `sudo fail2ban-client set sshd unbanip 10.10.20.21` → `1`. Status shows `Currently banned: 0`, `Total banned: 1`. From WEB02, `nc -zv 10.10.20.20 22` → `succeeded` again (`8-unban.txt`).

### Why fail2ban when SSH already refuses passwords

Key-only login already defeats password guessing, so fail2ban does not protect the accounts here. Its value is elsewhere:

- **Less noise.** A bot stops after 4 tries instead of thousands, and the logs stay readable.
- **Less exposure.** The banned source cannot reach sshd at all, even if a new OpenSSH vulnerability appears before the patch.
- **A signal.** Every `Ban` line names a host that misbehaved. Here it was WEB02, a server: in real life that is a sign of a compromised machine inside the network, worth an incident (Exercise 5.5).

## 3. Checkpoint

| Check | Result |
|-------|--------|
| `fast.log` contains `GPL ATTACK_RESPONSE id check returned root` | Yes, sid 2100498, 10.10.20.21:80 → 10.10.20.20 |
| `fast.log` contains our ICMP rule | Yes, sid 9000001, 3 alerts |
| fail2ban banned WEB02 | Yes, `Ban 10.10.20.21` after 4 failures; SSH refused, HTTP still allowed |
| fail2ban unbanned WEB02 | Yes, `unbanip` → banned 0; SSH reachable again |
