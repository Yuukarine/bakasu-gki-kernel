#!/usr/bin/env bash
set -Eeuo pipefail
if [[ $# -ne 1 ]]; then printf 'usage: %s TARGET_COPY\n' "$0" >&2; exit 64; fi
target=$1
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
baseline="$self_dir/transaction/ORIGINAL_TARGET"
test -f "$baseline"
cp -- "$baseline" "$target"
