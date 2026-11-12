#!/usr/bin/env bash
# Lab 04 - Exercise 4.5: create an Ubuntu VM from the command line instead of clicking.
#
# Usage:   provision.sh <vm-name> <vcpu> <ram-mb> <iso-path>
# Example: ./lab04/provision.sh lab-test 1 1024 "D:/ubuntu-24.04.5-live-server-amd64.iso"
#
# Creates the VM in VirtualBox's default machine folder with a 10 GB dynamic disk,
# NIC 1 on the NAT network BH-SRV, paravirtualisation KVM and the ISO in the DVD drive.
# The VM is not started. Delete it with: VBoxManage unregistervm <vm-name> --delete
# Works in Git Bash on Windows, and on Linux/macOS.
set -euo pipefail

NATNET=${NATNET:-BH-SRV}     # override with NATNET=other ./provision.sh ...
DISK_MB=${DISK_MB:-10240}    # 10 GB, dynamic (grows as the guest writes)

usage() {
  cat >&2 <<EOF
Usage: $(basename "$0") <vm-name> <vcpu> <ram-mb> <iso-path>

  vm-name   name of the new VM (must not exist yet)
  vcpu      number of virtual CPUs, e.g. 1
  ram-mb    memory in MB, e.g. 1024
  iso-path  installation ISO, e.g. D:/ubuntu-24.04.5-live-server-amd64.iso

Example: $(basename "$0") lab-test 1 1024 "D:/ubuntu-24.04.5-live-server-amd64.iso"
EOF
  exit 2
}
die() { echo "error: $*" >&2; exit 1; }

# --- Arguments --------------------------------------------------------------
[ $# -eq 4 ] || { [ $# -gt 0 ] && echo "error: expected 4 arguments, got $#" >&2; usage; }
VM=$1; CPU=$2; RAM=$3; ISO=$4

[[ $VM =~ ^[A-Za-z0-9][A-Za-z0-9._-]*$ ]] || die "invalid VM name '$VM' (letters, digits, . _ - only)"
[[ $CPU =~ ^[1-9][0-9]*$ ]]  || die "vcpu must be a positive integer, got '$CPU'"
[[ $RAM =~ ^[1-9][0-9]*$ ]]  || die "ram-mb must be a positive integer in MB, got '$RAM'"
[ "$RAM" -ge 512 ]           || die "ram-mb must be at least 512 for Ubuntu, got $RAM"
[ -f "$ISO" ]                || die "ISO not found: $ISO"

# --- VBoxManage (not on the PATH of a fresh Git Bash) ------------------------
if ! command -v VBoxManage >/dev/null 2>&1; then
  PATH="$PATH:/c/Program Files/Oracle/VirtualBox"
  command -v VBoxManage >/dev/null 2>&1 || die "VBoxManage not found; is VirtualBox installed?"
fi
vbox() { VBoxManage "$@" | tr -d '\r'; }   # Windows VBoxManage prints CRLF

# --- Safety checks before changing anything ---------------------------------
VMS=$(vbox list vms)                      # captured first: grep -q + pipefail can give false negatives
if grep -qF "\"$VM\" {" <<<"$VMS"; then
  die "a VM named '$VM' already exists; nothing was changed. Pick another name (only delete the old VM if you are sure nothing depends on it, e.g. no linked clone)."
fi
NATNETS=$(vbox natnetwork list)
grep -qE "^Name: +$NATNET\$" <<<"$NATNETS" || die "NAT network '$NATNET' does not exist (VBoxManage natnetwork list)"

FOLDER=$(vbox list systemproperties | sed -n 's/^Default machine folder: *//p')
[ -n "$FOLDER" ] || die "could not read the default machine folder (VBoxManage list systemproperties)"
DIR="$FOLDER/$VM"
[ ! -e "$DIR/$VM.vdi" ] || die "disk $DIR/$VM.vdi already exists (left over from an old VM?)"

case "$(uname -m)" in
  arm64|aarch64) CREATE_ARGS=(--ostype Ubuntu_arm64 --platform-architecture arm) ;;   # Apple Silicon
  *)             CREATE_ARGS=(--ostype Ubuntu_64) ;;
esac

# If a step fails half-way, say how to remove what was created.
trap 'echo "error: provisioning of $VM failed at the step above. Clean up with: VBoxManage unregistervm \"$VM\" --delete" >&2' ERR

# --- Provisioning -----------------------------------------------------------
echo "== Creating $VM: $CPU vCPU, $RAM MB, ${DISK_MB} MB disk, NIC1 on $NATNET, in $DIR"
VBoxManage createvm --name "$VM" "${CREATE_ARGS[@]}" --register
VBoxManage modifyvm "$VM" --cpus "$CPU" --memory "$RAM" --nic1 natnetwork --nat-network1 "$NATNET" --paravirtprovider kvm
VBoxManage createmedium disk --filename "$DIR/$VM.vdi" --size "$DISK_MB"
VBoxManage storagectl "$VM" --name SATA --add sata --controller IntelAhci
VBoxManage storageattach "$VM" --storagectl SATA --port 0 --device 0 --type hdd --medium "$DIR/$VM.vdi"
VBoxManage storageattach "$VM" --storagectl SATA --port 1 --device 0 --type dvddrive --medium "$ISO"

trap - ERR
echo "== Result"
vbox showvminfo "$VM" --machinereadable | grep -E '^(cpus|memory|nic1|nat-network1|paravirtprovider|"SATA-[01]-0")='
echo "== Done. Start it with: VBoxManage startvm \"$VM\" --type gui"
