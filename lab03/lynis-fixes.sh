#!/usr/bin/env bash
# Lab 03 - Exercise 3.4 step 6: two Lynis suggestions applied after the second audit. Run as root.
set -euo pipefail

echo "== Suggestion 1: SSH-7408, harden the SSH server further"
cat > /etc/ssh/sshd_config.d/20-lynis.conf <<'EOF'
# Lynis SSH-7408. Port 22 is kept on purpose: ufw only allows 10.10.20.0/24.
AllowTcpForwarding no
AllowAgentForwarding no
X11Forwarding no
ClientAliveCountMax 2
LogLevel VERBOSE
MaxSessions 2
TCPKeepAlive no
EOF
sshd -t && systemctl restart ssh
sshd -T | grep -Ei '^(allowtcpforwarding|allowagentforwarding|x11forwarding|clientalivecountmax|loglevel|maxsessions|tcpkeepalive) '

echo "== Suggestion 2: BANN-7126 / BANN-7130, legal banner"
BANNER='Authorised access only. This system belongs to BlueHarbor Logistics.
All activity may be monitored and recorded. Disconnect now if you are not authorised.'
printf '%s\n' "$BANNER" > /etc/issue
printf '%s\n' "$BANNER" > /etc/issue.net
cat /etc/issue

echo "== Also fixed: NAME-4404, hostname in /etc/hosts"
grep -q '^127\.0\.1\.1' /etc/hosts || sed -i '1a 127.0.1.1 web01.blueharbor.internal web01' /etc/hosts
head -3 /etc/hosts
