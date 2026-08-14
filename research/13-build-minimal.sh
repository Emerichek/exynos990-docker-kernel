#!/bin/bash
# 13 - build com docker-minimal.config: so o essencial, sem os
# tres grupos opcionais (cgroup pids, cgroup de rede, io throttling)
# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; OUT=out-min
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
export KBUILD_BUILD_USER=builder
export KBUILD_BUILD_HOST=wsl
LLVM_TOOLS="CC=clang LD=ld.lld AR=llvm-ar NM=llvm-nm OBJCOPY=llvm-objcopy OBJDUMP=llvm-objdump STRIP=llvm-strip"

WINCFG=$PROJECT_DIR/docker-minimal.config
tr -d '\r' < "$WINCFG" > "$SRC/arch/arm64/configs/docker-min.config"

cd "$SRC"
echo "=== configurando (minimal) ==="
make O=$OUT $LLVM_TOOLS exynos9830_defconfig >/dev/null
./scripts/kconfig/merge_config.sh -m -O $OUT $OUT/.config \
    arch/arm64/configs/y2s.config \
    arch/arm64/configs/docker-min.config >/dev/null
make O=$OUT $LLVM_TOOLS olddefconfig >/dev/null

grep -q "^CONFIG_LTO_CLANG=y" $OUT/.config || { echo "!! LTO nao entrou"; exit 1; }
echo "  LTO_CLANG ativo"

echo
echo "=== o que DEVE estar ligado ==="
F=0
for c in CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE CONFIG_BRIDGE \
         CONFIG_BRIDGE_NETFILTER CONFIG_LLC CONFIG_STP \
         CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_OVERLAY_FS CONFIG_VETH; do
    v=$(grep -E "^${c}=" $OUT/.config | cut -d= -f2)
    if [ -n "$v" ]; then printf '  [%s] %s\n' "$v" "$c"; else printf '  [NAO] %s\n' "$c"; F=$((F+1)); fi
done
[ "$F" = "0" ] || { echo "!! $F faltando"; exit 1; }

echo
echo "=== o que DEVE ficar de fora (os suspeitos) ==="
for c in CONFIG_CGROUP_PIDS CONFIG_NET_CLS_CGROUP CONFIG_CGROUP_NET_PRIO \
         CONFIG_CGROUP_NET_CLASSID CONFIG_BLK_DEV_THROTTLING; do
    if grep -qE "^${c}=y" $OUT/.config; then
        printf '  [!] %s ligada - NAO deveria\n' "$c"
    else
        printf '  [ok] %s fora\n' "$c"
    fi
done

echo
echo "=== compilando ==="
date
make O=$OUT $LLVM_TOOLS -j"$(nproc)" > "$BASE/build-min.log" 2>&1 || {
    echo "!! falhou"; tail -30 "$BASE/build-min.log"; exit 1; }
date

ORIG=42514448
NOVO=$(stat -c %s "$SRC/$OUT/arch/arm64/boot/Image")
echo
echo "============================================================"
printf "  original       : %'d\n" "$ORIG"
printf "  controle c/LTO : %'d  (+0, identico)\n" "$ORIG"
printf "  minimal        : %'d  (%+d)\n" "$NOVO" "$((NOVO-ORIG))"
cp "$SRC/$OUT/arch/arm64/boot/Image" $PROJECT_DIR/Image-min
echo "  copiada como: Image-min"
md5sum "$SRC/$OUT/arch/arm64/boot/Image"
echo "============================================================"
