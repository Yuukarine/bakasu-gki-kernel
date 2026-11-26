#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp="$root/.tmp/anykernel-fixtures"; mkdir -p "$tmp/bin" "$tmp/partitions" "$tmp/bootdevice" "$tmp/marker"; trap 'rm -rf "$tmp"' EXIT
run(){
  AK3_LIB_ONLY=0 AK3_DRY_RUN=1 AK3_SLOT_SUFFIX="${AK3_SLOT_SUFFIX:-}" AK3_PAGE_SIZE="${AK3_PAGE_SIZE:-}" AK3_MARKER_ROOT="${AK3_MARKER_ROOT:-}" AK3_PARTITION_ROOT="$tmp/partitions" AK3_BOOTDEVICE_ROOT="$tmp/bootdevice" AK3_BOOT_IMAGE="${AK3_BOOT_IMAGE-$tmp/boot.img}" \
  AK3_UNAME_R="${AK3_UNAME_R:-6.1.118-android14-11-o-gac2e718ebee}" AK3_EXPECTED_UNAME_R="${AK3_EXPECTED_UNAME_R:-6.1.118-android14-11-o-gac2e718ebee}" \
  AK3_EXPECTED_KMI="${AK3_EXPECTED_KMI:-android14-6.1}" "$root/anykernel/gki/anykernel.sh"
}
touch "$tmp/boot.img" "$tmp/partitions/boot_a"
AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run | grep -F 'resolver_source=dry-run'
# Active A/B init_boot absent and both slots absent is an explicit safe skip.
AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run | grep -F 'init_boot: absent on A/B device, inspection skipped'
# The second canonical by-name root is also accepted.
rm -f "$tmp/partitions/boot_a"; touch "$tmp/bootdevice/boot_a"
AK3_BOOT_IMAGE="" AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run | grep -F 'boot='"$tmp/bootdevice/boot_a"
rm -f "$tmp/bootdevice/boot_a"; touch "$tmp/partitions/boot_a"
# A/B is recognized even without a slot property; ambiguous active slot must not fall back to init_boot.
touch "$tmp/partitions/boot_b" "$tmp/partitions/init_boot"
unset AK3_SLOT_SUFFIX
if AK3_PAGE_SIZE=4096 run >"$tmp/ab-no-slot.out" 2>&1; then echo 'ambiguous A/B slot unexpectedly passed' >&2; exit 1; fi
grep -F 'A/B device requires active slot suffix' "$tmp/ab-no-slot.out"
rm -f "$tmp/partitions/init_boot"
# Opposite-slot init_boot is a hard failure.
touch "$tmp/partitions/init_boot_b"
if AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null 2>&1; then echo 'opposite init_boot unexpectedly passed' >&2; exit 1; fi
rm "$tmp/partitions/init_boot_b"; rm "$tmp/partitions/boot_b"
# Exact six marker paths reject; similar names and nested paths do not.
touch "$tmp/partitions/init_boot_a"
for marker in kernelsu.ko ksuinit magiskinit .backup .magisk .backup/.magisk; do
  rm -rf "$tmp/marker"; mkdir -p "$tmp/marker/$(dirname "$marker")"; touch "$tmp/marker/$marker"
  if AK3_MARKER_ROOT="$tmp/marker" AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null 2>&1; then echo "marker unexpectedly passed: $marker" >&2; exit 1; fi
done
rm -rf "$tmp/marker"; mkdir -p "$tmp/marker" "$tmp/marker/foo"; touch "$tmp/marker/.backup.something" "$tmp/marker/.magisk_backup" "$tmp/marker/foo/.backup" "$tmp/marker/foo/.magisk"
AK3_MARKER_ROOT="$tmp/marker" AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null

# Package fixtures exercise the offline osm0sis/AnyKernel3 framework path and
# the post-package root-entry gate without network access.
framework="$tmp/framework"
mkdir -p "$framework/META-INF/com/google/android" "$framework/tools" "$framework/.git"
printf '#!/bin/sh\n' > "$framework/META-INF/com/google/android/update-binary"
printf '# fixture\n' > "$framework/META-INF/com/google/android/updater-script"
printf '#!/bin/sh\n' > "$framework/tools/ak3-core.sh"
printf 'upstream\n' > "$framework/README.md"
printf '#!/bin/sh\n' > "$framework/anykernel.sh"
printf 'git\n' > "$framework/.git/config"
chmod +x "$framework/META-INF/com/google/android/update-binary" "$framework/tools/ak3-core.sh"
printf 'image\n' > "$tmp/Image"
package_out="$tmp/package-out"
package_log="$tmp/package.log"
scripts/package_anykernel.sh --template anykernel/gki --ak3-template-dir "$framework" --image "$tmp/Image" --name fixture-pass --output-dir "$package_out" >"$package_log"
pass_zip="$package_out/fixture-pass.zip"
for entry in META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script tools/ak3-core.sh anykernel.sh Image; do
  unzip -Z1 "$pass_zip" | sed 's#^\./##' | grep -Fxq "$entry" || { echo "missing package entry: $entry" >&2; exit 1; }
done
if unzip -Z1 "$pass_zip" | grep -Eq '(^|/)\.git(/|$)|(^|/)fixture-pass/'; then echo 'nested or .git entry in package' >&2; exit 1; fi
echo "$(sha256sum "$pass_zip")" | cmp -s - "$pass_zip.sha256" || { echo 'package checksum mismatch' >&2; exit 1; }

for missing in update-binary ak3-core.sh; do
  bad="$tmp/framework-missing-$missing"; cp -a "$framework" "$bad"
  if [ "$missing" = update-binary ]; then rm -f "$bad/META-INF/com/google/android/update-binary"; else rm -f "$bad/tools/ak3-core.sh"; fi
  if scripts/package_anykernel.sh --template anykernel/gki --ak3-template-dir "$bad" --image "$tmp/Image" --name "fixture-fail-$missing" --output-dir "$package_out" >"$tmp/fail-$missing.out" 2>"$tmp/fail-$missing.err"; then
    echo "package unexpectedly passed missing $missing" >&2; exit 1
  fi
  grep -Fq "package structure gate failed: missing root entry" "$tmp/fail-$missing.err" || { cat "$tmp/fail-$missing.err" >&2; exit 1; }
done
# getconf failure falls back to a consistent base page size and ignores hugepage VMAs.
rm -f "$tmp/partitions/init_boot_a"
cat > "$tmp/bin/getconf" <<'SH'
#!/bin/sh
exit 127
SH
chmod +x "$tmp/bin/getconf"
printf '00400000-00401000 r--p 00000000 00:00 0\nKernelPageSize:        4 kB\n\n00800000-00a00000 rw-p 00000000 00:00 0\nKernelPageSize:        2048 kB\n' > "$tmp/smaps"
PATH="$tmp/bin:/usr/bin:/bin"; unset AK3_PAGE_SIZE
PATH="$PATH" AK3_SLOT_SUFFIX=_a AK3_SMAPS_FILE="$tmp/smaps" run | grep -F 'page_size_source=smaps'
# Android 15+ requires the explicit uname page suffix and rejects a lower sublevel.
if AK3_UNAME_R='6.6.10-android15-8' AK3_EXPECTED_UNAME_R='6.6.10-android15-8' AK3_EXPECTED_KMI='android15-6.6' AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null 2>&1; then echo 'missing 4k suffix unexpectedly passed' >&2; exit 1; fi
AK3_UNAME_R='6.6.10-android15-8-4k' AK3_EXPECTED_UNAME_R='6.6.10-android15-8-4k' AK3_EXPECTED_KMI='android15-6.6' AK3_STOCK_SUBLEVEL=10 AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null
if AK3_UNAME_R='6.6.9-android15-8-4k' AK3_EXPECTED_UNAME_R='6.6.9-android15-8-4k' AK3_EXPECTED_KMI='android15-6.6' AK3_STOCK_SUBLEVEL=10 AK3_SLOT_SUFFIX=_a AK3_PAGE_SIZE=4096 run >/dev/null 2>&1; then echo 'lower sublevel unexpectedly passed' >&2; exit 1; fi
# Non-A/B uses an unqualified init_boot and skips cleanly when absent.
rm -f "$tmp/partitions/boot_a" "$tmp/partitions/init_boot_a" "$tmp/marker/.backup.something" "$tmp/marker/.magisk_backup" "$tmp/marker/foo/.backup" "$tmp/marker/foo/.magisk"
touch "$tmp/partitions/boot"
unset AK3_SLOT_SUFFIX AK3_PAGE_SIZE AK3_SMAPS_FILE AK3_MARKER_ROOT
AK3_DRY_RUN=1 AK3_PAGE_SIZE=4096 AK3_BOOT_IMAGE="$tmp/boot.img" AK3_PARTITION_ROOT="$tmp/partitions" AK3_BOOTDEVICE_ROOT="$tmp/bootdevice" "$root/anykernel/oneplus/anykernel.sh" | grep -F 'init_boot: absent, inspection skipped'
printf 'AnyKernel fixtures: PASS\n'
