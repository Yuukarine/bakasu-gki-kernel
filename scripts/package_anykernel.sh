#!/usr/bin/env bash
# Reproducible AnyKernel ZIP/checksum packager.
set -Eeuo pipefail
template= image= name= output_dir=artifacts
while (($#)); do case "$1" in
  --template) template=$2; shift 2;; --image) image=$2; shift 2;; --name) name=$2; shift 2;; --output-dir) output_dir=$2; shift 2;; *) echo "unknown option: $1" >&2; exit 2;;
esac; done
[[ -d $template ]] || { echo "AnyKernel template missing: $template" >&2; exit 1; }
[[ -n $name ]] || name=kernel
mkdir -p "$output_dir" "$output_dir/package"
rm -rf "$output_dir/package/$name"
cp -a "$template" "$output_dir/package/$name"
if [[ -n $image ]]; then [[ -f $image ]] || { echo "kernel image missing: $image" >&2; exit 1; }; cp "$image" "$output_dir/package/$name/Image"; fi
command -v zip >/dev/null 2>&1 || { echo 'zip is required for packaging' >&2; exit 1; }
( cd "$output_dir/package/$name" && zip -qr "../../$name.zip" . )
sha256sum "$output_dir/$name.zip" > "$output_dir/$name.zip.sha256"
rm -rf "$output_dir/package/$name"
printf 'package=%s/%s.zip\nchecksum=%s/%s.zip.sha256\n' "$output_dir" "$name" "$output_dir" "$name"
