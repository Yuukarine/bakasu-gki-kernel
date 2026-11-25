#!/usr/bin/env bash
# Verify declared upstream provenance and apply local C patches; Kconfig fragments remain separate.
set -Eeuo pipefail
source_dir=${KERNEL_SOURCE_DIR:-.tmp/kernel_src}
manifest=${PATCH_MANIFEST:-patches/sources/manifest.tsv}
log=${PATCH_LOG:-artifacts/patch-sources.log}
features=${PATCH_FEATURES:-bakasu,susfs-v2.4.0,nomount,unicode-bypass-fix,faster-sdp-900ma,ptrace-leak-fix,amneziawg}
[[ -d $source_dir ]] || { echo "kernel source missing: $source_dir" >&2; exit 1; }
[[ -r $manifest ]] || { echo "patch manifest missing: $manifest" >&2; exit 1; }
mkdir -p "$(dirname -- "$log")"; : > "$log"
declare -A kind url ref fragment
while IFS=$'\t' read -r feature source_kind source_url source_ref kconfig_fragment; do
  [[ -z ${feature:-} || ${feature:0:1} == '#' ]] && continue
  [[ -n ${source_kind:-} && -n ${source_url:-} && -n ${source_ref:-} ]] || { echo "invalid manifest row for $feature" >&2; exit 1; }
  kind[$feature]=$source_kind; url[$feature]=$source_url; ref[$feature]=$source_ref; fragment[$feature]=${kconfig_fragment:--}
done < "$manifest"
IFS=, read -r -a selected <<< "$features"
for feature in "${selected[@]}"; do
  [[ -n $feature ]] || continue
  [[ -n ${kind[$feature]:-} ]] || { echo "feature missing from manifest: $feature" >&2; exit 1; }
  remote_sha=$(git ls-remote --exit-code "${url[$feature]}" "${ref[$feature]}" | awk 'NR==1 {print $1}')
  [[ $remote_sha =~ ^[0-9a-f]{40}$ ]] || { echo "source ref not found: $feature ${url[$feature]}#${ref[$feature]}" >&2; exit 1; }
  patch_dir="patches/sources/$feature"
  mapfile -t patches < <(find "$patch_dir" -maxdepth 1 -type f -name '*.patch' -print 2>/dev/null | sort)
  if ((${#patches[@]} == 0)); then
    printf 'feature=%s status=source-verified-no-local-patch kind=%s url=%s ref=%s sha=%s fragment=%s\n' "$feature" "${kind[$feature]}" "${url[$feature]}" "${ref[$feature]}" "$remote_sha" "${fragment[$feature]}" >> "$log"
    continue
  fi
  for patch in "${patches[@]}"; do
    git -C "$source_dir" apply --check "$PWD/$patch"
    git -C "$source_dir" apply "$PWD/$patch"
    printf 'feature=%s status=applied patch=%s kind=%s url=%s ref=%s sha=%s fragment=%s\n' "$feature" "$patch" "${kind[$feature]}" "${url[$feature]}" "${ref[$feature]}" "$remote_sha" "${fragment[$feature]}" >> "$log"
  done
done
