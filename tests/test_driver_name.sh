#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp="$root/.tmp/driver-name-fixtures"
mkdir -p "$tmp/source/kernel"
trap 'find "$tmp" -depth -delete' EXIT
cat > "$tmp/source/kernel/Kbuild" <<'KBUILD'
KSU_VERSION := 30701
KSU_VERSION_FULL := $(subst ",,$(CONFIG_KSU_FULL_NAME_FORMAT))
KSU_VERSION_FULL := $(subst %TAG_NAME%,tag,$(KSU_VERSION_FULL))
KBUILD

before=$(sha256sum "$tmp/source/kernel/Kbuild" | awk '{print $1}')
CUSTOM_DRIVER_NAME='' "$root/scripts/set_bakasu_driver_name.sh" --source-dir "$tmp/source" >/dev/null
after=$(sha256sum "$tmp/source/kernel/Kbuild" | awk '{print $1}')
[[ $before == "$after" ]] || { echo 'empty name changed Kbuild' >&2; exit 1; }

name='v4.2.0-⚡Yuukari⚡@BakaSU'
CUSTOM_DRIVER_NAME="$name" "$root/scripts/set_bakasu_driver_name.sh" --source-dir "$tmp/source" >/dev/null
grep -Fqx "KSU_VERSION_FULL := $name" "$tmp/source/kernel/Kbuild"
grep -Fqx 'KSU_VERSION := 30701' "$tmp/source/kernel/Kbuild"

for invalid in 'bad"name' 'bad$name' $'bad\nname' "$(printf 'a%.0s' {1..65})"; do
  if CUSTOM_DRIVER_NAME="$invalid" "$root/scripts/set_bakasu_driver_name.sh" --source-dir "$tmp/source" >"$tmp/error" 2>&1; then
    echo 'invalid driver name unexpectedly passed' >&2
    exit 1
  fi
  grep -Fq 'custom_driver_name: FAIL:' "$tmp/error"
done
printf 'driver-name fixtures: PASS\n'
