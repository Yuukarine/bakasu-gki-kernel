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
unset KBUILD_BUILD_TIMESTAMP
make_image(){
  python3 - "$tmp/Image" "$1" <<'PY'
import sys
data = bytearray(0x3c)
data[0x38:0x3c] = b'ARMd'
data += ("Linux version " + sys.argv[2] + " (build-user@build-host) (Ubuntu clang version 18.1.3 (1ubuntu1), Ubuntu LLD 18.1.3) #1 SMP PREEMPT Sat Nov 28 03:37:02 UTC 2026\n\0").encode()
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
# A real Image may contain an unfinished proc banner AND the full banner.
make_image "$full_target"
python3 - "$tmp/Image" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
data = p.read_bytes()
placeholder = data[60:].replace(b'#1 SMP PREEMPT Sat Nov 28 03:37:02 UTC 2026', b'# SMP PREEMPT ')
p.write_bytes(data + placeholder)
PY2
KBUILD_BUILD_TIMESTAMP='Sat Nov 28 03:37:02 UTC 2026' "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/full.out"
grep -Fq 'banner_placeholder: Linux version' "$tmp/full.out"
grep -Fq '#1 SMP PREEMPT Sat Nov 28 03:37:02 UTC 2026' "$tmp/full.out"
if KBUILD_BUILD_TIMESTAMP='Fri Nov 27 00:00:00 UTC 2026' "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/time.out" 2>&1; then echo 'wrong timestamp passed' >&2; exit 1; fi
grep -Fq 'expected timestamp=' "$tmp/time.out"
python3 - "$tmp/Image" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_bytes(p.read_bytes().replace(b'build-user@build-host', b'runner@runnervm0j63q'))
PY2
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/runner.out" 2>&1; then echo 'runner banner passed' >&2; exit 1; fi
grep -Fq 'runner metadata:' "$tmp/runner.out"
make_image "$full_target"
python3 - "$tmp/Image" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_bytes(p.read_bytes().replace(b'#1 SMP PREEMPT Sat Nov 28 03:37:02 UTC 2026', b'# SMP PREEMPT '))
PY2
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/placeholder.out" 2>&1; then echo 'placeholder-only banner passed' >&2; exit 1; fi
grep -Fq 'expected one distinct full banner, found 0' "$tmp/placeholder.out"
make_image "$full_target"
python3 - "$tmp/Image" "$truncated_target" <<'PY2'
from pathlib import Path
import sys
p = Path(sys.argv[1])
p.write_bytes(p.read_bytes() + ('Linux version ' + sys.argv[2] + ' (build-user@build-host) (clang) # SMP PREEMPT \0').encode())
PY2
if "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected "$full_target" >"$tmp/conflict.out" 2>&1; then echo 'conflicting placeholder release passed' >&2; exit 1; fi
grep -Fq 'expected one Linux version, found 2' "$tmp/conflict.out"
printf 'image release fixtures: PASS\n'
