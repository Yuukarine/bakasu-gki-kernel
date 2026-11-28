#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
mkdir -p "$root/.tmp"
tmp=$(mktemp -d "$root/.tmp/build-metadata.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
mkdir -p "$tmp/source" "$tmp/bin"
git -C "$tmp/source" init -q
GIT_COMMITTER_DATE=2024-01-03T04:05:06Z git -C "$tmp/source" -c user.name=fixture -c user.email=fixture@localhost \
  -c commit.gpgsign=false commit --allow-empty -qm 'fixed kernel clock' \
  --date='2024-01-02T03:04:05Z'
# The committer clock, not the author date, is the source of truth.
source_epoch=$(git -C "$tmp/source" show -s --format=%ct HEAD)
expected=$(LC_ALL=C date -u -d "@$source_epoch" '+%a %b %e %T UTC %Y')
cat > "$tmp/bin/make" <<'MAKE'
#!/usr/bin/env bash
printf '%s|%s|%s|%s\n' "$KBUILD_BUILD_USER" "$KBUILD_BUILD_HOST" "$KBUILD_BUILD_VERSION" "$KBUILD_BUILD_TIMESTAMP" >> "$METADATA_LOG"
if [[ ${*: -1} == kernelversion ]]; then printf '6.1.118\n'; exit 0; fi
exit 37
MAKE
chmod +x "$tmp/bin/make"
for iteration in 1 2; do
  set +e
  (cd "$root"; PATH="$tmp/bin:$PATH" METADATA_LOG="$tmp/metadata-$iteration" \
    KERNEL_SOURCE_DIR="$tmp/source" KERNEL_OUT=".tmp/metadata-out-$iteration" \
    STOCK_UNAME=6.1.118-android14-11-o-gac2e718ebee6 \
    KBUILD_BUILD_USER=runner KBUILD_BUILD_HOST=runnervm0j63q KBUILD_BUILD_VERSION=99 \
    KBUILD_BUILD_TIMESTAMP='runner wall clock' TZ=Asia/Tokyo \
    bash scripts/build_oneplus.sh) >"$tmp/stdout-$iteration" 2>"$tmp/stderr-$iteration"
  status=$?
  set -e
  [[ $status == 37 ]] || { cat "$tmp/stderr-$iteration" >&2; echo "unexpected mock make exit=$status" >&2; exit 1; }
  [[ $(wc -l < "$tmp/metadata-$iteration") == 2 ]]
  [[ $(sort -u "$tmp/metadata-$iteration") == "build-user|build-host|1|$expected" ]]
  rmdir "$root/.tmp/metadata-out-$iteration"
done
cmp "$tmp/metadata-1" "$tmp/metadata-2"
python3 - "$root" <<'PY'
from pathlib import Path
import sys, yaml
workflow = yaml.safe_load((Path(sys.argv[1]) / '.github/workflows/build-oneplus.yml').read_text())
env = workflow['jobs']['build']['env']
assert env['KBUILD_BUILD_USER'] == 'build-user'
assert env['KBUILD_BUILD_HOST'] == 'build-host'
assert env['KBUILD_BUILD_VERSION'] == '1'
steps = workflow['jobs']['build']['steps']
checkout = next(s['run'] for s in steps if s.get('name') == 'Checkout OnePlus source')
assert 'show -s --format=%ct HEAD' in checkout
assert 'LC_ALL=C date -u -d "@$source_epoch"' in checkout
assert 'KBUILD_BUILD_TIMESTAMP=$timestamp' in checkout
PY
printf 'deterministic build metadata fixtures: PASS\n'
