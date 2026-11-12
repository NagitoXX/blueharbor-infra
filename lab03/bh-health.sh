#!/usr/bin/env bash
set -euo pipefail
LOG=/var/log/bh-health.log
TS=$(date --iso-8601=seconds)
LOAD=$(cut -d" " -f1 /proc/loadavg)
MEM=$(free -m | awk '/^Mem:/ {printf "%.0f", $3/$2*100}')
DISK=$(df --output=pcent / | tail -1 | tr -dc '0-9')
STATUS=OK
if [ "$DISK" -ge 80 ] || [ "$MEM" -ge 90 ]; then STATUS=WARN; fi
echo "$TS host=$(hostname) load=$LOAD mem=${MEM}% disk=${DISK}% status=$STATUS" >> "$LOG"
if [ "$STATUS" != OK ]; then logger -t bh-health "WARN on $(hostname): mem=${MEM}% disk=${DISK}%"; fi
