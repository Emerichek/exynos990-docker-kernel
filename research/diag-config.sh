#!/bin/bash
# diagnostico: por que OVERLAY_FS e VETH nao entraram
BASE="$HOME/kernel"
SRC="$BASE/src"
export ARCH=arm64
export PATH="$BASE/clang/bin:$BASE/gcc/bin:$PATH"
export CROSS_COMPILE=aarch64-linux-android-
export CLANG_TRIPLE=aarch64-linux-gnu-
cd "$SRC"

echo "=== 1. estao no defconfig base? ==="
grep -nE "OVERLAY_FS|CONFIG_VETH" arch/arm64/configs/exynos9830_defconfig || echo "  nao aparecem"

echo
echo "=== 2. como ficaram no .config final? ==="
grep -nE "OVERLAY_FS|CONFIG_VETH" out/.config || echo "  ausentes do .config"

echo
echo "=== 3. o docker.config toca nelas? ==="
grep -nE "OVERLAY_FS|VETH" arch/arm64/configs/docker.config || echo "  nao"

echo
echo "=== 4. refazendo do zero, COM as mensagens do merge ==="
make O=out2 CC=clang exynos9830_defconfig >/dev/null 2>&1
echo "--- apos defconfig base ---"
grep -E "^CONFIG_OVERLAY_FS|^CONFIG_VETH|OVERLAY_FS is not|VETH is not" out2/.config || echo "  ausentes"

echo "--- rodando merge_config (saida visivel) ---"
./scripts/kconfig/merge_config.sh -m -O out2 out2/.config \
    arch/arm64/configs/y2s.config \
    arch/arm64/configs/docker.config 2>&1 | grep -iE "override|value|warning" | head -20
echo "--- apos merge ---"
grep -E "^CONFIG_OVERLAY_FS|^CONFIG_VETH|OVERLAY_FS is not|VETH is not" out2/.config || echo "  ausentes"

make O=out2 CC=clang olddefconfig >/dev/null 2>&1
echo "--- apos olddefconfig ---"
grep -E "^CONFIG_OVERLAY_FS|^CONFIG_VETH|OVERLAY_FS is not|VETH is not" out2/.config || echo "  ausentes"

echo
echo "=== 5. dependencias declaradas no Kconfig ==="
echo "--- OVERLAY_FS ---"
sed -n '/^config OVERLAY_FS$/,/^config /p' fs/overlayfs/Kconfig | head -12
echo "--- VETH ---"
sed -n '/^config VETH$/,/^config /p' drivers/net/Kconfig | head -12
