# 1. Check Kubernetes Node States
kubectl get nodes -o wide

# 2. Check Talos OS Health on Control Plane
talosctl health --nodes $CP_IP

# 3. Verify etcd ring health
talosctl -n $CP_IP etcd status

# To verify this step, ensure all nodes have status Ready, 
# talosctl health exits with code 0 (no warnings), 
# and etcd status shows zero raft errors or split-brain alerts.

# Target upgrade image (e.g., v1.14.0)
INSTALLER_IMAGE="ghcr.io/siderolabs/installer:v1.14.2"

talosctl upgrade \
  --nodes $CP_IP \
  --image $INSTALLER_IMAGE \
#  --drain=false \
  --wait

# The --wait flag streams the node's transition: 
# downloading the squashfs image to Partition B, modifying the bootloader, 
# rebooting, and waiting for the API to come back online.

# To verify this step, 
# run talosctl version --nodes $CP_IP and 
# confirm the Tag field under Server displays the new target version.

# Verify Talos OS versions across the whole cluster
talosctl version --nodes $CP_IP,$WORKER_IP

# Check for any crashing application workloads
kubectl get pods -A | grep -v "Running"

