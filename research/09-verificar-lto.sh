#!/bin/bash
# 09 - confere os requisitos do Docker DENTRO da Image com LTO
# raiz do repositorio: derivada da localizacao deste script,
# ou defina PROJECT_DIR no ambiente para apontar para outro lugar
PROJECT_DIR="${PROJECT_DIR:-$(cd "$(dirname "$0")/.." && pwd)}"

set -e
BASE="$HOME/kernel"; SRC="$BASE/src"
IMG="$SRC/out-lto/arch/arm64/boot/Image"
[ -f "$IMG" ] || { echo "!! Image nao encontrada"; exit 1; }

"$SRC/scripts/extract-ikconfig" "$IMG" > "$BASE/config-lto.txt"
echo "config extraida da imagem: $(wc -l < "$BASE/config-lto.txt") linhas"

echo
echo "=== LTO dentro da imagem ==="
grep -E "^CONFIG_LTO_CLANG|^CONFIG_THINLTO|^CONFIG_LTO=" "$BASE/config-lto.txt"

echo
echo "=== requisitos do Docker ==="
FALTOU=0
for c in CONFIG_NAMESPACES CONFIG_NET_NS CONFIG_PID_NS CONFIG_UTS_NS CONFIG_IPC_NS \
         CONFIG_POSIX_MQUEUE CONFIG_CGROUPS CONFIG_CGROUP_SCHED CONFIG_CGROUP_DEVICE \
         CONFIG_CGROUP_FREEZER CONFIG_CPUSETS CONFIG_MEMCG CONFIG_KEYS CONFIG_SECCOMP \
         CONFIG_CGROUP_PIDS CONFIG_CGROUP_BPF CONFIG_VETH CONFIG_BRIDGE \
         CONFIG_BRIDGE_NETFILTER CONFIG_LLC CONFIG_STP CONFIG_NF_NAT CONFIG_IP_NF_NAT \
         CONFIG_IP_NF_FILTER CONFIG_IP_NF_TARGET_MASQUERADE \
         CONFIG_NETFILTER_XT_MATCH_ADDRTYPE CONFIG_NETFILTER_XT_MATCH_CONNTRACK \
         CONFIG_NF_CONNTRACK CONFIG_OVERLAY_FS CONFIG_EXT4_FS_POSIX_ACL CONFIG_BLK_CGROUP; do
    v=$(grep -E "^${c}=" "$BASE/config-lto.txt" | cut -d= -f2)
    if [ -n "$v" ]; then printf '  [%s] %s\n' "$v" "$c"
    else printf '  [NAO] %s\n' "$c"; FALTOU=$((FALTOU+1)); fi
done

echo
if [ "$FALTOU" = "0" ]; then
    echo ">> 31/31 requisitos atendidos, com LTO. pronto para teste no aparelho."
    cp "$IMG" $PROJECT_DIR/Image-lto
    echo "   copiada para o Windows como: Image-lto"
    md5sum "$IMG"
else
    echo "!! $FALTOU faltando - nao flashar"
    exit 1
fi
