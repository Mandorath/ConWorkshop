# Lab Assignment: Dissecting Linux Namespaces with `unshare`

**Estimated Time:** 10 minutes  
**Environment:** Linux terminal / VM with `sudo` privileges  
**Objective:** Observe hands-on how Linux kernel namespaces isolate host resources (UTS and PID) to build the core foundation of a container.

---

## Background

Containers do not exist as distinct entities in the Linux kernel; they are standard Linux processes running inside isolated namespaces (`pid`, `net`, `mnt`, `uts`, `ipc`, `user`) governed by `cgroups`. The `unshare` CLI disassociates specific namespaces from the parent shell without needing Docker, Podman, or any container engine installed.

---

## Step 1: Record Baseline Host State (1 min)

Check your host's current hostname and total process count:

```bash
# 1. Inspect current hostname
hostname

# 2. Check current shell PID and total running processes on the host
echo "Current Shell PID: $$"
ps aux | wc -l
```

---

## Step 2: Isolate the Hostname with the UTS Namespace (3 mins)

The **UTS (UNIX Timesharing System)** namespace allows a process tree to have its own hostname and domain name without mutating the host system.

1. Launch a bash shell inside a private UTS namespace:
   ```bash
   sudo unshare --uts /bin/bash
   ```

2. Change the hostname inside the isolated shell:
   ```bash
   hostname isolated-node
   ```

3. Verify the change inside this shell:
   ```bash
   hostname
   ```

4. Switch to a **second terminal window** on your host (or press `Ctrl+Z`, run `hostname`, then resume with `fg`):
   ```bash
   hostname
   ```

> **Observation:** The host retains its original hostname. The modified hostname exists solely within the isolated UTS namespace.

Type `exit` in the isolated shell before moving to Step 3:
```bash
exit
```

---

## Step 3: Isolate the Process Tree with PID and Mount Namespaces (4 mins)

The **PID namespace** virtualizes process IDs. The first process spawned inside a new PID namespace becomes **PID 1** (the init process of that isolated environment).

1. Execute a shell with its own PID, Mount, and UTS namespaces:
   ```bash
   sudo unshare --uts --pid --mount-proc --fork /bin/bash
   ```

   * `--uts`: Isolates system hostname.
   * `--pid`: Creates an isolated PID number space.
   * `--mount-proc`: Mounts a fresh, private `/proc` filesystem so commands like `ps` reflect only the local namespace.
   * `--fork`: Forks the specified program as a child process (required because a process cannot change its own PID namespace; only child processes inherit the new namespace).

2. Set a custom prompt and inspect the running processes:
   ```bash
   export PS1="[container-shell]# "
   ps aux
   ```

   **Expected Output:**
   ```text
   USER       PID %CPU %MEM    VSZ   RSS TTY      STAT START   TIME COMMAND
   root         1  0.0  0.0  11824  5120 pts/1    S    10:00   0:00 /bin/bash
   root         2  0.0  0.0  13512  3328 pts/1    R+   10:00   0:00 ps aux
   ```

> **Observation:** The hundreds of host processes have disappeared. The isolated bash shell now runs as **PID 1**.

---

## Step 4: The Dual-Perspective Test (2 mins)

Prove that your isolated "PID 1" is simultaneously an ordinary process on the host.

1. Inside `[container-shell]#`, spawn a long-running background command:
   ```bash
   sleep 9999 &
   ps aux
   ```
   *Note the PID assigned to `sleep` (typically `PID 3`).*

2. From your **second (host) terminal**, search for that exact process:
   ```bash
   ps aux | grep "sleep 9999" | grep -v grep
   ```

   **Expected Host Output:**
   ```text
   root     42189  0.0  0.0   7480  1024 pts/1    S    10:02   0:00 sleep 9999
   ```

---

## Verification & Debrief

| Perspective | `sleep 9999` PID | What Can It See? |
| :--- | :--- | :--- |
| **Inside Namespace** | `PID 3` | Only `/bin/bash`, `sleep`, and `ps` |
| **On Host OS** | `PID 42189` | Every process running across the entire system |

### Cleanup
Terminate the background job and exit the namespace:
```bash
[container-shell]# kill %1
[container-shell]# exit
```

### Core Architecture Takeaway
Container runtimes (`runc`, `containerd`, `CRI-O`) perform these identical kernel operations when bootstrapping a container:
1. Call `clone()` / `unshare()` with namespace flags (`CLONE_NEWPID`, `CLONE_NEWNET`, `CLONE_NEWNS`, etc.).
2. Restrict resources using Control Groups (`cgroups v2`).
3. Pivot the filesystem root to an OCI image layer (`pivot_root`).
4. Execute the entrypoint binary as PID 1.