# Lab Assignment: Resource Control with Linux cgroups

**Estimated Time:** 10 minutes
**Environment:** Rocky Linux VM with `sudo` privileges
**Objective:** Observe how Linux Control Groups (cgroups) limit the CPU resources a process is allowed to consume, forming the resource-management foundation of containers.

## Background

While namespaces (like `unshare`) isolate *what* a process can see, **cgroups** isolate *how much* of the host's resources (CPU, memory, disk I/O) a process can use.

On modern Linux distributions like Rocky Linux, `systemd` acts as the primary manager for cgroups (specifically cgroups v2). Instead of interacting directly with the `/sys/fs/cgroup` virtual filesystem, we can use standard systemd tools to dynamically apply limits to running processes.

## Step 1: Create a Baseline CPU Spike (3 mins)

First, let's create a process that consumes as much CPU as possible without any limitations. We will use the `dd` command to endlessly copy zeros to nowhere.

1. Launch the CPU-heavy process in the background:
   ```bash
   dd if=/dev/zero of=/dev/null &
   ```

2. Open the `top` task manager to observe the CPU usage:
   ```bash
   top
   ```
   *Press `q` to exit `top` when you are done observing.*

> **Observation:** You should see the `dd` process at the top of the list, consuming exactly **100%** of a single CPU core. 

3. Terminate the unbounded process:
   ```bash
   killall dd
   ```

## Step 2: Apply a Cgroup Limit using systemd (4 mins)

Now, we will run the exact same command, but we will wrap it in a `systemd` transient unit. This allows us to assign a specific cgroup policy to the process—in this case, restricting it to only 20% of a CPU core.

1. Start the process inside a restricted cgroup named `cpuhog`:
   ```bash
   sudo systemd-run --unit=cpuhog --property=CPUQuota=20% dd if=/dev/zero of=/dev/null
   ```
   *Expected Output: `Running as unit: cpuhog.service`*

2. Verify the CPU usage again using `top`:
   ```bash
   top
   ```
   *Press `q` to exit.*

> **Observation:** Even though `dd` is trying to run as fast as possible, the Linux kernel scheduler is now throttling it. You will see its CPU usage hovering strictly around **20.0%**.

## Step 3: Inspect the Cgroup Hierarchy (2 mins)

You can view the actual cgroup tree and real-time resource usage managed by systemd.

1. Run the systemd cgroup top command:
   ```bash
   systemd-cgtop
   ```
   *Press `q` to exit.*

2. Look for the `cpuhog.service` in the list. You will see it listed within the `system.slice` hierarchy, showing its restricted CPU consumption.

## Verification & Debrief

| Execution Method | CPU Usage | Why? |
| :--- | :--- | :--- |
| **Standard Shell** | 100% | The process has unrestricted access to the default shell slice. |
| **systemd-run (cgroup)** | 20% | The kernel actively pauses the process once it hits its quota within a given time slice. |

### Cleanup
Stop the transient service to kill the process and clean up the cgroup:
```bash
sudo systemctl stop cpuhog
```

### Core Architecture Takeaway
When you run a pod with `resources.limits.cpu: "200m"` in Kubernetes, the container runtime (like containerd) talks to the host OS to create a cgroup with this exact type of CPUQuota. If the container tries to exceed it, the Linux kernel throttles it, ensuring other containers on the same node do not get starved of resources.