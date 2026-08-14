#!/bin/bash
# 15 - Reproduzir o kernel ORIGINAL bit a bit.
#
# Invocacao identica a do LineageOS (vendor/lineage/build/tasks/kernel.mk):
#   so CC=clang e LD=ld.lld sao sobrescritos; AR/NM/OBJCOPY/STRIP vem
#   do CROSS_COMPILE, ou seja, sao os binutils GNU.
#
# Se conseguirmos md5 identico, a paridade esta provada e podemos
# confiar em qualquer build seguinte.
set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; CMP="$BASE/cmp"; OUT=out-par
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"

echo "=== string de versao do kernel ORIGINAL ==="
VER=$(strings "$CMP/kernel-original" | grep -m1 "^Linux version")
echo "$VER"
echo

# extrai user@host e timestamp da string original
UH=$(echo "$VER" | sed -n 's/.*(\([^)]*\)) (.*/\1/p')
TS=$(echo "$VER" | sed -n 's/.*#1 SMP PREEMPT //p')
echo "  build user@host : $UH"
echo "  timestamp       : $TS"
echo

export KBUILD_BUILD_USER="${UH%@*}"
export KBUILD_BUILD_HOST="${UH#*@}"
export KBUILD_BUILD_TIMESTAMP="$TS"

cd "$SRC"
echo "=== configurando (sem opcoes nossas) ==="
make O=$OUT CC=clang LD=ld.lld CROSS_COMPILE=aarch64-linux-android- \
     CLANG_TRIPLE=aarch64-linux-gnu- exynos9830_defconfig >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
     arch/arm64/configs/y2s.config >/dev/null
make O=$OUT CC=clang LD=ld.lld CROSS_COMPILE=aarch64-linux-android- \
     CLANG_TRIPLE=aarch64-linux-gnu- olddefconfig >/dev/null
grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config || { echo "!! LTO nao entrou"; exit 1; }
echo "  LTO ativo"

echo
echo "=== compilando com a invocacao EXATA do LineageOS ==="
date
make O=$OUT CC=clang LD=ld.lld CROSS_COMPILE=aarch64-linux-android- \
     CLANG_TRIPLE=aarch64-linux-gnu- -j"$(nproc)" > "$BASE/build-par.log" 2>&1 || {
    echo "!! falhou"; tail -30 "$BASE/build-par.log"; exit 1; }
date

IMG="$SRC/$OUT/arch/arm64/boot/Image"
echo
echo "============================================================"
echo "  original : $(md5sum "$CMP/kernel-original" | cut -d' ' -f1)  $(stat -c %s "$CMP/kernel-original")"
echo "  nossa    : $(md5sum "$IMG" | cut -d' ' -f1)  $(stat -c %s "$IMG")"
echo
if cmp -s "$CMP/kernel-original" "$IMG"; then
    echo "  >>> IDENTICOS BIT A BIT. Paridade total provada."
else
    N=$(cmp -l "$CMP/kernel-original" "$IMG" 2>/dev/null | wc -l)
    echo "  >>> diferem em $N bytes"
    echo "  primeiras diferencas (offset decimal, byte original, byte nosso):"
    cmp -l "$CMP/kernel-original" "$IMG" 2>/dev/null | head -8
fi
echo
echo "  versao da nossa:"
strings "$IMG" | grep -m1 "^Linux version"
echo "============================================================"
