#!/usr/bin/env bash
set -e

echo "=== 1. Stopping and undefining QEMU/KVM virtual machines ==="
for VM in talos-cp talos-worker; do
  if virsh dominfo "$VM" >/dev/null 2>&1; then
    echo "Processing $VM..."
    # Force stop the VM if running
    if virsh domstate "$VM" | grep -q "running"; then
      echo "  Stopping $VM..."
      virsh destroy "$VM" || true
    fi
    # Undefine domain and nvram
    echo "  Undefining $VM..."
    virsh undefine "$VM" --nvram --remove-all-storage 2>/dev/null || virsh undefine "$VM" || true
  else
    echo "  VM '$VM' not found in libvirt; skipping."
  fi
done

echo "=== 2. Removing virtual disk files ==="
DISKS=(
  "./talos-cp.qcow2"
  "./talos-worker.qcow2"
  "/var/lib/libvirt/images/talos-cp.qcow2"
  "/var/lib/libvirt/images/talos-worker.qcow2"
)

for DISK in "${DISKS[@]}"; do
  if [ -f "$DISK" ]; then
    echo "  Removing disk file: $DISK"
    rm -f "$DISK"
  fi
done

echo "=== 3. Removing generated cluster manifests and credentials ==="
FILES_TO_REMOVE=(
  "controlplane.yaml"
  "worker.yaml"
  "talosconfig"
  "kubeconfig"
)

for FILE in "${FILES_TO_REMOVE[@]}"; do
  if [ -f "$FILE" ]; then
    echo "  Removing: $FILE"
    rm -f "$FILE"
  fi
done

echo "=== 4. Resetting shell environment variables ==="
unset TALOSCONFIG
unset KUBECONFIG
unset CP_IP
unset WORKER_IP

echo "Cleanup complete! The cluster and configuration artifacts have been removed."