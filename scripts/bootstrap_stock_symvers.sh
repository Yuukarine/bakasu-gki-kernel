#!/usr/bin/env bash
# Build an unpatched baseline and print its Module.symvers for resolver bootstrap.
set -Eeuo pipefail
src=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}; out=${STOCK_KERNEL_OUT:-.tmp/stock-out}
[[ -d $src ]] || { echo "kernel source missing: $src" >&2; exit 1; }
mkdir -p "$out"
make -C "$src" O="$PWD/$out" olddefconfig
make -C "$src" O="$PWD/$out" -j"${JOBS:-$(nproc)}" modules
[[ -s $out/Module.symvers ]] || { echo 'stock baseline Module.symvers missing' >&2; exit 1; }
cat "$out/Module.symvers"
