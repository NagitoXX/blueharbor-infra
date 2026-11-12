#!/usr/bin/env bash
# Lab 03 - Exercise 3.5 step 4: fix the four faults found by diagnose.sh. Run as root.
set -euo pipefail
export SYSTEMD_PAGER= LC_ALL=C

echo "== Fault 2: disk filled by /var/tmp/.bh-cache.bin"
ls -l /var/tmp/.bh-cache.bin
if fuser /var/tmp/.bh-cache.bin 2>/dev/null; then echo "file is in use, not deleting"; exit 1; fi
rm -f /var/tmp/.bh-cache.bin
df -h /

echo "== Fault 3: web page unreadable (mode 000)"
chmod 644 /var/www/html/index.nginx-debian.html
[ -e /var/www/html/index.html ] && chmod 644 /var/www/html/index.html
ls -l /var/www/html/

echo "== Fault 1: nginx stopped and masked"
systemctl unmask nginx
systemctl enable --now nginx
systemctl is-enabled nginx; systemctl is-active nginx

echo "== Fault 4: health-check timer disabled"
systemctl enable --now bh-health.timer
systemctl start bh-health.service
systemctl is-enabled bh-health.timer; systemctl is-active bh-health.timer
tail -1 /var/log/bh-health.log
