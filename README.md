# Vulnerability Research Portfolio

A personal research lab and collection of writeups.

## Legal & Ethical Scope
All code in this repository is intended for use within an isolated personal lab environment, for educational purposes only. Do not run any of it against systems you do not own.

## Contents
- `setup.sh` — Installs the full toolchain for the environment. Run inside an isolated VM.
- `.gitignore` — Prevents accidental commits of flags, core dumps, and temporary files.
- `Makefile` — Builds all vulnerable binaries with the appropriate compiler flags.
- `01-foundations/mem.c` — A program demonstrating memory layout and stack frame structure.
- `02-reverse-engineering/crackme.c` — A crackme for reverse-engineering practice (strip after compilation).
- `03-binexp-control-flow/ret2win/` — A vulnerable program and a ret2win exploit.
- `04-binexp-defeating-mitigations/ret2libc/` — A vulnerable program and a ret2libc exploit that bypasses NX and ASLR.

## Building
```bash
make all       # Build all binaries
make clean     # Remove built binaries
```

## Running the Exploits
First, activate the virtual environment with pwntools installed:
```bash
source ~/vr-venv/bin/activate
cd 03-binexp-control-flow/ret2win && python3 exploit.py
```

> **Note:** The `OFFSET` value in the ret2win exploit is a placeholder. Determine the correct value using `cyclic`, as described in the Binary Exploitation stage.
