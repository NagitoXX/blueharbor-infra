#!/usr/bin/env bash
# Lab 03 - Exercise 3.4 steps 2 to 4: firewall, automatic security updates, kernel network settings.
# Run as root on WEB01.
set -euo pipefail

echo "== 2. Firewall"
ufw default deny incoming
ufw default allow outgoing
ufw allow from 10.10.20.0/24 to any port 22 proto tcp
ufw allow 80/tcp
ufw --force enable            # same as "ufw enable" without the y/n prompt
ufw status verbose

echo "== 3. Automatic security updates"
DEBIAN_FRONTEND=noninteractive apt-get -y install unattended-upgrades
# Same as "dpkg-reconfigure -plow unattended-upgrades" answered Yes
echo 'unattended-upgrades unattended-upgrades/enable_auto_updates boolean true' | debconf-set-selections
dpkg-reconfigure -f noninteractive unattended-upgrades
cat /etc/apt/apt.conf.d/20auto-upgrades

echo "== 4. Kernel network settings"
cat > /etc/sysctl.d/99-bh.conf <<'EOF'
net.ipv4.conf.all.accept_redirects = 0
net.ipv4.conf.all.send_redirects = 0
net.ipv4.conf.all.log_martians = 1
net.ipv4.tcp_syncookies = 1
EOF
sysctl --system > /dev/null
sysctl net.ipv4.conf.all.accept_redirects net.ipv4.conf.all.send_redirects net.ipv4.conf.all.log_martians net.ipv4.tcp_syncookies
