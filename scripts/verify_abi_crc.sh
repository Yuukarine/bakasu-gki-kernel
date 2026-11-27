#!/usr/bin/env bash
# Thin compatibility wrapper around the deterministic Rust ABI gate.
set -Eeuo pipefail
usage(){ cat <<'USAGE'
Usage: verify_abi_crc.sh [--bore] [--reference FILE --candidate FILE] REFERENCE CANDIDATE
USAGE
}
ref='' cand='' bore=0
while (($#)); do case "$1" in
  -h|--help) usage; exit 0;; --bore) bore=1; shift;; --reference) [[ $# -gt 1 ]] || { usage >&2; exit 2; }; ref=$2; shift 2;; --candidate) [[ $# -gt 1 ]] || { usage >&2; exit 2; }; cand=$2; shift 2;;
  --) shift; break;; -*) echo "unknown option: $1" >&2; exit 2;;
  *) if [[ -z $ref ]]; then ref=$1; elif [[ -z $cand ]]; then cand=$1; else echo "unexpected argument: $1" >&2; exit 2; fi; shift;;
esac; done
[[ -n $ref && -n $cand ]] || { usage >&2; exit 2; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
default_bin="$root/tools/ktool/target/release/ktool"
ktool_bin=${KTOOL_BIN:-$default_bin}
if [[ ! -x $ktool_bin ]]; then
  command -v cargo >/dev/null 2>&1 || { echo 'ktool unavailable: cargo is required to build it' >&2; exit 2; }
  cargo build --release --locked --manifest-path "$root/tools/ktool/Cargo.toml" >&2
  ktool_bin=$default_bin
fi
[[ -x $ktool_bin ]] || { echo "ktool binary not executable: $ktool_bin" >&2; exit 2; }
args=(verify-abi "$ref" "$cand")
(( bore )) && args+=(--bore)
"$ktool_bin" "${args[@]}"
