#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/rom-export-fixtures.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/source/android"
printf 'other_protected\nrfkill_alloc\nrfkill_register\n' > "$tmp/source/android/abi_gki_protected_exports_aarch64"
printf 'rfkill.ko rfkill_alloc 0x1\nrfkill.ko rfkill_register 0x2\n' > "$tmp/exports"
grep -Fxq rfkill_alloc "$tmp/source/android/abi_gki_protected_exports_aarch64"
python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" | grep -F 'rfkill_protected_removed=2'
[[ $(cat "$tmp/source/android/abi_gki_protected_exports_aarch64") == other_protected ]]
python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" | grep -F 'rfkill_protected_removed=0'
printf 'rfkill.ko unrelated_symbol 0x1\n' > "$tmp/exports"
if python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" > "$tmp/error" 2>&1; then
  echo 'unrelated export policy unexpectedly passed' >&2; exit 1
fi
grep -Fq 'verified rfkill exports only' "$tmp/error"
printf 'ROM export policy fixtures: PASS\n'
