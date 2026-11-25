#!/usr/bin/env bash
set -euo pipefail
root=$(cd "$(dirname "$0")/.." && pwd)
tmp=$(mktemp -d "${TMPDIR:-/tmp}/abi-fixtures.XXXXXX")
trap 'rm -rf "$tmp"' EXIT
cat > "$tmp/ref" <<'EOT'
0xAAAA foo vmlinux EXPORT_SYMBOL
0xBBBB bar vmlinux EXPORT_SYMBOL_GPL
EOT
cp "$tmp/ref" "$tmp/candidate"
"$root/scripts/verify_abi_crc.sh" "$tmp/ref" "$tmp/candidate" | grep -F 'CRC CHECK: PASS'
printf '0xCCCC foo vmlinux EXPORT_SYMBOL\n0xBBBB bar vmlinux EXPORT_SYMBOL_GPL\n' > "$tmp/drift"
if "$root/scripts/verify_abi_crc.sh" "$tmp/ref" "$tmp/drift" >/dev/null 2>&1; then echo 'CRC drift fixture unexpectedly passed' >&2; exit 1; fi
printf '0xDDDD explicit vmlinux EXPORT_SYMBOL\n' > "$tmp/explicit"
printf '0xEEEE cache vmlinux EXPORT_SYMBOL\n' > "$tmp/cache"
printf '0xFFFF prebuilt vmlinux EXPORT_SYMBOL\n' > "$tmp/prebuilt"
resolved=$($root/scripts/resolve_stock_symvers.sh --output "$tmp/out" --input "$tmp/explicit" --cache "$tmp/cache" --prebuilt "$tmp/prebuilt")
grep -F 'source=explicit' <<<"$resolved"
grep -F '0xDDDD explicit' "$tmp/out"
resolved=$($root/scripts/resolve_stock_symvers.sh --output "$tmp/out" --cache "$tmp/cache" --prebuilt "$tmp/prebuilt")
grep -F 'source=cache' <<<"$resolved"
resolved=$($root/scripts/resolve_stock_symvers.sh --output "$tmp/out" --prebuilt "$tmp/prebuilt")
grep -F 'source=gki-prebuilt' <<<"$resolved"
resolved=$($root/scripts/resolve_stock_symvers.sh --output "$tmp/out" --bootstrap 'printf "0x1234 bootstrapped vmlinux EXPORT_SYMBOL\\n"')
grep -F 'source=bootstrap_stock_symvers' <<<"$resolved"
echo 'fixture validation: PASS'
