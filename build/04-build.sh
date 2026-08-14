#!/bin/bash
# 17 - receita do ExtremeXT aplicada a arvore do LineageOS:
#      LLVM=1 (suite LLVM inteira) + LLVM_IAS=1 (assembler integrado
#      do clang no lugar do GNU as). Caminho de geracao de codigo
#      que ainda nao tentamos.
#
# Ja vai COM as opcoes do Docker: config nao e mais a variavel em
# questao (o controle de config identica tambem nao bootou).
# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; OUT=out-ias
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl

ARGS="LLVM=1 LLVM_IAS=1 ARCH=arm64 READELF=$BASE/clang/bin/llvm-readelf"

cd "$SRC"
echo "=== configurando (LLVM=1 LLVM_IAS=1) ==="
make O=$OUT $ARGS exynos9830_defconfig >/dev/null 2>&1 || {
    echo "!! defconfig falhou com IAS"; exit 1; }
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    arch/arm64/configs/y2s.config \
    arch/arm64/configs/docker.config >/dev/null
make O=$OUT $ARGS olddefconfig >/dev/null

grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config && echo "  LTO_CLANG ativo" || echo "  ! LTO desligado"
F=0
for c in CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE CONFIG_BRIDGE \
         CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_OVERLAY_FS CONFIG_VETH; do
    grep -qE "^${c}=y" $OUT/.config || { echo "  [NAO] $c"; F=$((F+1)); }
done
[ "$F" = "0" ] && echo "  opcoes do Docker presentes" || { echo "!! $F faltando"; exit 1; }

echo
echo "=== compilando com assembler integrado do clang ==="
date
if ! make O=$OUT $ARGS -j"$(nproc)" > "$BASE/build-ias.log" 2>&1; then
    echo
    echo "!! A BUILD FALHOU. Erros mais frequentes:"
    grep -E "error:" "$BASE/build-ias.log" | sed 's/.*error: //' | sort | uniq -c | sort -rn | head -12
    echo
    echo "  total de erros: $(grep -c 'error:' "$BASE/build-ias.log")"
    echo "  (clang 12 assemblando codigo 4.19 da Samsung costuma engasgar"
    echo "   em asm inline - se for isso, esta receita nao serve aqui)"
    exit 1
fi
date

ORIG=42514448
NOVO=$(stat -c %s "$SRC/$OUT/arch/arm64/boot/Image")
echo
echo "============================================================"
printf "  original      : %'d\n" "$ORIG"
printf "  com LLVM_IAS  : %'d  (%+d)\n" "$NOVO" "$((NOVO-ORIG))"
cp "$SRC/$OUT/arch/arm64/boot/Image" $PROJECT_DIR/Image-ias
echo "  copiada como: Image-ias"
md5sum "$SRC/$OUT/arch/arm64/boot/Image"
echo "============================================================"
