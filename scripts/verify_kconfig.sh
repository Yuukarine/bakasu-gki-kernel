#!/usr/bin/env bash
# Thin compatibility wrapper around the Rust Kconfig gate.
set -Eeuo pipefail
usage(){ cat <<'USAGE'
Usage: verify_kconfig.sh --config FILE [--branch aosp-gki|oneplus-ogki] [--fragments DIR]
USAGE
}
args=(verify-kconfig)
while (($#)); do
  case "$1" in
    -h|--help) usage; exit 0;;
    -c|--config) [[ $# -gt 1 ]] || { usage >&2; exit 2; }; args+=(--config "$2"); shift 2;;
    -b|--branch) [[ $# -gt 1 ]] || { usage >&2; exit 2; }; args+=(--branch "$2"); shift 2;;
    -f|--fragments) [[ $# -gt 1 ]] || { usage >&2; exit 2; }; args+=(--fragments "$2"); shift 2;;
    *) echo "kconfig verification: FAIL: unknown option: $1" >&2; exit 1;;
  esac
done
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
default_bin="$root/tools/ktool/target/release/ktool"
ktool_bin=${KTOOL_BIN:-$default_bin}
if [[ ! -x $ktool_bin ]]; then
  command -v cargo >/dev/null 2>&1 || { echo 'ktool unavailable: cargo is required to build it' >&2; exit 2; }
  cargo build --release --locked --manifest-path "$root/tools/ktool/Cargo.toml" >&2
  ktool_bin=$default_bin
fi
[[ -x $ktool_bin ]] || { echo "ktool binary not executable: $ktool_bin" >&2; exit 2; }
"$ktool_bin" "${args[@]}"
