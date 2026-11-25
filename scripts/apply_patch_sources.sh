#!/usr/bin/env bash
# Apply only local, declared C patch sources; Kconfig fragments remain separate.
set -Eeuo pipefail
source_dir=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}
manifest=${PATCH_MANIFEST:-patches/sources/manifest.tsv}
log=${PATCH_LOG:-artifacts/patch-sources.log}
features=${PATCH_FEATURES:-bakasu,susfs-v2.4.0,nomount,unicode-bypass-fix,faster-sdp-900ma,ptrace-leak-fix,amneziawg}
[[ -d $source_dir ]] || { echo "kernel source missing: $source_dir" >&2; exit 1; }
[[ -r $manifest ]] || { echo "patch manifest missing: $manifest" >&2; exit 1; }
mkdir -p "$(dirname -- "$log")"; : > "$log"
IFS=, read -r -a selected <<< "$features"
for feature in "${selected[@]}"; do
  [[ -n $feature ]] || continue
  patch_dir="patches/sources/$feature"
  mapfile -t patches < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print 2>/dev/null | sort)
  if ((${#patches[@]} == 0)); then
    printf 'feature=%s status=upstream-tree-or-override-required\n' "$feature" >> "$log"
    continue
  fi
  for patch in "${patches[@]}"; do
    git -C "$source_dir" apply --check "$PWD/$patch"
    git -C "$source_dir" apply "$PWD/$patch"
    printf 'feature=%s status=applied patch=%s\n' "$feature" "$patch" >> "$log"
  done
done
