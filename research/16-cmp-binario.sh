#!/bin/bash
# 16 - quao diferentes sao o kernel original e o nosso controle?
BASE="$HOME/kernel"; SRC="$BASE/src"; CMP="$BASE/cmp"
O="$CMP/kernel-original"
N="$SRC/out-ctrl2/arch/arm64/boot/Image"

echo "  original : $(stat -c %s "$O") bytes  $(md5sum "$O" | cut -d' ' -f1)"
echo "  controle : $(stat -c %s "$N") bytes  $(md5sum "$N" | cut -d' ' -f1)"
echo

DIF=$(cmp -l "$O" "$N" 2>/dev/null | wc -l)
TOT=$(stat -c %s "$O")
echo "  bytes diferentes : $DIF de $TOT  ($(awk -v d=$DIF -v t=$TOT 'BEGIN{printf "%.2f", d*100/t}')%)"
echo

echo "=== onde comecam e terminam as diferencas ==="
cmp -l "$O" "$N" 2>/dev/null | head -3 | awk '{printf "  primeira em offset %d\n", $1}'
cmp -l "$O" "$N" 2>/dev/null | tail -3 | awk '{printf "  ultima   em offset %d\n", $1}'

echo
echo "=== distribuicao: quantos bytes diferentes por faixa de 4 MB ==="
cmp -l "$O" "$N" 2>/dev/null | awk -v t=$TOT '
{ b=int($1/4194304); c[b]++ }
END { for (i=0;i<=int(t/4194304);i++) printf "  %2d-%2d MB : %s\n", i*4, (i+1)*4, (c[i]?c[i]:0) }'

echo
echo "=== a string de versao tem o mesmo tamanho? ==="
echo -n "  original : "; strings "$O" | grep -m1 "^Linux version" | wc -c
echo -n "  controle : "; strings "$N" | grep -m1 "^Linux version" | wc -c
