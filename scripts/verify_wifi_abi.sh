#!/usr/bin/env bash
# Fail closed: requirements never establish that a missing provider exists.
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
profile="$root/configs/abi/ace3v-cn01-16.0.3.500"
[[ $# == 2 && $1 == --kernel ]] || { echo 'usage: verify_wifi_abi.sh --kernel Module.symvers' >&2; exit 1; }
kernel=$2
ktool=${KTOOL_BIN:-$root/tools/ktool/target/release/ktool}
if [[ ! -x $ktool ]]; then
  cargo build --release --locked --manifest-path "$root/tools/ktool/Cargo.toml" >&2
fi
"$ktool" verify-module-abi --imports "$profile/imports.tsv" --exports "$profile/exports.tsv" --modules "$profile/modules.txt" --kernel "$kernel"
