#!/usr/bin/env bash
# Apply the BORE patch and its Kconfig fragment before olddefconfig/build.
set -Eeuo pipefail
patch_file=${BORE_PATCH_FILE:-patches/sources/bore/bore.patch}
source_dir=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}
fragment=${BORE_FRAGMENT:-configs/features/oneplus-bore.fragment}
merge=${KCONFIG_MERGE_CONFIG:-$source_dir/scripts/kconfig/merge_config.sh}
out=${KERNEL_OUT:-out}
[[ -f $patch_file ]] || { echo "BORE patch missing: $patch_file" >&2; exit 1; }
[[ -r $fragment ]] || { echo "BORE fragment missing: $fragment" >&2; exit 1; }
[[ -x $merge || -f $merge ]] || { echo "merge_config.sh missing: $merge" >&2; exit 1; }
"$merge" -m -O "$PWD/$out" "$PWD/$out/.config" "$PWD/$fragment"
git -C "$source_dir" apply --check "$PWD/$patch_file"
git -C "$source_dir" apply "$PWD/$patch_file"
printf 'BORE: fragment merged, patch applied before olddefconfig\n'
