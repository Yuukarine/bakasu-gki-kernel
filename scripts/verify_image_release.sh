#!/usr/bin/env bash
# Thin compatibility wrapper around the Rust ARM64 Image/UTS gate.
set -Eeuo pipefail
usage(){ printf '%s\n' 'Usage: verify_image_release.sh --image FILE --expected RELEASE' >&2; }
image='' expected=''
while (($#)); do
  case "$1" in
    --image) [[ $# -gt 1 ]] || { usage; exit 2; }; image=$2; shift 2;;
    --expected) [[ $# -gt 1 ]] || { usage; exit 2; }; expected=$2; shift 2;;
    -h|--help) usage; exit 0;;
    *) printf 'unknown option: %s\n' "$1" >&2; usage; exit 2;;
  esac
done
[[ -s $image ]] || { printf 'image release verification: FAIL: image missing or empty: %s\n' "$image" >&2; exit 1; }
[[ $expected =~ ^[0-9]+\.[0-9]+\.[0-9]+-[^[:space:]+]+$ ]] || { printf 'image release verification: FAIL: invalid expected release: %s\n' "$expected" >&2; exit 1; }
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
default_bin="$root/tools/ktool/target/release/ktool"
ktool_bin=${KTOOL_BIN:-$default_bin}
if [[ ! -x $ktool_bin ]]; then
  command -v cargo >/dev/null 2>&1 || { echo 'ktool unavailable: cargo is required to build it' >&2; exit 2; }
  cargo build --release --locked --manifest-path "$root/tools/ktool/Cargo.toml" >&2
  ktool_bin=$default_bin
fi
[[ -x $ktool_bin ]] || { echo "ktool binary not executable: $ktool_bin" >&2; exit 2; }
args=(inspect-image "$image" --expected-uts "$expected")
if [[ -n ${KBUILD_BUILD_TIMESTAMP:-} ]]; then args+=(--expected-timestamp "$KBUILD_BUILD_TIMESTAMP"); fi
"$ktool_bin" "${args[@]}"
