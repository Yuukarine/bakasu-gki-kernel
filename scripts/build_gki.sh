#!/usr/bin/env bash
set -Eeuo pipefail
src=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}; out=${KERNEL_OUT:-out}
[[ -d $src ]] || { echo "kernel source missing: $src" >&2; exit 1; }
mkdir -p "$out"
make -C "$src" O="$PWD/$out" olddefconfig
scripts/verify_kconfig.sh --config "$out/.config" --branch aosp-gki
make -C "$src" O="$PWD/$out" -j"${JOBS:-$(nproc)}" Image modules
[[ -f $out/Module.symvers ]] || { echo 'built Module.symvers missing' >&2; exit 1; }
cp "$out/Module.symvers" Module.symvers
