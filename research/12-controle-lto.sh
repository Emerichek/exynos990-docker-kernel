#!/bin/bash
# 12 - CONTROLE DE VERDADE: com LTO (como o LineageOS) e ZERO
# opcoes nossas. Se este nao bootar, o problema nao sao as opcoes.
# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; OUT=out-ctrl2
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl
LLVM_TOOLS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"

cd "$SRC"
echo "=== configurando SEM docker.config, COM LTO ==="
make O=$OUT $LLVM_TOOLS exynos9830_defconfig >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    arch/arm64/configs/y2s.config >/dev/null
make O=$OUT $LLVM_TOOLS olddefconfig >/dev/null

grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config || { echo "!! LTO nao entrou"; exit 1; }
echo "  LTO_CLANG ativo"
for c in CONFIG_IPC_NS CONFIG_BRIDGE CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE; do
    grep -qE "^${c}=y" $OUT/.config && { echo "!! $c ligada - nao deveria"; exit 1; }
done
echo "  nenhuma opcao do docker presente (correto)"

echo
echo "=== compilando ==="
date
make O=$OUT $LLVM_TOOLS -j"$(nproc)" > "$BASE/build-ctrl2.log" 2>&1 || {
    echo "!! falhou"; tail -30 "$BASE/build-ctrl2.log"; exit 1; }
date

ORIG=42514448
NOVO=$(stat -c %s "$SRC/$OUT/arch/arm64/boot/Image")
echo
echo "============================================================"
printf "  kernel original : %'d bytes\n" "$ORIG"
printf "  controle c/ LTO : %'d bytes  (%+d)\n" "$NOVO" "$((NOVO-ORIG))"
D=$((NOVO-ORIG)); [ "$D" -lt 0 ] && D=$((-D))
if [ "$D" -lt 65536 ]; then
    echo "  >> praticamente identico ao original (< 64 KB)."
    echo "     Se ESTE nao bootar, o problema e o processo de build."
else
    echo "  >> ainda difere $D bytes - ha divergencia alem do LTO."
fi
cp "$SRC/$OUT/arch/arm64/boot/Image" $PROJECT_DIR/Image-ctrl
echo "  copiada para o Windows como: Image-ctrl"
md5sum "$SRC/$OUT/arch/arm64/boot/Image"
echo "============================================================"
