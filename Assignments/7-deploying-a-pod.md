# Lab Assignment: Pod Architecture & Deployments on Talos Linux

**Estimated Time:** 15 minutes  
**Prerequisites:** 2-node Talos cluster running with `talosconfig` and `kubeconfig` configured (`kubectl` access established).  
**Objective:** Understand the relationship between Pods and Deployments, deploy a declarative workload onto the worker node, and validate network connectivity using standard Kubernetes primitives.

---

## 1. Verify Cluster & CNI Readiness

Before scheduling workloads, verify that Talos's built-in Flannel daemon has initialized and both nodes report `Ready`.

```bash
# Verify both nodes are in the Ready state
kubectl get nodes -o wide

# Confirm default Flannel and CoreDNS pods are running
kubectl get pods -n kube-system -l k8s-app=flannel
kubectl get pods -n kube-system -l k8s-app=kube-dns
```

Both nodes should display `STATUS: Ready`. Flannel automatically provisions the overlay pod CIDR subnet across each node.

---

## 2. Pods vs. Deployments: Core Concepts

* **Pod:** The smallest deployable computing unit in Kubernetes. A Pod encapsulates one or more co-located containers, shared storage volumes, and a single shared network namespace (one Pod IP). Direct Pod definitions (`kind: Pod`) are ephemeral; if the underlying worker node reboots or crashes, standalone pods are not recreated.
* **Deployment:** A higher-level controller (`kind: Deployment`) that manages declarative updates for Pods via an intermediate **ReplicaSet**. Deployments provide:
  * **Self-healing:** Replaces failed or evicted Pods automatically.
  * **Scaling:** Adjusts replica counts dynamically.
  * **Zero-Downtime Rollouts:** Manages phased rolling updates and rollbacks across revisions.

---

## 3. Create the Deployment Manifest

Talos Linux enforces Kubernetes Pod Security Standards (`restricted` profile by default on newer versions). Container images running as root will be rejected. 

Create a file named `deployment.yaml` using an unprivileged Nginx image configured with non-root security contexts:

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web-demo
  namespace: default
  labels:
    app.kubernetes.io/name: web-demo
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: web-demo
  template:
    metadata:
      labels:
        app.kubernetes.io/name: web-demo
    spec:
      securityContext:
        runAsNonRoot: true
        runAsUser: 101
        runAsGroup: 101
        fsGroup: 101
        seccompProfile:
          type: RuntimeDefault
      containers:
        - name: nginx
          image: nginxinc/nginx-unprivileged:alpine
          ports:
            - containerPort: 8080
              name: http
          securityContext:
            allowPrivilegeEscalation: false
            readOnlyRootFilesystem: false
            capabilities:
              drop:
                - ALL
          resources:
            requests:
              cpu: 50m
              memory: 64Mi
            limits:
              cpu: 100m
              memory: 128Mi
```

---

## 4. Deploy the Workload

Apply the manifest to the cluster:

```bash
kubectl apply -f deployment.yaml
```

Track the roll-out state:

```bash
# Watch the deployment rollout complete
kubectl rollout status deployment/web-demo

# Inspect the underlying ReplicaSet created by the Deployment
kubectl get replicasets -l app.kubernetes.io/name=web-demo

# Inspect the individual Pods
kubectl get pods -l app.kubernetes.io/name=web-demo -o wide
```

Notice the `NODE` column in `kubectl get pods -o wide`: the Pods are automatically scheduled onto your worker node because the Talos control plane node maintains a `node-role.kubernetes.io/control-plane:NoSchedule` taint by default.

---

## 5. Validate Pod Connectivity

Because Pod IP addresses are allocated from Flannel's private overlay network, they are not directly routable from your workstation's host network. Test connectivity using two standard Kubernetes validation patterns:

### Method A: Local Port-Forwarding (Direct Workstation Access)
Proxy a local workstation port directly to one of the deployment's Pods:

```bash
# Forward local port 8080 to container port 8080
kubectl port-forward deployment/web-demo 8080:8080
```

Open a second terminal window and test HTTP access:

```bash
curl -I http://localhost:8080
```

*Expected output:* `HTTP/1.1 200 OK`

Press `Ctrl+C` in the first terminal to terminate the port-forward session.

### Method B: Intra-Cluster In-Pod Verification
Validate that Flannel routes traffic between Pods across the virtual network by spinning up an ephemeral debug container:

```bash
# 1. Capture the internal Flannel IP of one web-demo pod
POD_IP=$(kubectl get pods -l app.kubernetes.io/name=web-demo -o jsonpath='{.items[0].status.podIP}')
echo "Target Pod IP: $POD_IP"

# 2. Run a temporary curl probe inside the cluster network
kubectl run curl-test --image=curlimages/curl --rm -it --restart=Never -- curl -s -I "http://$POD_IP:8080"
```

*Expected output:* A standard `HTTP/1.1 200 OK` header response returned from within the overlay network.

---

## 6. Test Controller Self-Healing

1. Delete one of the active Pods manually:
   ```bash
   TARGET_POD=$(kubectl get pods -l app.kubernetes.io/name=web-demo -o jsonpath='{.items[0].metadata.name}')
   kubectl delete pod $TARGET_POD
   ```
2. Immediately inspect the Pod list:
   ```bash
   kubectl get pods -l app.kubernetes.io/name=web-demo
   ```

*Observation:* While the deleted Pod terminates, the Deployment controller detects that the current state (1 Pod) does not match the desired state (2 replicas) and instantly provisions a replacement Pod with a new UID and IP address.

---

## 7. Cleanup

Remove the deployed resources:

```bash
kubectl delete -f deployment.yaml
```