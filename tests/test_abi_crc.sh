#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
tmp="$root/.tmp/abi-fixtures"; mkdir -p "$tmp/cache"; trap 'find "$tmp" -mindepth 1 -maxdepth 1 -exec rm -rf {} +' EXIT
cat > "$tmp/ref" <<'EOT'
0xAAAA foo vmlinux EXPORT_SYMBOL
0xBBBB bar vmlinux EXPORT_SYMBOL_GPL
EOT
cp "$tmp/ref" "$tmp/candidate"
BAKASU_WORK_ROOT="$tmp" "$root/scripts/verify_abi_crc.sh" --bore "$tmp/ref" "$tmp/candidate" | grep -F 'CRC CHECK: PASS'
printf '0xCCCC foo vmlinux EXPORT_SYMBOL\n0xBBBB bar vmlinux EXPORT_SYMBOL_GPL\n' > "$tmp/drift"
if BAKASU_WORK_ROOT="$tmp" "$root/scripts/verify_abi_crc.sh" --bore "$tmp/ref" "$tmp/drift" >/dev/null 2>&1; then echo 'CRC drift fixture unexpectedly passed' >&2; exit 1; fi
printf '0xDDDD explicit vmlinux EXPORT_SYMBOL\n' > "$tmp/explicit"
printf '0xEEEE cache vmlinux EXPORT_SYMBOL\n' > "$tmp/cache/Module.symvers"
printf '0xFFFF prebuilt vmlinux EXPORT_SYMBOL\n' > "$tmp/prebuilt"
cache_sha=$(sha256sum "$tmp/cache/Module.symvers" | awk '{print $1}')
cat > "$tmp/cache/metadata" <<META
cache_key=fixture-kmi-page-stock-source-toolchain
kmi=android14-6.1
page_size=4096
stock_uname=6.1.118-test
source_sha=source-fixture
toolchain=clang-fixture
sha256=$cache_sha
META
resolved=$(BAKASU_WORK_ROOT="$tmp" "$root/scripts/resolve_stock_symvers.sh" --output "$tmp/out" --input "$tmp/explicit" --cache "$tmp/cache" --prebuilt "$tmp/prebuilt")
grep -F 'resolver_source=path' <<<"$resolved"
resolved=$(BAKASU_WORK_ROOT="$tmp" "$root/scripts/resolve_stock_symvers.sh" --output "$tmp/out" --cache "$tmp/cache" --prebuilt "$tmp/prebuilt" --expected-cache-key fixture-kmi-page-stock-source-toolchain --kmi android14-6.1 --page-size 4096 --stock-uname 6.1.118-test --source-sha source-fixture --toolchain clang-fixture)
grep -F 'resolver_source=cache' <<<"$resolved"
grep -F '0xEEEE' "$tmp/out"
printf 'sha256=wrong\ncache_key=bad\n' > "$tmp/cache/metadata"
resolved=$(BAKASU_WORK_ROOT="$tmp" "$root/scripts/resolve_stock_symvers.sh" --output "$tmp/out" --cache "$tmp/cache" --prebuilt "$tmp/prebuilt" --expected-cache-key fixture-kmi-page-stock-source-toolchain)
grep -F 'resolver_source=prebuilt' <<<"$resolved"
resolved=$(BAKASU_WORK_ROOT="$tmp" "$root/scripts/resolve_stock_symvers.sh" --output "$tmp/out" --prebuilt "$tmp/prebuilt")
grep -F 'resolver_source=prebuilt' <<<"$resolved"
resolved=$(BAKASU_WORK_ROOT="$tmp" "$root/scripts/resolve_stock_symvers.sh" --output "$tmp/out" --bootstrap 'printf "0x1234 bootstrapped vmlinux EXPORT_SYMBOL\n"')
grep -F 'resolver_source=bootstrap' <<<"$resolved"
printf 'ABI CRC/resolver fixtures: PASS\n'
