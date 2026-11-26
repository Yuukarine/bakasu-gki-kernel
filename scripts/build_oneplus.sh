#!/usr/bin/env bash
set -Eeuo pipefail
src=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}; out=${KERNEL_OUT:-out}
[[ -d $src ]] || { echo "kernel source missing: $src" >&2; exit 1; }
mkdir -p "$out"
expected_release=${STOCK_UNAME:-}
if [[ -n $expected_release ]]; then
  [[ $expected_release =~ ^[0-9]+\.[0-9]+\.[0-9]+-[^[:space:]+]+$ ]] || { echo "invalid STOCK_UNAME: $expected_release" >&2; exit 1; }
  expected_base=${expected_release%%-*}
  # kernelrelease may append a dirty SCM suffix while patches are applied;
  # kernelversion is the authoritative VERSION.PATCHLEVEL.SUBLEVEL base.
  source_base=$(make -s -C "$src" O="$PWD/$out" CONFIG_LOCALVERSION_AUTO=n LOCALVERSION= kernelversion)
  [[ $source_base == "$expected_base" ]] || { echo "source kernel base mismatch: expected=$expected_base actual=$source_base" >&2; exit 1; }
  export LOCALVERSION="-${expected_release#*-}"
fi
make -C "$src" O="$PWD/$out" CONFIG_LOCALVERSION_AUTO=n olddefconfig
scripts/verify_kconfig.sh --config "$out/.config" --branch oneplus-ogki
make -C "$src" O="$PWD/$out" CONFIG_LOCALVERSION_AUTO=n -j"${JOBS:-$(nproc)}" Image modules
[[ -f $out/Module.symvers ]] || { echo 'built Module.symvers missing' >&2; exit 1; }
if [[ -n $expected_release ]]; then
  scripts/verify_image_release.sh --image "$out/arch/arm64/boot/Image" --expected "$expected_release"
fi
cp "$out/Module.symvers" Module.symvers
