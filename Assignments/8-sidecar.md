# Lab Assignment: The Sidecar Pattern

**Estimated Time:** 10 minutes

**Prerequisites:** 2-node Talos cluster running with `kubectl` access configured.

**Objective:** Understand the sidecar container pattern by deploying a Pod with two containers sharing a filesystem volume, and learn how to interact with multi-container Pods.

## Background

In Kubernetes, a Pod can host more than one container. When multiple containers are placed in the same Pod, they are guaranteed to be scheduled on the same physical worker node. More importantly, they share the same **Network Namespace** (they can talk to each other over `localhost`) and can share **Storage Volumes**.

A **Sidecar** is a secondary container deployed alongside a primary application container to augment or extend its functionality without changing the primary application's code. 

**Common Sidecar Use Cases:**
* **Logging/Metrics:** An agent that reads local log files and ships them to a central server (like Datadog or Promtail).
* **Service Mesh:** A proxy (like Envoy in Istio) that intercepts all incoming/outgoing network traffic for security and routing.
* **Content Synchronization:** A background script that periodically pulls updated configuration files or website content from a Git repository.

## Step 1: Create the Sidecar Pod Manifest

We will simulate the "Content Synchronization" use case. 
* Our **Primary Container** will be an Nginx web server.
* Our **Sidecar Container** will be a lightweight Alpine Linux script that constantly updates an `index.html` file.
* They will communicate via a shared `emptyDir` volume (a temporary disk that exists as long as the Pod is running).

Create a file named `sidecar-pod.yaml`:

```yaml
apiVersion: v1
kind: Pod
metadata:
  name: sidecar-demo
  labels:
    app: sidecar-test
spec:
  # Pod-level security context (required for Talos)
  securityContext:
    runAsNonRoot: true
    runAsUser: 101
    runAsGroup: 101
    fsGroup: 101
    seccompProfile:
      type: RuntimeDefault
  
  # Define a shared temporary volume
  volumes:
    - name: shared-content
      emptyDir: {}

  containers:
    # 1. PRIMARY CONTAINER (Nginx Web Server)
    - name: web-server
      image: nginxinc/nginx-unprivileged:alpine
      ports:
        - containerPort: 8080
      volumeMounts:
        - name: shared-content
          mountPath: /usr/share/nginx/html
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
            
    # 2. SIDECAR CONTAINER (Content Generator)
    - name: content-generator
      image: alpine:latest
      # A simple script that overwrites the index.html file every 5 seconds
      command: ["/bin/sh", "-c"]
      args:
        - |
          while true; do
            echo "<h1>Hello from the Sidecar!</h1><p>Current time: $(date)</p>" > /app-data/index.html
            sleep 5
          done
      volumeMounts:
        - name: shared-content
          mountPath: /app-data
      securityContext:
        allowPrivilegeEscalation: false
        capabilities:
          drop:
            - ALL
```

## Step 2: Deploy and Inspect the Pod

Apply the manifest to your cluster:

```bash
kubectl apply -f sidecar-pod.yaml
```

Watch the Pod start up:

```bash
kubectl get pods -w
```

> **Observation:** Pay close attention to the `READY` column. It will show `0/2`, then `1/2`, and finally `2/2`. This indicates that the Pod defines **two** containers, and Kubernetes waits for both to be fully running before marking the overall Pod as Ready. Press `Ctrl+C` to exit the watch mode once it hits `2/2`.

## Step 3: Validate the Shared Volume

Our Nginx container knows nothing about the sidecar. It just serves whatever files exist in `/usr/share/nginx/html`. Let's see if the sidecar successfully wrote the content there.

1. Port-forward your local workstation to the Nginx container:

   ```bash
   kubectl port-forward pod/sidecar-demo 8080:8080 &
   ```

2. Access the web server:

   ```bash
   curl http://localhost:8080
   ```

3. Wait 6 seconds and run the `curl` command again.

> **Observation:** You should see the HTML output change, with the timestamp updating. The sidecar is running a continuous loop in the background, updating the file on the shared volume, which Nginx then immediately serves to the user. 

4. Stop the port-forwarding:

   ```bash
   kill %1
   ```

## Step 4: Interacting with Specific Containers

When a Pod has only one container, `kubectl logs` or `kubectl exec` automatically targets that container. With sidecars, you must specify *which* container you want to interact with using the `-c` flag.

1. View the logs of the primary web server:
   ```bash
   kubectl logs pod/sidecar-demo -c web-server
   ```

2. Open an interactive shell inside the sidecar container to inspect the shared volume:
   ```bash
   kubectl exec -it pod/sidecar-demo -c content-generator -- /bin/sh
   ```

3. Inside the sidecar shell, verify the files, then exit:
   ```bash
   # You are now inside the sidecar
   cat /app-data/index.html
   exit
   ```

## Verification & Debrief

| Concept | Implementation | Key Benefit | 
| ----- | ----- | ----- | 
| **Shared Storage** | `emptyDir` volume mounted to `/usr/share/nginx/html` and `/app-data`. | Allows containers to pass data seamlessly (e.g., sync scripts, log processors). | 
| **Separation of Concerns** | Nginx only serves HTTP. Alpine only fetches data. | You don't have to rebuild the Nginx image just to add a custom data-fetching script. | 
| **Container Targeting** | `kubectl exec -c <name>` | Allows granular debugging of individual processes within a single Pod. | 

### Cleanup

Delete the Pod:

```bash
kubectl delete -f sidecar-pod.yaml
```