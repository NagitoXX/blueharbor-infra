#!/usr/bin/env bash
# Lab 03 - Exercise 3.5 step 3: diagnosis, in the order of the method. Run as root. Read-only.
export SYSTEMD_PAGER= LC_ALL=C

echo "########## 0. Symptom"
curl -sS -I --max-time 5 http://localhost 2>&1 | head -3

echo "########## 1. Service state"
systemctl status nginx --no-pager 2>&1 | head -6
systemctl is-enabled nginx 2>&1
ls -l /etc/systemd/system/nginx.service 2>&1
systemctl list-units --failed --no-pager

echo "########## 2. Logs (warnings since boot, last 25)"
journalctl -p warning -b --no-pager | grep -v -E "vmwgfx|hogged CPU|kauditd" | tail -25

echo "########## 3. Resources"
df -h /
du -xh / --max-depth=2 2>/dev/null | sort -h | tail -8
ls -la /var/tmp

echo "########## 4. Permissions"
ls -l /var/www/html/

echo "########## 5. Scheduled jobs"
systemctl list-timers --all --no-pager | grep -E "NEXT|bh-health" || echo "bh-health.timer not in list-timers"
systemctl is-enabled bh-health.timer; systemctl is-active bh-health.timer
tail -3 /var/log/bh-health.log
