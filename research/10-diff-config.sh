#!/bin/bash
# 10 - extrai o kernel ORIGINAL da boot.img e compara a config
# embutida nele com a do nosso kernel. Zero risco: so le arquivos.
set -e

BASE="$HOME/kernel"; SRC="$BASE/src"; CMP="$BASE/cmp"
cd "$CMP"

# ---------- extrai o kernel do boot.img (header android v2) ----------
python3 - <<'PY'
import struct
f = open('boot-original-DEVICE.img','rb')
d = f.read(4096)
assert d[:8] == b'ANDROID!', 'nao e uma boot.img android'
(kernel_sz, kernel_addr, ramdisk_sz, ramdisk_addr,
 second_sz, second_addr, tags_addr, page_sz,
 hdr_ver, os_ver) = struct.unpack('<10I', d[8:48])
print(f'  header_version : {hdr_ver}')
print(f'  page_size      : {page_sz}')
print(f'  kernel_size    : {kernel_sz}')
print(f'  kernel_addr    : 0x{kernel_addr:08x}')
print(f'  ramdisk_size   : {ramdisk_sz}')
print(f'  ramdisk_addr   : 0x{ramdisk_addr:08x}')
print(f'  tags_addr      : 0x{tags_addr:08x}')
f.seek(page_sz)
open('kernel-original','wb').write(f.read(kernel_sz))
PY

echo
echo "=== kernel original extraido ==="
ls -l kernel-original

# ---------- extrai as duas configs ----------
"$SRC/scripts/extract-ikconfig" kernel-original > config-original.txt
"$SRC/scripts/extract-ikconfig" "$SRC/out-lto/arch/arm64/boot/Image" > config-nossa.txt
echo "  original: $(wc -l < config-original.txt) linhas"
echo "  nossa   : $(wc -l < config-nossa.txt) linhas"

# ---------- diff ----------
echo
echo "============================================================"
echo " DIFERENCAS (so as linhas CONFIG_*)"
echo "============================================================"
grep -E '^(CONFIG_|# CONFIG_)' config-original.txt | sort > o.txt
grep -E '^(CONFIG_|# CONFIG_)' config-nossa.txt   | sort > n.txt

# normaliza "# CONFIG_X is not set" -> CONFIG_X=n  para comparar valores
norm() { sed -E 's/^# (CONFIG_[A-Za-z0-9_]+) is not set$/\1=n/' "$1" | sort; }
norm o.txt > on.txt; norm n.txt > nn.txt

echo
echo "--- opcoes cujo VALOR mudou ---"
join -t= -j1 <(sort -t= -k1,1 on.txt) <(sort -t= -k1,1 nn.txt) 2>/dev/null | \
  awk -F= '$2!=$3 {printf "  %-45s %s -> %s\n", $1, $2, $3}' | sort

echo
echo "--- so no ORIGINAL (sumiram na nossa) ---"
comm -23 <(cut -d= -f1 on.txt | sort -u) <(cut -d= -f1 nn.txt | sort -u) | sed 's/^/  /'

echo
echo "--- so na NOSSA (aparecem do nada) ---"
comm -13 <(cut -d= -f1 on.txt | sort -u) <(cut -d= -f1 nn.txt | sort -u) | sed 's/^/  /'

echo
echo "============================================================"
N=$(join -t= -j1 <(sort -t= -k1,1 on.txt) <(sort -t= -k1,1 nn.txt) 2>/dev/null | awk -F= '$2!=$3' | wc -l)
echo " total de opcoes com valor diferente: $N"
echo " (esperado: ~18, as que ligamos de proposito)"
echo "============================================================"
