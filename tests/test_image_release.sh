#!/usr/bin/env bash
set -Eeuo pipefail
root=$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")/.." && pwd)
grep -Fq 'stock_uname: 6.1.118-android14-11-o-gac2e718ebee6,' "$root/.github/workflows/build-oneplus.yml"
if grep -Fq 'stock_uname: 6.1.118-android14-11-o-gac2e718ebee,' "$root/.github/workflows/build-oneplus.yml"; then
  echo 'truncated Ace 3V target remains in workflow' >&2
  exit 1
fi
tmp=$(mktemp -d "$root/.tmp/image-release.XXXXXX"); trap 'rm -rf "$tmp"' EXIT
printf 'fixture bytes\n' > "$tmp/Image"
cat > "$tmp/file" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux kernel ARM64 boot executable Image, little-endian, 4K pages'
EOF
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.118-android14-11-o-gac2e718ebee6 (builder)'
EOF
chmod +x "$tmp/file" "$tmp/strings"
PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee6
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.141+ (builder)'
EOF
if PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee6 >"$tmp/mismatch.out" 2>&1; then echo 'mismatched release unexpectedly passed' >&2; exit 1; fi
grep -Fq 'expected=6.1.118-android14-11-o-gac2e718ebee6 actual=6.1.141+' "$tmp/mismatch.out"
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.118-android14-11-o-gac2e718ebee6-dirty (builder)'
EOF
if PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee6 >"$tmp/dirty.out" 2>&1; then echo 'dirty release unexpectedly passed' >&2; exit 1; fi
grep -Fq 'actual=6.1.118-android14-11-o-gac2e718ebee6-dirty' "$tmp/dirty.out"
cat > "$tmp/strings" <<'EOF'
#!/bin/sh
printf '%s\n' 'Linux version 6.1.118-android14-11-o-gac2e718ebee (builder)'
EOF
if PATH="$tmp:$PATH" "$root/scripts/verify_image_release.sh" --image "$tmp/Image" --expected 6.1.118-android14-11-o-gac2e718ebee6 >"$tmp/truncated.out" 2>&1; then echo 'truncated release unexpectedly passed' >&2; exit 1; fi
grep -Fq 'actual=6.1.118-android14-11-o-gac2e718ebee' "$tmp/truncated.out"
printf 'image release fixtures: PASS\n'
