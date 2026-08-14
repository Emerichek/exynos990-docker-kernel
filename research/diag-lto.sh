#!/bin/bash
# por que o LTO foi desligado?
BASE="$HOME/kernel"
SRC="$BASE/src"
cd "$SRC"

echo "=== dependencias de LTO_CLANG (arch/Kconfig) ==="
sed -n '/^config LTO_CLANG$/,/^config /p' arch/Kconfig | head -30

echo
echo "=== e de THINLTO ==="
sed -n '/^config THINLTO$/,/^config /p' arch/Kconfig | head -12

echo
echo "=== ferramentas LLVM disponiveis no clang prebuilt ==="
for t in ld.lld llvm-ar llvm-nm llvm-objcopy llvm-objdump llvm-strip; do
    if [ -x "$BASE/clang/bin/$t" ]; then
        echo "  [ok]    $t"
    else
        echo "  [FALTA] $t"
    fi
done

echo
echo "=== o que o defconfig pede vs o que saiu ==="
echo "--- pedido no exynos9830_defconfig ---"
grep -E "^CONFIG_LTO|^# CONFIG_LTO|^CONFIG_THINLTO" arch/arm64/configs/exynos9830_defconfig
echo "--- resultado na build COM docker (out/.config) ---"
grep -E "^CONFIG_LTO|^# CONFIG_LTO|^CONFIG_THINLTO" out/.config 2>/dev/null
echo "--- resultado na build de controle (out-ctrl/.config) ---"
grep -E "^CONFIG_LTO|^# CONFIG_LTO|^CONFIG_THINLTO" out-ctrl/.config 2>/dev/null
