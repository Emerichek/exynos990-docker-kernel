#!/bin/bash
# 07 - BUILD DE CONTROLE: exatamente o que o LineageOS compila,
# sem nenhuma opcao nossa. Serve para descobrir se o problema esta
# no nosso processo de build ou nas opcoes que adicionamos.
#
# Nao flasha nada. Só compara tamanhos.
set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
OUT=out-ctrl
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl

cd "$SRC"

echo "=== o defconfig pede LTO? ==="
grep -nE "LTO|CFI_CLANG" arch/arm64/configs/exynos9830_defconfig || echo "  nenhuma mencao a LTO no defconfig"
echo
echo "=== o que o build.config define ==="
grep -E "LTO|CLANG_VERSION|DEFCONFIG" build.config.universal9830 || true

echo
echo "=== configurando (SEM docker.config) ==="
make O=$OUT CC=clang exynos9830_defconfig >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    arch/arm64/configs/y2s.config >/dev/null
make O=$OUT CC=clang olddefconfig >/dev/null

echo "  confirmando que as opcoes do docker NAO estao aqui:"
for c in CONFIG_IPC_NS CONFIG_BRIDGE CONFIG_POSIX_MQUEUE; do
    v=$(grep -E "^${c}=" $OUT/.config | cut -d= -f2)
    echo "    $c = ${v:-(desligada, como esperado)}"
done
echo "  estado do LTO nesta config:"
grep -E "^CONFIG_LTO|^# CONFIG_LTO" $OUT/.config || echo "    (sem simbolos LTO)"

echo
echo "=== compilando o controle ==="
date
make O=$OUT CC=clang -j"$(nproc)" > "$BASE/build-ctrl.log" 2>&1 || {
    echo "!! falhou. ultimas linhas:"; tail -30 "$BASE/build-ctrl.log"; exit 1; }
date

echo
echo "============================================================"
echo " COMPARACAO DE TAMANHOS"
echo "============================================================"
ORIG=42514448
CTRL=$(stat -c %s "$SRC/$OUT/arch/arm64/boot/Image")
DOCK=$(stat -c %s "$SRC/out/arch/arm64/boot/Image" 2>/dev/null || echo 0)
printf "  kernel original do LineageOS : %'d bytes\n" "$ORIG"
printf "  nossa build DE CONTROLE      : %'d bytes  (%+d)\n" "$CTRL" "$((CTRL-ORIG))"
[ "$DOCK" != "0" ] && printf "  nossa build COM docker       : %'d bytes  (%+d)\n" "$DOCK" "$((DOCK-ORIG))"
echo
DIF=$((CTRL-ORIG)); [ "$DIF" -lt 0 ] && DIF=$((-DIF))
if [ "$DIF" -lt 262144 ]; then
    echo " >> O CONTROLE BATE COM O ORIGINAL (diferenca < 256 KB)."
    echo "    Nosso processo de build esta correto."
    echo "    Logo, o que quebrou o boot foi UMA DAS OPCOES que adicionamos."
    echo "    Proximo passo: bissecao das 18 opcoes."
else
    echo " >> O CONTROLE JA DIFERE DO ORIGINAL em $DIF bytes."
    echo "    O problema NAO sao as opcoes: e o nosso processo de build."
    echo "    Nao adianta bisseccionar config - precisamos de paridade de build."
fi
echo "============================================================"
