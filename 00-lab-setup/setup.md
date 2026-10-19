# Lab Setup

## 1. Virtual Machine & OS Installation

### Base Image & Integrity Verification
1. Download the official pre-built **Kali Linux** QEMU image from the Kali website and verify its cryptographic hash on the host before importing:
   - **OS / Image Version:** `Kali Linux 2026.2`
   - **Architecture:** `amd64` (`x86_64`)
   - **Image Archive:** `kali-linux-2026.2-qemu-amd64.7z` (extracts to `kali-linux-2026.2-qemu-amd64.qcow2`)
   - **SHA-256 Hash:** `c7c35588d05277c482c908bf7a136d348f76ffa68700b04ff53c0b217e6bd071`

```bash
# Verify image integrity on the host machine before creating the VM
sha256sum kali-linux-2026.2-qemu-amd64.7z
```

### VM Hardware Specification (QEMU/KVM via libvirt)
2. Import the `qcow2` disk into **QEMU/KVM** (`virt-manager` / `virsh`) with the following resource allocation:
   - **Hypervisor:** QEMU/KVM (`qemu:///system`)
   - **vCPU:** 4 vCPUs (1 socket, 2 cores, 2 threads per core, host-passthrough mode)
   - **Memory:** 4096 MB (4 GB) RAM
   - **Storage:** 80 GB `qcow2` virtual disk (VirtIO-blk bus)

### Isolation Boundary & Network Policy
3. Configure the VM isolation boundary to ensure untrusted binaries, exploits, and vulnerable containers cannot compromise the host OS or lateral-move into the home LAN:
   - **Host-Guest Isolation:** Shared folders (`virtiofs` / `9p`), USB passthrough, and bidirectional clipboard/file drag-and-drop (`spice-vdagent`) are **disabled** when analyzing untrusted targets. Artifact transfer into the VM is performed strictly one-way (via temporary read-only ISO mounts).
   - **Baseline Network Mode (Setup & Updates):** Attached to `libvirt` NAT (`default` / `virbr0`, `192.168.122.0/24`). Allows outbound internet access for `apt`, `pip`, and `docker pull`.
   - **Research / Exploit Execution Network Mode:** Switched to an **Isolated Virtual Network** (internal bridge with no physical NIC forwarding and no gateway) before running live exploits, malware samples, or vulnerable CVE containers.

4. Boot the VM and update the base operating system:
```bash
sudo apt update && sudo apt upgrade -y
```

---

## 2. Install Lab Tools & Dependencies
Install the core toolchain, Docker, Ghidra, and the C/C++ build dependencies required to compile Python extensions:
```bash
sudo apt install -y build-essential gdb git python3 python3-pip python3-dev \
  python3-venv docker.io docker-compose cmake pkg-config \
  libglib2.0-dev libffi-dev libssl-dev ghidra
```

---

## 3. Configure Tooling
### Install pwndbg (GDB plugin)
```bash
git clone https://github.com/pwndbg/pwndbg
cd pwndbg && ./setup.sh && cd ..
```

### Install pwntools in a Virtual Environment
Create an isolated virtual environment and install `pwntools`:
```bash
python3 -m venv ~/vr-venv
source ~/vr-venv/bin/activate
pip install pwntools
```

### Configure Docker Permissions
Allow the current user to run Docker containers without `sudo` (log out and log back in afterward for group changes to take effect):
```bash
sudo usermod -aG docker $USER
```

---

## 4. Self-Check & Verification
Run the following commands to verify that all components of the research toolchain function properly:

1. **Verify `gcc`:**
```bash
gcc --version
echo 'int main(){return 0;}' > t.c && gcc t.c -o t && ./t && echo BUILD_OK
rm -f t.c t
```

2. **Verify `pwntools`:**
```bash
source ~/vr-venv/bin/activate
python3 -c "from pwn import *; print('pwntools OK')"
```

3. **Verify `Docker` (without `sudo`):**
```bash
docker run --rm hello-world
```

4. **Verify `gdb` and `pwndbg`:**
Run `gdb -q` in the terminal and confirm that it loads with the `pwndbg>` prompt.

5. **Verify `Ghidra`:**
Run `ghidra` from the terminal, verify the GUI launches with Java 21, and create a new test project.

### Verification evidence
Actual terminal output captured on the Kali Linux 2026.2 VM (`2026-10-19`):

```text
┌──(kali㉿kali)-[~]
└─$ gcc --version | head -n 1
gcc (Debian 16.1.0-1) 16.1.0

┌──(kali㉿kali)-[~]
└─$ echo 'int main(){return 0;}' > t.c && gcc t.c -o t && ./t && echo BUILD_OK && rm -f t.c t
BUILD_OK

┌──(kali㉿kali)-[~]
└─$ source ~/vr-venv/bin/activate && python3 -c "from pwn import *; print('pwntools OK')"
pwntools OK

┌──(kali㉿kali)-[~]
└─$ docker run --rm hello-world | grep -E "Hello from Docker|working correctly"
Hello from Docker!
This message shows that your installation appears to be working correctly.

┌──(kali㉿kali)-[~]
└─$ gdb -q -ex "quit"
pwndbg: loaded 164 pwndbg commands. Type pwndbg [filter] for a list.
pwndbg: created $rebase, $base, $bn_sym, $bn_var, $bn_eval GDB functions (can be used with print/break)
```

---

## 5. Installed Tool Versions
```text
build-essential-12.12
cmake-4.3.4
docker-compose-2.40.3
docker.io-28.5.2+dfsg4
gcc-16.1.0
gdb-17.2
ghidra-12.1.4+ds
git-2.53.0
libffi-dev-3.8.0
libglib2.0-dev-2.90.0
libssl-dev-3.6.4
pkg-config-2.5.1
python3-3.14.7
python3-dev-3.14.7
python3-pip-26.1.2+dfsg
python3-venv-3.14.7
pwntools-4.15.0
```

To generate this version list on your machine, run (with `vr-venv` activated):
```bash
{
  dpkg-query -W -f='${Package}-${Version}\n' \
    build-essential gcc gdb git python3 python3-pip python3-dev python3-venv \
    docker.io docker-compose cmake pkg-config libglib2.0-dev \
    libffi-dev libssl-dev ghidra 2>/dev/null \
    | sed -E 's/-[0-9]+:/-/; s/[+~-][^.-]*$//'
  python3 -m pip show pwntools 2>/dev/null | awk '/^Name:/{n=$2} /^Version:/{print n"-"$2}'
}
```

---

## 6. VM Snapshot Policy
After verifying all tools, I created the clean QEMU/KVM snapshot `vr-lab-clean-2026-10-19` on `2026-10-19`. It captures the VM in a clean shutoff state containing the verified toolchain (`gcc`, `gdb` + `pwndbg`, `pwntools`, `docker`, `ghidra`) with no target binaries or active containers.

### Snapshot Specification & Evidence
- **VM Domain Name:** `kali linux`
- **Snapshot Name:** `vr-lab-clean-2026-10-19`
- **Creation Timestamp:** `2026-10-19`
- **VM State:** `shutoff` (clean baseline, zero research artifacts)

**Snapshot creation & verification on the host (`virsh`):**
```text
$ virsh --connect qemu:///system snapshot-create-as \
  --domain 'kali linux' \
  --name vr-lab-clean-2026-10-19 \
  --description "Clean baseline with verified VR toolchain and no research targets"
Domain snapshot vr-lab-clean-2026-10-19 created
$ virsh --connect qemu:///system snapshot-list --domain 'kali linux'
 Name                      Creation Time               State
----------------------------------------------------------------
 vr-lab-clean-2026-10-19   2026-10-19 12:58:32 +0300   shutoff

```

### How to Restore the Clean Snapshot
- **Via CLI (`virsh` on Host):**
  ```bash
  virsh --connect qemu:///system snapshot-revert --domain 'kali linux' --snapshotname vr-lab-clean-2026-10-19
  ```
- **Via GUI (`virt-manager`):** Open the VM window -> click **Manage VM snapshots** -> select `vr-lab-clean-2026-10-19` -> click **Run selected snapshot**.

### When and Why to Revert to the Clean Snapshot
- **After analyzing untrusted binaries, exploits, or malware:** Ensures any system compromise, persistence mechanism, rootkit, or accidental filesystem corruption is completely wiped.
- **Before starting a new research target or CVE environment:** Guarantees a deterministic, clean baseline with no leftover background processes, environment variables, Docker containers, or modified library configurations that could skew experiment reproducibility.
- **After a broken system update:** Allows immediate recovery if a rolling-release `apt upgrade` create dependencies conflicts that break Tools.

---

## 7. Training Platform Accounts
- **picoCTF:** `avidan1`
- **pwn.college:** `avidan1`
- **PortSwigger:** `avidan`
