# Lab Assignment: Filesystem Isolation with `chroot`

**Estimated Time:** 10 minutes
**Environment:** Rocky Linux VM with `sudo` privileges
**Objective:** Observe how `chroot` (change root) isolates a process's view of the filesystem, completing the trinity of container fundamentals (Namespaces + Cgroups + chroot).

## Background

While namespaces isolate process trees and cgroups limit resources, a container also needs its own isolated filesystem (the container image). Long before Docker existed, Unix systems used `chroot` to change the apparent root directory (`/`) for a running process and its children.

A process running inside a `chroot` jail cannot see or access files outside of its designated directory tree. 

## Step 1: Create a Dummy Secret on the Host (1 min)

First, let's create a file on the host operating system to prove that our isolated environment won't be able to access it.

```bash
# Create a test file on the host's real root filesystem
sudo touch /secret-host-file.txt
echo "This is host data" | sudo tee /secret-host-file.txt

# Verify it exists
cat /secret-host-file.txt
```

## Step 2: Bootstrap the "Fake" Root Filesystem (4 mins)

A `chroot` environment is entirely empty by default. If we just change the root to an empty directory, the shell will crash because it won't be able to find `/bin/bash` or `ls`. 

Because you are on Rocky Linux, we can use the `dnf` package manager's `--installroot` feature to quickly build a minimal OS directory containing just the basic shell utilities.

```bash
# 1. Create a directory to act as our new root
mkdir /tmp/fake-root

# 2. Use dnf to install bash and coreutils into this specific directory
# Note: This will download a few megabytes of data and take about 1-2 minutes.
sudo dnf --installroot=/tmp/fake-root --releasever=9 --nodocs install bash coreutils -y
```

*Wait for the `Complete!` message before proceeding.*

## Step 3: Enter the Chroot Jail (2 mins)

Now, we will start a new `bash` process, but we will tell the Linux kernel to treat `/tmp/fake-root` as the absolute top-level directory (`/`).

```bash
# Enter the chroot
sudo chroot /tmp/fake-root /bin/bash

# Change the prompt so you don't forget you are in the jail!
export PS1="[chroot-jail]# "
```

## Step 4: Prove the Isolation (2 mins)

You are now operating inside the restricted filesystem. Let's test the boundaries.

1. **Where are we?**
   ```bash
   pwd
   ```
   *(Notice it says `/`, not `/tmp/fake-root`)*

2. **What does the filesystem look like?**
   ```bash
   ls -l /
   ```
   *(Notice the minimal layout. There are no host user home directories here.)*

3. **Can we see the host's secret file?**
   ```bash
   cat /secret-host-file.txt
   ```
   *(Expected output: `cat: /secret-host-file.txt: No such file or directory`)*

4. **Leave a mark inside the jail:**
   ```bash
   touch /i-was-here.txt
   exit
   ```

## Step 5: The Host Perspective (1 min)

You have now exited back to the normal Rocky Linux host shell. Let's see where the file you created actually ended up.

```bash
ls -l /tmp/fake-root/i-was-here.txt
```

## Verification & Debrief

| Perspective | Root Path (`/`) | Can see `/secret-host-file.txt`? | 
| ----- | ----- | ----- | 
| **Standard Host Shell** | The physical VM disk root | Yes | 
| **Inside the Chroot** | `/tmp/fake-root/` | No | 

### Cleanup

Remove the fake root filesystem and the test file:

```bash
sudo rm -rf /tmp/fake-root
sudo rm -f /secret-host-file.txt
```

### Core Architecture Takeaway

This is exactly how container images work! When you pull an image like `nginx:alpine`, you are downloading a pre-packaged directory containing Alpine Linux files. Container runtimes (like `containerd`) unpack that directory, configure Namespaces and Cgroups, and then use `pivot_root` (a modern, more secure successor to `chroot`) to lock the application inside that isolated filesystem.