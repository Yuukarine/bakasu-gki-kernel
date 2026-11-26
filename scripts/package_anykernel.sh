#!/usr/bin/env bash
# Build an AnyKernel3 ZIP from the pinned osm0sis framework and a device script.
set -Eeuo pipefail

repo_root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
template=''
ak3_template_dir=${AK3_TEMPLATE_DIR:-}
image=''
dtb=''
dtbo=''
name=kernel
output_dir=artifacts
manifest=${AK3_MANIFEST:-$repo_root/patches/sources/manifest.tsv}

usage() {
  printf '%s\n' 'usage: package_anykernel.sh --template DIR [--ak3-template-dir DIR] --image FILE --name NAME --output-dir DIR [--dtb FILE] [--dtbo FILE]' >&2
}
while (($#)); do
  case "$1" in
    --template) [[ $# -ge 2 ]] || { usage; exit 2; }; template=$2; shift 2 ;;
    --ak3-template-dir) [[ $# -ge 2 ]] || { usage; exit 2; }; ak3_template_dir=$2; shift 2 ;;
    --image) [[ $# -ge 2 ]] || { usage; exit 2; }; image=$2; shift 2 ;;
    --dtb) [[ $# -ge 2 ]] || { usage; exit 2; }; dtb=$2; shift 2 ;;
    --dtbo) [[ $# -ge 2 ]] || { usage; exit 2; }; dtbo=$2; shift 2 ;;
    --name) [[ $# -ge 2 ]] || { usage; exit 2; }; name=$2; shift 2 ;;
    --output-dir) [[ $# -ge 2 ]] || { usage; exit 2; }; output_dir=$2; shift 2 ;;
    --manifest) [[ $# -ge 2 ]] || { usage; exit 2; }; manifest=$2; shift 2 ;;
    -h|--help) usage; exit 0 ;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage; exit 2 ;;
  esac
done

[[ -n $template && -d $template ]] || { printf 'AnyKernel device template missing: %s\n' "$template" >&2; exit 1; }
[[ -n $name && $name != */* ]] || { printf 'invalid package name: %s\n' "$name" >&2; exit 1; }
[[ -r $manifest ]] || { printf 'AnyKernel source manifest missing: %s\n' "$manifest" >&2; exit 1; }
command -v zip >/dev/null 2>&1 || { echo 'zip is required for packaging' >&2; exit 1; }
command -v sha256sum >/dev/null 2>&1 || { echo 'sha256sum is required for packaging' >&2; exit 1; }

source_url=$(awk -F '\t' '$1 == "osm0sis-anykernel3" {print $3; exit}' "$manifest")
source_ref=$(awk -F '\t' '$1 == "osm0sis-anykernel3" {print $4; exit}' "$manifest")
source_sha=$(awk -F '\t' '$1 == "osm0sis-anykernel3" {print $6; exit}' "$manifest")
[[ -n $source_url && -n $source_ref ]] || { echo 'osm0sis AnyKernel3 source is missing from manifest' >&2; exit 1; }

resolve_path() {
  local value=$1
  if [[ $value = /* ]]; then printf '%s\n' "$value"; else printf '%s/%s\n' "$repo_root" "$value"; fi
}
template=$(resolve_path "$template")
output_dir=$(resolve_path "$output_dir")
[[ -n $ak3_template_dir ]] && ak3_template_dir=$(resolve_path "$ak3_template_dir")
[[ -n $image ]] && image=$(resolve_path "$image")
[[ -n $dtb ]] && dtb=$(resolve_path "$dtb")
[[ -n $dtbo ]] && dtbo=$(resolve_path "$dtbo")

tmp_root=$(mktemp -d "$repo_root/.tmp/anykernel-package.XXXXXX")
staging=$tmp_root/staging
cleanup() { rm -rf "$tmp_root"; }
trap cleanup EXIT

if [[ -n $ak3_template_dir ]]; then
  [[ -d $ak3_template_dir ]] || { printf 'AK3 template directory missing: %s\n' "$ak3_template_dir" >&2; exit 1; }
  ak3_source=$ak3_template_dir
  resolver_source=local
else
  ak3_source=$tmp_root/upstream
  git clone --depth 1 --branch "$source_ref" "$source_url" "$ak3_source" >/dev/null
  resolver_source=clone
fi
[[ -d $ak3_source/META-INF && -d $ak3_source/tools ]] || { echo 'AnyKernel3 framework must contain META-INF/ and tools/' >&2; exit 1; }
if [[ -n $source_sha ]]; then
  git_root=$(git -C "$ak3_source" rev-parse --show-toplevel 2>/dev/null || :)
  if [[ $git_root = "$ak3_source" ]]; then
    actual_sha=$(git -C "$ak3_source" rev-parse HEAD 2>/dev/null || :)
    if [[ -n $actual_sha && $actual_sha != "$source_sha" ]]; then
      printf 'AnyKernel3 source SHA mismatch: expected=%s actual=%s\n' "$source_sha" "$actual_sha" >&2
      exit 1
    fi
  fi
fi

mkdir -p "$output_dir/package" "$staging"
cp -a "$ak3_source"/. "$staging/"
rm -rf "$staging/.git" "$staging/README.md" "$staging/anykernel.sh"
cp "$template/anykernel.sh" "$staging/anykernel.sh"
chmod +x "$staging/anykernel.sh"

copy_payload() {
  local source=$1 target=$2
  [[ -z $source ]] && return 0
  [[ -f $source ]] || { printf 'payload missing: %s\n' "$source" >&2; exit 1; }
  cp -a "$source" "$staging/$target"
}
copy_payload "$image" Image
if [[ -z $dtb && -n $image && -f ${image%/*}/dtb ]]; then dtb=${image%/*}/dtb; fi
if [[ -z $dtbo && -n $image && -f ${image%/*}/dtbo ]]; then dtbo=${image%/*}/dtbo; fi
copy_payload "$dtb" dtb
copy_payload "$dtbo" dtbo
[[ -f $staging/Image ]] || { echo 'kernel Image missing from package staging' >&2; exit 1; }

zip_path=$output_dir/$name.zip
rm -f "$zip_path" "$zip_path.sha256"
(cd "$staging" && zip -r9 "$zip_path" . >/dev/null)

list_zip_entries() {
  if command -v unzip >/dev/null 2>&1; then unzip -Z1 "$zip_path"; elif command -v zipinfo >/dev/null 2>&1; then zipinfo -1 "$zip_path"; else echo 'unzip or zipinfo is required for ZIP validation' >&2; exit 1; fi
}
mapfile -t entries < <(list_zip_entries)
normalized=()
for entry in "${entries[@]}"; do
  entry=${entry#./}
  [[ $entry != .git && $entry != .git/* ]] || { echo 'package contains forbidden .git/' >&2; exit 1; }
  [[ $entry != */$name/* && $entry != package/* ]] || { printf 'package contains nested parent directory: %s\n' "$entry" >&2; exit 1; }
  normalized+=("$entry")
done
required=(META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script tools/ak3-core.sh anykernel.sh Image)
for required_entry in "${required[@]}"; do
  printf '%s\n' "${normalized[@]}" | grep -Fxq "$required_entry" || { printf 'package structure gate failed: missing root entry %s\n' "$required_entry" >&2; exit 1; }
done
sha256sum "$zip_path" > "$zip_path.sha256"
printf 'package=%s\nchecksum=%s\nresolver_source=%s\n' "$zip_path" "$zip_path.sha256" "$resolver_source"
