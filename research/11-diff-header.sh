#!/bin/bash
# 11 - compara o cabecalho de imagem ARM64 dos dois kernels e o DTB.
# O cabecalho diz ao bootloader onde carregar e quanta memoria reservar.
set -e
BASE="$HOME/kernel"; SRC="$BASE/src"; CMP="$BASE/cmp"
cd "$CMP"

python3 - <<'PY'
import struct

def hdr(path):
    with open(path,'rb') as f:
        d = f.read(64)
    # Documentation/arm64/booting.txt
    code0, code1 = struct.unpack('<II', d[0:8])
    text_offset, image_size, flags = struct.unpack('<QQQ', d[8:32])
    res2, res3, res4 = struct.unpack('<QQQ', d[32:56])
    magic = d[56:60]
    return dict(code0=code0, code1=code1, text_offset=text_offset,
                image_size=image_size, flags=flags, magic=magic, head=d[:16].hex())

import os
a = hdr('kernel-original')
b = hdr(os.path.expanduser('~/kernel/src/out-lto/arch/arm64/boot/Image'))

sa = os.path.getsize('kernel-original')
sb = os.path.getsize(os.path.expanduser('~/kernel/src/out-lto/arch/arm64/boot/Image'))

print(f"{'campo':<16}{'ORIGINAL':>22}{'NOSSA':>22}   {'':>3}")
print('-'*66)
def row(k, fa, fb, fmt='{}'):
    m = 'OK ' if fa == fb else '!! '
    print(f"{k:<16}{fmt.format(fa):>22}{fmt.format(fb):>22}   {m}")

row('magic',      a['magic'].decode(errors='replace'), b['magic'].decode(errors='replace'))
row('code0',      hex(a['code0']), hex(b['code0']))
row('code1',      hex(a['code1']), hex(b['code1']))
row('text_offset',hex(a['text_offset']), hex(b['text_offset']))
row('image_size', a['image_size'], b['image_size'])
row('flags',      hex(a['flags']), hex(b['flags']))
row('tamanho',    sa, sb)
print()
print(f"  image_size declarado - original : {a['image_size']:,} bytes")
print(f"  image_size declarado - nossa    : {b['image_size']:,} bytes")
print(f"  diferenca                       : {b['image_size']-a['image_size']:+,} bytes")
print()
print(f"  primeiros 16 bytes original : {a['head']}")
print(f"  primeiros 16 bytes nossa    : {b['head']}")
PY

echo
echo "=== o DTB e o mesmo? ==="
# dtb do boot.img original (extraido pelo magiskboot no aparelho tinha 342016 bytes)
python3 - <<'PY'
import struct
f=open('boot-original-DEVICE.img','rb'); d=f.read(4096)
(ks,ka,rs,ra,ss,sa2,ta,ps,hv,ov)=struct.unpack('<10I', d[8:48])
# header v2: dtb_size fica apos recovery_dtbo_size(4)+offset(8)+header_size(4)
off = 8+40+16+512+32+1024
rec_sz, rec_off, hdr_sz, dtb_sz = struct.unpack('<IQII', d[off:off+20])
print(f'  dtb_size no boot.img: {dtb_sz}')
def pages(n): return (n+ps-1)//ps*ps
start = ps + pages(ks) + pages(rs) + pages(ss) + pages(rec_sz)
f.seek(start); open('dtb-original','wb').write(f.read(dtb_sz))
PY
ls -l dtb-original 2>/dev/null
echo "  md5 do dtb original : $(md5sum dtb-original 2>/dev/null | cut -d' ' -f1)"
DTBN="$SRC/out-lto/arch/arm64/boot/dts/exynos/exynos9830.dtb"
if [ -f "$DTBN" ]; then
    echo "  md5 do dtb que compilamos: $(md5sum "$DTBN" | cut -d' ' -f1)  ($(stat -c %s "$DTBN") bytes)"
else
    echo "  (nosso dtb nao encontrado em $DTBN)"
    find "$SRC/out-lto/arch/arm64/boot/dts" -name "*.dtb" 2>/dev/null | head -5
fi
