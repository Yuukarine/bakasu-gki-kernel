#!/usr/bin/env bash
set -Eeuo pipefail
[[ $# -eq 1 ]] || { echo "usage: $0 TARGET_COPY" >&2; exit 64; }
self_dir=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)
cp -- "$self_dir/transaction/ORIGINAL_TARGET" "$1"
