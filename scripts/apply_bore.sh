#!/usr/bin/env bash
# Apply the BORE patch and its Kconfig fragment before olddefconfig/build.
set -Eeuo pipefail
patch_file=${BORE_PATCH_FILE:-patches/sources/bore/bore.patch}
patch_url=${BORE_PATCH_URL:-}
source_dir=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}
fragment=${BORE_FRAGMENT:-configs/features/oneplus-bore.fragment}
merge=${KCONFIG_MERGE_CONFIG:-$source_dir/scripts/kconfig/merge_config.sh}
out=${KERNEL_OUT:-out}
if [[ ! -f $patch_file && -n $patch_url ]]; then
  patch_file=${BAKASU_WORK_ROOT:-.tmp}/bore.patch
  mkdir -p "$(dirname -- "$patch_file")"
  command -v curl >/dev/null 2>&1 || { echo 'curl required to fetch BORE patch' >&2; exit 1; }
  curl -fsSL --retry 3 --retry-all-errors "$patch_url" -o "$patch_file"
fi
[[ -s $patch_file ]] || { echo "BORE patch missing: $patch_file (set BORE_PATCH_URL or provide a pinned local patch)" >&2; exit 1; }
[[ -r $fragment ]] || { echo "BORE fragment missing: $fragment" >&2; exit 1; }
[[ -x $merge || -f $merge ]] || { echo "merge_config.sh missing: $merge" >&2; exit 1; }
"$merge" -m -O "$PWD/$out" "$PWD/$out/.config" "$PWD/$fragment"
git -C "$source_dir" apply --check "$PWD/$patch_file"
git -C "$source_dir" apply "$PWD/$patch_file"
printf 'BORE: fragment merged, patch applied before olddefconfig\n'
