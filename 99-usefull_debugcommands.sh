#!/bin/bash
source ips.sh
#export TALOSCONFIG="./talosconfig"
# Stream machine logs to see the installer progress or error
talosctl logs machined --insecure -n $CP_IP

# Check kernel logs
talosctl dmesg --insecure -n $CP_IP

# Check which disks Talos detects
talosctl disks --insecrure -n $CP_IP

# Check which disks are stated in the machine configuration
grep -A 2 "install:" controlplane.yaml worker.yaml
