#!/usr/bin/env bash
# Lab 07 - Exercise 7.4: install Prometheus and Grafana OSS on WEB01. Run as root.
# Expects this folder (lab07/monitoring) copied to /tmp/mon. Output: /tmp/mon/install.log
set -euo pipefail
SRC=/tmp/mon
exec > >(tee "$SRC/install.log") 2>&1
export DEBIAN_FRONTEND=noninteractive

echo "== 1. Prometheus"
apt-get -y -q install prometheus
cp -n /etc/prometheus/prometheus.yml /etc/prometheus/prometheus.yml.orig
install -m 0644 "$SRC/prometheus.yml" /etc/prometheus/prometheus.yml
promtool check config /etc/prometheus/prometheus.yml
systemctl restart prometheus

echo "== 2. Grafana OSS (apt.grafana.com, as in the Grafana docs 'Install on Debian or Ubuntu')"
apt-get -y -q install apt-transport-https software-properties-common wget gpg
mkdir -p /etc/apt/keyrings
wget -q -O - https://apt.grafana.com/gpg.key | gpg --dearmor --yes -o /etc/apt/keyrings/grafana.gpg
echo "deb [signed-by=/etc/apt/keyrings/grafana.gpg] https://apt.grafana.com stable main" > /etc/apt/sources.list.d/grafana.list
apt-get -q update
apt-get -y -q install grafana

echo "== 2b. Grafana provisioning: data source, dashboards, alert rule"
install -m 0644 "$SRC/grafana/provisioning/datasources/prometheus.yaml" /etc/grafana/provisioning/datasources/
install -m 0644 "$SRC/grafana/provisioning/dashboards/blueharbor.yaml"  /etc/grafana/provisioning/dashboards/
install -m 0644 "$SRC/grafana/provisioning/alerting/bh-cpu.yaml"       /etc/grafana/provisioning/alerting/
install -d -o grafana -g grafana -m 0755 /var/lib/grafana/dashboards
install -m 0644 "$SRC/grafana/dashboards/blueharbor-servers.json" /var/lib/grafana/dashboards/
# Community dashboard "Node Exporter Full" (grafana.com ID 1860), wired to our data source
if wget -q -O /tmp/1860.json https://grafana.com/api/dashboards/1860/revisions/latest/download; then
  sed -e 's/\${DS_PROMETHEUS}/prometheus-bh/g' /tmp/1860.json > /var/lib/grafana/dashboards/node-exporter-full.json
  chmod 0644 /var/lib/grafana/dashboards/node-exporter-full.json
else
  echo "WARNING: could not download dashboard 1860; the BlueHarbor dashboard is still provisioned"
fi
systemctl enable --now grafana-server
systemctl restart grafana-server

echo "== 3. Firewall: Grafana and Prometheus from the server network (laptop arrives via 10.10.20.1)"
ufw allow from 10.10.20.0/24 to any port 3000 proto tcp
ufw allow from 10.10.20.0/24 to any port 9090 proto tcp
ufw status numbered

echo "== Checks"
sleep 10
systemctl is-active prometheus grafana-server prometheus-node-exporter
curl -s 'http://localhost:9090/api/v1/targets?state=active' | python3 -c 'import json,sys; [print(t["labels"]["job"], t["scrapeUrl"], t["health"]) for t in json.load(sys.stdin)["data"]["activeTargets"]]'
curl -s http://localhost:3000/api/health
echo "== done"
