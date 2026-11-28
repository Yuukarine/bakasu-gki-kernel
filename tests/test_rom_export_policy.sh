#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/rom-export-fixtures.XXXXXX")
trap 'rm -rf -- "$tmp"' EXIT
mkdir -p "$tmp/source/android"
printf 'other_protected\nrfkill_alloc\nrfkill_register\ntipc_dump_done\ntipc_dump_start\ntipc_nl_sk_walk\ntipc_sk_fill_sock_diag\n' > "$tmp/source/android/abi_gki_protected_exports_aarch64"
printf 'rfkill.ko rfkill_alloc 0x1\nrfkill.ko rfkill_register 0x2\n' > "$tmp/exports"
cat >> "$tmp/exports" <<'TIPC'
tipc.ko tipc_dump_done 0xdc43d984
tipc.ko tipc_dump_start 0x60da1d20
tipc.ko tipc_nl_sk_walk 0xf6b650cc
tipc.ko tipc_sk_fill_sock_diag 0x2a0945d7
TIPC
cp "$tmp/exports" "$tmp/good-exports"
if python3 "$root/scripts/prepare_rom_module_exports.py" --check-only --source "$tmp/source" --exports "$tmp/exports" > "$tmp/blocked" 2>&1; then
  echo 'blocked TIPC/rfkill provider unexpectedly passed' >&2; exit 1
fi
grep -Fq 'protected provider exports:' "$tmp/blocked"
grep -Fxq rfkill_alloc "$tmp/source/android/abi_gki_protected_exports_aarch64"
python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" | grep -F 'rfkill_protected_removed=2'
python3 "$root/scripts/prepare_rom_module_exports.py" --check-only --source "$tmp/source" --exports "$tmp/exports" | grep -F 'ROM LOAD POLICY: PASS'
[[ $(cat "$tmp/source/android/abi_gki_protected_exports_aarch64") == other_protected ]]
python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" | grep -F 'rfkill_protected_removed=0'
printf 'rfkill.ko unrelated_symbol 0x1\n' > "$tmp/exports"
if python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" > "$tmp/error" 2>&1; then
  echo 'unrelated export policy unexpectedly passed' >&2; exit 1
fi
grep -Fq 'verified rfkill exports only' "$tmp/error"
# The four TIPC names and their CRCs are evidence, not an open-ended bypass.
for mutation in missing wrong-crc unrelated; do
  case $mutation in
    missing) grep -v tipc_dump_done "$tmp/good-exports" > "$tmp/exports" ;;
    wrong-crc) sed 's/0xdc43d984/0x00000000/' "$tmp/good-exports" > "$tmp/exports" ;;
    unrelated) cp "$tmp/good-exports" "$tmp/exports"; printf 'tipc.ko unrelated_export 0x1\n' >> "$tmp/exports" ;;
  esac
  if python3 "$root/scripts/prepare_rom_module_exports.py" --source "$tmp/source" --exports "$tmp/exports" > "$tmp/error" 2>&1; then
    echo "bad TIPC export evidence passed: $mutation" >&2; exit 1
  fi
  grep -Fq 'exactly four verified ROM TIPC exports' "$tmp/error"
done
printf 'ROM export policy fixtures: PASS\n'
