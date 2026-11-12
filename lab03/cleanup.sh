#!/usr/bin/env bash
# Lab 03 - Exercise 3.4 step 5: disable services WEB01 does not need. Run as root.
set -uo pipefail

# No modem, not a VMware guest, no thermal control in a VM, no desktop disk manager, no LXD
systemctl disable --now ModemManager.service open-vm-tools.service vgauth.service \
  thermald.service udisks2.service lxd-installer.socket
# No snap is installed or used
systemctl disable --now snapd.service snapd.socket snapd.seeded.service
# No cloud datasource in VirtualBox; also stops cloud-init from rewriting netplan
touch /etc/cloud/cloud-init.disabled

systemctl list-unit-files --state=enabled --no-pager | tail -1
ss -tulpn
