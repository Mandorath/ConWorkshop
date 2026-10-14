#!/bin/bash
source ips.sh
# Set talosctl context
export TALOSCONFIG="./talosconfig"
talosctl config endpoint $CP_IP
talosctl config node $CP_IP

# Issue bootstrap command
talosctl bootstrap

echo sleeping for 20 seconds
sleep 20
talosctl services
