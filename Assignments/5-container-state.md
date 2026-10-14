# Lab Assignment: Stateless vs. Stateful Containers

**Estimated Time:** 10 minutes
**Environment:** Rocky Linux VM with `podman` installed
**Objective:** Observe the ephemeral (temporary) nature of container filesystems and learn how to decouple data from the container lifecycle using volume mounts.

## Background

By default, containers are **stateless** and ephemeral. When a container engine (like Podman, containerd, or Docker) creates a container, it provides a read-write layer on top of the read-only image. If the container crashes, is deleted, or is rescheduled, that read-write layer is permanently destroyed along with all data inside it.

To run **stateful** applications (like databases), we must bypass the container's temporary filesystem and mount a persistent directory from the host operating system directly into the container.

## Step 1: The Stateless Nightmare (Data Loss) (3 mins)

First, we will simulate a stateless web application writing user uploads to its local filesystem.

1. Start a background container named `stateless-app`:

   ```bash
   podman run -d --name stateless-app alpine sleep 9999
   
   ```

2. Execute a command inside the running container to simulate a user uploading an important file:

   ```bash
   podman exec stateless-app sh -c "echo 'CRITICAL_USER_DATA_123' > /important-data.txt"
   
   ```

3. Verify the file exists inside the container:

   ```bash
   podman exec stateless-app cat /important-data.txt
   
   ```

4. **Disaster Strikes:** The container crashes or is deleted during a routine update. Let's forcefully remove it and start a fresh one with the same name:

   ```bash
   podman rm -f stateless-app
   podman run -d --name stateless-app alpine sleep 9999
   
   ```

5. Try to read the data in the new container:

   ```bash
   podman exec stateless-app cat /important-data.txt
   
   ```

> **Observation:** You will receive a `No such file or directory` error. The new container started from the pristine, read-only Alpine image. The user's data was destroyed when the previous container was removed.

## Step 2: The Stateful Solution (Persistent Volumes) (4 mins)

Now, let's fix the architecture by decoupling the data from the container's lifecycle.

1. Create a directory on your Rocky Linux host to serve as persistent storage:

   ```bash
   mkdir -p ~/persistent-storage
   
   ```

2. Start a new container, but this time use the `-v` flag to bind-mount the host directory into the container at `/app-data`. 
   
   *Note: Because Rocky Linux uses SELinux, we append `:Z` to the mount so Podman automatically applies the correct SELinux context, allowing the container to write to it.*

   ```bash
   podman run -d --name stateful-app -v ~/persistent-storage:/app-data:Z alpine sleep 9999
   
   ```

3. Write data to the mounted directory from *inside* the container:

   ```bash
   podman exec stateful-app sh -c "echo 'SAFE_DATABASE_RECORDS' > /app-data/database.txt"
   
   ```

4. Verify the data actually exists on the *host* machine:

   ```bash
   cat ~/persistent-storage/database.txt
   
   ```

## Step 3: Proving Data Survival (2 mins)

Let's simulate another disaster by destroying the stateful container.

1. Forcefully remove the container:

   ```bash
   podman rm -f stateful-app
   
   ```

2. Spin up a completely new, temporary container, mount the same volume, and immediately read the file:

   ```bash
   podman run --rm -v ~/persistent-storage:/app-data:Z alpine cat /app-data/database.txt
   
   ```

> **Observation:** The output successfully displays `SAFE_DATABASE_RECORDS`. Even though the original container was completely destroyed, the data lived safely on the host machine and was instantly available to the replacement container.

## Verification & Debrief

| Workload Type | Data Storage Location | Survives Container Deletion? | Ideal Use Cases | 
| ----- | ----- | ----- | ----- |
| **Stateless** | Container's internal R/W layer | No | Web servers, API gateways, computation workers | 
| **Stateful** | External Volume Mount | Yes | PostgreSQL, Redis, Prometheus metrics, file servers | 

### Cleanup

Remove the lingering stateless container and the host directory:

```bash
podman rm -f stateless-app
rm -rf ~/persistent-storage
```

### Core Architecture Takeaway

This is the exact mechanism Kubernetes uses to manage storage!
*   **Stateless Deployments:** Pods rely on the ephemeral container filesystem (`emptyDir`). If the Pod dies, the data dies.
*   **StatefulSets:** Pods request **Persistent Volumes (PVs)** via **Persistent Volume Claims (PVCs)**. The `kubelet` dynamically mounts an external disk (like an AWS EBS volume or a local host path) into the container, just like your `-v` flag did here.