#!/bin/bash
# 06 - extrai a config de DENTRO da Image compilada e confere.
# Isto e o que o aparelho vai reportar em /proc/config.gz - a prova
# final antes de gravar qualquer coisa.
set -e

BASE="$HOME/kernel"
SRC="$BASE/src"
IMG="$SRC/out/arch/arm64/boot/Image"

[ -f "$IMG" ] || { echo "!! Image nao encontrada"; exit 1; }

echo "=== extraindo a config de dentro da Image ==="
"$SRC/scripts/extract-ikconfig" "$IMG" > "$BASE/config-embutida.txt"
echo "  $(wc -l < "$BASE/config-embutida.txt") linhas extraidas"

echo
echo "=== requisitos do Docker, lidos da imagem compilada ==="
FALTOU=0
for c in CONFIG_NAMESPACES CONFIG_NET_NS CONFIG_PID_NS CONFIG_UTS_NS \
         CONFIG_IPC_NS CONFIG_POSIX_MQUEUE CONFIG_CGROUPS CONFIG_CGROUP_SCHED \
         CONFIG_CGROUP_DEVICE CONFIG_CGROUP_FREEZER CONFIG_CPUSETS CONFIG_MEMCG \
         CONFIG_KEYS CONFIG_SECCOMP CONFIG_CGROUP_PIDS CONFIG_CGROUP_BPF \
         CONFIG_VETH CONFIG_BRIDGE CONFIG_BRIDGE_NETFILTER CONFIG_LLC CONFIG_STP \
         CONFIG_NF_NAT CONFIG_IP_NF_NAT CONFIG_IP_NF_FILTER \
         CONFIG_IP_NF_TARGET_MASQUERADE CONFIG_NETFILTER_XT_MATCH_ADDRTYPE \
         CONFIG_NETFILTER_XT_MATCH_CONNTRACK CONFIG_NF_CONNTRACK \
         CONFIG_OVERLAY_FS CONFIG_EXT4_FS_POSIX_ACL CONFIG_BLK_CGROUP; do
    v=$(grep -E "^${c}=" "$BASE/config-embutida.txt" | cut -d= -f2)
    if [ -n "$v" ]; then
        printf '  [%s]  %s\n' "$v" "$c"
    else
        printf '  [NAO] %s\n' "$c"
        FALTOU=$((FALTOU+1))
    fi
done

echo
echo "=== confirmando o que ficou DE FORA de proposito ==="
for c in CONFIG_USER_NS CONFIG_VXLAN CONFIG_MACVLAN; do
    if grep -qE "^${c}=" "$BASE/config-embutida.txt"; then
        printf '  [!] %s esta LIGADA (era para estar desligada)\n' "$c"
    else
        printf '  [ok] %s desligada, como planejado\n' "$c"
    fi
done

echo
echo "=== comparando com o kernel ATUAL do aparelho ==="
echo "  o atual tem 3 obrigatorios faltando (IPC_NS, POSIX_MQUEUE, CGROUP_DEVICE)"
echo "  e 3 de rede (BRIDGE, BRIDGE_NETFILTER, ADDRTYPE)"
echo
if [ "$FALTOU" = "0" ]; then
    echo ">> A IMAGEM COMPILADA ATENDE A TODOS OS REQUISITOS DO DOCKER."
    echo "   pode prosseguir para a troca do kernel."
else
    echo "!! $FALTOU requisito(s) faltando NA IMAGEM. nao grave ainda."
    exit 1
fi
