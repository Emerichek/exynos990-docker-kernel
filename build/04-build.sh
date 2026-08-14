#!/bin/bash
# ============================================================
#  04-build.sh - compila o kernel com suporte a Docker
#
#  A INVOCACAO E O PONTO CRITICO:
#      LLVM=1        toda a suite LLVM (clang, lld, llvm-ar, llvm-objcopy...)
#      LLVM_IAS=1    assembler integrado do clang, no lugar do GNU as
#
#  Kernels compilados com o "as" do binutils - o que a documentacao do
#  LineageOS sugere, com apenas CC=clang LD=ld.lld - CARREGAM MAS NAO
#  EXECUTAM neste bootloader. O log mostra "Starting kernel..." e nada
#  depois: sem panico, sem registro em pstore. Foram quatro builds
#  descartadas ate isolar isso. Ver research/ para o historico.
#
#  Uso:
#      bash 04-build.sh
#      KERNEL_BASE=/mnt/d/kernel bash 04-build.sh
#      FRAGMENTO=docker-minimal.config bash 04-build.sh
#      DEVICE=z3s bash 04-build.sh
# ============================================================
set -e

# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

KERNEL_BASE="${KERNEL_BASE:-$HOME/kernel}"
SRC="$KERNEL_BASE/src"
OUT="${OUT:-out-docker}"
DEVICE="${DEVICE:-y2s}"
FRAGMENTO="${FRAGMENTO:-docker-kernel.config}"
DEFCONFIG="${DEFCONFIG:-exynos9830_defconfig}"

[ -d "$SRC" ] || { echo "!! $SRC nao existe - rode 02-fontes.sh antes"; exit 1; }

export ARCH=arm64
export PATH="$KERNEL_BASE/clang/bin:$KERNEL_BASE/gcc/bin:$PATH"
export KBUILD_BUILD_USER="${KBUILD_BUILD_USER:-builder}"
export KBUILD_BUILD_HOST="${KBUILD_BUILD_HOST:-$(hostname)}"

ARGS="LLVM=1 LLVM_IAS=1 ARCH=arm64 READELF=$KERNEL_BASE/clang/bin/llvm-readelf"

# instala o fragmento escolhido na arvore
tr -d '\r' < "$PROJECT_DIR/config/$FRAGMENTO" > "$SRC/arch/arm64/configs/docker.config"

cd "$SRC"
echo "=== configurando ==="
echo "  defconfig : $DEFCONFIG"
echo "  aparelho  : $DEVICE.config"
echo "  fragmento : $FRAGMENTO"
echo
make O=$OUT $ARGS "$DEFCONFIG" >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    "arch/arm64/configs/$DEVICE.config" \
    arch/arm64/configs/docker.config >/dev/null
make O=$OUT $ARGS olddefconfig >/dev/null

# ------------------------------------------------------------------
# PORTAO 1: o LTO sobreviveu?
# O Kconfig desfaz em silencio o que nao consegue atender.
# ------------------------------------------------------------------
if grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config; then
    echo "  [ok] LTO_CLANG ativo"
else
    echo "!! LTO_CLANG desligado. Nao adianta compilar - a imagem sai"
    echo "   ~3,4 MB maior e nao boota. Confira se o ld.lld esta em uso."
    exit 1
fi

# ------------------------------------------------------------------
# PORTAO 2: as opcoes do Docker entraram?
# ------------------------------------------------------------------
echo
echo "=== opcoes do Docker no .config final ==="
FALTOU=0
for c in CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE CONFIG_BRIDGE \
         CONFIG_BRIDGE_NETFILTER CONFIG_LLC CONFIG_STP \
         CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_OVERLAY_FS CONFIG_VETH; do
    v=$(grep -E "^${c}=" $OUT/.config | cut -d= -f2)
    if [ -n "$v" ]; then printf '  [%s] %s\n' "$v" "$c"
    else printf '  [NAO] %s\n' "$c"; FALTOU=$((FALTOU+1)); fi
done
[ "$FALTOU" = "0" ] || { echo "!! $FALTOU faltando - abortando"; exit 1; }

# ------------------------------------------------------------------
echo
echo "=== compilando com -j$(nproc) ==="
date
make O=$OUT $ARGS -j"$(nproc)" > "$KERNEL_BASE/build.log" 2>&1 || {
    echo "!! falhou. ultimos erros:"
    grep -E "error:" "$KERNEL_BASE/build.log" | tail -15
    exit 1; }
date

IMG="$SRC/$OUT/arch/arm64/boot/Image"
[ -f "$IMG" ] || { echo "!! Image nao foi gerada"; exit 1; }

# ------------------------------------------------------------------
# PORTAO 3: o tamanho bate com o kernel de fabrica?
# Sem LTO a imagem cresce ~3,4 MB; com LTO, so alguns KB.
# ------------------------------------------------------------------
NOVO=$(stat -c %s "$IMG")
echo
echo "============================================================"
printf "  Image gerada : %'d bytes\n" "$NOVO"
echo
if [ "$NOVO" -gt 44000000 ]; then
    echo "  !! GRANDE DEMAIS. Um kernel com LTO fica proximo do de"
    echo "     fabrica (~42,5 MB). Acima de ~44 MB indica LTO ausente."
    echo "     NAO GRAVE."
    exit 1
fi
echo "  [ok] tamanho compativel com LTO ativo"

mkdir -p "$PROJECT_DIR/out"
cp "$IMG" "$PROJECT_DIR/out/Image"
echo
echo "  copiada para: $PROJECT_DIR/out/Image"
echo "  md5: $(md5sum "$IMG" | cut -d' ' -f1)"
echo
echo "  Proximo passo: flash/ - veja o README"
echo "============================================================"
