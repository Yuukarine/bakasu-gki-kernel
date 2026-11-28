#!/usr/bin/env bash
# Build an unpatched baseline and print its Module.symvers for resolver bootstrap.
set -Eeuo pipefail
src=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}; out=${STOCK_KERNEL_OUT:-.tmp/stock-out}
[[ -d $src ]] || { echo "kernel source missing: $src" >&2; exit 1; }
mkdir -p "$out"
make -C "$src" O="$PWD/$out" gki_defconfig
[[ -x "$src/scripts/config" ]] || make -C "$src" O="$PWD/$out" scripts
"$src/scripts/config" --file "$PWD/$out/.config" --enable MODULES --enable MODVERSIONS
make -C "$src" O="$PWD/$out" olddefconfig
if [[ ${TOOLCHAIN_ID:-} == android-clang-r487747c-pahole-1.23-v2 ]]; then
  scripts/verify_oneplus_toolchain_config.sh "$out/.config"
fi
make -C "$src" O="$PWD/$out" -j"${JOBS:-$(nproc)}" modules
[[ -s $out/Module.symvers ]] || { echo 'stock baseline Module.symvers missing' >&2; exit 1; }
cat "$out/Module.symvers"
