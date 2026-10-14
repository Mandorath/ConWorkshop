#!/bin/bash
# 1. Create virtual disks (minimum 20G recommended)
qemu-img create -f qcow2 talos-cp.qcow2 20G
qemu-img create -f qcow2 talos-worker.qcow2 20G

# 2. Launch Control Plane VM (2 vCPU, 2-3GB RAM)
virt-install \
  --name talos-cp \
  --memory 3072 \
  --vcpus 2 \
  --disk path=./talos-cp.qcow2,bus=virtio \
  --cdrom ./metal-amd64.iso \
  --network network=default,model=virtio \
  --os-variant linux2022 \
  --noautoconsole

# 3. Launch Worker VM (2 vCPU, 2GB RAM)
virt-install \
  --name talos-worker \
  --memory 2048 \
  --vcpus 2 \
  --disk path=./talos-worker.qcow2,bus=virtio \
  --cdrom ./metal-amd64.iso \
  --network network=default,model=virtio \
  --os-variant linux2022 \
  --noautoconsole
