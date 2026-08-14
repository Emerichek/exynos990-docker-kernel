#!/bin/bash
# 01 - dependencias de build no Ubuntu do WSL2
set -e

# se ja for root usa "env" no lugar de sudo, assim o $SUDO nunca expande
# para vazio (o que quebraria a linha de comando). Roda via: wsl -u root
if [ "$(id -u)" = "0" ]; then SUDO="env"; else SUDO="sudo -E"; fi

echo "=== instalando dependencias ==="
export DEBIAN_FRONTEND=noninteractive
$SUDO apt-get update -qq
$SUDO apt-get install -y -qq \
    git build-essential bc bison flex libssl-dev libncurses-dev \
    zip unzip python3 ccache device-tree-compiler lz4 cpio rsync

echo
echo "=== versoes ==="
echo "git      : $(git --version)"
echo "gcc      : $(gcc -dumpversion)"
echo "make     : $(make --version | head -1)"
echo "bison    : $(bison --version | head -1)"
echo "flex     : $(flex --version)"
echo "dtc      : $(dtc --version 2>&1 | head -1)"
echo "nproc    : $(nproc)"
echo
echo "=== espaco ==="
df -h "$HOME" | tail -1
echo
echo ">> ok"
