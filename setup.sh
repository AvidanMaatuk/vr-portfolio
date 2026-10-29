#!/usr/bin/env bash
set -e

sudo apt update && sudo apt upgrade -y

sudo apt install -y build-essential gdb git python3 python3-pip python3-dev \
  python3-venv docker.io docker-compose cmake pkg-config \
  libglib2.0-dev libffi-dev libssl-dev ghidra

if [ ! -d pwndbg ]; then
  git clone https://github.com/pwndbg/pwndbg
  ( cd pwndbg && ./setup.sh )
fi

python3 -m venv ~/vr-venv
source ~/vr-venv/bin/activate
pip install pwntools

sudo usermod -aG docker "$USER"
sudo systemctl enable --now docker

gcc --version
echo 'int main(){return 0;}' > t.c && gcc t.c -o t && ./t && echo BUILD_OK
rm -f t.c t

python3 -c "from pwn import *; print('pwntools OK')"

sg docker -c "docker run --rm hello-world"

gdb -q -ex quit

{
  dpkg-query -W -f='${Package}-${Version}\n' \
    build-essential gcc gdb git python3 python3-pip python3-dev python3-venv \
    docker.io docker-compose cmake pkg-config libglib2.0-dev \
    libffi-dev libssl-dev ghidra 2>/dev/null \
    | sed -E 's/-[0-9]+:/-/; s/[+~-][^.-]*$//'
  python3 -m pip show pwntools 2>/dev/null | awk '/^Name:/{n=$2} /^Version:/{print n"-"$2}'
}

echo "setup done. log out and back in, then run: source ~/vr-venv/bin/activate"
