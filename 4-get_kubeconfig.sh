#!/bin/bash
# Retrieve kubeconfig
source ips.sh
talosctl kubeconfig . --nodes $CP_IP
export KUBECONFIG="./kubeconfig"

# Verify cluster node status
kubectl get nodes -o wide
kubectl get pods -n kube-system
