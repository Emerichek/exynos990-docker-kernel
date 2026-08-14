#!/bin/bash
# 14 - RKP / uH / Knox: o que o kernel original tem ligado, e o
# nosso controle bate 100%?
set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; CMP="$BASE/cmp"
cd "$CMP"

echo "=== opcoes de seguranca Samsung no kernel ORIGINAL ==="
grep -iE "^CONFIG_.*(RKP|_UH|UH_|TIMA|KNOX|HARX|DEFEX|PROCA|KDP)" config-original.txt | sort || echo "  nenhuma"

echo
echo "=== o controle tem config 100% identica ao original? ==="
"$SRC/scripts/extract-ikconfig" "$SRC/out-ctrl2/arch/arm64/boot/Image" > config-ctrl.txt
grep -E '^(CONFIG_|# CONFIG_)' config-original.txt | sort > a.txt
grep -E '^(CONFIG_|# CONFIG_)' config-ctrl.txt     | sort > b.txt
if diff -q a.txt b.txt >/dev/null; then
    echo "  IDENTICA - zero diferencas"
else
    echo "  diferencas encontradas:"
    diff a.txt b.txt | head -40
    echo "  (total: $(diff a.txt b.txt | grep -c '^[<>]') linhas)"
fi

echo
echo "=== simbolos RKP presentes nos binarios ==="
for f in kernel-original "$SRC/out-ctrl2/arch/arm64/boot/Image"; do
    n=$(basename "$f")
    c=$(strings "$f" 2>/dev/null | grep -ciE "rkp|uh_|vmm\.elf|knox" || true)
    echo "  $n : $c ocorrencias de rkp/uh/knox"
done

echo
echo "=== o blob do hypervisor esta na arvore? ==="
find "$SRC" -iname "*vmm*" -o -iname "*uh.elf*" -o -iname "*rkp*.elf*" 2>/dev/null | head -10
echo "--- diretorios relacionados ---"
ls -d "$SRC"/drivers/*uh* "$SRC"/drivers/*rkp* "$SRC"/init/*rkp* 2>/dev/null | head
