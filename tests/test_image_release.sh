#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
full_target=6.1.118-android14-11-o-gac2e718ebee6
truncated_target=${full_target%6}
grep -Fq "stock_uname: ${full_target}," "$root/.github/workflows/build-oneplus.yml"
if grep -Fq "stock_uname: ${truncated_target}," "$root/.github/workflows/build-oneplus.yml"; then
  echo 'truncated Ace 3V target remains in workflow' >&2
  exit 1
fi
tmp=$(mktemp -d "$root/.tmp/image-release.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
make_image(){
  python3 - "$tmp/Image" "$1" <<'PY'
import sys
data = bytearray(0x3c)
data[0x38:0x3c] = b'ARMd'
data += ("Linux version " + sys.argv[2] + " (builder)\0").encode()
open(sys.argv[1], 'wb').write(data)
PY
}
make_image "$full_target"
"$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target"
make_image '6.1.141+'
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/mismatch.out" 2>&1; then echo 'mismatched release unexpectedly passed' >&2; exit 1; fi
grep -Fq "expected=$full_target actual=6.1.141+" "$tmp/mismatch.out"
make_image "$full_target-dirty"
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/dirty.out" 2>&1; then echo 'dirty release unexpectedly passed' >&2; exit 1; fi
grep -Fq "actual=$full_target-dirty" "$tmp/dirty.out"
make_image "$truncated_target"
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/truncated.out" 2>&1; then echo 'truncated release unexpectedly passed' >&2; exit 1; fi
grep -Fq "actual=$truncated_target" "$tmp/truncated.out"
printf 'image release fixtures: PASS\n'
