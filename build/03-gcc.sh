#!/bin/bash
# 03 - binutils cruzado (as/ld/objcopy).
# O clang nao traz binutils, e o build.config do kernel usa
# CROSS_COMPILE=aarch64-linux-android-, que vem deste prebuilt do AOSP.
set -e

BASE="$HOME/kernel"
GCC="$BASE/gcc"

if [ -x "$GCC/bin/aarch64-linux-android-ld" ]; then
    echo ">> gcc prebuilt ja presente em $GCC"
else
    echo "=== clonando aarch64-linux-android-4.9 (binutils do AOSP) ==="
    git clone --depth=1 \
        https://github.com/LineageOS/android_prebuilts_gcc_linux-x86_aarch64_aarch64-linux-android-4.9 \
        "$GCC"
fi

echo
echo "=== conferencia ==="
"$GCC/bin/aarch64-linux-android-ld" --version | head -1
"$GCC/bin/aarch64-linux-android-as" --version | head -1
du -sh "$GCC"
echo
echo ">> ok"
