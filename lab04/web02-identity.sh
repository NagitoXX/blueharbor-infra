#!/usr/bin/env bash
# Lab 04 - Exercise 4.2 step 2: give the WEB02 linked clone its own identity.
# Run as root on the WEB02 console (the clone starts with WEB01's IP, so WEB01 must be off).
set -euo pipefail

echo "== Hostname"
hostnamectl set-hostname web02
sed -i 's/web01/web02/g' /etc/hosts
hostnamectl --static; grep 127.0.1.1 /etc/hosts

echo "== Network: 10.10.20.20 -> 10.10.20.21"
ls /etc/netplan/
f=$(grep -l '10\.10\.20\.20' /etc/netplan/*.yaml)          # the file that holds the address
sed -i 's#10\.10\.20\.20/24#10.10.20.21/24#' "$f"
mv "$f" /etc/netplan/01-web02.yaml
chmod 600 /etc/netplan/01-web02.yaml
grep -n 'addresses' /etc/netplan/01-web02.yaml
netplan generate                                           # stops here on a YAML error
netplan apply
ip -4 -br addr show enp0s3

echo "== New machine-id"
cat /etc/machine-id
rm /etc/machine-id && systemd-machine-id-setup

echo "== New SSH host keys"
rm /etc/ssh/ssh_host_*
dpkg-reconfigure -f noninteractive openssh-server
ssh-keygen -lf /etc/ssh/ssh_host_ed25519_key.pub

echo "== Done, rebooting in 5 s"
sleep 5
systemctl reboot
