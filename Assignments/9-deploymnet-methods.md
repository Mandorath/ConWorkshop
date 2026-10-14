# Lab Assignment: Advanced Orchestration - Helm, Kustomize, and Operators

**Estimated Time:** 25 minutes

**Prerequisites:** 
* 2-node Talos cluster running with `kubectl` access configured.
* `helm` CLI installed on your local workstation.

**Objective:** Experience the three primary methods for deploying complex applications to Kubernetes: template-driven packaging (Helm), declarative overlays (Kustomize), and active automated reconciliation (Operators).

---

## Part 1: Helm (Template-Driven Package Management)

**Concept:** Helm treats deployments like packages. It uses a templating engine (Go templates) to inject variables from a `values.yaml` file into generic YAML manifests, allowing you to deploy the same application with different configurations.

### Step 1.1: Add a Helm Repository
We will use the public Bitnami repository, which hosts hundreds of pre-packaged applications.

```bash
helm repo add bitnami https://charts.bitnami.com/bitnami
helm repo update
```

### Step 1.2: Observe the Templating Engine
Before deploying, let's see how Helm generates YAML dynamically. We will ask Helm to render an Nginx web server template, overriding the default replica count to 3.

```bash
helm template my-web bitnami/nginx --set replicaCount=3 | grep -A 10 "kind: Deployment"
```

> **Observation:** Notice how Helm took the raw template from the internet, injected your `replicaCount=3` parameter, and output fully valid Kubernetes YAML.

### Step 1.3: Deploy and Track the Release
Helm tracks what it installs. Deploy the chart to your cluster:

```bash
helm install my-web bitnami/nginx --set replicaCount=1
```

Verify that Helm is tracking this release:

```bash
helm list
kubectl get pods -l app.kubernetes.io/instance=my-web
```

---

## Part 2: Kustomize (Template-Free Overlays)

**Concept:** Kustomize avoids templates completely. Instead, it uses a "Base" (a complete, valid set of YAML files) and applies "Overlays" (patches that overwrite specific fields for different environments, like Dev or Prod).

### Step 2.1: Create the Base
Create a directory for your base application and define a simple ConfigMap.

```bash
mkdir -p kustomize-demo/base
cd kustomize-demo

cat <<EOF > base/configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  environment: "base"
  log_level: "info"
EOF

cat <<EOF > base/kustomization.yaml
resources:
  - configmap.yaml
EOF
```

### Step 2.2: Create the Production Overlay
Now, create a production overlay that patches the base configuration without altering the original files.

```bash
mkdir -p overlays/prod

cat <<EOF > overlays/prod/patch.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: app-config
data:
  environment: "PRODUCTION"
  log_level: "error"
EOF

cat <<EOF > overlays/prod/kustomization.yaml
resources:
  - ../../base
patches:
  - path: patch.yaml
namePrefix: prod-
EOF
```

### Step 2.3: Build and Apply the Overlay
Use `kubectl`'s native Kustomize support to merge the base and the patch, and apply it directly to the cluster.

```bash
# Preview the merged output (Notice the name prefix and updated data)
kubectl kustomize overlays/prod

# Apply it to the cluster
kubectl apply -k overlays/prod

# Verify the ConfigMap in the cluster
kubectl get configmap prod-app-config -o yaml
```

---

## Part 3: Operators (Active Automation via CRDs)

**Concept:** Helm and Kustomize only *deploy* YAML. Once the YAML is applied, their job is done. An **Operator** is a running application (a custom controller) that lives inside your cluster. It watches for Custom Resource Definitions (CRDs) and actively manages day-2 operations like failovers, backups, and upgrades.

We will deploy the CloudNativePG Operator, which automates PostgreSQL databases.

### Step 3.1: Install the Operator and CRDs
First, install the operator's "brain" into the cluster.

```bash
kubectl apply --server-side -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.25.0.yaml
```

Wait for the operator pod to start running:

```bash
kubectl get pods -n cnpg-system -w
```
*(Press Ctrl+C when running)*

### Step 3.2: Submit a Custom Resource (CR)
Normally, deploying a highly available database requires dozens of Deployments, Services, and StatefulSets. With an Operator, we just submit a tiny Custom Resource, and the Operator does the rest.

```bash
cat <<EOF > db-cluster.yaml
apiVersion: postgresql.cnpg.io/v1
kind: Cluster
metadata:
  name: demo-db
spec:
  instances: 2
  storage:
    ephemeral: true
EOF

kubectl apply -f db-cluster.yaml
```

### Step 3.3: Watch the Operator Work
Watch your cluster and observe how the Operator reacts to your request.

```bash
kubectl get pods -w
```
> **Observation:** You will see the operator automatically provision `demo-db-1`, wait for it to initialize, and then provision a replica `demo-db-2`, joining them together in a high-availability cluster automatically. 

---

## Verification & Debrief

| Tool | Core Mechanism | Best Used For |
| :--- | :--- | :--- |
| **Helm** | Templating & Parameter Injection | Distributing 3rd-party apps (e.g., installing Redis or Prometheus). |
| **Kustomize** | Declarative Patching | In-house apps deployed across multiple environments (Dev/Stage/Prod). |
| **Operators** | Custom Controllers & CRDs | Stateful, complex applications requiring active management (Databases). |

### Cleanup

Clean up all resources deployed during this lab:

```bash
# Helm cleanup
helm uninstall my-web

# Kustomize cleanup
kubectl delete -k overlays/prod

# Operator cleanup
kubectl delete -f db-cluster.yaml
kubectl delete -f https://raw.githubusercontent.com/cloudnative-pg/cloudnative-pg/main/releases/cnpg-1.25.0.yaml
```