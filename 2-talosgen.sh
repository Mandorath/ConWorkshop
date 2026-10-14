#!/bin/bash
source ips.sh
echo $CP_IP
echo $WORKER_IP
talosctl gen config demo-cluster https://$CP_IP:6443 --force

# By default, the bare-metal config targets physical disks like /dev/sda. 
# Because QEMU/KVM exposes VirtIO block devices as /dev/vda,
# you must update the installation disk directive before pushing the configs:
# Update control plane install disk
sed -i 's|/dev/sda|/dev/vda|g' controlplane.yaml

# Update worker install disk
sed -i 's|/dev/sda|/dev/vda|g' worker.yaml

# Apply to Control Plane
talosctl apply-config --insecure --nodes $CP_IP --file controlplane.yaml

# Apply to Worker
talosctl apply-config --insecure --nodes $WORKER_IP --file worker.yaml
