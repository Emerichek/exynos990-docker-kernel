#!/bin/bash
# 02 - clona kernel + toolchain e aplica o fragmento de config
# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
CLANG="$BASE/clang"
WINCFG="$PROJECT_DIR/docker-kernel.config"

mkdir -p "$BASE"

# ---------- kernel ----------
if [ -d "$SRC/.git" ]; then
    echo ">> kernel ja clonado em $SRC"
else
    echo "=== clonando o kernel (LineageOS universal9830, lineage-23.2) ==="
    git clone --depth=1 -b lineage-23.2 \
        https://github.com/LineageOS/android_kernel_samsung_universal9830 "$SRC"
fi

# ---------- toolchain ----------
if [ -x "$CLANG/bin/clang" ]; then
    echo ">> clang ja presente em $CLANG"
else
    echo "=== clonando o clang-r416183b ==="
    git clone --depth=1 \
        https://github.com/LineageOS/android_prebuilts_clang_kernel_linux-x86_clang-r416183b \
        "$CLANG"
fi

# ---------- fragmento docker ----------
if [ ! -f "$WINCFG" ]; then
    echo "!! nao encontrei $WINCFG"
    exit 1
fi
tr -d '\r' < "$WINCFG" > "$SRC/arch/arm64/configs/docker.config"
echo ">> docker.config instalado em arch/arm64/configs/"

# ---------- conferencia ----------
echo
echo "=== conferencia ==="
echo "versao do kernel : $(grep -E '^(VERSION|PATCHLEVEL|SUBLEVEL)' "$SRC/Makefile" | tr -d ' ' | tr '\n' ' ')"
echo "branch           : $(git -C "$SRC" rev-parse --abbrev-ref HEAD)"
echo "commit           : $(git -C "$SRC" rev-parse --short=12 HEAD)"
echo "clang            : $("$CLANG/bin/clang" --version 2>/dev/null | head -1)"
echo
echo "defconfig base   : $([ -f "$SRC/arch/arm64/configs/exynos9830_defconfig" ] && echo presente || echo AUSENTE)"
echo "y2s.config       : $([ -f "$SRC/arch/arm64/configs/y2s.config" ] && echo presente || echo AUSENTE)"
echo "docker.config    : $([ -f "$SRC/arch/arm64/configs/docker.config" ] && echo presente || echo AUSENTE)"
echo
du -sh "$SRC" "$CLANG" 2>/dev/null
echo
echo ">> ok"
