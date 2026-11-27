#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp="$root/.tmp/module-abi-fixtures"
mkdir -p "$tmp"
trap 'rm -rf -- "$tmp"' EXIT
ktool=${KTOOL_BIN:-$root/tools/ktool/target/release/ktool}
if [[ ! -x $ktool ]]; then
  cargo build --release --locked --manifest-path "$root/tools/ktool/Cargo.toml"
fi
cat > "$tmp/imports" <<'DATA'
# consumer symbol crc provider
wifi.ko kernel_api 0x01 vmlinux
wifi.ko wireless_api 0x02 cfg80211.ko
DATA
printf 'cfg80211.ko wireless_api 0x00000002\n' > "$tmp/exports"
printf '0X00000001 kernel_api vmlinux EXPORT_SYMBOL\n' > "$tmp/kernel"
printf 'wifi.ko\ncfg80211.ko\n' > "$tmp/modules"
run_gate() {
  "$ktool" verify-module-abi --imports "$tmp/imports" --exports "$tmp/exports" --kernel "$tmp/kernel" --modules "$tmp/modules"
}
expect_fail() {
  local diagnostic=$1
  if run_gate > "$tmp/result" 2>&1; then
    printf 'module ABI fixture unexpectedly passed: %s\n' "$diagnostic" >&2
    exit 1
  fi
  grep -Fq -- "$diagnostic" "$tmp/result"
}
run_gate | grep -F 'MODULE ABI CHECK: PASS (imports=2 modules=1 missing_provider=0 missing_symbol=0 changed_crc=0)'
printf 'wifi.ko\n' > "$tmp/modules"
expect_fail 'missing_provider: consumer=wifi.ko provider=cfg80211.ko symbol=wireless_api'
printf 'wifi.ko\ncfg80211.ko\n' > "$tmp/modules"
: > "$tmp/exports"
expect_fail 'missing_symbol: consumer=wifi.ko provider=cfg80211.ko symbol=wireless_api'
printf 'cfg80211.ko wireless_api 0x03\n' > "$tmp/exports"
expect_fail 'changed_crc: consumer=wifi.ko provider=cfg80211.ko symbol=wireless_api expected=0x00000002 actual=0x00000003'
printf 'cfg80211.ko wireless_api 0x02\n' > "$tmp/exports"
printf 'wifi.ko kernel_api 0x01 unresolved\n' > "$tmp/imports"
expect_fail 'missing_provider: consumer=wifi.ko provider=unresolved symbol=kernel_api'
printf 'wifi.ko kernel_api 0x01 vmlinux\nwifi.ko kernel_api 0x01 vmlinux\n' > "$tmp/imports"
expect_fail 'duplicate/conflicting import wifi.ko kernel_api'
printf 'wifi.ko kernel_api INVALID vmlinux\n' > "$tmp/imports"
expect_fail 'invalid 32-bit CRC: INVALID'
printf 'ROM module ABI fixtures: PASS\n'
