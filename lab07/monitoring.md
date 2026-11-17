# Monitoring with Prometheus and Grafana (Exercise 7.4)

Done on 17/11/2026. WEB01 (10.10.20.20) is the monitoring server.

- Configuration: [monitoring/](monitoring/).
- Evidence: [evidence/7.4/](evidence/7.4/).

## What runs where

| Component | Host | Port | Notes |
|-----------|------|------|-------|
| prometheus-node-exporter | WEB01, WEB02 | 9100 | Installed by the `webserver` role (7.2). ufw lets only 10.10.20.20 in |
| Prometheus 2.45 (Ubuntu package) | WEB01 | 9090 | Scrapes every 15 s: job `node` → both exporters, job `prometheus` → itself |
| Grafana OSS 13.3.1 (apt.grafana.com) | WEB01 | 3000 | Data source, dashboards and alert rule **provisioned from files** |

ufw on WEB01 opens 3000 and 9090 to 10.10.20.0/24 only. The laptop reaches them from 10.10.20.1.

## Configuration as code

Instead of clicking in the UI, Grafana reads YAML and JSON files at start-up. Each file in [monitoring/](monitoring/) maps to a place on WEB01:

| File in the repository | Installed as | Content |
|------------------------|--------------|---------|
| `prometheus.yml` | `/etc/prometheus/prometheus.yml` | Jobs `prometheus` and `node` (`10.10.20.20:9100`, `10.10.20.21:9100`) |
| `grafana/provisioning/datasources/prometheus.yaml` | `/etc/grafana/provisioning/datasources/` | Data source `Prometheus`, uid `prometheus-bh`, URL `http://localhost:9090` |
| `grafana/provisioning/dashboards/blueharbor.yaml` | `/etc/grafana/provisioning/dashboards/` | Loads every JSON in `/var/lib/grafana/dashboards` into the folder **BlueHarbor** |
| `grafana/dashboards/blueharbor-servers.json` | `/var/lib/grafana/dashboards/` | Our dashboard: CPU (with the 80 % line), memory, disk `/`, targets UP |
| (downloaded at install) | `/var/lib/grafana/dashboards/node-exporter-full.json` | Community dashboard **Node Exporter Full**, grafana.com ID 1860 |
| `grafana/provisioning/alerting/bh-cpu.yaml` | `/etc/grafana/provisioning/alerting/` | Alert rule **High CPU on a web server** (below) |
| `install-monitoring.sh` | run once as root | Installs Prometheus, then Grafana from the official repository (same commands as the Grafana docs "Install on Debian or Ubuntu"), copies the files, opens ufw, checks |

The same files can rebuild the monitoring server identically. They show up in Git diffs, and the UI cannot change them by mistake (the dashboards are marked as provisioned).

## Alert rule

| Item | Value |
|------|-------|
| Query (A) | `100 - (avg by (instance) (rate(node_cpu_seconds_total{mode="idle"}[2m])) * 100)` = % CPU used per server |
| Reduce (B) | last value of each series |
| Condition (C) | B **> 80** |
| Evaluated | every 30 s |
| Pending period (`for`) | **2 m**: the condition must stay true for 2 minutes before firing, so a short peak does not page anyone |
| Labels | `severity=warning`, `team=sysops` |
| Summary | `CPU above 80 % on {{ $labels.instance }} for 2 minutes` |

## Test and checkpoint

| UTC | Event | Evidence |
|-----|-------|----------|
| 10:57 | Prometheus targets from the laptop: `node` 10.10.20.20:9100 **UP**, 10.10.20.21:9100 **UP**, `prometheus` **UP** | `targets.txt` |
| 12:10 | Grafana dashboard "BlueHarbor servers": CPU, memory and disk curves for both instances, both targets UP | `grafana-dashboard.jpg` |
| 12:09:59 | `stress-ng --cpu 1 --timeout 300s` on WEB02 (1 vCPU) | `stress-web02.txt` |
| 12:12:00 | Prometheus: WEB02 at **100 %**, WEB01 at 7.8 %. Rule instance 10.10.20.21:9100 → **Pending** | (Grafana rule page) |
| 12:14:00 | 2 minutes later → **Alerting / Firing** for `instance=10.10.20.21:9100`. WEB01 stays **Normal** | `grafana-alert-firing.jpg` |
| 12:15 | stress-ng ends; the rule goes back to Normal on its next evaluations | |

**Checkpoint:**

- The Prometheus targets are UP.
- The dashboard shows both servers.
- The alert reached the Firing state, for WEB02 only, because each server is evaluated separately with `by (instance)`.

## Problems met and choices made

1. **VirtualBox NAT port forwards for 3000/9090 crash the NAT service.**
   - With the rules `grafana` (127.0.0.1:3000) and `prom` (127.0.0.1:9090) added to BH-SRV, VBoxNetNAT stopped at start-up right after loading them: 5 failures out of 5, even with only the `grafana` rule. Its log ends on `Loading IPv4 port-forwarding rule "prom"`.
   - Each crash also cut SSH and Internet for the VMs. The first install attempt failed with `Temporary failure resolving` and 26 MB in 21 minutes.
   - The rules were removed. BH-SRV keeps only the three SSH forwards.
2. **SSH tunnel instead, through a narrow, approved exception.**
   - The laptop reaches Grafana and Prometheus with `ssh -N -L 3000:localhost:3000 -L 9090:localhost:9090 web01`.
   - The Lab 03 hardening blocked tunnels (`AllowTcpForwarding no`). With the operator's approval, [monitoring/30-opsadmin-tunnel.conf](monitoring/30-opsadmin-tunnel.conf) was added to `/etc/ssh/sshd_config.d/`. It sets `Match User opsadmin` → `AllowTcpForwarding local`.
   - Every other account keeps forwarding disabled, and remote (reverse) forwarding stays off for opsadmin too.
   - `sshd -T -C user=opsadmin,...` shows `allowtcpforwarding local`.
   - To remove it: delete the file and `systemctl reload ssh`.
3. **Prometheus UI paths.** The Ubuntu package only ships the classic web UI, so `/targets` returns 404 and the page is `/classic/targets`.
4. **Grafana admin password.**
   - The first sign-in used the default `admin`/`admin`. The operator then set a new password at the forced prompt; it is not stored anywhere in this repository.
   - Skipping that prompt would have left a default password on a dashboard that has an admin API.

## Limits and next steps

- **Nobody is notified.** The rule fires, but its destination is `empty`: no contact point (e-mail, Teams, webhook) is configured. Like the IDS alerts in Lab 05, an alert nobody receives is not yet monitoring. Next step: a contact point and a notification policy for `team=sysops`.
- **Only the Linux web tier is watched.** DC01 needs `windows_exporter`, and STOR01 (Lab 08) needs node_exporter.
- **One monitoring server, on a monitored host.** If WEB01 goes down, monitoring goes down with it. In production, Prometheus and Grafana run on their own host, and a second check watches the monitor.
- **Retention.** Prometheus keeps 15 days by default on WEB01's disk. That is enough for the lab, not for capacity planning over months.
- **Logs are the next exercise (7.5):** metrics say *that* something is wrong, logs say *why*.
