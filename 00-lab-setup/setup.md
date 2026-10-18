# Lab Setup

## 1. Virtual Machine & OS Installation
1. Create a new isolated VM in your preferred hypervisor (using **QEMU/KVM**).
2. Install **Kali Linux** on the VM (using the official pre-built Kali Linux VM image from the Kali website).
3. Update and upgrade the system:
```bash
sudo apt update && sudo apt upgrade -y
```

## 2. Install Lab Tools & Dependencies
Install the core toolchain, Docker, Ghidra, and the C/C++ build dependencies required to compile Python extensions:
```bash
sudo apt install -y build-essential gdb git python3 python3-pip python3-dev \
  python3-venv docker.io docker-compose cmake pkg-config \
  libglib2.0-dev libffi-dev libssl-dev ghidra
```

## 3. Configure Tooling
### Install pwndbg (GDB plugin)
```bash
git clone https://github.com/pwndbg/pwndbg
cd pwndbg && ./setup.sh && cd ..
```

### Install pwntools in a Virtual Environment
Create an isolated virtual environment and install `pwntools` (passing `CFLAGS` so `unicorn` compiles cleanly on GCC 16 / Python 3.14):
```bash
python3 -m venv ~/vr-venv
source ~/vr-venv/bin/activate
CFLAGS="-Wno-error=implicit-function-declaration -D_GNU_SOURCE" pip install pwntools
```

### Configure Docker Permissions
Allow the current user to run Docker containers without `sudo` (log out and log back in afterward for group changes to take effect):
```bash
sudo usermod -aG docker $USER
```

---

## 4. Self-Check & Verification
1. **Verify `gcc`:**
```bash
gcc --version
echo 'int main(){return 0;}' > t.c && gcc t.c -o t && ./t && echo BUILD_OK
rm -f t.c t
```
*(Expected output: `BUILD_OK`)*

2. **Verify `pwntools`:**
```bash
source ~/vr-venv/bin/activate
python3 -c "from pwn import *; print('pwntools OK')"
```
*(Expected output: `pwntools OK`)*

3. **Verify `Docker` (without `sudo`):**
```bash
docker run --rm hello-world
```

4. **Verify `gdb` and `pwndbg`:**
Run `gdb -q` in the terminal and confirm that it loads with the `pwndbg>` prompt.

5. **Verify `Ghidra`:**
Run `ghidra` from the terminal, verify the GUI launches, and create a new test project.

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
After verifying that all tools work properly, create a clean **VM Snapshot** in your hypervisor (QEMU/KVM).

**When and why to revert to the clean snapshot:**
* **After analyzing untrusted binaries, exploits, or malware:** Ensures any system compromise, persistence, or accidental corruption is completely wiped.
* **Before starting a new research target or CVE environment:** Guarantees a clean baseline with no leftover processes, containers, or modified configurations.
* **After a broken system update:** Allows immediate recovery if a system upgrade causes dependency version conflicts that break core research tools.

---

## 7. Training Platform Accounts
* **picoCTF:** `avidan1`
* **pwn.college:** `avidan1`
* **PortSwigger:** `avidan`
