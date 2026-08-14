#!/bin/bash
# 08 - build COM paridade: LTO/ThinLTO habilitado via ld.lld e
# ferramentas LLVM, que e como o LineageOS compila este kernel.
#
# A build anterior usava GNU ld, o que fazia o Kconfig desabilitar
# LTO_CLANG em silencio (depends on CC_IS_CLANG && LD_IS_LLD).
set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
OUT=out-lto
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl

# ferramentas LLVM: e isto que faz LD_IS_LLD ficar verdadeiro
LLVM_TOOLS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"

cd "$SRC"

echo "=== configurando com docker.config ==="
make O=$OUT $LLVM_TOOLS exynos9830_defconfig >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    arch/arm64/configs/y2s.config \
    arch/arm64/configs/docker.config >/dev/null
make O=$OUT $LLVM_TOOLS olddefconfig >/dev/null

# ------------------------------------------------------------------
# PORTAO 1: o LTO entrou mesmo desta vez?
# ------------------------------------------------------------------
echo
echo "=== LTO ==="
grep -E "^CONFIG_LTO|^# CONFIG_LTO|^CONFIG_THINLTO" $OUT/.config
if ! grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config; then
    echo
    echo "!! LTO_CLANG continua desligado. NAO adianta compilar."
    echo "   verifique se o ld.lld esta sendo usado de fato."
    exit 1
fi
echo "  >> LTO_CLANG ativo"

# ------------------------------------------------------------------
# PORTAO 2: as opcoes do Docker sobreviveram?
# ------------------------------------------------------------------
echo
echo "=== opcoes do Docker ==="
FALTOU=0
for c in CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE CONFIG_BRIDGE \
         CONFIG_BRIDGE_NETFILTER CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
         CONFIG_CGROUP_PIDS CONFIG_OVERLAY_FS CONFIG_VETH; do
    v=$(grep -E "^${c}=" $OUT/.config | cut -d= -f2)
    if [ -n "$v" ]; then printf '  [%s] %s\n' "$v" "$c"
    else printf '  [NAO] %s\n' "$c"; FALTOU=$((FALTOU+1)); fi
done
[ "$FALTOU" = "0" ] || { echo "!! $FALTOU faltando"; exit 1; }

echo
echo "=== compilando (LTO deixa o link bem mais lento) ==="
date
make O=$OUT $LLVM_TOOLS -j"$(nproc)" > "$BASE/build-lto.log" 2>&1 || {
    echo "!! falhou. ultimas linhas:"; tail -40 "$BASE/build-lto.log"; exit 1; }
date

# ------------------------------------------------------------------
# PORTAO 3: o tamanho bate com o do kernel original?
# ------------------------------------------------------------------
ORIG=42514448
NOVO=$(stat -c %s "$SRC/$OUT/arch/arm64/boot/Image")
echo
echo "============================================================"
printf "  kernel original do LineageOS : %'d bytes\n" "$ORIG"
printf "  nossa build COM LTO          : %'d bytes  (%+d)\n" "$NOVO" "$((NOVO-ORIG))"
DIF=$((NOVO-ORIG)); [ "$DIF" -lt 0 ] && DIF=$((-DIF))
echo
if [ "$DIF" -lt 2097152 ]; then
    echo "  >> DENTRO DO ESPERADO (diferenca < 2 MB)."
    echo "     As opcoes que ligamos justificam um crescimento pequeno."
    echo "     Vale flashar e testar."
else
    echo "  !! Ainda difere $DIF bytes. Investigar antes de flashar."
fi
echo "============================================================"
