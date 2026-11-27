#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
cd "$root"
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/anykernel-fixtures.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
fixture_sh=$(command -v sh)
mkdir -p "$tmp/min-bin"
# Resolve the exact manifest pin and inspect the real upstream core, not a mock.
ak3_url=$(awk -F '\t' '$1 == "osm0sis-anykernel3" {print $3; exit}' "$root/patches/sources/manifest.tsv")
ak3_sha=$(awk -F '\t' '$1 == "osm0sis-anykernel3" {print $6; exit}' "$root/patches/sources/manifest.tsv")
ak3_ref="$tmp/upstream-ak3"
git clone --depth 1 --branch master "$ak3_url" "$ak3_ref" >/dev/null 2>&1
git -C "$ak3_ref" fetch --depth 1 origin "$ak3_sha" >/dev/null 2>&1
git -C "$ak3_ref" checkout --detach "$ak3_sha" >/dev/null 2>&1
"$root/scripts/verify_anykernel_core.sh" --core "$ak3_ref/tools/ak3-core.sh" --template "$root/anykernel/oneplus/anykernel.sh" --template "$root/anykernel/gki/anykernel.sh"
# update-binary exports the core/tool applets into PATH. Only its property-reader
# applets are needed by this harness: no getprop, dd or magiskboot is available.
for applet in grep tail cut; do ln -s "$(command -v "$applet")" "$tmp/min-bin/$applet"; done

for family in oneplus gki; do
  script="$root/anykernel/$family/anykernel.sh"
  sh -n "$script"
  if command -v busybox >/dev/null 2>&1; then busybox ash -n "$script"; fi
  if command -v dash >/dev/null 2>&1; then dash -n "$script"; fi
  if command -v shellcheck >/dev/null 2>&1; then shellcheck -s sh "$script"; fi
  if grep -nE 'set[[:space:]]+-[[:alpha:]]*[eu]|pipefail|\[\[|KERNEL_FMT|(^|[;[:space:]])(dump_boot|write_boot|dd|magiskboot|local)([;[:space:]]|$)|/dev/block/|/proc/' "$script"; then
    echo "non-native boot implementation: $family" >&2; exit 1
  fi
  for required in "properties() { '" 'BLOCK=boot;' 'IS_SLOT_DEVICE=auto;' 'RAMDISK_COMPRESSION=auto;' 'PATCH_VBMETA_FLAG=auto;' 'NO_BLOCK_DISPLAY=1;' '. tools/ak3-core.sh;' 'split_boot;' 'flash_boot;'; do
    grep -Fxq "$required" "$script" || { echo "missing native contract: $required" >&2; exit 1; }
  done
  harness="$tmp/$family"
  mkdir -p "$harness/tools"
  cp "$script" "$harness/anykernel.sh"
  cat > "$harness/tools/ak3-core.sh" <<'CORE'
# file_getprop is the actual reader from pinned update-binary/core. properties()
# is a quoted metadata block; the installer reads it, it does not execute it.
file_getprop() { grep "^$2=" "$1" | tail -n1 | cut -d= -f2-; }
ui_print() { printf 'UI: %s\n' "$*"; }
abort() { ui_print "$*"; exit 1; }
[ "$BLOCK" = boot ] && [ "$IS_SLOT_DEVICE" = auto ] &&
[ "$RAMDISK_COMPRESSION" = auto ] && [ "$PATCH_VBMETA_FLAG" = auto ] &&
[ "$NO_BLOCK_DISPLAY" = 1 ] || abort 'bad core configuration'
case "$(file_getprop anykernel.sh kernel.string)" in
  'BakaSU OnePlus OGKI'|'BakaSU AOSP GKI 2.0') :;;
  *) abort 'bad kernel.string';;
esac
for property in do.devicecheck do.modules do.systemless do.cleanuponabort; do
  [ "$(file_getprop anykernel.sh "$property")" = 0 ] || abort "bad $property"
done
[ "$(file_getprop anykernel.sh do.cleanup)" = 1 ] || abort 'bad do.cleanup'
# Model core-owned state and fail paths without touching real partitions.
AKHOME=$PWD
BIN=$AKHOME/tools
SLOT=_b
split_boot() {
  [ "${CORE_FAIL:-}" != split ] || abort 'split failed'
  [ -f "$AKHOME/boot.img" ] && [ -f "$AKHOME/Image" ] || abort 'missing input'
  native_split=1
  printf 'split_boot\n'
}
flash_boot() {
  [ "$native_split" = 1 ] || abort 'flash before split'
  [ "${CORE_FAIL:-}" != flash ] || abort 'flash failed'
  printf 'flash_boot\n'
}
CORE
  printf 'new kernel\n' > "$harness/Image"
  for layout in ramdiskless with-ramdisk; do
    printf 'boot v4 %s\n' "$layout" > "$harness/boot.img"
    # Optional init_boot inspection was removed, so clean/patched init_boot must
    # both remain untouched and must never stop native boot flashing.
    for init_state in clean kernelsu.ko; do
      printf '%s\n' "$init_state" > "$harness/init_boot.img"
      before=$(sha256sum "$harness/boot.img" "$harness/init_boot.img")
      (cd "$harness" && PATH="$tmp/min-bin" "$fixture_sh" anykernel.sh) > "$tmp/smoke.out" 2> "$tmp/smoke.err"
      printf 'split_boot\nflash_boot\n' > "$tmp/expected.out"
      cmp "$tmp/expected.out" "$tmp/smoke.out"
      test ! -s "$tmp/smoke.err"
      [ "$before" = "$(sha256sum "$harness/boot.img" "$harness/init_boot.img")" ]
    done
  done
  for failure in split flash; do
    if (cd "$harness" && CORE_FAIL="$failure" PATH="$tmp/min-bin" "$fixture_sh" anykernel.sh) > "$tmp/failure.out" 2>&1; then
      echo "core $failure abort unexpectedly passed" >&2; exit 1
    fi
    grep -Fxq "UI: $failure failed" "$tmp/failure.out"
    if grep -Fxq 'flash_boot' "$tmp/failure.out"; then echo 'flashed after core abort' >&2; exit 1; fi
  done
  printf 'native core fixtures: PASS (%s; properties, order, minimal PATH, ramdisk-less, init_boot untouched, abort propagation)\n' "$family"
done

# Package fixtures exercise the offline osm0sis/AnyKernel3 framework path and
# the post-package root-entry gate without network access.
framework="$tmp/framework"
mkdir -p "$framework/META-INF/com/google/android" "$framework/tools" "$framework/.git"
printf '#!/bin/sh\n' > "$framework/META-INF/com/google/android/update-binary"
printf '# fixture\n' > "$framework/META-INF/com/google/android/updater-script"
printf '#!/bin/sh\n' > "$framework/tools/ak3-core.sh"
printf '#!/bin/sh\nexit 0\n' > "$framework/tools/magiskboot"
printf 'upstream\n' > "$framework/README.md"
printf '#!/bin/sh\n' > "$framework/anykernel.sh"
printf 'git\n' > "$framework/.git/config"
chmod +x "$framework/META-INF/com/google/android/update-binary" "$framework/tools/ak3-core.sh" "$framework/tools/magiskboot"
printf 'image\n' > "$tmp/Image"
package_out="$tmp/package-out"
package_log="$tmp/package.log"
for family in oneplus gki; do
scripts/package_anykernel.sh --template "anykernel/$family" --ak3-template-dir "$framework" --image "$tmp/Image" --name "fixture-pass-$family" --output-dir "$package_out" >"$package_log"
pass_zip="$package_out/fixture-pass-$family.zip"
for entry in META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script tools/ak3-core.sh tools/magiskboot anykernel.sh Image; do
  unzip -Z1 "$pass_zip" | sed 's#^\./##' | grep -Fxq "$entry" || { echo "missing package entry: $entry" >&2; exit 1; }
done
if unzip -Z1 "$pass_zip" | grep -Eq '(^|/)\.git(/|$)|(^|/)fixture-pass/'; then echo 'nested or .git entry in package' >&2; exit 1; fi
sha256sum "$pass_zip" | cmp -s - "$pass_zip.sha256" || { echo 'package checksum mismatch' >&2; exit 1; }

mkdir -p "$tmp/extracted-$family"
unzip -q "$pass_zip" -d "$tmp/extracted-$family"
for entry in META-INF/com/google/android/update-binary tools/ak3-core.sh tools/magiskboot anykernel.sh; do test -x "$tmp/extracted-$family/$entry"; done
cmp "$root/anykernel/$family/anykernel.sh" "$tmp/extracted-$family/anykernel.sh"
printf "ZIP structure/checksum/executable modes: PASS (%s)\n" "$family"
done

for missing in update-binary ak3-core.sh; do
  bad="$tmp/framework-missing-$missing"; cp -a "$framework" "$bad"
  if [ "$missing" = update-binary ]; then rm -f "$bad/META-INF/com/google/android/update-binary"; else rm -f "$bad/tools/ak3-core.sh"; fi
  if scripts/package_anykernel.sh --template anykernel/gki --ak3-template-dir "$bad" --image "$tmp/Image" --name "fixture-fail-$missing" --output-dir "$package_out" >"$tmp/fail-$missing.out" 2>"$tmp/fail-$missing.err"; then
    echo "package unexpectedly passed missing $missing" >&2; exit 1
  fi
  grep -Fq "package structure gate failed: missing root entry" "$tmp/fail-$missing.err" || { cat "$tmp/fail-$missing.err" >&2; exit 1; }
done
printf 'AnyKernel fixtures: PASS\n'
