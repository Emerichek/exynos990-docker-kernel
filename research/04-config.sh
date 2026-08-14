#!/bin/bash
# 04 - monta a configuracao: base + aparelho + docker, e CONFERE
set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-

cd "$SRC"

echo "=== 1/3  defconfig base (exynos9830_defconfig) ==="
make O=out CC=clang exynos9830_defconfig >/dev/null

echo "=== 2/3  mesclando y2s.config + docker.config ==="
./scripts/kconfig/merge_config.sh -m -O out out/.config \
    arch/arm64/configs/y2s.config \
    arch/arm64/configs/docker.config >/dev/null

echo "=== 3/3  resolvendo dependencias (olddefconfig) ==="
make O=out CC=clang olddefconfig >/dev/null

# ------------------------------------------------------------------
# Conferencia: o olddefconfig pode DESFAZER uma opcao se alguma
# dependencia dela nao estiver satisfeita - e faz isso em silencio.
# Por isso conferimos uma a uma no .config final.
# ------------------------------------------------------------------
echo
echo "=== resultado ==="
FALTOU=0
for c in CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUP_DEVICE \
         CONFIG_BRIDGE CONFIG_BRIDGE_NETFILTER CONFIG_LLC CONFIG_STP \
         CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_NETFILTER_XT_MARK \
         CONFIG_IP_NF_TARGET_REDIRECT CONFIG_DUMMY \
         CONFIG_CGROUP_PIDS CONFIG_CGROUP_BPF CONFIG_BLK_DEV_THROTTLING \
         CONFIG_OVERLAY_FS CONFIG_VETH CONFIG_SECCOMP CONFIG_MEMCG; do
    v=$(grep -E "^${c}=" out/.config | cut -d= -f2)
    if [ -n "$v" ]; then
        printf '  [%s]  %s\n' "$v" "$c"
    else
        printf '  [ NAO ] %s   <-- nao entrou\n' "$c"
        FALTOU=$((FALTOU+1))
    fi
done

echo
if [ "$FALTOU" = "0" ]; then
    echo ">> todas as opcoes entraram. pode compilar."
else
    echo "!! $FALTOU opcao(oes) nao entraram."
    echo "   investigue com: cd $SRC && make O=out menuconfig"
    exit 1
fi
