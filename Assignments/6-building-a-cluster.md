Talos Linux Bootstrapping Workshop

Target Environment: QEMU/KVM (libvirt)
Architecture: 1 Control Plane Node + 1 Worker Node
Deployment Method: Bare-Metal (metal) image with manual configuration delivery.

Overview

In this workshop, you will simulate a bare-metal Talos Linux deployment using local virtual machines. You will take two blank machines booting from an ISO, generate cryptographic identities for them, format their disks, and bootstrap a secure Kubernetes cluster—all without ever touching an SSH key or a Bash shell.

Prerequisites

A Linux host with libvirt, qemu-kvm, and virt-install installed.

The talosctl and kubectl CLI tools installed on your local workstation.

The Talos bare-metal ISO downloaded locally (e.g., metal-amd64.iso).

Assignment 1: Provision the Virtual Hardware

Talos needs hardware to boot. We will create virtual disks and launch the VMs, booting them directly from the Talos installation ISO.

Task:
Run the following commands to create the disk images and launch the VMs. Make sure to replace /path/to/metal-amd64.iso with the actual path to your downloaded Talos ISO.

# 1. Create virtual disks (20GB each)
qemu-img create -f qcow2 talos-cp.qcow2 20G
qemu-img create -f qcow2 talos-worker.qcow2 20G

# 2. Launch Control Plane VM
virt-install \
  --name talos-cp \
  --memory 3072 \
  --vcpus 2 \
  --disk path=./talos-cp.qcow2,bus=virtio \
  --cdrom /path/to/metal-amd64.iso \
  --network network=default,model=virtio \
  --os-variant linux2022 \
  --noautoconsole

# 3. Launch Worker VM
virt-install \
  --name talos-worker \
  --memory 2048 \
  --vcpus 2 \
  --disk path=./talos-worker.qcow2,bus=virtio \
  --cdrom /path/to/metal-amd64.iso \
  --network network=default,model=virtio \
  --os-variant linux2022 \
  --noautoconsole


Verification:
Run virsh list and confirm both talos-cp and talos-worker are listed with a running state.

Assignment 2: Network Discovery (Maintenance Mode)

Because the virtual disks are empty, Talos will boot from the ISO into an ephemeral "Maintenance Mode" in RAM and request an IP address from your local network.

Task:
Find the IP addresses assigned to your new VMs and save them as environment variables.

# List DHCP leases to find the assigned IPs
virsh net-dhcp-leases default


Once you identify the IPs, export them in your terminal:

export CP_IP="<INSERT_CONTROL_PLANE_IP>" 
export WORKER_IP="<INSERT_WORKER_IP>"    


Verification:
Run curl -k https://$CP_IP:50000. You should receive an immediate connection rejection or an SSL error (because it expects mTLS over gRPC), proving that the Maintenance API is listening on that port.

Assignment 3: PKI & Manifest Generation

Talos requires a set of cryptographic keys and declarative YAML configurations to operate.

Task:
Generate the machine configurations, specifying your Control Plane IP for the Kubernetes API endpoint (port 6443).

talosctl gen config demo-cluster https://$CP_IP:6443


Verification:
Run ls -l in your directory. You must see three new files: controlplane.yaml, worker.yaml, and talosconfig.

Assignment 4: Storage Alignment

By default, the bare-metal configs try to install Talos on a physical SATA/NVMe drive (/dev/sda). QEMU exposes disks as paravirtualized VirtIO block devices (/dev/vda).

Task:
Edit both YAML files to point the installer to /dev/vda.

sed -i 's|disk: /dev/sda|disk: /dev/vda|g' controlplane.yaml
sed -i 's|disk: /dev/sda|disk: /dev/vda|g' worker.yaml


Verification:
Run grep "disk:" controlplane.yaml worker.yaml. Both files should output disk: /dev/vda.

Assignment 5: Apply Configuration (OS Installation)

Now, deliver the configuration payload to the nodes running in memory. Because the nodes haven't been secured yet, we must bypass mTLS checks using the --insecure flag.

Task:
Apply the respective configs to your nodes.

talosctl apply-config --insecure --nodes $CP_IP --file controlplane.yaml
talosctl apply-config --insecure --nodes $WORKER_IP --file worker.yaml


Verification:
The command should succeed and the VMs will automatically reboot. During the reboot, Talos writes the OS to the virtual disk, ejects the ISO environment, and locks down port 50000 with the certificates generated in Assignment 3. Wait about 60 seconds before proceeding.

Assignment 6: Configure Context & Bootstrap

Your local talosctl tool now needs to use the talosconfig file to authenticate with the newly secured nodes. Then, you will trigger the Kubernetes initialization process.

Task:
Set your client context and issue the bootstrap command to the control plane.

export TALOSCONFIG="./talosconfig"
talosctl config endpoint $CP_IP
talosctl config node $CP_IP

talosctl bootstrap


Verification:
Run talosctl services. Within a minute or two, you should see the etcd and kubelet services transition to a Running or Healthy state.

Assignment 7: Kubernetes Access

With the control plane running, you need to extract the kubeconfig to use standard Kubernetes tooling.

Task:
Fetch the kubeconfig from the Talos API and verify your nodes.

talosctl kubeconfig . --nodes $CP_IP
export KUBECONFIG="./kubeconfig"

kubectl get nodes -o wide


Verification:
kubectl get nodes should list both your control plane and worker nodes. (Note: Their status will be NotReady until you deploy a CNI plugin like Cilium!)
