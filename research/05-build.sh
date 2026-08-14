#!/bin/bash
# 05 - compila. Meia hora a duas horas.
set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl

cd "$SRC"

J=$(nproc)
echo "=== compilando com -j$J ==="
date

make O=out CC=clang -j"$J" 2>&1 | tee "$BASE/build.log" | \
    grep -E "^(  CC|  LD|  AS)?.*(error|Error|ERROR|warning: .*\[-W(error|address)|\*\*\*)" || true

echo
echo "=== resultado ==="
date
IMG="$SRC/out/arch/arm64/boot/Image"
if [ -f "$IMG" ]; then
    ls -lh "$IMG"
    echo "  tipo: $(file -b "$IMG" 2>/dev/null || echo 'n/d')"
    echo
    echo ">> SUCESSO. imagem em:"
    echo "   $IMG"
    echo
    echo "   log completo: $BASE/build.log"
else
    echo "!! Image nao foi gerada. ultimas linhas do log:"
    tail -40 "$BASE/build.log"
    exit 1
fi
