# Role webserver

Configures a BlueHarbor web node: nginx, the TrackIt status page (template) and
prometheus-node-exporter, reachable on 9100/tcp from the monitoring host only (ufw).

| Variable | Default | Meaning |
|----------|---------|---------|
| `trackit_version` | `1.0.1` | Version shown on the status page |
| `node_exporter_allowed_from` | `10.10.20.20` | Only source allowed to scrape node_exporter |

Handler: `Reload nginx`, triggered only when the status page changes.

Usage (web.yml): `ansible-playbook web.yml -K [-e trackit_version=1.0.2]`
